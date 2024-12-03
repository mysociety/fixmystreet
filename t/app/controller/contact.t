use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::AbuseOnly;

use base 'FixMyStreet::Cobrand::Default';

sub abuse_reports_only { 1; }

1;

package FixMyStreet::Cobrand::GeneralEnquiries;

use base 'FixMyStreet::Cobrand::Default';

sub abuse_reports_only { 1 }

sub setup_general_enquiries_stash { 1 }

1;

package main;

use FixMyStreet::TestMech;
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/contact');
my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;
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
        anonymous => 0,
        hidden    => 1,
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
            other_problem => 1,
            name  => 'Different User',
            email => 'commenter@example.com',
            text  => 'This is an update',
        },
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
            hidden => 1,
            name  => 'Different User',
            email => 'commenter@example.com',
            text  => 'This is an update',
        },
    },
  )
{
    subtest 'check reporting a problem displays correctly' => sub {
        my $user = $mech->create_user_ok($test->{email}, name => $test->{name});

        my $problem = FixMyStreet::DB->resultset('Problem')->create(
            {
                title     => $test->{title},
                detail    => $test->{detail},
                postcode  => $test->{postcode},
                confirmed => $test->{confirmed},
                name      => $test->{name},
                anonymous => $test->{anonymous},
                state     => $test->{hidden} ? 'hidden' : 'confirmed',
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
            my $update_user = $mech->create_user_ok($update_info->{email},
                name => $update_info->{name});

            $update = FixMyStreet::DB->resultset('Comment')->create(
                {
                    problem_id => $update_info->{other_problem} ? $problem_main->id : $problem->id,
                    user        => $update_user,
                    state       => $update_info->{hidden} ? 'hidden' : 'confirmed',
                    text        => $update_info->{text},
                    confirmed   => \'current_timestamp',
                    mark_fixed => 'f',
                    anonymous  => 'f',
                }
            );
        }

        ok $problem, 'succesfully create a problem';

        if ( $update ) {
            if ( $test->{update}->{hidden} ) {
                $mech->get( '/contact?id=' . $problem->id . '&update_id=' . $update->id );
                is $mech->res->code, 404, 'cannot report a hidden update';
            } elsif ( $test->{update}->{other_problem} ) {
                $mech->get( '/contact?id=' . $problem->id . '&update_id=' . $update->id );
                is $mech->res->code, 404, 'cannot view an update for another problem';
            } else {
                $mech->get_ok( '/contact?id=' . $problem->id . '&update_id=' . $update->id );
                $mech->content_contains('reporting the following update');
                $mech->content_contains( $test->{update}->{text} );
            }
        } elsif ( $test->{hidden} ) {
            $mech->get( '/contact?id=' . $problem->id );
            is $mech->res->code, 410, 'cannot report a hidden problem';
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
        $test->{fields}->{'extra.phone'} = '';
        is_deeply $mech->visible_form_values, $test->{fields}, 'form values';
    };
}

my %common = (
    em => 'test@example.com',
    name => 'A name',
    subject => 'A subject',
    message => 'A message',
);

for my $test (
    { fields => \%common },
    { fields => { %common, id => $problem_main->id } },
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
        $mech->content_contains('Thank you for your enquiry');

        my $email = $mech->get_email;

        is $email->header('Subject'), 'FixMyStreet message: ' .  $test->{fields}->{subject}, 'subject';
        is $email->header('From'), "\"$test->{fields}->{name}\" <$test->{fields}->{em}>", 'from';
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/$test->{fields}->{message}/, 'body';
        like $body, qr/Sent by contact form on \S+.\s+IP address (?:\d{1,3}\.){3,}\d{1,3}, user agent ./, 'body footer';
        my $problem_id = $test->{fields}{id};
        like $body, qr/Complaint about report $problem_id/, 'reporting a report'
            if $test->{fields}{id};

        $problem_main->discard_changes;
        if ( $problem_id ) {
            ok $problem_main->flagged, 'problem flagged';
        } else {
            ok !$problem_main->flagged, 'problem not flagged';
        }

    };
}

subtest 'use do-not-reply address when recepient uses DMARC' => sub {
    my $fms_email = Test::MockModule->new('FixMyStreet::Email');
    $fms_email->mock('test_dmarc', sub { 1 });

    $mech->clear_emails_ok;
    $mech->get_ok('/contact');

    $mech->submit_form_ok( { with_fields => \%common } );
    $mech->content_contains('Thank you for your enquiry');

    my $email = $mech->get_email;

    my $from_email = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    is $email->header('From'), "\"$common{name}\" <$from_email>", 'from name and email correct';
};

subtest 'use reply-to when cobrand asks to' => sub {
    FixMyStreet::override_config {
        COBRAND_FEATURES => {
            always_use_reply_to => { default => 1 }
        },
    }, sub {
        $mech->clear_emails_ok;
        $mech->get_ok('/contact');
        $mech->submit_form_ok( { with_fields => \%common } );
        $mech->content_contains('Thank you for your enquiry');

        my $email = $mech->get_email;
        my $from_email = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
        is $email->header('From'), "\"$common{name}\" <$from_email>", 'from name and email correct';
        is $email->header('Reply-To'), "\"$common{name}\" <$common{em}>", 'reply-to correct';
    }
};

for my $test (
    { fields => \%common }
  )
{
    subtest 'check email contains user details' => sub {
        my $user = $mech->create_user_ok(
            $test->{fields}->{em},
            name => $test->{fields}->{name}
        );

        my $older_unhidden_problem = FixMyStreet::DB->resultset('Problem')->create(
            {
                title     => 'Some problem or other',
                detail    => 'More detail on the problem',
                postcode  => 'EH99 1SP',
                confirmed => '2011-05-04 10:44:28.145168',
                anonymous => 0,
                name      => $test->{fields}->{name},
                state     => 'confirmed',
                user      => $user,
                latitude  => 0,
                longitude => 0,
                areas     => 0,
                used_map  => 0,
            }
        );

        my $newer_hidden_problem = FixMyStreet::DB->resultset('Problem')->create(
            {
                title     => 'A hidden problem',
                detail    => 'Shhhh secret',
                postcode  => 'EH99 1SP',
                confirmed => '2012-06-05 10:44:28.145168',
                anonymous => 0,
                name      => $test->{fields}->{name},
                state     => 'hidden',
                user      => $user,
                latitude  => 0,
                longitude => 0,
                areas     => 0,
                used_map  => 0,
            }
        );

        $mech->clear_emails_ok;
        $mech->get_ok('/contact');
        $test->{fields}{em} = ucfirst $user->email; # Check case
        $mech->submit_form_ok( { with_fields => $test->{fields} } );

        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);

        my $user_id = $user->id;
        my $user_email = $user->email;
        my $older_unhidden_problem_id = $older_unhidden_problem->id;
        my $newer_hidden_problem_id = $newer_hidden_problem->id;

        like $body, qr/admin\/users\/$user_id/, 'email contains admin link to edit user';
        like $body, qr/admin\/reports\?search=$user_email/, 'email contains admin link to show users reports';
        like $body, qr/admin\/report_edit\/$older_unhidden_problem_id/, 'email contains admin link for users latest unhidden report';
        unlike $body, qr/admin\/report_edit\/$newer_hidden_problem_id/, 'email does not link to hidden reports';

    };
}

