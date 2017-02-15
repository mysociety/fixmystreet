package FixMyStreet::Script::ArchiveOldEnquiries;

use strict;
use warnings;
require 5.8.0;

use FixMyStreet;
use FixMyStreet::App;
use FixMyStreet::DB;
use FixMyStreet::Cobrand;
use FixMyStreet::Map;
use FixMyStreet::Email;


my $opts = {
    commit => 0,
    body => '2237',
    cobrand => 'oxfordshire',
    closure_cutoff => "2015-01-01 00:00:00",
    email_cutoff => "2016-01-01 00:00:00",
};

sub query {
    return {
        bodies_str => { 'LIKE', "%".$opts->{body}."%"},
        -and       => [
          lastupdate => { '<', $opts->{email_cutoff} },
          lastupdate => { '>', $opts->{closure_cutoff} },
        ],
        state      => [ FixMyStreet::DB::Result::Problem->open_states() ],
    };
}

sub archive {
    my $params = shift;
    if ( $params ) {
        $opts = {
            %$opts,
            %$params,
        };
    }

    unless ( $opts->{commit} ) {
        printf "Doing a dry run; emails won't be sent and reports won't be closed.\n";
        printf "Re-run with --commit to actually archive reports.\n\n";
    }

    my @user_ids = FixMyStreet::DB->resultset('Problem')->search(query(),
    {
        distinct => 1,
        columns  => ['user_id'],
        rows => $opts->{limit},
    })->all;

    @user_ids = map { $_->user_id } @user_ids;

    my $users = FixMyStreet::DB->resultset('User')->search({
        id => \@user_ids
    });

    my $user_count = $users->count;
    my $problem_count = FixMyStreet::DB->resultset('Problem')->search(query(),
    {
        columns  => ['id'],
        rows => $opts->{limit},
    })->count;

    printf("%d users will receive closure emails about %d reports which will be closed.\n", $user_count, $problem_count);

    if ( $opts->{commit} ) {
        my $i = 0;
        while ( my $user = $users->next ) {
            printf("%d/%d: User ID %d\n", ++$i, $user_count, $user->id);
            send_email_and_close($user);
        }
    }

    my $problems_to_close = FixMyStreet::DB->resultset('Problem')->search({
        bodies_str => { 'LIKE', "%".$opts->{body}."%"},
        lastupdate => { '<', $opts->{closure_cutoff} },
        state      => [ FixMyStreet::DB::Result::Problem->open_states() ],
    }, {
        rows => $opts->{limit},
    });

    printf("Closing %d old reports, without sending emails: ", $problems_to_close->count);

    if ( $opts->{commit} ) {
        $problems_to_close->update({ state => 'closed', send_questionnaire => 0 });
    }

    printf("done.\n")
}

sub send_email_and_close {
    my ($user) = @_;

    my $problems = $user->problems->search(query(), {
        order_by => { -desc => 'confirmed' },
    });

    my @problems = $problems->all;

    return if scalar(@problems) == 0;

    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($opts->{cobrand})->new();
    $cobrand->set_lang_and_domain($problems[0]->lang, 1);
    FixMyStreet::Map::set_map_class($cobrand->map_type);

    my %h = (
      reports => [@problems],
      report_count => scalar(@problems),
      site_name => $cobrand->moniker,
      user => $user,
      cobrand => $cobrand,
    );

    # Send email
    printf("    Sending email about %d reports: ", scalar(@problems));
    my $email_error = FixMyStreet::Email::send_cron(
        $problems->result_source->schema,
        'archive.txt',
        \%h,
        {
            To => [ [ $user->email, $user->name ] ],
        },
        undef,
        undef,
        $cobrand,
        $problems[0]->lang,
    );

    unless ( $email_error ) {
        printf("done.\n    Closing reports: ");

        $problems->update({ state => 'closed', send_questionnaire => 0 });
        printf("done.\n");
    } else {
        printf("error! Not closing reports for this user.\n")
    }
}
