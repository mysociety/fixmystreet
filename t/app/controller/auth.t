use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $test_email    = 'test@example.com';
my $test_password = 'foobar';
$mech->delete_user($test_email);

END {
    $mech->delete_user($test_email);
    done_testing();
}

$mech->get_ok('/auth');

# check that we can't reach a page that is only available to authenticated users
$mech->not_logged_in_ok;

# check that submitting form with no / bad email creates an error.
$mech->get_ok('/auth');

for my $test (
    [ ''                         => 'enter your email' ],
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
            button    => 'email_sign_in',
        },
        "try to create an account with email '$email'"
    );
    is $mech->uri->path, '/auth', "still on auth page";
    $mech->content_contains($error_message);
}

# create a new account
$mech->clear_emails_ok;
$mech->get_ok('/auth');
$mech->submit_form_ok(
    {
        form_name => 'general_auth',
        fields    => { email => $test_email, },
        button    => 'email_sign_in',
    },
    "create an account for '$test_email'"
);

# check that we are not logged in yet
$mech->not_logged_in_ok;

# check that we got one email
{
    $mech->email_count_is(1);
    my $email = $mech->get_email;
    $mech->clear_emails_ok;
    is $email->header('Subject'), "Your FixMyStreet.com account details",
      "subject is correct";
    is $email->header('To'), $test_email, "to is correct";

    # extract the link
    my ($link) = $email->body =~ m{(http://\S+)};
    ok $link, "Found a link in email '$link'";

    # check that the user does not exist
    sub get_user {
        FixMyStreet::App->model('DB::User')->find( { email => $test_email } );
    }
    ok !get_user(), "no user exists";

    # visit the confirm link (with bad token) and check user no confirmed
    $mech->get_ok( $link . 'XXX' );
    ok !get_user(), "no user exists";
    $mech->not_logged_in_ok;

    # visit the confirm link and check user is confirmed
    $mech->get_ok($link);
    ok get_user(), "user created";
    is $mech->uri->path, '/my', "redirected to the 'my' section of site";
    $mech->logged_in_ok;

    # logout and try to use the token again
    $mech->log_out_ok;
    $mech->get_ok($link);
    is $mech->uri, $link, "not logged in";
    $mech->content_contains( 'Link too old or already used',
        'token now invalid' );
    $mech->not_logged_in_ok;
}

# get a sign in email and change password
{
    $mech->clear_emails_ok;
    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        {
            form_name => 'general_auth',
            fields    => {
                email => "$test_email",
                r     => 'faq', # Just as a test
            },
            button    => 'email_sign_in',
        },
        "email_sign_in with '$test_email'"
    );

    # rest is as before so no need to test

    # follow link and change password - check not prompted for old password
    $mech->not_logged_in_ok;

    $mech->email_count_is(1);
    my $email = $mech->get_email;
    $mech->clear_emails_ok;
    my ($link) = $email->body =~ m{(http://\S+)};
    $mech->get_ok($link);
    is $mech->uri->path, '/faq', "redirected to the Help page";

    $mech->get_ok('/auth/change_password');

    ok my $form = $mech->form_name('change_password'),
      "found change password form";
    is_deeply [ sort grep { $_ } map { $_->name } $form->inputs ],    #
      [ 'confirm', 'new_password' ],
      "check we got expected fields (ie not old_password)";

    # check the various ways the form can be wrong
    for my $test (
        { new => '',       conf => '',           err => 'enter a password', },
        { new => 'secret', conf => '',           err => 'do not match', },
        { new => '',       conf => 'secret',     err => 'do not match', },
        { new => 'secret', conf => 'not_secret', err => 'do not match', },
      )
    {
        $mech->get_ok('/auth/change_password');
        $mech->content_lacks( $test->{err}, "did not find expected error" );
        $mech->submit_form_ok(
            {
                form_name => 'change_password',
                fields =>
                  { new_password => $test->{new}, confirm => $test->{conf}, },
            },
            "change_password with '$test->{new}' and '$test->{conf}'"
        );
        $mech->content_contains( $test->{err}, "found expected error" );
    }

    my $user =
      FixMyStreet::App->model('DB::User')->find( { email => $test_email } );
    ok $user, "got a user";
    ok !$user->password, "user has no password";

    $mech->get_ok('/auth/change_password');
    $mech->submit_form_ok(
        {
            form_name => 'change_password',
            fields =>
              { new_password => $test_password, confirm => $test_password, },
        },
        "change_password with '$test_password' and '$test_password'"
    );
    is $mech->uri->path, '/auth/change_password',
      "still on change password page";
    $mech->content_contains( 'password has been changed',
        "found password changed" );

    $user->discard_changes();
    ok $user->password, "user now has a password";
}

foreach my $remember_me ( '1', '0' ) {
    subtest "sign in using valid details (remember_me => '$remember_me')" => sub {
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            {
                form_name => 'general_auth',
                fields    => {
                    email       => $test_email,
                    password_sign_in => $test_password,
                    remember_me => ( $remember_me ? 1 : undef ),
                },
                button => 'sign_in',
            },
            "sign in with '$test_email' & '$test_password"
        );
        is $mech->uri->path, '/my', "redirected to correct page";

        my $expiry = $mech->session_cookie_expiry;
        $remember_me
          ? cmp_ok( $expiry, '>', 86400, "long expiry time" )
          : is( $expiry, 0, "no expiry time" );

        # logout
        $mech->log_out_ok;
    };
}

# try to sign in with bad details
$mech->get_ok('/auth');
$mech->submit_form_ok(
    {
        form_name => 'general_auth',
        fields    => {
            email    => $test_email,
            password_sign_in => 'not the password',
        },
        button => 'sign_in',
    },
    "sign in with '$test_email' & '$test_password"
);
is $mech->uri->path, '/auth', "redirected to correct page";
$mech->content_contains( 'problem with your email/password combination', 'found error message' );

# more test:
# TODO: test that email are always lowercased
