package FixMyStreet::Cobrand::Dummy;
use parent 'FixMyStreet::Cobrand::Default';

sub must_have_2fa {
    my ($self, $user) = @_;
    return 'skip' if $user->name eq 'skip';
    return 1;
}

package FixMyStreet::Cobrand::Expiring;
use parent 'FixMyStreet::Cobrand::Default';

sub password_expiry { 86400 }

package main;

use Test::MockModule;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $test_email    = 'test@example.com';
my $test_email3   = 'newuser@example.org';
my $test_password = 'foobar123';

$mech->get_ok('/auth');

# check that we can't reach a page that is only available to authenticated users
$mech->not_logged_in_ok;

# check that submitting form with no / bad email creates an error.
$mech->get_ok('/auth');

for my $test (
    [ ''                         => 'Please enter your email' ],
    [ 'not an email'             => 'Please check your email address is correct' ],
    [ 'bob@foo'                  => 'Please check your email address is correct' ],
    [ 'bob@foonaoedudnueu.co.uk' => 'Please check your email address is correct' ],
  )
{
    my ( $email, $error_message ) = @$test;

    my $resolver = Test::MockModule->new('Net::DNS::Resolver');
    $resolver->mock('send', sub {
        my ($self, $domain, $type) = @_;
        return Net::DNS::Packet->new;
    });

    pass "--- testing bad email '$email' gives error '$error_message'";
    $mech->get_ok('/auth');
    is_deeply $mech->page_errors, [], 'no errors initially';
    $mech->submit_form_ok(
        {
            form_name => 'general_auth',
            fields => { username => $email, },
            button => 'sign_in_by_code',
        },
        "try to create an account with email '$email'"
    );
    is $mech->uri->path, '/auth', "still on auth page";
    is_deeply $mech->page_errors, [ $error_message ], 'errors match';
}

# Email address parsing should pass from here
my $resolver = Test::MockModule->new('Email::Valid');
$resolver->mock('address', sub { $_[1] });

# create a new account
$mech->clear_emails_ok;
$mech->get_ok('/auth');
$mech->submit_form_ok(
    {
        form_name => 'general_auth',
        fields => { username => $test_email, password_register => $test_password },
        button => 'sign_in_by_code',
    },
    "create an account for '$test_email'"
);

# check that we are not logged in yet
$mech->not_logged_in_ok;

# check that we got one email
{
    my $email = $mech->get_email;
    $mech->clear_emails_ok;
    is $email->header('Subject'), "Your FixMyStreet account details",
      "subject is correct";
    is $email->header('To'), $test_email, "to is correct";

    # extract the link
    my $link = $mech->get_link_from_email($email);

    # check that the user does not exist
    sub get_user {
        FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    }
    ok !get_user(), "no user exists";

    # visit the confirm link (with bad token) and check user no confirmed
    $mech->get_ok( $link . 'XXX' );
    ok !get_user(), "no user exists";
    $mech->not_logged_in_ok;

    # visit the confirm link and check user is confirmed
    $mech->get_ok($link);
    my $user = get_user();
    ok $user, "user created";
    is $mech->uri->path, '/my', "redirected to the 'my' section of site";
    ok $user->get_extra_metadata('last_password_change'), 'password change set';
    $mech->logged_in_ok;

    # logout
    $mech->log_out_ok;
}

# try to sign in with bad details
$mech->get_ok('/auth');
$mech->submit_form_ok(
    {
        form_name => 'general_auth',
        fields    => {
            username => $test_email,
            password_sign_in => 'not the password',
        },
        button => 'sign_in_by_password',
    },
    "sign in with '$test_email' & 'not the password'"
);
is $mech->uri->path, '/auth', "redirected to correct page";
$mech->content_contains( 'problem with your login information', 'found error message' );

subtest "sign in but have email form autofilled" => sub {
    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        {
            form_name => 'general_auth',
            fields    => {
                username => $test_email,
                password_sign_in => $test_password,
                name => 'Auto-completed from elsewhere',
            },
            button => 'sign_in_by_password',
        },
        "sign in with '$test_email' and auto-completed name"
    );
    is $mech->uri->path, '/my', "redirected to correct page";
};

$mech->log_out_ok;

