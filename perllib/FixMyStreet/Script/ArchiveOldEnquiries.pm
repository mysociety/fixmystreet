package FixMyStreet::Script::ArchiveOldEnquiries;

use v5.14;
use warnings;

use FixMyStreet::DB;
use FixMyStreet::Cobrand;
use FixMyStreet::Map;
use FixMyStreet::Email;


my $opts = {
    commit => 0,
    closed_state => 'closed',
};

sub query {
    my $rs = shift;
    return $rs->to_body($opts->{body})->search({
        -and => [
          lastupdate => { '<', $opts->{email_cutoff} },
          lastupdate => { '>', $opts->{closure_cutoff} },
        ],
        state => [ FixMyStreet::DB::Result::Problem->open_states() ],
    });
}

sub update_options {
    my $params = shift;
    if ( $params ) {
        $opts = {
            %$opts,
            %$params,
        };
    }
}

sub archive {
    my $params = shift;
    update_options($params);

    unless ( $opts->{commit} ) {
        printf "Doing a dry run; emails won't be sent and reports won't be closed.\n";
        printf "Re-run with --commit to actually archive reports.\n\n";
    }

    my $rs = FixMyStreet::DB->resultset('Problem');
    my @user_ids = query($rs)->search(undef,
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
    my $problem_count = query($rs)->search(undef,
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

    my $problems_to_close = $rs->to_body($opts->{body})->search({
        lastupdate => { '<', $opts->{closure_cutoff} },
        state      => [ FixMyStreet::DB::Result::Problem->open_states() ],
    }, {
        rows => $opts->{limit},
    });

    printf("Closing %d old reports, without sending emails: ", $problems_to_close->count);
    close_problems($problems_to_close);
    printf("done.\n")
}

sub send_email_and_close {
    my ($user) = @_;

    my $problems = $user->problems;
    $problems = query($problems)->search(undef, {
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
        close_problems($problems);
        printf("done.\n");
    } else {
        printf("error! Not closing reports for this user.\n")
    }
}

sub close_problems {
    return unless $opts->{commit};

    my $problems = shift;

    my $extra = { auto_closed_by_script => 1 };
    $extra->{is_superuser} = 1 if !$opts->{user_name};

    my $cobrand;
    while (my $problem = $problems->next) {
        # need to do this in case no reports were closed with an
        # email in which case we won't have set the lang and domain
        if ($opts->{cobrand} && !$cobrand) {
            $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($opts->{cobrand})->new();
            $cobrand->set_lang_and_domain($problem->lang, 1);
        }

        my $timestamp = \'current_timestamp';
        my $comment = $problem->add_to_comments( {
            text => $opts->{closure_text} || '',
            created => $timestamp,
            confirmed => $timestamp,
            user_id => $opts->{user},
            name => $opts->{user_name} || _('an administrator'),
            mark_fixed => 0,
            anonymous => 0,
            state => 'confirmed',
            problem_state => $opts->{closed_state},
            extra => $extra,
        } );
        $problem->update({ state => $opts->{closed_state}, send_questionnaire => 0 });

        next if $opts->{retain_alerts};

        # Stop any alerts being sent out about this closure.
        my @alerts = FixMyStreet::DB->resultset('Alert')->search( {
            alert_type => 'new_updates',
            parameter  => $problem->id,
            confirmed  => 1,
        } );

        for my $alert (@alerts) {
            my $alerts_sent = FixMyStreet::DB->resultset('AlertSent')->find_or_create( {
                alert_id  => $alert->id,
                parameter => $comment->id,
            } );
        }

    }
}
