use FixMyStreet::TestMech;
use t::Mock::Twilio;

my $twilio = t::Mock::Twilio->new;
LWP::Protocol::PSGI->register($twilio->to_psgi_app, host => 'api.twilio.com');

my $mech = FixMyStreet::TestMech->new;
my $user = $mech->create_user_ok('test@example.com', name => 'Test User');
my $user2 = $mech->create_user_ok('commenter@example.com', name => 'Commenter');
my $body = $mech->create_body_ok(2504, 'Westminster City Council');

my $dt = DateTime->new(
    year => 2011,
    month => 04,
    day => 16,
    hour => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode => 'SW1A 1AA',
        bodies_str => $body->id,
        areas => ',105255,11806,11828,2247,2504,',
        category => 'Other',
        title => 'Test 2',
        detail => 'Test 2 Detail',
        used_map => 't',
        name => 'Test User',
        anonymous => 'f',
        state => 'confirmed',
        confirmed => $dt->ymd . ' ' . $dt->hms,
        lang => 'en-gb',
        service => '',
        cobrand => 'default',
        cobrand_data => '',
        send_questionnaire => 't',
        latitude => '51.5016605453401',
        longitude => '-0.142497580865087',
        user_id => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

my $comment = FixMyStreet::App->model('DB::Comment')->find_or_create( {
    problem_id => $report_id,
    user_id => $user2->id,
    name => 'Other User',
    mark_fixed => 'false',
    text => 'This is some update text',
    state => 'confirmed',
    confirmed => $dt->ymd . ' ' . $dt->hms,
    anonymous => 'f',
});

my $comment_id = $comment->id;
ok $comment, "created test update - $comment_id";

for my $test (
    {
        desc => 'Invalid phone',
        fields => {
            username => '01214960000000',
            update => 'Update',
            name => 'Name',
            photo1 => '',
            photo2 => '',
            photo3 => '',
            fixed => undef,
            add_alert => 1,
            may_show_name => undef,
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        field_errors => [ 'Please check your phone number is correct' ]
    },
    {
        desc => 'landline number',
        fields => {
            username => '01214960000',
            update => 'Update',
            name => 'Name',
            photo1 => '',
            photo2 => '',
            photo3 => '',
            fixed => undef,
            add_alert => 1,
            may_show_name => undef,
            password_register => '',
            password_sign_in => '',
        },
        changes => {
            username => '0121 496 0000',
        },
        field_errors => [ 'Please enter a mobile number' ]
    },
  )
{
    subtest "submit an update - $test->{desc}" => sub {
        $mech->get_ok("/report/$report_id");

        FixMyStreet::override_config {
            SMS_AUTHENTICATION => 1,
            PHONE_COUNTRY => 'GB',
        }, sub {
            $mech->submit_form_ok( { with_fields => $test->{fields} }, 'submit update' );
        };

        is_deeply $mech->page_errors, $test->{field_errors}, 'field errors';

        my $values = {
            %{ $test->{fields} },
            %{ $test->{changes} },
        };

        is_deeply $mech->visible_form_values('updateForm'), $values, 'form changes';
    };
}

my $test_phone = '+61491570156';
for my $test (
    {
        desc => 'submit an update, unregistered, logged out',
        form_values => {
            submit_update => 1,
            username => $test_phone,
            update => 'Update from an unregistered user',
            add_alert => undef,
            name => 'Unreg User',
            may_show_name => undef,
        },
    },
    {
        desc => 'submit an update, unregistered, logged out, sign up for alerts',
        form_values => {
            submit_update => 1,
            username => $test_phone,
            update => 'Update from an unregistered user',
            add_alert => 1,
            name => 'Unreg User',
            may_show_name => undef,
        },
    },
    {
        desc => 'submit an update, registered, logged out, confirming by text',
        registered => 1,
        form_values => {
            submit_update => 1,
            username => $test_phone,
            update => 'Update from a registered user',
            add_alert => undef,
            name => 'Reg User',
            password_register => 'new_secret',
        },
    },
) {
    subtest $test->{desc} => sub {
        $mech->log_out_ok();
        my $user;
        if ($test->{registered}) {
            $user = $mech->create_user_ok( $test_phone );
            $user->update( { name => 'Mr Reg', password => 'secret2' } );
        }

        $mech->get_ok("/report/$report_id");
        FixMyStreet::override_config {
            SMS_AUTHENTICATION => 1,
            TWILIO_ACCOUNT_SID => 'AC123',
        }, sub {
            $mech->submit_form_ok( { with_fields => $test->{form_values} }, 'submit update');
        };
        $mech->content_contains('Nearly done! Now check your phone');

        if ($user) {
            $user->discard_changes;
            ok $user->check_password( 'secret2' ), 'password unchanged';
            is $user->name, 'Mr Reg', 'name unchanged';
        }

        my ($token) = $mech->content =~ /name="token" value="([^"]*)"/;
        $token = FixMyStreet::App->model('DB::Token')->find({
            token => $token,
            scope => 'comment'
        });
        ok $token, 'Token found in database';

        my $update_id = $token->data->{id};
        my $add_alerts = $token->data->{add_alert};
        my $update = FixMyStreet::App->model('DB::Comment')->find( { id => $update_id } );

        ok $update, 'found update in database';
        is $update->state, 'unconfirmed', 'update unconfirmed';
        my $details = $test->{form_values};
        is $update->user->phone, $details->{username}, 'update phone';
        is $update->user->phone_verified, 1;
        is $update->text, $details->{update}, 'update text';
        is $add_alerts, $details->{add_alert} ? 1 : 0, 'do not sign up for alerts';

        my $code = $twilio->get_text_code;
        $mech->submit_form_ok( { with_fields => { code => '00000' } });
        $mech->content_contains('Try again');
        $mech->submit_form_ok( { with_fields => { code => $code } });

        $mech->content_contains("/report/$report_id#update_$update_id");

        if ($user) {
            $user->discard_changes;
            ok $user->check_password( 'new_secret' ), 'password changed';
            is $user->name, 'Reg User', 'name changed';
        } else {
            $user = FixMyStreet::App->model( 'DB::User' )->find( { phone => $details->{username} } );
            ok $user, 'found user';
        }

        my $alert = FixMyStreet::App->model( 'DB::Alert' )->find(
            { user => $user, alert_type => 'new_updates', confirmed => 1, }
        );

        ok $details->{add_alert} ? defined( $alert ) : !defined( $alert ), 'sign up for alerts';

        $update->discard_changes;
        is $update->state, 'confirmed', 'update confirmed';
        $mech->delete_user( $user );
    };
}