for my $test (
    {
        fields => { %common, dest => undef },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'Please enter who your message is for',
            'You can only contact the team behind FixMyStreet using our contact form', # The JS-hidden one
        ]
    },
    {
        fields => { %common, dest => 'council' },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'You can only contact the team behind FixMyStreet using our contact form',
        ]
    },
    {
        fields => { %common, dest => 'update' },
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
            $test->{fields}->{'extra.phone'} = '';
            is_deeply $mech->visible_form_values, $test->{fields}, 'form values';

            # Ugh, but checking div not hidden; text always shown and hidden with CSS
            if ( $test->{fields}->{dest} and $test->{fields}->{dest} eq 'update' ) {
                $mech->content_contains('<div class="form-error__box form-error--update">');
            } elsif ( $test->{fields}->{dest} and $test->{fields}->{dest} eq 'council' ) {
                # Ugh, but checking div not hidden
                $mech->content_contains('<div class="form-error__box form-error--council">');
            }
        }
    };
}

for my $test (
    { fields => { %common, dest => 'help' } },
    { fields => { %common, dest => 'feedback' } },
    { fields => { %common, dest => 'from_council' } },
  )
{
    subtest 'check email sent correctly with dest field set to us' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'fixmystreet' ],
        }, sub {
            $mech->clear_emails_ok;
            $mech->get_ok('/contact');
            $mech->submit_form_ok( { with_fields => $test->{fields} } );
            $mech->content_contains('Thank you for your enquiry');
            $mech->email_count_is(1);
        }
    };
}

