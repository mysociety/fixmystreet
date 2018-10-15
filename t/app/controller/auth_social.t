use Test::MockModule;
use LWP::Protocol::PSGI;
use LWP::Simple;
use JSON::MaybeXS;

use t::Mock::Facebook;
use t::Mock::Twitter;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;
 
# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my ($report) = $mech->create_problems_for_body(1, '2345', 'Test');

FixMyStreet::override_config {
    FACEBOOK_APP_ID => 'facebook-app-id',
    TWITTER_KEY => 'twitter-key',
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

my $fb_email = 'facebook@example.org';
my $fb_uid = 123456789;

my $resolver = Test::MockModule->new('Email::Valid');
$resolver->mock('address', sub { 'facebook@example.org' });

for my $fb_state ( 'refused', 'no email', 'existing UID', 'okay' ) {
    for my $page ( 'my', 'report', 'update' ) {
        subtest "test FB '$fb_state' login for page '$page'" => sub {
            # Lots of user changes happening here, make sure we don't confuse
            # Catalyst with a cookie session user that no longer exists
            $mech->log_out_ok;
            $mech->cookie_jar({});
            if ($fb_state eq 'existing UID') {
                my $user = $mech->create_user_ok($fb_email);
                $user->update({ facebook_id => $fb_uid });
            } else {
                $mech->delete_user($fb_email);
            }

            # Set up a mock to catch (most, see below) requests to Facebook
            my $fb = t::Mock::Facebook->new;
            $fb->returns_email(0) if $fb_state eq 'no email' || $fb_state eq 'existing UID';
            LWP::Protocol::PSGI->register($fb->to_psgi_app, host => 'www.facebook.com');
            LWP::Protocol::PSGI->register($fb->to_psgi_app, host => 'graph.facebook.com');

            # Due to https://metacpan.org/pod/Test::WWW::Mechanize::Catalyst#External-Redirects-and-allow_external
            # the redirect to Facebook's OAuth page can mess up the session
            # cookie. So let's pretend we always on www.facebook.com, which
            # sorts that out.
            $mech->host('www.facebook.com');

            # Fetch the page with the form via which we wish to log in
            my $fields;
            if ($page eq 'my') {
                $mech->get_ok('/my');
            } elsif ($page eq 'report') {
                $mech->get_ok('/');
                $mech->submit_form_ok( { with_fields => { pc => 'SW1A1AA' } }, "submit location" );
                $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
                $fields = {
                    title => 'Test title',
                    detail => 'Test detail',
                };
            } else {
                $mech->get_ok('/report/' . $report->id);
                $fields = {
                    update => 'Test update',
                };
            }
            $mech->submit_form(with_fields => $fields, button => 'facebook_sign_in');

            # As well as the cookie issue above, caused by this external
            # redirect rewriting the host, the redirect gets handled directly
            # by Catalyst, not our mocked handler, so will be a 404. Check
            # the redirect happened instead.
            is $mech->res->previous->code, 302, 'FB button redirected';
            like $mech->res->previous->header('Location'), qr{facebook\.com.*dialog/oauth.*facebook-app-id}, 'FB redirect to oauth URL';

            # Okay, now call the callback Facebook would send us to
            if ($fb_state eq 'refused') {
                $mech->get_ok('/auth/Facebook?error_code=ERROR');
            } else {
                $mech->get_ok('/auth/Facebook?code=response-code');
            }

            # Check we're showing the right form, regardless of what came back
            if ($page eq 'report') {
                $mech->content_contains('/report/new');
            } elsif ($page eq 'update') {
                $mech->content_contains('/report/update');
            }

            if ($fb_state eq 'refused') {
                $mech->content_contains('Sorry, we could not log you in. Please fill in the form below.');
                $mech->not_logged_in_ok;
            } elsif ($fb_state eq 'no email') {
                $mech->content_contains('We need your email address, please give it below.');
                # We don't have an email, so check that we can still submit it,
                # and the ID carries through the confirmation
                $fields->{username} = $fb_email;
                $fields->{name} = 'Ffion Tester' unless $page eq 'my';
                $mech->submit_form(with_fields => $fields, $page eq 'my' ? (button => 'sign_in_by_code') : ());
                $mech->content_contains('Nearly done! Now check your email');

                my $url = $mech->get_link_from_email;
                $mech->clear_emails_ok;
                ok $url, "extracted confirm url '$url'";

                my $user = FixMyStreet::App->model( 'DB::User' )->find( { email => $fb_email } );
                if ($page eq 'my') {
                    is $user, undef, 'No user yet exists';
                } else {
                    is $user->facebook_id, undef, 'User has no facebook ID';
                }
                $mech->get_ok( $url );
                $user = FixMyStreet::App->model( 'DB::User' )->find( { email => $fb_email } );
                is $user->facebook_id, $fb_uid, 'User now has correct facebook ID';

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

$resolver->mock('address', sub { 'twitter@example.org' });

my $tw_email = 'twitter@example.org';
my $tw_uid = 987654321;

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
                $fields = {
                    title => 'Test title',
                    detail => 'Test detail',
                };
            } else {
                $mech->get_ok('/report/' . $report->id);
                $fields = {
                    update => 'Test update',
                };
            }
            $mech->submit_form(with_fields => $fields, button => 'twitter_sign_in');

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

                my $user = FixMyStreet::App->model( 'DB::User' )->find( { email => $tw_email } );
                if ($page eq 'my') {
                    is $user, undef, 'No user yet exists';
                } else {
                    is $user->twitter_id, undef, 'User has no twitter ID';
                }
                $mech->get_ok( $url );
                $user = FixMyStreet::App->model( 'DB::User' )->find( { email => $tw_email } );
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

END {
    done_testing();
}
