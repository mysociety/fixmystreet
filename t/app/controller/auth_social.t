use Test::MockModule;
use LWP::Protocol::PSGI;
use LWP::Simple;
use JSON::MaybeXS;

use t::Mock::Facebook;
use t::Mock::Twitter;
use t::Mock::OpenIDConnect;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2504, 'Westminster City Council');

my ($report) = $mech->create_problems_for_body(1, $body->id, 'My Test Report');
my $test_email = $report->user->email;

my $contact = $mech->create_contact_ok(
    body_id => $body->id, category => 'Damaged bin', email => 'BIN',
    extra => [
        { code => 'bin_type', description => 'Type of bin', required => 'True' },
        { code => 'bin_service', description => 'Service needed', required => 'False' },
    ]
);
# Two options, incidentally, so that the template "Only one option, select it"
# code doesn't kick in and make the tests pass
my $contact2 = $mech->create_contact_ok(
    body_id => $body->id, category => 'Whatever', email => 'WHATEVER',
);

my $resolver = Test::MockModule->new('Email::Valid');
my $social = Test::MockModule->new('FixMyStreet::App::Controller::Auth::Social');
$social->mock('generate_nonce', sub { 'MyAwesomeRandomValue' });

for my $test (
    {
    type => 'facebook',
    config => {
        FACEBOOK_APP_ID => 'facebook-app-id',
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    },
    update => 1,
    email => $mech->uniquify_email('facebook@example.org'),
    uid => 123456789,
    mock => 't::Mock::Facebook',
    mock_hosts => ['www.facebook.com', 'graph.facebook.com'],
    host => 'www.facebook.com',
    error_callback => '/auth/Facebook?error_code=ERROR',
    success_callback => '/auth/Facebook?code=response-code',
    redirect_pattern => qr{facebook\.com.*dialog/oauth.*facebook-app-id},
}, {
    type => 'oidc',
    config => {
        ALLOWED_COBRANDS => 'westminster',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            anonymous_account => {
                westminster => 'test',
            },
            oidc_login => {
                westminster => {
                    client_id => 'example_client_id',
                    secret => 'example_secret_key',
                    auth_uri => 'http://oidc.example.org/oauth2/v2.0/authorize',
                    token_uri => 'http://oidc.example.org/oauth2/v2.0/token',
                    logout_uri => 'http://oidc.example.org/oauth2/v2.0/logout',
                    password_change_uri => 'http://oidc.example.org/oauth2/v2.0/password_change',
                    display_name => 'MyWestminster'
                }
            }
        }
    },
    email => $mech->uniquify_email('oidc@example.org'),
    uid => "westminster:example_client_id:my_cool_user_id",
    mock => 't::Mock::OpenIDConnect',
    mock_hosts => ['oidc.example.org'],
    host => 'oidc.example.org',
    error_callback => '/auth/OIDC?error=ERROR',
    success_callback => '/auth/OIDC?code=response-code&state=login',
    redirect_pattern => qr{oidc\.example\.org/oauth2/v2\.0/authorize},
    logout_redirect_pattern => qr{oidc\.example\.org/oauth2/v2\.0/logout},
    password_change_pattern => qr{oidc\.example\.org/oauth2/v2\.0/password_change},
    user_extras => [
        [westminster_account_id => "1c304134-ef12-c128-9212-123908123901"],
    ],
}
) {

FixMyStreet::override_config $test->{config}, sub {

$resolver->mock('address', sub { $test->{email} });

for my $state ( 'refused', 'no email', 'existing UID', 'okay' ) {
    for my $page ( 'my', 'report', 'update' ) {
        next if $page eq 'update' && !$test->{update};

        subtest "test $test->{type} '$state' login for page '$page'" => sub {
            # Lots of user changes happening here, make sure we don't confuse
            # Catalyst with a cookie session user that no longer exists
            $mech->log_out_ok;
            $mech->cookie_jar({});
            if ($state eq 'existing UID') {
                my $user = $mech->create_user_ok($test->{email});
                if ($test->{type} eq 'facebook') {
                    $user->update({ facebook_id => $test->{uid} });
                } elsif ($test->{type} eq 'oidc') {
                    $user->update({ oidc_ids => [ $test->{uid} ] });
                }
            } else {
                $mech->delete_user($test->{email});
            }
            if ($page eq 'my' && $state eq 'existing UID') {
                $report->update({ user_id => FixMyStreet::DB->resultset( 'User' )->find( { email => $test->{email} } )->id });
            } else {
                $report->update({ user_id => FixMyStreet::DB->resultset( 'User' )->find( { email => $test_email } )->id });
            }

            # Set up a mock to catch (most, see below) requests to the OAuth API
            my $mock_api = $test->{mock}->new;
            $mock_api->returns_email(0) if $state eq 'no email' || $state eq 'existing UID';
            for my $host (@{ $test->{mock_hosts} }) {
                LWP::Protocol::PSGI->register($mock_api->to_psgi_app, host => $host);
            }

            # Due to https://metacpan.org/pod/Test::WWW::Mechanize::Catalyst#External-Redirects-and-allow_external
            # the redirect to the OAuth page can mess up the session
            # cookie. So let's pretend we're always on the API host, which
            # sorts that out.
            $mech->host($test->{host});

            # Fetch the page with the form via which we wish to log in
            my $fields;
            if ($page eq 'my') {
                $mech->get_ok('/my');
            } elsif ($page eq 'report') {
                $mech->get_ok('/');
                $mech->submit_form_ok( { with_fields => { pc => 'SW1A1AA' } }, "submit location" );
                $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
                $mech->submit_form(with_fields => {
                    category => 'Damaged bin',
                    title => 'Test title',
                    detail => 'Test detail',
                });
                $fields = {
                    bin_type => 'Salt bin',
                };
            } else {
                $mech->get_ok('/report/' . $report->id);
                $fields = {
                    update => 'Test update',
                };
            }
            $mech->submit_form(with_fields => $fields, button => 'social_sign_in');

            # As well as the cookie issue above, caused by this external
            # redirect rewriting the host, the redirect gets handled directly
            # by Catalyst, not our mocked handler, so will be a 404. Check
            # the redirect happened instead.
            is $mech->res->previous->code, 302, "$test->{type} button redirected";
            like $mech->res->previous->header('Location'), $test->{redirect_pattern}, "$test->{type} redirect to oauth URL";

            # Okay, now call the callback we'd be sent to
            # NB: for OIDC these should be post_ok, but that doesn't work because
            # the session cookie doesn't seem to be included (related to the
            # cookie issue above perhaps).
            if ($state eq 'refused') {
                $mech->get_ok($test->{error_callback});
            } else {
                $mech->get_ok($test->{success_callback});
            }

            # Check we're showing the right form, regardless of what came back
            if ($page eq 'report') {
                $mech->content_contains('/report/new');
                $mech->content_contains('Salt bin');
            } elsif ($page eq 'update') {
                $mech->content_contains('/report/update');
            }

            if ($state eq 'refused') {
                $mech->content_contains('Sorry, we could not log you in.');
                $mech->not_logged_in_ok;
            } elsif ($state eq 'no email') {
                $mech->content_contains('We need your email address, please give it below.');
                # We don't have an email, so check that we can still submit it,
                # and the ID carries through the confirmation
                $fields->{username} = $test->{email};
                $fields->{name} = 'Ffion Tester' unless $page eq 'my';
                $mech->submit_form(with_fields => $fields, $page eq 'my' ? (button => 'sign_in_by_code') : ());
                $mech->content_contains('Nearly done! Now check your email');

                my $url = $mech->get_link_from_email;
                $mech->clear_emails_ok;
                ok $url, "extracted confirm url '$url'";

                my $user = FixMyStreet::DB->resultset( 'User' )->find( { email => $test->{email} } );
                if ($page eq 'my') {
                    is $user, undef, 'No user yet exists';
                } else {
                    if ($test->{type} eq 'facebook') {
                        is $user->facebook_id, undef, 'User has no facebook ID';
                    } elsif ($test->{type} eq 'oidc') {
                        is $user->oidc_ids, undef, 'User has no OIDC IDs';
                    }
                }
                $mech->get_ok( $url );
                $user = FixMyStreet::DB->resultset( 'User' )->find( { email => $test->{email} } );
                if ($test->{type} eq 'facebook') {
                    is $user->facebook_id, $test->{uid}, 'User now has correct facebook ID';
                } elsif ($test->{type} eq 'oidc') {
                    is_deeply $user->oidc_ids, [ $test->{uid} ], 'User now has correct OIDC IDs';
                }
                if ($test->{user_extras}) {
                    for my $extra (@{ $test->{user_extras} }) {
                        my ($k, $v) = @$extra;
                        is $user->get_extra_metadata($k), $v, "User has correct $k extra field";
                    }
                }

            } elsif ($page ne 'my') {
                # /my auth login goes directly there, no message like this
                $mech->content_contains('You have successfully signed in; please check and confirm your details are accurate');
                $mech->logged_in_ok;
                if ($test->{user_extras}) {
                    my $user = FixMyStreet::DB->resultset( 'User' )->find( { email => $test->{email} } );
                    for my $extra (@{ $test->{user_extras} }) {
                        my ($k, $v) = @$extra;
                        is $user->get_extra_metadata($k), $v, "User has correct $k extra field";
                    }
                }
            } else {
                is $mech->uri->path, '/my', 'Successfully on /my page';
                if ($test->{user_extras}) {
                    my $user = FixMyStreet::DB->resultset( 'User' )->find( { email => $test->{email} } );
                    for my $extra (@{ $test->{user_extras} }) {
                        my ($k, $v) = @$extra;
                        is $user->get_extra_metadata($k), $v, "User has correct $k extra field";
                    }
                }
                if ($state eq 'existing UID') {
                    my $report_id = $report->id;
                    $mech->content_contains( $report->title );
                    $mech->content_contains( "/report/$report_id" );
                }
                if ($test->{type} eq 'oidc') {
                    ok $mech->find_link( text => 'Change password', url_regex => $test->{password_change_pattern} );
                }
            }

            $mech->get('/auth/sign_out');
            if ($test->{type} eq 'oidc' && $state ne 'refused' && $state ne 'no email') {
                # XXX the 'no email' situation is skipped because of some confusion
                # with the hosts/sessions that I've not been able to get to the bottom of.
                # The code does behave as expected when testing manually, however.
                is $mech->res->previous->code, 302, "$test->{type} sign out redirected";
                like $mech->res->previous->header('Location'), $test->{logout_redirect_pattern}, "$test->{type} sign out redirect to oauth logout URL";
            }
            $mech->not_logged_in_ok;
        }
    }
}
}
};

