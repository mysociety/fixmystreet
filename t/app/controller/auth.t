use Test::MockModule;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $test_email    = 'test@example.com';
my $test_email2   = 'test@example.net';
my $test_email3   = 'newuser@example.org';
my $test_password = 'foobar';

END {
    done_testing();
}

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
            fields    => { email => $email, },
            button    => 'email_sign_in',
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
        fields    => { email => $test_email, },
        button    => 'email_sign_in',
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

    # logout
    $mech->log_out_ok;
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

    my $link = $mech->get_link_from_email;
    $mech->get_ok($link);
    is $mech->uri->path, '/faq', "redirected to the Help page";

    $mech->get_ok('/auth/change_password');

    ok my $form = $mech->form_name('change_password'),
      "found change password form";
    is_deeply [ sort grep { $_ } map { $_->name } $form->inputs ],    #
      [ 'confirm', 'new_password', 'token' ],
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

subtest "Test change email page" => sub {
    # Still signed in from the above test
    $mech->get_ok('/my');
    $mech->follow_link_ok({url => '/auth/change_email'});
    $mech->submit_form_ok(
        { with_fields => { email => "" } },
        "submit blank change email form"
    );
    $mech->content_contains( 'Please enter your email', "found expected error" );
    $mech->submit_form_ok({ with_fields => { email => $test_email2 } }, "change_email to $test_email2");
    is $mech->uri->path, '/auth/change_email', "still on change email page";
    $mech->content_contains( 'Now check your email', "found check your email" );
    my $link = $mech->get_link_from_email;
    $mech->get_ok($link);
    is $mech->uri->path, '/auth/change_email/success', "redirected to the change_email page";
    $mech->content_contains('successfully confirmed');
    ok(FixMyStreet::App->model('DB::User')->find( { email => $test_email2 } ), "got a user");

    ok(FixMyStreet::App->model('DB::User')->create( { email => $test_email } ), "created old user");
    $mech->submit_form_ok({ with_fields => { email => $test_email } },
        "change_email back to $test_email"
    );
    is $mech->uri->path, '/auth/change_email', "still on change email page";
    $mech->content_contains( 'Now check your email', "found check your email" );
    $link = $mech->get_link_from_email;
    $mech->get_ok($link);
    is $mech->uri->path, '/auth/change_email/success', "redirected to the change_email page";
    $mech->content_contains('successfully confirmed');

    # Test you can't click the link if logged out
    $mech->submit_form_ok({ with_fields => { email => $test_email } },
        "change_email back to $test_email"
    );
    is $mech->uri->path, '/auth/change_email', "still on change email page";
    $mech->content_contains( 'Now check your email', "found check your email" );
    $link = $mech->get_link_from_email;
    $mech->log_out_ok;
    $mech->get_ok($link);
    isnt $mech->uri->path, '/auth/change_email/success', "not redirected to the change_email page";
    $mech->content_contains('Sorry');
};

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
            "sign in with '$test_email' & '$test_password'"
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
    "sign in with '$test_email' & 'not the password'"
);
is $mech->uri->path, '/auth', "redirected to correct page";
$mech->content_contains( 'problem with your email/password combination', 'found error message' );

subtest "sign in but have email form autofilled" => sub {
    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        {
            form_name => 'general_auth',
            fields    => {
                email    => $test_email,
                password_sign_in => $test_password,
                name => 'Auto-completed from elsewhere',
            },
            button => 'sign_in',
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
                email    => $uc_test_email,
                password_sign_in => $test_password,
            },
            button => 'sign_in',
        },
        "sign in with '$uc_test_email' and auto-completed name"
    );
    is $mech->uri->path, '/my', "redirected to correct page";

    $mech->content_contains($test_email);
    $mech->content_lacks($uc_test_email);

    my $count = FixMyStreet::App->model('DB::User')->search( { email => $uc_test_email } )->count;
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
                fields    => { email => $test_email3, },
                button    => 'email_sign_in',
            },
            "create a new account"
        );

        ok $mech->email_count_is(0);

        my $count = FixMyStreet::App->model('DB::User')->search( { email => $test_email3 } )->count;
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
                    email             => "$test_email",
                    password_register => $new_password,
                    r                 => 'faq', # Just as a test
                },
                button    => 'email_sign_in',
            },
            "email_sign_in with '$test_email'"
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
                    email    => $test_email,
                    password_sign_in => $new_password,
                },
                button => 'sign_in',
            },
            "sign in with '$test_email' and new password"
        );
        is $mech->uri->path, '/my', "redirected to correct page";
    };
};
