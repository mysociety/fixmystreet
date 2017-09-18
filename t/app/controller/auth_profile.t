use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $test_email    = 'test@example.com';
my $test_email2   = 'test@example.net';
my $test_password = 'foobar';

END {
    done_testing();
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
            button => 'email_sign_in',
        },
        "email_sign_in with '$test_email'"
    );

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