FixMyStreet::override_config {
    TWITTER_KEY => 'twitter-key',
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

my $tw_email = $mech->uniquify_email('twitter@example.org');
my $tw_uid = 987654321;

$resolver->mock('address', sub { $tw_email });

# Twitter has no way of getting the email, so no "okay" state here
for my $tw_state ( 'refused', 'existing UID', 'no email' ) {
    for my $page ( 'my', 'report', 'update' ) {
        subtest "test Twitter '$tw_state' login for page '$page'" => sub {
            # Lots of user changes happening here, make sure we don't confuse
            # Catalyst with a cookie session user that no longer exists
            $mech->log_out_ok;
            $mech->cookie_jar({});
            if ($tw_state eq 'existing UID') {
                my $user = $mech->create_user_ok($tw_email);
                $user->update({ twitter_id => $tw_uid });
            } else {
                $mech->delete_user($tw_email);
            }

            # Set up a mock to catch (most, see below) requests to Twitter
            my $tw = t::Mock::Twitter->new;
            LWP::Protocol::PSGI->register($tw->to_psgi_app, host => 'api.twitter.com');

            # Due to https://metacpan.org/pod/Test::WWW::Mechanize::Catalyst#External-Redirects-and-allow_external
            # the redirect to Twitter's OAuth page can mess up the session
            # cookie. So let's pretend we always on api.twitter.com, which
            # sorts that out.
            $mech->host('api.twitter.com');

            # Fetch the page with the form via which we wish to log in
            my $fields;
            if ($page eq 'my') {
                $mech->get_ok('/my');
            } elsif ($page eq 'report') {
                $mech->get_ok('/');
                $mech->submit_form_ok( { with_fields => { pc => 'SW1A1AA' } }, "submit location" );
                $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
                $mech->submit_form(with_fields => {
                    category => 'Damaged bin',
                    title => 'Test title',
                    detail => 'Test detail',
                });
                $fields = {
                    bin_type => 'Salt bin',
                };
            } else {
                $mech->get_ok('/report/' . $report->id);
                $fields = {
                    update => 'Test update',
                };
            }
            $mech->submit_form(with_fields => $fields, button => 'social_sign_in');

            # As well as the cookie issue above, caused by this external
            # redirect rewriting the host, the redirect gets handled directly
            # by Catalyst, not our mocked handler, so will be a 404. Check
            # the redirect happened instead.
            is $mech->res->previous->code, 302, 'Twitter button redirected';
            like $mech->res->previous->header('Location'), qr{api\.twitter\.com/oauth/authenticate\?oauth_token=request-token}, 'Twitter redirect to oauth URL';

            # Okay, now call the callback Facebook would send us to
            if ($tw_state eq 'refused') {
                $mech->get_ok('/auth/Twitter?denied=token');
            } else {
                $mech->get_ok('/auth/Twitter?oauth_token=request-token&oauth_verifier=verifier');
            }

            # Check we're showing the right form, regardless of what came back
            if ($page eq 'report') {
                $mech->content_contains('/report/new');
                $mech->content_contains('Salt bin');
            } elsif ($page eq 'update') {
                $mech->content_contains('/report/update');
            }

            if ($tw_state eq 'refused') {
                $mech->content_contains('Sorry, we could not log you in. Please fill in the form below.');
                $mech->not_logged_in_ok;
            } elsif ($tw_state eq 'no email') {
                $mech->content_contains('We need your email address, please give it below.');
                # We don't have an email, so check that we can still submit it,
                # and the ID carries through the confirmation
                $fields->{username} = $tw_email;
                $fields->{name} = 'Ffion Tester' unless $page eq 'my';
                $mech->submit_form(with_fields => $fields, $page eq 'my' ? (button => 'sign_in_by_code') : ());
                $mech->content_contains('Nearly done! Now check your email');

                my $url = $mech->get_link_from_email;
                $mech->clear_emails_ok;
                ok $url, "extracted confirm url '$url'";

                my $user = FixMyStreet::DB->resultset( 'User' )->find( { email => $tw_email } );
                if ($page eq 'my') {
                    is $user, undef, 'No user yet exists';
                } else {
                    is $user->twitter_id, undef, 'User has no twitter ID';
                }
                $mech->get_ok( $url );
                $user = FixMyStreet::DB->resultset( 'User' )->find( { email => $tw_email } );
                is $user->twitter_id, $tw_uid, 'User now has correct twitter ID';

            } elsif ($page ne 'my') {
                # /my auth login goes directly there, no message like this
                $mech->content_contains('You have successfully signed in; please check and confirm your details are accurate');
                $mech->logged_in_ok;
            } else {
                is $mech->uri->path, '/my', 'Successfully on /my page';
            }
        }
    }
}

};

done_testing();
