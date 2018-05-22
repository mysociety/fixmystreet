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
has email => ( is => 'ro' );
has verbose => ( is => 'ro' );
has dry_run => ( is => 'ro' );

sub BUILDARGS {
    my ($cls, %args) = @_;
    $args{dry_run} = delete $args{'dry-run'};
    return \%args;
}

has cobrand => (
    is => 'lazy',
    default => sub {
        my $base_url = FixMyStreet->config('BASE_URL');
        my $site = CronFns::site($base_url);
        FixMyStreet::Cobrand->get_class_for_moniker($site)->new;
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
    $self->close_updates if $self->close;
}

sub close_updates {
    my $self = shift;

    my $problems = FixMyStreet::DB->resultset("Problem")->search({
        lastupdate => { '<', interval($self->close) },
        state => [ FixMyStreet::DB::Result::Problem->closed_states(), FixMyStreet::DB::Result::Problem->fixed_states() ],
        extra => [ undef, { -not_like => '%closed_updates%' } ],
    });

    while (my $problem = $problems->next) {
        say "Closing updates on problem #" . $problem->id if $self->verbose;
        next if $self->dry_run;
        $problem->set_extra_metadata( closed_updates => 1 );
        $problem->update;
    }
}

sub anonymize_reports {
    my $self = shift;

    # Need to look though them all each time, in case any new updates/alerts
    my $problems = FixMyStreet::DB->resultset("Problem")->search({
        lastupdate => { '<', interval($self->anonymize) },
        state => [ FixMyStreet::DB::Result::Problem->closed_states(), FixMyStreet::DB::Result::Problem->fixed_states() ],
    });

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
        FixMyStreet::DB->resultset('Alert')->search({
            user_id => { '!=' => $self->anonymous_user->id },
            alert_type => 'new_updates',
            parameter => $problem->id,
        })->update({
            user_id => $self->anonymous_user->id,
            whendisabled => \'current_timestamp',
        });
    }
}

sub anonymize_users {
    my $self = shift;

    my $users = FixMyStreet::DB->resultset("User")->search({
        last_active => { '<', interval($self->anonymize) },
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
            },
            { To => [ $user->email, $user->name ] },
            undef, 0, $self->cobrand,
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
