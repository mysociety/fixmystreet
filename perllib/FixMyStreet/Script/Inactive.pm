package FixMyStreet::Script::Inactive;

use v5.14;
use warnings;

use Moo;
use CronFns;
use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;

has anonymize => ( is => 'ro' );
has close => ( is => 'ro' );
has delete => ( is => 'ro' );
has email => ( is => 'ro' );
has verbose => ( is => 'ro' );
has dry_run => ( is => 'ro' );

has cobrand => (
    is => 'ro',
    coerce => sub { FixMyStreet::Cobrand->get_class_for_moniker($_[0])->new },
);

sub BUILDARGS {
    my ($cls, %args) = @_;
    $args{dry_run} = delete $args{'dry-run'};
    return \%args;
}

has base_cobrand => (
    is => 'lazy',
    default => sub {
        my $base_url = FixMyStreet->config('BASE_URL');
        my $site = CronFns::site($base_url);
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($site)->new;
        $cobrand->set_lang_and_domain(undef, 1);
        $cobrand;
    },
);

has anonymous_user => (
    is => 'lazy',
    default => sub {
        FixMyStreet::DB->resultset("User")->find_or_create({
            email => 'removed-automatically@' . FixMyStreet->config('EMAIL_DOMAIN'),
        });
    }
);

sub users {
    my $self = shift;

    say "DRY RUN" if $self->dry_run;
    $self->anonymize_users;
    $self->email_inactive_users if $self->email;
}

sub reports {
    my $self = shift;

    say "DRY RUN" if $self->dry_run;
    $self->anonymize_reports if $self->anonymize;
    $self->delete_reports if $self->delete;
    $self->close_updates if $self->close;
}

sub close_updates {
    my $self = shift;

    my $problems = FixMyStreet::DB->resultset("Problem")->search({
        lastupdate => { '<', interval($self->close) },
        state => [ FixMyStreet::DB::Result::Problem->closed_states(), FixMyStreet::DB::Result::Problem->fixed_states() ],
        extra => [ undef, { -not_like => '%closed_updates%' } ],
    });
    $problems = $problems->search({ cobrand => $self->cobrand->moniker }) if $self->cobrand;

    while (my $problem = $problems->next) {
        say "Closing updates on problem #" . $problem->id if $self->verbose;
        next if $self->dry_run;
        $problem->set_extra_metadata( closed_updates => 1 );
        $problem->update;
    }
}

sub _relevant_reports {
    my ($self, $time) = @_;
    my $problems = FixMyStreet::DB->resultset("Problem")->search({
        lastupdate => { '<', interval($time) },
        state => [
            FixMyStreet::DB::Result::Problem->closed_states(),
            FixMyStreet::DB::Result::Problem->fixed_states(),
            FixMyStreet::DB::Result::Problem->hidden_states(),
        ],
    });
    if ($self->cobrand) {
        $problems = $problems->search({ cobrand => $self->cobrand->moniker });
        $problems = $self->cobrand->call_hook(inactive_reports_filter => $time, $problems) || $problems;
    }
    return $problems;
}

sub anonymize_reports {
    my $self = shift;

    # Need to look though them all each time, in case any new updates/alerts
    my $problems = $self->_relevant_reports($self->anonymize);

    while (my $problem = $problems->next) {
        say "Anonymizing problem #" . $problem->id if $self->verbose;
        next if $self->dry_run;

        # Remove personal data from the report
        $problem->update({
            user => $self->anonymous_user,
            name => '',
            anonymous => 1,
            send_questionnaire => 0,
        }) if $problem->user != $self->anonymous_user;

        # Remove personal data from the report's updates
        $problem->comments->search({
            user_id => { '!=' => $self->anonymous_user->id },
        })->update({
            user_id => $self->anonymous_user->id,
            name => '',
            anonymous => 1,
        });

        # Remove alerts - could just delete, but of interest how many there were, perhaps?
        $problem->alerts->search({
            user_id => { '!=' => $self->anonymous_user->id },
        })->update({
            user_id => $self->anonymous_user->id,
            whendisabled => \'current_timestamp',
        });
    }
}

sub delete_reports {
    my $self = shift;

    my $problems = $self->_relevant_reports($self->delete);

    while (my $problem = $problems->next) {
        say "Deleting associated data of problem #" . $problem->id if $self->verbose;
        next if $self->dry_run;

        $problem->comments->delete;
        $problem->questionnaires->delete;
        $problem->alerts->delete;
    }
    say "Deleting all matching problems" if $self->verbose;
    return if $self->dry_run;
    $problems->delete;
}

sub anonymize_users {
    my $self = shift;

    my $users = FixMyStreet::DB->resultset("User")->search({
        last_active => { '<', interval($self->anonymize) },
        email => { -not_like => 'removed-%@' . FixMyStreet->config('EMAIL_DOMAIN') },
    });

    while (my $user = $users->next) {
        say "Anonymizing user #" . $user->id if $self->verbose;
        next if $self->dry_run;
        $user->anonymize_account;
    }
}

sub email_inactive_users {
    my $self = shift;

    my $users = FixMyStreet::DB->resultset("User")->search({
       last_active => [ -and => { '<', interval($self->email) },
           { '>=', interval($self->anonymize) } ],
    });
    while (my $user = $users->next) {
        next if $user->get_extra_metadata('inactive_email_sent');

        say "Emailing user #" . $user->id if $self->verbose;
        next if $self->dry_run;
        FixMyStreet::Email::send_cron(
            $user->result_source->schema,
            'inactive-account.txt',
            {
                email_from => $self->email,
                anonymize_from => $self->anonymize,
                user => $user,
                url => $self->base_cobrand->base_url_with_lang . '/my',
            },
            { To => [ [ $user->email, $user->name ] ] },
            undef, 0, $self->base_cobrand,
        );

        $user->set_extra_metadata('inactive_email_sent', 1);
        $user->update;
    }
}

sub interval {
    my $interval = shift;
    my $s = "current_timestamp - '$interval months'::interval";
    return \$s;
}

1;
