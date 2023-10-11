package FixMyStreet::Script::ArchiveOldEnquiries;

use v5.14;
use warnings;
use Text::CSV;
use Path::Tiny;

use FixMyStreet::DB;
use FixMyStreet::Cobrand;
use FixMyStreet::Map;
use FixMyStreet::Email;


my $opts = {
    commit => 0,
    closed_state => 'closed',
};

sub filter {
    my $rs = shift;
    $rs ||= FixMyStreet::DB->resultset('Problem');
    my $params = {
        state => [ FixMyStreet::DB::Result::Problem->open_states() ],
    };
    if ($opts->{category}) {
        $params->{category} = $opts->{category};
    }
    return $rs->to_body($opts->{body})->search($params);
}

sub query {
    my $rs = shift;
    return filter($rs)->search({
        -and => [
          lastupdate => { '<', $opts->{email_cutoff} },
          lastupdate => { '>', $opts->{closure_cutoff} },
        ],
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

    if ($opts->{'show-emails'}) {
        $opts->{show_emails} = $opts->{'show-emails'};
    }
}

sub archive {
    my $params = shift;
    update_options($params);

    unless ( $opts->{commit} ) {
        printf "Doing a dry run; emails won't be sent and reports won't be closed.\n";
        printf "Re-run with --commit to actually archive reports.\n\n";
    }

    if ($opts->{show_emails}) {
        if ($opts->{reports} || $opts->{commit}) {
            die "Aborting: the show_emails flag was specified with --commit or --reports. Run without --show_emails to close reports.\n";
        }
    }

    if ( $opts->{reports} ) {
        close_list()
    } elsif ( $opts->{closure_cutoff} ) {
        close_with_emails();
    }
}

sub close_list {
    my $reports = get_ids_from_csv();
    my $max_reports = scalar @$reports;

    my $rs = filter()->search({ id => $reports });

    my $no_message = $rs->search({
        lastupdate => { '<', $opts->{closure_cutoff} },
    });

    my $with_message = $rs->search({
        lastupdate => { '>=', $opts->{closure_cutoff} },
    });

    die "Found more reports than expected\n" if $no_message->count + $with_message->count > $max_reports;

    $opts->{retain_alerts} = 1;

    printf("Closing %d reports, with alerts: ", $with_message->count);
    close_problems($with_message);
    printf "done\n";
    $opts->{retain_alerts} = 0;
    printf("Closing %d reports, without alerts: ", $no_message->count);
    close_problems($no_message);
    printf "done\n";
}

sub get_ids_from_csv {
    my @report_ids;

    my $csv = Text::CSV->new;
    open my $fh, "<:encoding(utf-8)", $opts->{reports} or die "Failed to open $opts->{reports}: $!\n";
    while (my $line = $csv->getline($fh)) {
        push @report_ids, $line->[0] if $line->[0] =~ m/^\d+$/;
    }

    return \@report_ids;
}

sub get_closure_message {
    return $opts->{closure_text} if $opts->{closure_text};

    if ( $opts->{closure_file} ) {
        my $file = path($opts->{closure_file});
        chomp(my $message = $file->slurp_utf8);
        return $message;
    } else {
        my $cobrand;
        eval {
            $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($opts->{cobrand})->new()->council_area;
        };
        if ($@) {
            $cobrand = 'your council area';
        }
        my $message = "FixMyStreet is being updated in " . $cobrand . " to improve how problems get reported.\n\nAs part of this process we are closing all reports made before the update.\n\nAll of your reports will have been received and reviewed by " . $cobrand . " but, if you believe that this issue has not been resolved, please open a new report on it.\n\nThank you.";
        return $message;
    }
}

sub close_with_emails {
    die "Please provide the name of a cobrand for the archive email template" unless $opts->{cobrand};
    die "Please provide an email_cutoff option" unless $opts->{email_cutoff};
    my @user_ids = query()->search(undef,
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
    my $problem_count = query()->search(undef,
    {
        columns  => ['id'],
        rows => $opts->{limit},
    })->count;

    printf("%d users will receive closure emails about %d reports which will be closed.\n", $user_count, $problem_count);

    if ( $opts->{commit} || $opts->{show_emails} ) {
        my $i = 0;
        while ( my $user = $users->next ) {
            printf("%d/%d: User ID %d\n", ++$i, $user_count, $user->id);
            send_email_and_close($user);
        }
    }

    my $problems_to_close = filter()->search({
        lastupdate => { '<', $opts->{closure_cutoff} },
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
    FixMyStreet::Map::set_map_class($cobrand);

    my %h = (
      reports => [@problems],
      report_count => scalar(@problems),
      site_name => $cobrand->moniker,
      user => $user,
      cobrand => $cobrand,
    );

    # Send email
    printf("    Sending email about %d reports: ", scalar(@problems));

    my $output_email_as_string = $opts->{show_emails} ? 1 : 0;

    my $email_error = FixMyStreet::Email::send_cron(
        $problems->result_source->schema,
        'archive-old-enquiries.txt',
        \%h,
        {
            To => [ [ $user->email, $user->name ] ],
        },
        undef,
        $output_email_as_string,
        $cobrand,
        $problems[0]->lang,
    );

    unless ( $email_error ) {
        printf("done.\n    Closing reports: ");
        close_problems($problems);
        printf("done.\n");
    } else { # test: emails went to std. output
        if ( $opts->{show_emails} ) {
            printf("done.\n");
        } else { # genuine error
            printf("error! Not closing reports for this user.\n$email_error")
        }
    }
}

sub close_problems {
    return unless $opts->{commit};

    my $problems = shift;

    my $extra = { auto_closed_by_script => 1 };

    my $cobrand;
    while (my $problem = $problems->next) {
        # need to do this in case no reports were closed with an
        # email in which case we won't have set the lang and domain
        if ($opts->{cobrand} && !$cobrand) {
            $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($opts->{cobrand})->new();
            $cobrand->set_lang_and_domain($problem->lang, 1);
        }

        my $comment = $problem->add_to_comments( {
            text => get_closure_message() || '',
            user => FixMyStreet::DB->resultset("User")->find($opts->{user}),
            problem_state => $opts->{closed_state},
            extra => $extra,
            send_state => 'processed',
        } );
        $problem->update({ state => $opts->{closed_state}, send_questionnaire => 0 });

        next if $opts->{retain_alerts};

        # Stop any alerts being sent out about this closure.
        $problem->cancel_update_alert($comment->id);
    }
}