subtest "sign in with uppercase email" => sub {
    $mech->get_ok('/auth');
    my $uc_test_email = uc $test_email;
    $mech->submit_form_ok(
        {
            form_name => 'general_auth',
            fields    => {
                username => $uc_test_email,
                password_sign_in => $test_password,
            },
            button => 'sign_in_by_password',
        },
        "sign in with '$uc_test_email' and auto-completed name"
    );
    is $mech->uri->path, '/my', "redirected to correct page";

    $mech->content_contains($test_email);
    $mech->content_lacks($uc_test_email);

    my $count = FixMyStreet::DB->resultset('User')->search( { email => $uc_test_email } )->count;
    is $count, 0, "uppercase user wasn't created";
};


FixMyStreet::override_config {
    SIGNUPS_DISABLED => 1,
}, sub {
    subtest 'signing in with an unknown email address disallowed' => sub {
        $mech->log_out_ok;
        # create a new account
        $mech->clear_emails_ok;
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            {
                form_name => 'general_auth',
                fields => { username => $test_email3, },
                button => 'sign_in_by_code',
            },
            "create a new account"
        );

        ok $mech->email_count_is(0);

        my $count = FixMyStreet::DB->resultset('User')->search( { email => $test_email3 } )->count;
        is $count, 0, "no user exists";
    };

    subtest 'signing in as known email address with new password is allowed' => sub {
        my $new_password = "myshinynewpassword";

        $mech->clear_emails_ok;
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            {
                form_name => 'general_auth',
                fields    => {
                    username => "$test_email",
                    password_register => $new_password,
                    r                 => 'faq', # Just as a test
                },
                button => 'sign_in_by_code',
            },
            "sign_in_by_code with '$test_email'"
        );

        $mech->not_logged_in_ok;

        ok $mech->email_count_is(1);
        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);
        is $mech->uri->path, '/faq', "redirected to the Help page";

        $mech->log_out_ok;

        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            {
                form_name => 'general_auth',
                fields    => {
                    username => $test_email,
                    password_sign_in => $new_password,
                },
                button => 'sign_in_by_password',
            },
            "sign in with '$test_email' and new password"
        );
        is $mech->uri->path, '/my', "redirected to correct page";
    };
};

subtest "check logging in with token" => sub {
    $mech->log_out_ok;
    $mech->not_logged_in_ok;

    my $user =  FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    # token needs to be 18 characters
    $user->set_extra_metadata('access_token', '1234567890abcdefgh');
    $user->update();

    $mech->add_header('Authorization', 'Bearer 1234567890abcdefgh');
    $mech->logged_in_ok;

    $mech->delete_header('Authorization');
    $mech->not_logged_in_ok;

    $mech->get_ok('/auth/check_auth?access_token=1234567890abcdefgh');

    $mech->add_header('Authorization', 'Bearer 1234567890abcdefgh');
    $user->set_extra_metadata('access_token', 'XXXXXXXXXXXXXXXXXX');
    $user->update();
    $mech->not_logged_in_ok;

    $mech->delete_header('Authorization');
};

subtest 'check password length/common' => sub {
    $mech->get_ok('/auth/create');
    $mech->submit_form_ok({
        form_name => 'general_auth',
        fields => { username => $test_email, password_register => 'short' },
        button => 'sign_in_by_code',
    });
    $mech->content_contains("Please make sure your password is at least");
    $mech->submit_form_ok({
        form_name => 'general_auth',
        fields => { username => $test_email, password_register => 'common' },
        button => 'sign_in_by_code',
    });
    $mech->content_contains("Please choose a less commonly-used password");
};

subtest 'check common password AJAX call' => sub {
    $mech->post_ok('/auth/common_password', { password_register => 'password' });
    $mech->content_contains("Please choose a less commonly-used password");
    $mech->post_ok('/auth/common_password', { password_register => 'squirblewirble' });
    $mech->content_contains("true");
};

subtest 'test forgotten password page' => sub {
    $mech->get_ok('/auth/forgot');
    $mech->content_contains('Forgot password');
    $mech->submit_form_ok({
        form_name => 'general_auth',
        fields => { username => $test_email, password_register => 'squirblewirble' },
        button => 'sign_in_by_code',
    });
    $mech->clear_emails_ok;
};

