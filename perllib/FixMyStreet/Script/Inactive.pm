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
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($site)->new;
        $cobrand->set_lang_and_domain(undef, 1);
        $cobrand;
    },
);

sub users {
    my $self = shift;

    say "DRY RUN" if $self->dry_run;
    $self->anonymize_users;
    $self->email_inactive_users if $self->email;
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
                url => $self->cobrand->base_url_with_lang . '/my',
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
