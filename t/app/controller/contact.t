use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/contact');
$mech->title_like(qr/Contact Us/);
$mech->content_contains("It's often quickest to ");

my $problem_main;

for my $test (
    {
        name      => 'A User',
        email     => 'problem_report_test@example.com',
        title     => 'Some problem or other',
        detail    => 'More detail on the problem',
        postcode  => 'EH99 1SP',
        confirmed => '2011-05-04 10:44:28.145168',
        anonymous => 0,
        meta      => 'Reported by A User at 10:44, Wed  4 May 2011',
        main      => 1,
    },
    {
        name      => 'A User',
        email     => 'problem_report_test@example.com',
        title     => 'A different problem',
        detail    => 'More detail on the different problem',
        postcode  => 'EH99 1SP',
        confirmed => '2011-05-03 13:24:28.145168',
        anonymous => 1,
        meta      => 'Reported anonymously at 13:24, Tue  3 May 2011',
    },
    {
        name      => 'A User',
        email     => 'problem_report_test@example.com',
        title     => 'A different problem',
        detail    => 'More detail on the different problem',
        postcode  => 'EH99 1SP',
        confirmed => '2011-05-03 13:24:28.145168',
        anonymous => 1,
        meta      => 'Reported anonymously at 13:24, Tue  3 May 2011',
        update    => {
            name  => 'Different User',
            email => 'commenter@example.com',
            text  => 'This is an update',
        },
    },
  )
{
    subtest 'check reporting a problem displays correctly' => sub {
        my $user = FixMyStreet::App->model('DB::User')->find_or_create(
            {
                name  => $test->{name},
                email => $test->{email}
            }
        );

        my $problem = FixMyStreet::App->model('DB::Problem')->create(
            {
                title     => $test->{title},
                detail    => $test->{detail},
                postcode  => $test->{postcode},
                confirmed => $test->{confirmed},
                name      => $test->{name},
                anonymous => $test->{anonymous},
                state     => 'confirmed',
                user      => $user,
                latitude  => 0,
                longitude => 0,
                areas     => 0,
                used_map  => 0,
            }
        );

        my $update;

        if ( $test->{update} ) {
            my $update_info = $test->{update};
            my $update_user = FixMyStreet::App->model('DB::User')->find_or_create(
                {
                    name  => $update_info->{name},
                    email => $update_info->{email}
                }
            );

            $update = FixMyStreet::App->model('DB::Comment')->create(
                {
                    problem_id => $problem->id,
                    user        => $update_user,
                    state       => 'confirmed',
                    text        => $update_info->{text},
                    confirmed   => \'current_timestamp',
                    mark_fixed => 'f',
                    anonymous  => 'f',
                }
            );
        }

        ok $problem, 'succesfully create a problem';

        if ( $update ) {
            $mech->get_ok( '/contact?id=' . $problem->id . '&update_id=' . $update->id );
            $mech->content_contains('reporting the following update');
            $mech->content_contains( $test->{update}->{text} );
        } else {
            $mech->get_ok( '/contact?id=' . $problem->id );
            $mech->content_contains('reporting the following problem');
            $mech->content_contains( $test->{title} );
            $mech->content_contains( $test->{meta} );
        }

        $update->delete if $update;
        if ($test->{main}) {
            $problem_main = $problem;
        } else {
            $problem->delete;
        }
    };
}

for my $test (
    {
        fields => {
            em      => ' ',
            name    => '',
            subject => '',
            message => '',
        },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'Please enter your name',
            'Please enter your email',
            'Please enter a subject',
            'Please write a message',
        ]
    },
    {
        fields => {
            em      => 'invalidemail',
            name    => '',
            subject => '',
            message => '',
        },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'Please enter your name',
            'Please enter a valid email address',
            'Please enter a subject',
            'Please write a message',
        ]
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => '',
            message => '',
        },
        page_errors => [
            'There were problems with your report. Please see below.',
            'Please enter a subject', 'Please write a message',
        ]
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => '',
        },
        page_errors => [
            'There were problems with your report. Please see below.',
            'Please write a message',
        ]
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => '  ',
            message => '',
        },
        page_errors => [
            'There were problems with your report. Please see below.',
            'Please enter a subject',
            'Please write a message',
        ]
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => ' ',
        },
        page_errors => [
            'There were problems with your report. Please see below.',
            'Please write a message',
        ]
    },
    {
        url    => '/contact?id=' . $problem_main->id,
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            id      => 'invalid',
        },
        page_errors  => [ 'Illegal ID' ],
    },
  )
{
    subtest 'check submit page error handling' => sub {
        $mech->get_ok( $test->{url} ? $test->{url} : '/contact' );
        $mech->submit_form_ok( { with_fields => $test->{fields} } );
        is_deeply $mech->page_errors, $test->{page_errors}, 'page errors';

        # we santise this when we submit so need to remove it
        delete $test->{fields}->{id}
          if $test->{fields}->{id} and $test->{fields}->{id} eq 'invalid';
        is_deeply $mech->visible_form_values, $test->{fields}, 'form values';
    };
}