for my $test (
    {
        desc => 'submit an update for a registered user, signing in with wrong password',
        form_values => {
            submit_update => 1,
            username => $test_phone,
            update => 'Update from a user',
            add_alert => undef,
            password_sign_in => 'secret',
        },
        field_errors => [
            "There was a problem with your login information. If you cannot remember your password, or do not have one, please fill in the \x{2018}No\x{2019} section of the form.",
            'Please enter your name', # FIXME Not really necessary error
        ],
    },
    {
        desc => 'submit an update for a registered user and sign in',
        form_values => {
            submit_update => 1,
            username => $test_phone,
            update => 'Update from a user',
            add_alert => undef,
            password_sign_in => 'secret2',
        },
        message => 'You have successfully signed in; please check and confirm your details are accurate:',
    }
) {
    subtest $test->{desc} => sub {
        # Set things up
        my $user = $mech->create_user_ok( $test->{form_values}->{username} );
        my $pw = 'secret2';
        $user->update( { name => 'Mr Reg', password => $pw } );
        $report->comments->delete;

        $mech->log_out_ok();
        $mech->clear_emails_ok();
        $mech->get_ok("/report/$report_id");
        FixMyStreet::override_config {
            SMS_AUTHENTICATION => 1,
        }, sub {
            $mech->submit_form_ok(
                {
                    button => 'submit_sign_in',
                    with_fields => $test->{form_values}
                },
                'submit update'
            );
        };

        $mech->content_contains($test->{message}) if $test->{message};

        is_deeply $mech->page_errors, $test->{field_errors}, 'check there were errors'
            if $test->{field_errors};

        SKIP: {
            skip( "Incorrect password", 4 ) unless $test->{form_values}{password_sign_in} eq $pw;

            # Now submit with a name
            $mech->submit_form_ok(
                { with_fields => { name => 'Joe Bloggs', } },
                "submit good details"
            );

            $mech->content_contains('Thank you for updating this issue');

            my $update = $report->comments->first;
            ok $update, 'found update';
            is $update->text, $test->{form_values}->{update}, 'update text';
            is $update->user->phone, $test->{form_values}->{username}, 'update user';
            is $update->state, 'confirmed', 'update confirmed';
            $mech->delete_user( $update->user );
        }
    };
}

done_testing();
