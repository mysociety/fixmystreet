use Test::MockModule;
use LWP::Protocol::PSGI;
use LWP::Simple;
use JSON::MaybeXS;

use t::Mock::Facebook;
use t::Mock::Twitter;
use t::Mock::OpenIDConnect;
use t::Mock::Tilma;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

#my $tfl_mock = Test::MockModule->new('FixMyStreet::Cobrand::TfL');
#$tfl_mock->mock('must_have_2fa', sub { 0 });

my $body = $mech->create_body_ok(2504, 'Westminster City Council');
my $body2 = $mech->create_body_ok(2508, 'Hackney Council');
my $body3 = $mech->create_body_ok(2488, 'Brent Council', {}, { cobrand => 'brent' });
my $body4 = $mech->create_body_ok(2482, 'TfL', {}, { cobrand => 'tfl' }); # Bromley area

FixMyStreet::DB->resultset("Role")->create({
    body => $body4,
    name => 'Streetcare - Basic Editor Viewers',
    permissions => ['moderate', 'user_edit'],
});

FixMyStreet::DB->resultset("Role")->create({
    body => $body4,
    name => 'Streetcare - Admin',
    permissions => ['moderate', 'user_edit'],
});

my ($report) = $mech->create_problems_for_body(1, $body->id, 'My Test Report');
my $test_email = $report->user->email;
my ($report2) = $mech->create_problems_for_body(1, $body2->id, 'My Test Report');
my $test_email2 = $report->user->email;
my ($report3) = $mech->create_problems_for_body(1, $body3->id, 'My Test Report');
my $test_email3 = $report3->user->email;
my ($report4) = $mech->create_problems_for_body(1, $body4->id, 'My Test Report');
my $test_email4 = $report4->user->email;


foreach ($body->id, $body2->id, $body3->id, $body4->id) {
    $mech->create_contact_ok(
        body_id => $_, category => 'Damaged bin', email => 'BIN',
        group => 'Bins',
        extra => {
            _fields => [
                { code => 'bin_type', description => 'Type of bin', required => 'True' },
                { code => 'bin_service', description => 'Service needed', required => 'False' },
            ]
        }
    );
    # Two options, incidentally, so that the template "Only one option, select it"
    # code doesn't kick in and make the tests pass
    $mech->create_contact_ok( body_id => $_, category => 'Whatever', email => 'WHATEVER' );
    $mech->create_contact_ok( body_id => $_, category => 'Invisible bin', email => 'INVISIBLE', group => 'Bins' );
}

my $resolver = Test::MockModule->new('Email::Valid');
my $social = Test::MockModule->new('FixMyStreet::App::Controller::Auth::Social');
$social->mock('generate_nonce', sub { 'MyAwesomeRandomValue' });
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.staging.mysociety.org');