for my $test (
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
        },
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            id      => $problem_main->id,
        },
    },

  )
{
    subtest 'check email sent correctly' => sub {
        $problem_main->discard_changes;
        ok !$problem_main->flagged, 'problem not flagged';

        $mech->clear_emails_ok;
        if ($test->{fields}{id}) {
            $mech->get_ok('/contact?id=' . $test->{fields}{id});
        } else {
            $mech->get_ok('/contact');
        }
        $mech->submit_form_ok( { with_fields => $test->{fields} } );
        $mech->content_contains('Thank you for your feedback');
        $mech->email_count_is(1);

        my $email = $mech->get_email;

        is $email->header('Subject'), 'FMS message: ' .  $test->{fields}->{subject}, 'subject';
        is $email->header('From'), "\"$test->{fields}->{name}\" <$test->{fields}->{em}>", 'from';
        like $email->body, qr/$test->{fields}->{message}/, 'body';
        like $email->body, qr/Sent by contact.cgi on \S+. IP address (?:\d{1,3}\.){3,}\d{1,3}/, 'body footer';
        my $problem_id = $test->{fields}{id};
        like $email->body, qr/Complaint about report $problem_id/, 'reporting a report'
            if $test->{fields}{id};

        $problem_main->discard_changes;
        if ( $problem_id ) {
            ok $problem_main->flagged, 'problem flagged';
        } else {
            ok !$problem_main->flagged, 'problem not flagged';
        }

    };
}

for my $test (
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            dest    => undef,
        },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'Please enter who your message is for',
        ]
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            dest    => 'council',
        },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'You can only contact the team behind FixMyStreet using our contact form',
        ]
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            dest    => 'update',
        },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'You can only contact the team behind FixMyStreet using our contact form',
        ]
    },
  )
{
    subtest 'check submit page incorrect destination handling' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'fixmystreet' ],
        }, sub {
            $mech->host('www.fixmystreet.com');
            $mech->get_ok( $test->{url} ? $test->{url} : '/contact' );
            $mech->submit_form_ok( { with_fields => $test->{fields} } );
            is_deeply $mech->page_errors, $test->{page_errors}, 'page errors';

            # we santise this when we submit so need to remove it
            delete $test->{fields}->{id}
              if $test->{fields}->{id} and $test->{fields}->{id} eq 'invalid';
            is_deeply $mech->visible_form_values, $test->{fields}, 'form values';

            if ( $test->{fields}->{dest} and $test->{fields}->{dest} eq 'update' ) {
                $mech->content_contains( 'www.writetothem.com', 'includes link to WTT if trying to update report' );
            } elsif ( $test->{fields}->{dest} and $test->{fields}->{dest} eq 'council' ) {
                $mech->content_lacks( 'www.writetothem.com', 'does not include link to WTT if trying to contact council' );
                $mech->content_contains( 'should find contact details', 'mentions checking council website for contact details' );
            }
        }
    };
}

for my $test (
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            dest    => 'help',
        },
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            dest    => 'feedback',
        },
    },
    {
        fields => {
            em      => 'test@example.com',
            name    => 'A name',
            subject => 'A subject',
            message => 'A message',
            dest    => 'from_council',
        },
    },
  )
{
    subtest 'check email sent correctly with dest field set to us' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'fixmystreet' ],
        }, sub {
            $mech->clear_emails_ok;
            $mech->get_ok('/contact');
            $mech->submit_form_ok( { with_fields => $test->{fields} } );
            $mech->content_contains('Thank you for your feedback');
            $mech->email_count_is(1);
        }
    };
}

$problem_main->delete;

done_testing();
