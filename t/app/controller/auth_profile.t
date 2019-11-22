package FixMyStreet::Cobrand::Dummy;
use parent 'FixMyStreet::Cobrand::Default';

sub must_have_2fa { 1 }

package main;

use Test::MockModule;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $resolver = Test::MockModule->new('Email::Valid');
$resolver->mock('address', sub { $_[1] });

use t::Mock::Twilio;

my $twilio = t::Mock::Twilio->new;
LWP::Protocol::PSGI->register($twilio->to_psgi_app, host => 'api.twilio.com');

my $test_email    = 'test@example.com';
my $test_email2   = 'test@example.net';
my $test_password = 'foobar123';

# get a sign in email and change password
subtest "Test change password page" => sub {
    $mech->clear_emails_ok;
    $mech->get_ok('/auth');
    $mech->submit_form_ok(
        {
            form_name => 'general_auth',
            fields    => {
                username => $test_email,
                r     => 'faq', # Just as a test
            },
            button => 'sign_in_by_code',
        },
        "sign_in_by_code with '$test_email'"
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

    my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    ok $user, "got a user";
    ok !$user->password, "user has no password";

    $mech->get_ok('/auth/change_password');
    $mech->submit_form_ok(
        {
            form_name => 'change_password',
            fields =>
              { new_password => 'new_password', confirm => 'new_password', },
        },
        "change_password with 'new_password' and 'new_password'"
    );
    is $mech->uri->path, '/auth/change_password',
      "still on change password page";
    $mech->content_contains('check your email');

    $link = $mech->get_link_from_email;
    $mech->get_ok($link);
    is $mech->uri->path, '/my', "redirected to /my";

    $mech->content_contains( 'password has been changed',
        "found password changed" );

    $user->discard_changes();
    ok $user->password, "user now has a password";
};

# Change password, when already got one
subtest "Test change password page with current password" => sub {
    $mech->get_ok('/auth/change_password');

    ok my $form = $mech->form_name('change_password'),
      "found change password form";
    is_deeply [ sort grep { $_ } map { $_->name } $form->inputs ],    #
      [ 'confirm', 'current_password', 'new_password', 'token' ],
      "check we got expected fields (ie not old_password)";

    # check the various ways the form can be wrong
    for my $test (
        { current => '', new => '', conf => '', err => 'check the passwords', },
        { current => 'new_password', new => '', conf => '', err => 'enter a password', },
        { current => 'new_password', new => 'secret', conf => '', err => 'do not match', },
        { current => 'new_password', new => '', conf => 'secret', err => 'do not match', },
        { current => 'new_password', new => 'secret', conf => 'not_secret', err => 'do not match', },
      )
    {
        $mech->get_ok('/auth/change_password');
        $mech->content_lacks( $test->{err}, "did not find expected error" );
        $mech->submit_form_ok(
            {
                form_name => 'change_password',
                fields =>
                  { current_password => $test->{current}, new_password => $test->{new}, confirm => $test->{conf}, },
            },
            "change_password with '$test->{current}', '$test->{new}' and '$test->{conf}'"
        );
        $mech->content_contains( $test->{err}, "found expected error" );
    }

    my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    ok $user, "got a user";

    $mech->get_ok('/auth/change_password');
    $mech->submit_form_ok(
        {
            form_name => 'change_password',
            fields =>
              { current_password => 'new_password', new_password => $test_password, confirm => $test_password },
        },
        "change_password with 'new_password' and '$test_password'"
    );
    is $mech->uri->path, '/auth/change_password',
      "still on change password page";
    $mech->content_contains( 'password has been changed',
        "found password changed" );

    $user->discard_changes();
    ok $user->password, "user now has a password";
};

subtest 'check password length/common' => sub {
    $mech->get_ok('/auth/change_password');
    $mech->submit_form_ok({
        form_name => 'change_password',
        fields => { current_password => $test_password, new_password => 'short', confirm => 'short' },
    });
    $mech->content_contains("Please make sure your password is at least");
    $mech->submit_form_ok({
        form_name => 'change_password',
        fields => { current_password => $test_password, new_password => 'common', confirm => 'common' },
    });
    $mech->content_contains("Please choose a less commonly-used password");
};

subtest "Test change email page" => sub {
    $mech->create_problems_for_body(1, 2514, 'Title1', { user => FixMyStreet::DB->resultset('User')->find( { email => $test_email } ) } );

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
    is $mech->uri->path, '/my', "redirected to /my page";
    $mech->content_contains('successfully confirmed');
    ok(FixMyStreet::DB->resultset('User')->find( { email => $test_email2 } ), "got a user");

    my $p = FixMyStreet::DB->resultset("Problem")->first;
    is $p->user->email, $test_email2, 'problem user updated';

    my $user1 = FixMyStreet::DB->resultset('User')->create( { email => $test_email, email_verified => 1 } );
    ok($user1, "created old user");
    $mech->create_problems_for_body(1, 2514, 'Title1', { user => $user1 } );

    $mech->follow_link_ok({url => '/auth/change_email'});
    $mech->submit_form_ok({ with_fields => { email => $test_email } },
        "change_email back to $test_email"
    );
    is $mech->uri->path, '/auth/change_email', "still on change email page";
    $mech->content_contains( 'Now check your email', "found check your email" );
    $link = $mech->get_link_from_email;
    $mech->get_ok($link);
    is $mech->uri->path, '/my', "redirected to /my page";
    $mech->content_contains('successfully confirmed');

    for (FixMyStreet::DB->resultset("Problem")->all) {
        is $_->user->email, $test_email;
    }

    # Test you can't click the link if logged out
    $mech->follow_link_ok({url => '/auth/change_email'});
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

my $test_phone_bad = '01214960000000';
my $test_landline = '01214960000';
my $test_mobile = '+61491570156';
my $test_mobile2 = '+61491570157';

my $user_mob2 = FixMyStreet::DB->resultset('User')->create( {
    phone => $test_mobile,
    phone_verified => 1,
    name => 'Aus Mobile user',
} );
$mech->create_problems_for_body(1, 2514, 'Title1', { user => $user_mob2 } );

subtest "Test add/verify/change phone page" => sub {
    $mech->get_ok('/auth');
    $mech->submit_form_ok({
        with_fields => {
            username => $test_email,
            password_sign_in => $test_password,
        },
    });

    $mech->follow_link_ok({url => '/auth/change_phone'});
    $mech->submit_form_ok( { with_fields => { username => "" } }, "submit blank change phone form" );
    is $mech->uri->path, '/my', 'redirected';
    $mech->content_contains('successfully removed');

    $mech->follow_link_ok({url => '/auth/change_phone'});
    $mech->submit_form_ok({ with_fields => { username => $test_phone_bad } });
    $mech->content_contains( 'Please check your phone number is correct', "found expected error" );

    FixMyStreet::override_config({
        SMS_AUTHENTICATION => 1,
        PHONE_COUNTRY => 'GB',
    }, sub {
        $mech->submit_form_ok({ with_fields => { username => $test_landline } });
    });
    is $mech->uri->path, '/my', 'redirected';
    $mech->content_contains('successfully added');

    FixMyStreet::override_config({
        SMS_AUTHENTICATION => 1,
        PHONE_COUNTRY => 'GB',
    }, sub {
        $mech->follow_link_ok({url => '/auth/verify/phone'});
        $mech->submit_form_ok({ with_fields => { username => $test_landline } });
    });
    $mech->content_contains( 'Please enter a mobile number', "found expected error" );

    FixMyStreet::override_config({
        SMS_AUTHENTICATION => 1,
        TWILIO_ACCOUNT_SID => 'AC123',
    }, sub {
        $mech->submit_form_ok({ with_fields => { username => $test_mobile } });
    });
    is $mech->uri->path, '/auth/verify/phone', "still on change phone page";
    $mech->content_contains( 'Now check your phone', "found check your phone" );

    $mech->submit_form_ok({
        with_fields => { code => '00000' }
    }, 'submit incorrect code');
    $mech->content_contains('Try again');

    my $code = $twilio->get_text_code;
    $mech->submit_form_ok({
        with_fields => { code => $code }
    }, 'submit correct code');

    my $user = FixMyStreet::DB->resultset('User')->find( { phone => $test_mobile } );
    ok $user, "user exists";
    is $user->email_verified, 1;
    is $user->email, $test_email, 'email still same';
    is $mech->uri->path, '/my', "redirected to /my page";
    $mech->content_contains('successfully verified');
    $mech->logged_in_ok;
};

subtest "Test change phone to existing account" => sub {
    $mech->get_ok('/auth');
    FixMyStreet::override_config({
        SMS_AUTHENTICATION => 1,
    }, sub {
        $mech->submit_form_ok({
            with_fields => {
                username => $test_mobile,
                password_sign_in => $test_password,
            },
        });
    });

    $mech->follow_link_ok({url => '/auth/change_phone'});

    FixMyStreet::override_config({
        SMS_AUTHENTICATION => 1,
        TWILIO_ACCOUNT_SID => 'AC123',
    }, sub {
        $mech->submit_form_ok({ with_fields => { username => $test_mobile2 } });
    });
    is $mech->uri->path, '/auth/change_phone', "still on change phone page";
    $mech->content_contains( 'Now check your phone', "found check your phone" );

    my $code = $twilio->get_text_code;
    $mech->submit_form_ok({ with_fields => { code => $code } }, 'submit correct code');

    my $user = FixMyStreet::DB->resultset('User')->find( { phone => $test_mobile } );
    ok !$user, 'old user does not exist';
    $user = FixMyStreet::DB->resultset('User')->find( { phone => $test_mobile2 } );
    ok $user, "new mobile user exists";
    is $user->email_verified, 1;
    is $user->email, $test_email, 'email still same';
    is $mech->uri->path, '/my', "redirected to /my page";
    $mech->content_contains('successfully verified');

    for (FixMyStreet::DB->resultset("Problem")->all) {
        is $_->user->email, $test_email;
    }
};

subtest "Test superuser can access generate token page" => sub {
    my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    ok $user->update({ is_superuser => 0 }), 'user not superuser';

    $mech->log_out_ok;
    $mech->get_ok('/auth');
    $mech->submit_form_ok({
        with_fields => {
            username => $test_email,
            password_sign_in => $test_password,
        },
    });

    $mech->content_lacks('Security');

    $mech->get('/auth/generate_token');
    is $mech->res->code, 403, "access denied";

    ok $user->update({ is_superuser => 1 }), 'user is superuser';

    $mech->get_ok('/my');
    $mech->content_contains('Security');
    $mech->get_ok('/auth/generate_token');
};

my $body = $mech->create_body_ok(2237, 'Oxfordshire');

subtest "Test staff user can access generate token page" => sub {
    my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    ok $user->update({ is_superuser => 0 }), 'user not superuser';

    $mech->log_out_ok;
    $mech->get_ok('/auth');
    $mech->submit_form_ok({
        with_fields => {
            username => $test_email,
            password_sign_in => $test_password,
        },
    });

    $mech->content_lacks('Security');

    $mech->get('/auth/generate_token');
    is $mech->res->code, 403, "access denied";

    ok $user->update({ from_body => $body }), 'user is staff user';

    $mech->get_ok('/my');
    $mech->content_contains('Security');
    $mech->get_ok('/auth/generate_token');
};

subtest "Test generate token page" => sub {
    my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    ok $user->update({ is_superuser => 1 }), 'user set to superuser';

    $mech->log_out_ok;

    $mech->get_ok('/auth');
    $mech->submit_form_ok({
        with_fields => {
            username => $test_email,
            password_sign_in => $test_password,
        },
    });

    ok !$user->get_extra_metadata('access_token');

    $mech->get_ok('/my');
    $mech->follow_link_ok({url => '/auth/generate_token'});
    $mech->content_lacks('Token:');
    $mech->submit_form_ok(
        { button => 'generate_token' },
        "submit generate token form"
    );
    $mech->content_contains( 'Your token has been generated', "token generated" );

    $user->discard_changes();
    my $token = $user->get_extra_metadata('access_token');
    ok $token, 'access token set';

    $mech->content_contains($token, 'access token displayed');

    $mech->get_ok('/auth/generate_token');
    $mech->content_contains('Current token:');
    $mech->content_contains($token, 'access token displayed');
    $mech->content_contains('If you generate a new token');

    $mech->log_out_ok;
    $mech->add_header('Authorization', "Bearer $token");
    $mech->logged_in_ok;
    $mech->delete_header('Authorization');
};

subtest "Test two-factor authentication admin" => sub {
  for (0, 1) {
    my $user = $mech->log_in_ok($test_email);
    if ($_) {
        ok $user->update({ is_superuser => 1, from_body => undef }), 'user set to superuser';
    } else {
        ok $user->update({ is_superuser => 0, from_body => $body }), 'user set to staff user';
    }

    $mech->get_ok('/auth/generate_token');
    ok !$user->get_extra_metadata('2fa_secret');

    $mech->submit_form_ok({ button => '2fa_activate' }, "submit 2FA activation");
    my ($token) = $mech->content =~ /name="secret32" value="([^"]*)">/;

    use Auth::GoogleAuth;
    my $auth = Auth::GoogleAuth->new({ secret32 => $token });
    my $code = $auth->code;
    my $wrong_code = $auth->code(undef, time() - 120);

    $mech->submit_form_ok({ with_fields => { '2fa_code' => $wrong_code } }, "provide wrong 2FA code" );
    $mech->content_contains('Try again');
    $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );

    $mech->content_contains('has been activated', "2FA activated");

    $user->discard_changes();
    my $user_token = $user->get_extra_metadata('2fa_secret');
    is $token, $user_token, '2FA secret set';

    $mech->get_ok('/auth/generate_token');
    $mech->content_lacks($token, 'secret no longer displayed');

    $mech->submit_form_ok({ button => '2fa_deactivate' }, "submit 2FA deactivation");
    $mech->content_contains('has been deactivated', "2FA deactivated");
  }
};

subtest "Test enforced two-factor authentication" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'dummy',
    }, sub {
        use Auth::GoogleAuth;
        my $auth = Auth::GoogleAuth->new;
        my $code = $auth->code;

        # Sign in with 2FA
        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        $user->password('password');
        $user->set_extra_metadata('2fa_secret', $auth->secret32);
        $user->update;

        $mech->get_ok('/auth');
        $mech->submit_form_ok(
            { with_fields => { username => $test_email, password_sign_in => 'password' } },
            "sign in using form" );
        $mech->content_contains('Please generate a two-factor code');
        $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );

        $mech->get_ok('/auth/generate_token');
        $mech->content_contains('Change two-factor');
        $mech->content_lacks('Deactivate two-factor');

        my ($csrf) = $mech->content =~ /meta content="([^"]*)" name="csrf-token"/;
        $mech->post_ok('/auth/generate_token', {
            '2fa_deactivate' => 1,
            'token' => $csrf,
        });
        $mech->content_lacks('has been deactivated', "2FA not deactivated");
        $mech->content_contains('Please scan this image', 'Change 2FA page shown instead');
    };
};

done_testing();