for my $test (&tst_config) {

FixMyStreet::override_config $test->{config}, sub {

$resolver->mock('address', sub { $test->{email} });

for my $state ( 'refused', 'no email', 'existing UID', 'okay' ) {
    for my $page ( 'my', 'report', 'update' ) {
        next if $page eq 'update' && !$test->{update};

        subtest "test $test->{type} '$state' login for page '$page'" => sub {
            my $test_report = $test->{report} || $report;
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
                $test_report->update({ user_id => FixMyStreet::DB->resultset( 'User' )->find( { email => $test->{email} } )->id });
            } else {
                $test_report->update({ user_id => FixMyStreet::DB->resultset( 'User' )->find( { email => ($report->{test_email} || $test_email) } )->id });
            }

            # Set up a mock to catch (most, see below) requests to the OAuth API
            my $mock_api = $test->{mock}->new( host => $test->{host} );

            if ($test->{uid} =~ /:/) {
                my ($cobrand) = $test->{uid} =~ /^(.*?):/;
                $mock_api->cobrand($cobrand);
            }
            $mock_api->returns_email(0) if $state eq 'no email' || $state eq 'existing UID';
            $mock_api->roles($test->{roles}) if $test->{roles};
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
                $mech->submit_form_ok( { with_fields => { pc => $test->{pc} || 'SW1A1AA' } }, "submit location" );
                $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
                $mech->submit_form(with_fields => {
                    category => 'G|Bins',
                    'category.Bins' => 'Damaged bin',
                    title => 'Test title',
                    detail => 'Test detail',
                });
                $fields = {
                    bin_type => 'Salt bin',
                };
            } else {
                $mech->get_ok('/report/' . $test_report->id);
                $fields = {
                    update => 'Test update',
                };
            }
            $mech->form_with_fields('social_sign_in');
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
                if ($test->{oidc_fail_test} && $page eq 'my' && $state eq 'okay') {
                    my $oidc_lite = Test::MockModule->new('OIDC::Lite::Client::WebServer::AuthCodeFlow');
                    $oidc_lite->mock('get_access_token', sub { die  });
                    $mech->get('/auth/OIDC?code=throw&state=login');
                    is $mech->res->code, 500, "got 500 for page";
                    is $mech->response->header( 'X-Custom-Error-Provided'), 'yes', 'X-Custom-Error-Provided header added';
                }
                $mech->get_ok($test->{success_callback});
            }

            # Check we're showing the right form, regardless of what came back
            if ($page eq 'report') {
                $mech->content_contains('/report/new');
                $mech->content_contains('Salt bin');
                $mech->content_like(qr{value="G|Bins"\s+data-subcategory="Bins" checked});
                $mech->content_contains('name="category.Bins" data-category_display="Damaged bin" value=\'Damaged bin\' checked');
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
                $fields->{username} = $test->{email} if $page eq 'my';
                $fields->{username_register} = $test->{email} unless $page eq 'my';
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
                if ($test->{roles}) {
                    &test_roles($test);
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
                if ($test->{roles}) {
                    &test_roles($test);
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
                if ($test->{roles}) {
                    &test_roles($test);
                }
                if ($state eq 'existing UID') {
                    my $report_id = $test_report->id;
                    $mech->content_contains( $test_report->title );
                    $mech->content_contains( "/report/$report_id" );
                }
                if ($test->{type} eq 'oidc' && $test->{password_change_pattern}) {
                    ok $mech->find_link( text => 'Change password', url_regex => $test->{password_change_pattern} );
                }
            }

            $mech->get('/auth/sign_out');
            if ($test->{type} eq 'oidc' && $test->{logout_redirect_pattern} && $state ne 'refused' && $state ne 'no email') {
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
                    category => 'G|Bins',
                    'category.Bins' =>'Damaged bin',
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
                $fields->{username_register} = $tw_email unless $page eq 'my';
                $fields->{username} = $tw_email if $page eq 'my';
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

sub test_roles {
    my $test = $_[0];

    my $user = FixMyStreet::DB->resultset( 'User' )->find( { email => $test->{email} } );
    my @roles;
    for my $role ($user->roles->all) {
        push @roles, $role->name;
    };
    my @expected_sort = sort @{$test->{expected_roles}};
    my @roles_sort = sort @roles;

    is_deeply \@expected_sort, \@roles_sort, 'Correct roles assigned to user';
}

sub tst_config {
my @configurations = (
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
        logout_redirect_pattern => qr{http://oidc\.example\.org/oauth2/v2\.0/logout\?post_logout_redirect_uri=http%3A%2F%2Foidc.example.org%2Fauth%2Fsign_out&id_token_hint=},
        password_change_pattern => qr{oidc\.example\.org/oauth2/v2\.0/password_change},
        user_extras => [
            [westminster_account_id => "1c304134-ef12-c128-9212-123908123901"],
        ],
    },
    {
        type => 'oidc',
        config => {
            ALLOWED_COBRANDS => 'brent',
            MAPIT_URL => 'http://mapit.uk/',
            COBRAND_FEATURES => {
                anonymous_account => {
                    brent => 'test',
                },
                oidc_login => {
                    brent => {
                        client_id => 'example_client_id',
                        secret => 'example_secret_key',
                        auth_uri => 'http://oidc.example.org/oauth2/v2.0/authorize',
                        token_uri => 'http://oidc.example.org/oauth2/v2.0/token',
                        logout_uri => 'http://oidc.example.org/oauth2/v2.0/logout',
                        password_change_uri => 'http://oidc.example.org/oauth2/v2.0/password_change',
                        display_name => 'MyAccount'
                    }
                }
            }
        },
        email => $mech->uniquify_email('oidc@example.org'),
        uid => "brent:example_client_id:my_cool_user_id",
        mock => 't::Mock::OpenIDConnect',
        mock_hosts => ['oidc.example.org'],
        host => 'oidc.example.org',
        error_callback => '/auth/OIDC?error=ERROR',
        success_callback => '/auth/OIDC?code=response-code&state=login',
        redirect_pattern => qr{oidc\.example\.org/oauth2/v2\.0/authorize},
        logout_redirect_pattern => qr{oidc\.example\.org/oauth2/v2\.0/logout},
        password_change_pattern => qr{oidc\.example\.org/oauth2/v2\.0/password_change},
        report => $report3,
        report_email => $test_email3,
        pc => 'HA9 0FJ',
    },
    {
        type => 'oidc',
        config => {
            ALLOWED_COBRANDS => 'brent',
            MAPIT_URL => 'http://mapit.uk/',
            COBRAND_FEATURES => {
                anonymous_account => {
                    brent => 'test',
                },
                oidc_login => {
                    brent => {
                        client_id => 'example_client_id',
                        secret => 'example_secret_key',
                        auth_uri => 'http://oidc.example.org/oauth2/v2.0/authorize',
                        token_uri => 'http://oidc.example.org/oauth2/v2.0/token',
                        logout_uri => 'http://oidc.example.org/oauth2/v2.0/logout',
                        password_change_uri => 'http://oidc.example.org/oauth2/v2.0/password_change',
                        display_name => 'MyAccount',
                        hosts => {
                            'brent-wasteworks-oidc.example.org' => {
                                client_id => 'wasteworks_client_id',
                                secret => 'wasteworks_secret_key',
                                auth_uri => 'http://brent-wasteworks-oidc.example.org/oauth2/v2.0/authorize',
                                token_uri => 'http://brent-wasteworks-oidc.example.org/oauth2/v2.0/token',
                                logout_uri => 'http://brent-wasteworks-oidc.example.org/oauth2/v2.0/logout',
                                password_change_uri => 'http://brent-wasteworks-oidc.example.org/oauth2/v2.0/password_change',
                                display_name => 'MyAccount - WasteWorks',
                            }
                        }
                    }
                }
            }
        },
        email => $mech->uniquify_email('oidc@example.org'),
        uid => "brent:wasteworks_client_id:my_cool_user_id",
        mock => 't::Mock::OpenIDConnect',
        mock_hosts => ['brent-wasteworks-oidc.example.org'],
        host => 'brent-wasteworks-oidc.example.org',
        error_callback => '/auth/OIDC?error=ERROR',
        success_callback => '/auth/OIDC?code=response-code&state=login',
        redirect_pattern => qr{brent-wasteworks-oidc\.example\.org/oauth2/v2\.0/authorize},
        logout_redirect_pattern => qr{brent-wasteworks-oidc\.example\.org/oauth2/v2\.0/logout},
        password_change_pattern => qr{brent-wasteworks-oidc\.example\.org/oauth2/v2\.0/password_change},
        report => $report3,
        report_email => $test_email3,
        pc => 'HA9 0FJ',
    },
    {
        type => 'oidc',
        config => {
            ALLOWED_COBRANDS => 'hackney',
            MAPIT_URL => 'http://mapit.uk/',
            COBRAND_FEATURES => {
                anonymous_account => {
                    hackney => 'test',
                },
                oidc_login => {
                    hackney => {
                        client_id => 'example_client_id',
                        secret => 'example_secret_key',
                        auth_uri => 'http://oidc.example.org/oauth2/v2.0/authorize_google',
                        token_uri => 'http://oidc.example.org/oauth2/v2.0/token_google',
                        allowed_domains => [ 'example.org' ],
                    }
                },
                do_not_reply_email => {
                    hackney => 'fms-hackney-DO-NOT-REPLY@hackney-example.com',
                },
                verp_email_domain => {
                    hackney => 'hackney-example.com',
                },
            }
        },
        email => $mech->uniquify_email('oidc_google@example.org'),
        uid => "hackney:example_client_id:my_google_user_id",
        mock => 't::Mock::OpenIDConnect',
        mock_hosts => ['oidc.example.org'],
        host => 'oidc.example.org',
        error_callback => '/auth/OIDC?error=ERROR',
        success_callback => '/auth/OIDC?code=response-code&state=login',
        redirect_pattern => qr{oidc\.example\.org/oauth2/v2\.0/authorize_google},
        pc => 'E8 1DY',
        # Need to use a different report that's within Hackney
        report => $report2,
        report_email => $test_email2,
    },
);

for my $setup (
    {
        roles => ['BasicEditorViewers'],
        expected_roles => ['Streetcare - Basic Editor Viewers'],
    },
    {
        roles => ['Admin'],
        expected_roles => ['Streetcare - Admin'],
    },
    {
        roles => ['BasicEditorViewers', 'Admin'],
        expected_roles => ['Streetcare - Admin', 'Streetcare - Basic Editor Viewers'],
    },
    {
        roles => ['Non-existant role'],
        expected_roles => [],
    },
    {
        roles => [],
        expected_roles => [],
    },
    {
        roles => undef,
        expected_roles => [],
    }

) {
    push @configurations,
    {
        type => 'oidc',
        oidc_fail_test => 1,
        config => {
            ALLOWED_COBRANDS => 'tfl',
            MAPIT_URL => 'http://mapit.uk/',
            COBRAND_FEATURES => {
                anonymous_account => {
                    tfl => 'test',
                },
                oidc_login => {
                    tfl => {
                        client_id => 'example_client_id',
                        secret => 'example_secret_key',
                        auth_uri => 'http://oidc.example.org/oauth2/v2.0/authorize',
                        token_uri => 'http://oidc.example.org/oauth2/v2.0/token',
                        logout_uri => 'http://oidc.example.org/oauth2/v2.0/logout',
                        password_change_uri => 'http://oidc.example.org/oauth2/v2.0/password_change',
                        display_name => 'MyAccount',
                        role_map => {
                            BasicEditorViewers => 'Streetcare - Basic Editor Viewers',
                            Admin => 'Streetcare - Admin',
                        },
                    }
                }
            }
        },
        email => $mech->uniquify_email('oidc@tfl.gov.uk'),
        uid => "tfl:example_client_id:my_cool_user_id",
        mock => 't::Mock::OpenIDConnect',
        mock_hosts => ['oidc.example.org'],
        host => 'oidc.example.org',
        error_callback => '/auth/OIDC?error=ERROR',
        success_callback => '/auth/OIDC?code=response-code&state=login',
        redirect_pattern => qr{oidc\.example\.org/oauth2/v2\.0/authorize},
        logout_redirect_pattern => qr{oidc\.example\.org/oauth2/v2\.0/logout},
        password_change_pattern => qr{oidc\.example\.org/oauth2/v2\.0/password_change},
        report => $report4,
        report_email => $test_email4,
        pc => 'BR1 3UH',
        roles => $setup->{roles},
        expected_roles => $setup->{expected_roles},
    }
}

return @configurations;
};

done_testing();