for my $test (
    {
        fields => { %common, dest => undef },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'Please enter a topic of your message',
            'You can only use this form to report inappropriate content', # The JS-hidden one
        ]
    },
    {
        fields => { %common, dest => 'council' },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'You can only use this form to report inappropriate content',
        ]
    },
    {
        fields => { %common, dest => 'update' },
        page_errors =>
          [ 'There were problems with your report. Please see below.',
            'You can only use this form to report inappropriate content',
        ]
    },
  )
{
    subtest 'check Bucks submit page incorrect destination handling' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'buckinghamshire' ],
        }, sub {
            my $bucks = $mech->create_body_ok(2217, 'Buckinghamshire Council', { cobrand => 'buckinghamshire' });
            my ($problem) = $mech->create_problems_for_body(1, $bucks->id, 'Test');
            $mech->get_ok( '/contact?id=' . $problem->id, 'can visit for abuse report' );
            $mech->submit_form_ok( { with_fields => $test->{fields} } );
            is_deeply $mech->page_errors, $test->{page_errors}, 'page errors';

            $test->{fields}->{'extra.phone'} = '';
            is_deeply $mech->visible_form_values, $test->{fields}, 'form values';

            if ( $test->{fields}->{dest} and $test->{fields}->{dest} eq 'update' ) {
                $mech->content_contains('please leave an update');
            } elsif ( $test->{fields}->{dest} and $test->{fields}->{dest} eq 'council' ) {
                $mech->content_contains('should find other contact details');
            }
        }
    };
}

for my $test (
    {
        fields => {
            %common,
            token => $csrf,
            dest        => 'from_council',
            success_url => '/faq',
            s => "",
        },
        url_should_be => 'http://localhost/faq',
    },
    {
        fields => {
            %common,
            token => $csrf,
            dest        => 'from_council',
            success_url => 'http://www.example.com',
            s => "",
        },
        url_should_be => 'http://www.example.com',
    },
  )
{
    subtest 'check user can be redirected to a custom URL after contact form is submitted' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'fixmystreet' ],
        }, sub {
            $mech->post('/contact/submit', $test->{fields});
            is $mech->uri->as_string, $test->{url_should_be};
        }
    };
}

subtest 'check can limit contact to abuse reports' => sub {
    FixMyStreet::override_config {
        'ALLOWED_COBRANDS' => [ 'abuseonly' ],
    }, sub {
        $mech->get( '/contact' );
        is $mech->res->code, 404, 'cannot visit contact page';
        $mech->get_ok( '/contact?id=' . $problem_main->id, 'can visit for abuse report' );

        my $token = FixMyStreet::DB->resultset("Token")->create({
            scope => 'moderation',
            data => { id => $problem_main->id }
        });

        $mech->get_ok( '/contact?m=' . $token->token, 'can visit for moderation complaint' );

    }
};

