use strict;
use warnings;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use Test::More tests => 44;
use Email::Send::Test;

use FixMyStreet::App;

use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';
my $mech = Test::WWW::Mechanize::Catalyst->new;

my $test_email = 'test@example.com';

END {
    ok(
        FixMyStreet::App->model('DB::User')->find( { email => $test_email } )
          ->delete,
        "delete test user"
    );
}

$mech->get_ok('/auth');

# check that we can't reach a page that is only available to authenticated users
is $mech->get('/auth/check_auth')->code, 401, "got 401 at check_auth";

# check that submitting form with no / bad email creates an error.
$mech->get_ok('/auth');

for my $test (
    [ ''                         => 'enter an email address' ],
    [ 'not an email'             => 'check your email address is correct' ],
    [ 'bob@foo'                  => 'check your email address is correct' ],
    [ 'bob@foonaoedudnueu.co.uk' => 'check your email address is correct' ],
  )
{
    my ( $email, $error_message ) = @$test;
    pass "--- testing bad email '$email' gives error '$error_message'";
    $mech->get_ok('/auth');
    $mech->content_lacks($error_message);
    $mech->submit_form_ok(
        {
            form_name => 'general_auth',
            fields    => { email => $email, },
            button    => 'create_account',
        },
        "try to create an account with email '$email'"
    );
    is $mech->uri->path, '/auth', "still on auth page";
    $mech->content_contains($error_message);
}

# create a new account
Email::Send::Test->clear;
$mech->get_ok('/auth');
$mech->submit_form_ok(
    {
        form_name => 'general_auth',
        fields    => { email => $test_email, },
        button    => 'create_account',
    },
    "create an account for '$test_email'"
);
is $mech->uri->path, '/auth/welcome', "redirected to welcome page";

# check that we are now logged in
$mech->get_ok("/auth/check_auth");

# check that we got one email
{
    my @emails = Email::Send::Test->emails;
    Email::Send::Test->clear;

    is scalar(@emails), 1, "got one email";
    is $emails[0]->header('Subject'), "Your new FixMyStreet.com account",
      "subject is correct";
    is $emails[0]->header('To'), $test_email, "to is correct";

    # extract the link
    my ($link) = $emails[0]->body =~ m{(http://\S+)};
    ok $link, "Found a link in email '$link'";

    # check that the user is currently not confirmed
    my $user =
      FixMyStreet::App->model('DB::User')->find( { email => $test_email } );
    ok $user, "got a user";
    ok !$user->is_confirmed, "user has not been confirmed";

    # visit the confirm link (with bad token) and check user no confirmed
    $mech->get_ok( $link . 'XXX' );
    $user->discard_changes;
    ok !$user->is_confirmed, "user has not been confirmed";

    # visit the confirm link and check user is confirmed
    $mech->get_ok($link);
    $user->discard_changes;
    ok $user->is_confirmed, "user has been confirmed";
}

# logout
$mech->get_ok("/auth/logout");
is $mech->get('/auth/check_auth')->code, 401, "got 401 at check_auth";

# login using valid details

# logout

# try to login with bad details

# try to create an account with bad details

# get a password reset email (for bad email address)

# get a password reminder (for good email address)

# try using  bad reset token

# use the good reset token and change the password

# try to use the good token again

# delete the test user
