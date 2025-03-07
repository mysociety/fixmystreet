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
has category => ( is => 'ro' );
has state => ( is => 'ro' );
has created => ( is => 'ro' );

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

    my $problems = $self->_relevant_reports($self->close, 0);
    $problems = $problems->search({
        -or => [
            extra => undef,
            -not => { extra => { '\?' => 'closed_updates' } }
        ],
    });

    while (my $problem = $problems->next) {
        say "Closing updates on problem #" . $problem->id if $self->verbose;
        next if $self->dry_run;
        $problem->set_extra_metadata( closed_updates => 1 );
        $problem->update;
    }
}

sub _relevant_reports {
    my ($self, $time, $include_hidden) = @_;
    my $field = $self->created ? 'created' : 'lastupdate';
    my @states;
    if ($self->state) {
        if ($self->state ne 'all') {
            push @states, $self->state;
        }
    } else {
        push @states, FixMyStreet::DB::Result::Problem->closed_states(),
            FixMyStreet::DB::Result::Problem->fixed_states();
        push @states, FixMyStreet::DB::Result::Problem->hidden_states()
            if $include_hidden;
    }
    my $problems = FixMyStreet::DB->resultset("Problem")->search({
        $field => { '<', interval($time) },
        @states ? (state => \@states) : (),
        $self->category ? (category => $self->category) : (),
        $self->cobrand ? (cobrand => $self->cobrand->moniker) : (),
    })->order_by('id');
    return $problems;
}

sub anonymize_reports {
    my $self = shift;

    # Need to look though them all each time, in case any new updates/alerts
    my $problems = $self->_relevant_reports($self->anonymize, 1);

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

    my $problems = $self->_relevant_reports($self->delete, 1);
    if ($self->cobrand) {
        $problems = $self->cobrand->call_hook(inactive_reports_filter => $self->delete, $problems) || $problems;
    }

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

sub _body_users {
    my $body_users = FixMyStreet::DB->resultset("Body")->search({
        comment_user_id => { '!=' => undef },
    }, {
        columns => 'comment_user_id',
    });
    return $body_users;
}

sub _anon_users {
    my @email;
    foreach (FixMyStreet::Cobrand->available_cobrand_classes) {
        next unless $_->{class};
        my $d = $_->{class}->anonymous_account or next;
        push @email, $d->{email};
    }
    return \@email;
}

sub anonymize_users {
    my $self = shift;

    my $body_users = _body_users();
    my $anon_users = _anon_users();
    my $users = FixMyStreet::DB->resultset("User")->search({
        last_active => { '<', interval($self->anonymize) },
        id => { -not_in => $body_users->as_query },
        email => [ -and =>
            { -not_like => 'removed-%@' . FixMyStreet->config('EMAIL_DOMAIN') },
            { -not_in => $anon_users },
        ],
    });

    while (my $user = $users->next) {
        say "Anonymizing user #" . $user->id if $self->verbose;
        next if $self->dry_run;
        $user->anonymize_account;
    }
}

sub email_inactive_users {
    my $self = shift;

    my $body_users = _body_users();
    my $anon_users = _anon_users();
    my $users = FixMyStreet::DB->resultset("User")->search({
        last_active => [ -and => { '<', interval($self->email) },
            { '>=', interval($self->anonymize) } ],
        id => { -not_in => $body_users->as_query },
        email => { -not_in => $anon_users },
    });
    while (my $user = $users->next) {
        next if $user->get_extra_metadata('inactive_email_sent');
        next unless $user->email && $user->email_verified;

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
    if ($interval =~ /^(\d+)m?$/) {
        $interval = "$1 months";
    } elsif ($interval =~ /^(\d+)d$/) {
        $interval = "$1 days";
    }
    my $s = "current_timestamp - '$interval'::interval";
    return \$s;
}

1;
