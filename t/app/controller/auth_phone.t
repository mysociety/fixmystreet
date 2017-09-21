use FixMyStreet::TestMech;

use t::Mock::Twilio;

my $twilio = t::Mock::Twilio->new;
LWP::Protocol::PSGI->register($twilio->to_psgi_app, host => 'api.twilio.com');

my $mech = FixMyStreet::TestMech->new;

subtest 'Log in with invalid number, fail' => sub {
    FixMyStreet::override_config {
        SMS_AUTHENTICATION => 1,
        PHONE_COUNTRY => 'GB',
        TWILIO_ACCOUNT_SID => 'AC123',
    }, sub {
        $mech->get_ok('/auth');
        $mech->submit_form_ok({
            form_name => 'general_auth',
            fields => { username => '01214960000000' },
            button => 'sign_in_by_code',
        }, "sign in using bad number");
        $mech->content_contains('Please check your phone number is correct');
    };
};

subtest 'Log in using landline, fail' => sub {
    FixMyStreet::override_config {
        SMS_AUTHENTICATION => 1,
        PHONE_COUNTRY => 'GB',
        TWILIO_ACCOUNT_SID => 'AC123',
    }, sub {
        $mech->get_ok('/auth');
        $mech->submit_form_ok({
            form_name => 'general_auth',
            fields => { username => '01214960000' },
            button => 'sign_in_by_code',
        }, "sign in using landline");
        $mech->content_contains('Please enter a mobile number');
    };
};

subtest 'Log in using mobile, by text' => sub {
    FixMyStreet::override_config {
        SMS_AUTHENTICATION => 1,
        PHONE_COUNTRY => 'GB',
        TWILIO_ACCOUNT_SID => 'AC123',
    }, sub {
        $mech->submit_form_ok({
            form_name => 'general_auth',
            fields => { username => '+61491570156', password_register => 'secret' },
            button => 'sign_in_by_code',
        }, "sign in using mobile");

        $mech->submit_form_ok({
            with_fields => { code => '00000' }
        }, 'submit incorrect code');
        $mech->content_contains('Try again');

        my $code = $twilio->get_text_code;
        $mech->submit_form_ok({
            with_fields => { code => $code }
        }, 'submit correct code');

        my $user = FixMyStreet::App->model('DB::User')->find( { phone => '+61491570156' } );
        ok $user, "user created";
        is $mech->uri->path, '/my', "redirected to the 'my' section of site";
        $mech->logged_in_ok;
        $mech->log_out_ok;
    };
};

subtest 'Log in using mobile, by password' => sub {
    FixMyStreet::override_config {
        SMS_AUTHENTICATION => 1,
    }, sub {
        $mech->get_ok('/auth');
        $mech->submit_form_ok({
            form_name => 'general_auth',
            fields => { username => '+61491570156', password_sign_in => 'incorrect' },
            button => 'sign_in_by_password',
        }, "sign in using wrong password");
        $mech->content_contains('There was a problem');
        $mech->submit_form_ok({
            form_name => 'general_auth',
            fields => { username => '+61491570156', password_sign_in => 'secret' },
            button => 'sign_in_by_password',
        }, "sign in using password");

        is $mech->uri->path, '/my', "redirected to the 'my' section of site";
        $mech->logged_in_ok;
    };
};

done_testing();