subtest 'check redirected to correct form for general enquiries cobrand' => sub {
    FixMyStreet::override_config {
        'ALLOWED_COBRANDS' => [ 'generalenquiries' ],
    }, sub {
        $mech->get( '/contact' );
        is $mech->res->code, 200, "got 200 for final destination";
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/contact/enquiry';

        $mech->get_ok( '/contact?id=' . $problem_main->id, 'can visit for abuse report' );

        my $token = FixMyStreet::DB->resultset("Token")->create({
            scope => 'moderation',
            data => { id => $problem_main->id }
        });

        $mech->get_ok( '/contact?m=' . $token->token, 'can visit for moderation complaint' );

    }
};

$problem_main->delete;

subtest 'recaptcha' => sub {
    my $mod_lwp = Test::MockModule->new('LWP::UserAgent');
    $mod_lwp->mock(
        'post',
        sub {
            HTTP::Response->new( 200, 'OK', [], '{ "success": true }' );
        },
    );
    my $mod_app = Test::MockModule->new('FixMyStreet::App');

    subtest 'for FMS' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'fixmystreet',
            RECAPTCHA => { secret => 'secret', site_key => 'site_key' },
        } => sub {
            ok $mech->host('www.fixmystreet.com');
            $mech->get_ok('/contact');
            $mech->content_lacks('g-recaptcha');  # GB is default test country

            $mod_app->mock( 'user_country', sub {'FR'} );

            $mech->get_ok('/contact');
            $mech->content_contains('g-recaptcha');
            $mech->submit_form_ok(
                { with_fields => { %common, dest => 'help' } } );
            $mech->content_contains('Thank you for your enquiry');
        };
    };

    subtest 'for BathNES (has its own contact/index.html file)' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'bathnes',
            RECAPTCHA => { secret => 'secret', site_key => 'site_key' },
        } => sub {
            my $bathnes = $mech->create_body_ok(
                2551, 'Bath and North East Somerset Council',
                { cobrand => 'bathnes' },
            );
            ok $mech->host('https://fix.bathnes.gov.uk/');

            $mod_app->mock( 'user_country', sub {'GB'} );

            $mech->get_ok('/contact');
            $mech->content_contains('Bath & North East Somerset Council');
            $mech->content_lacks('g-recaptcha');

            $mod_app->mock( 'user_country', sub {'FR'} );

            $mech->get_ok('/contact');
            $mech->content_contains('g-recaptcha');
            $mech->submit_form_ok( { with_fields => \%common } );
            $mech->content_contains('Thank you for your enquiry');
        };
    };

    subtest 'for another cobrand (Lincolnshire)' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'lincolnshire',
            RECAPTCHA => { secret => 'secret', site_key => 'site_key' },
        } => sub {
            my $lincs = $mech->create_body_ok(
                2232, 'Lincolnshire County Council',
                { cobrand => 'lincolnshire' },
            );
            ok $mech->host('fixmystreet.lincolnshire.gov.uk');

            $mod_app->mock( 'user_country', sub {'GB'} );

            $mech->get_ok('/contact');
            $mech->content_contains('Lincolnshire County Council');
            $mech->content_lacks('g-recaptcha');

            $mod_app->mock( 'user_country', sub {'FR'} );

            $mech->get_ok('/contact');
            $mech->content_contains('g-recaptcha');
            $mech->submit_form_ok( { with_fields => \%common } );
            $mech->content_contains('Thank you for your enquiry');
        };
    };

    subtest 'Surrey never shows reCAPTCHA' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'surrey',
            RECAPTCHA => { secret => 'secret', site_key => 'site_key' },
        } => sub {
            $mech->create_body_ok(
                2242, 'Surrey County Council',
                { cobrand => 'surrey' },
            );
            ok $mech->host('tellus.surreycc.gov.uk');

            $mod_app->mock( 'user_country', sub {'GB'} );

            $mech->get_ok('/contact');
            $mech->content_contains('Surrey County Council');
            $mech->content_lacks('g-recaptcha');

            $mod_app->mock( 'user_country', sub {'FR'} );

            $mech->get_ok('/contact');
            $mech->content_lacks('g-recaptcha');
            $mech->submit_form_ok( { with_fields => \%common } );
            $mech->content_contains('Thank you for your enquiry');
        };
    };
};

done_testing();