subtest "Test two-factor authentication login" => sub {
    use Auth::GoogleAuth;
    my $auth = Auth::GoogleAuth->new;
    my $code = $auth->code;
    my $wrong_code = $auth->code(undef, time() - 120);

    my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    $user->password('password');
    $user->set_extra_metadata('2fa_secret', $auth->secret32);
    $user->update;

    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        { with_fields => { username => $test_email, password_sign_in => 'password' } },
        "sign in using form" );
    $mech->content_contains('Please generate a two-factor code');
    $mech->submit_form_ok({ with_fields => { '2fa_code' => $wrong_code } }, "provide wrong 2FA code" );
    $mech->content_contains('Try again');
    $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
    $mech->logged_in_ok;
};

subtest "Test enforced two-factor authentication" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'dummy',
    }, sub {
        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        $user->unset_extra_metadata('2fa_secret');
        $user->update;

        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $test_email, password_sign_in => 'password' } },
            "sign in using form" );

        $mech->content_contains('requires two-factor');
        $mech->submit_form_ok({ with_fields => { '2fa_action' => 'activate' } }, "submit 2FA activation");
        my ($token) = $mech->content =~ /name="secret32" value="([^"]*)">/;

        use Auth::GoogleAuth;
        my $auth = Auth::GoogleAuth->new({ secret32 => $token });
        my $code = $auth->code;
        my $wrong_code = $auth->code(undef, time() - 120);

        $mech->submit_form_ok({ with_fields => { '2fa_code' => $wrong_code } }, "provide wrong 2FA code" );
        $mech->content_contains('Try again');
        $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
        $mech->content_contains('successfully enabled two-factor authentication', "2FA activated");

        $user->discard_changes();
        my $user_token = $user->get_extra_metadata('2fa_secret');
        is $token, $user_token, '2FA secret set';

        $mech->logged_in_ok;

        $user->name('skip');
        $user->update;
        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $test_email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('<h1>Your account');
    };
};

subtest "Test enforced two-factor authentication, no password yet set" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'dummy',
    }, sub {
        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        $user->unset_extra_metadata('2fa_secret');
        $user->name('Test User');
        $user->update;

        $mech->clear_emails_ok;
        $mech->get_ok('/auth');
        $mech->submit_form_ok({
            fields => { username => $test_email, password_register => $test_password },
            button => 'sign_in_by_code',
        }, "log in by email");

        my $link = $mech->get_link_from_email;
        $mech->get_ok($link);

        $mech->content_contains('requires two-factor');
        $mech->submit_form_ok({ with_fields => { '2fa_action' => 'activate' } }, "submit 2fa activation");
        my ($token) = $mech->content =~ /name="secret32" value="([^"]*)">/;

        my $auth = Auth::GoogleAuth->new({ secret32 => $token });
        my $code = $auth->code;
        $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2fa code" );

        $user->discard_changes();
        my $user_token = $user->get_extra_metadata('2fa_secret');
        is $token, $user_token, '2FA secret set';

        $mech->logged_in_ok;

        $mech->get_ok($link);
        $mech->content_contains('Please generate a two-factor code');
        $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
        $mech->content_lacks('requires two-factor');

        $user->name('skip');
        $user->update;
        $mech->get_ok($link);
        $mech->content_contains('Your account');
    };
};

subtest "Check two-factor log in by email works" => sub {
    use Auth::GoogleAuth;
    my $auth = Auth::GoogleAuth->new;
    my $code = $auth->code;

    my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    $user->set_extra_metadata('2fa_secret', $auth->secret32);
    $user->update;

    $mech->clear_emails_ok;
    $mech->get_ok('/auth');
    $mech->submit_form_ok({
        fields => { username => $test_email, password_register => $test_password },
        button => 'sign_in_by_code',
    }, "log in by email");

    my $link = $mech->get_link_from_email;
    $mech->get_ok($link);
    $mech->content_contains('Please generate a two-factor code');
    $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
    $mech->logged_in_ok;
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'expiring'
}, sub {
    subtest 'Password expiry' => sub {
        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        $user->set_extra_metadata('last_password_change', time() - 200000);
        $user->unset_extra_metadata('2fa_secret');
        $user->update;

        $mech->get_ok('/');
        $mech->content_contains('Password expired');
        $mech->submit_form_ok(
            { with_fields => { password_register => 'new-password' } },
            "fill in reset form" );

        my $link = $mech->get_link_from_email;
        $mech->clear_emails_ok;
        $mech->get_ok($link);
        $mech->logged_in_ok;
    };
};

done_testing();
