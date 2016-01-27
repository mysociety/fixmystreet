use strict;
use warnings;
use Test::More;
use LWP::Protocol::PSGI;
use LWP::Simple;
use JSON::MaybeXS;

use t::Mock::Facebook;
use t::Mock::MapIt;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;
 
# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my ($report) = $mech->create_problems_for_body(1, '2345', 'Test');

LWP::Protocol::PSGI->register(t::Mock::MapIt->to_psgi_app, host => 'mapit.uk');

FixMyStreet::override_config {
    FACEBOOK_APP_ID => 'facebook-app-id',
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

my $fb_email = 'facebook@example.org';
my $fb_uid = 123456789;

for my $fb_state ( 'refused', 'no email', 'existing UID', 'okay' ) {
    for my $page ( 'my', 'report', 'update' ) {
        subtest "test FB '$fb_state' login for page '$page'" => sub {
            $mech->log_out_ok;
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
                if ($page eq 'update') {
                    $fields->{rznvy} = $fb_email;
                } else {
                    $fields->{email} = $fb_email;
                }
                $fields->{name} = 'Ffion Tester';
                $mech->submit_form(with_fields => $fields);
                $mech->content_contains('Nearly done! Now check your email');

                my $email = $mech->get_email;
                ok $email, "got an email";
                $mech->clear_emails_ok;
                my ( $url, $url_token ) = $email->body =~ m{(https?://\S+/[CMP]/)(\S+)};
                ok $url, "extracted confirm url '$url'";

                my $user = FixMyStreet::App->model( 'DB::User' )->find( { email => $fb_email } );
                if ($page eq 'my') {
                    is $user, undef, 'No user yet exists';
                } else {
                    is $user->facebook_id, undef, 'User has no facebook ID';
                }
                $mech->get_ok( $url . $url_token );
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

};

END {
    $mech->delete_problems_for_body('2345');
    done_testing();
}
