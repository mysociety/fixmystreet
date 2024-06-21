use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $notts_police = $mech->create_body_ok(2236, 'Immediate Justice', {}, { cobrand => 'nottinghamshirepolice' });
my $contact = $mech->create_contact_ok( body_id => $notts_police->id, category => 'Graffiti', email => 'graffiti@example.org' );

my $standard_user_1
    = $mech->create_user_ok( 'user1@email.com', name => 'User 1' );
my $standard_user_2
    = $mech->create_user_ok( 'user2@email.com', name => 'User 2' );
my $staff_user = $mech->create_user_ok(
    'staff@email.com',
    name      => 'Staff User',
    from_body => $notts_police,
);
my $superuser = $mech->create_user_ok(
    'super@email.com',
    name         => 'Super User',
    is_superuser => 1,
);

subtest 'Get error when email included in report' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'nottinghamshirepolice',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/report/new?longitude=-1.151204&latitude=52.956196');
        $mech->submit_form_ok({ with_fields => { category => 'Graffiti', title => 'Graffiti', detail => 'On subway wall', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains('Click the link in our confirmation email to publish your problem', 'Detail field without email proceeds normally');
        $mech->get_ok('/report/new?longitude=-1.151204&latitude=52.956196');
        $mech->submit_form_ok({ with_fields => { category => 'Graffiti', title => 'Graffiti', detail => 'On subway wall. Contact me at user@example.org', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains("<p class='form-error'>Please remove any email addresses from report", "Report detail with email gives error");
        $mech->get_ok('/report/new?longitude=-1.151204&latitude=52.956196');
        $mech->submit_form_ok({ with_fields => { category => 'Graffiti', title => 'Graffiti contact me me@me.co.uk', detail => 'On subway wall', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains("<p class='form-error'>Please remove any email addresses from report", "Report title with email gives error");
    }
};

subtest 'Permissions for report updates' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'nottinghamshirepolice',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->delete_problems_for_body( $notts_police->id );

        my ($report) = $mech->create_problems_for_body(
            1,
            $notts_police->id,
            'A report',
            {   user     => $standard_user_1,
                category => 'Graffiti',
            },
        );

        subtest 'Open report' => sub {
            ok $report->is_open;

            note 'User not logged in';
            $mech->log_out_ok;
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_unlike(
                qr/select.*id="state"/,
                'no state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_fixed"/,
                'no checkbox for fixed',
            );

            note 'Original reporter logged in';
            $mech->log_in_ok( $standard_user_1->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_unlike(
                qr/select.*id="state"/,
                'no state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_fixed"/,
                'no checkbox for fixed',
            );

            note 'Another standard user logged in';
            $mech->log_in_ok( $standard_user_2->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_unlike(
                qr/select.*id="state"/,
                'no state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_fixed"/,
                'no checkbox for fixed',
            );

            note 'Staff logged in';
            $mech->log_in_ok( $staff_user->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_like(
                qr/select.*id="state"/,
                'has state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_fixed"/,
                'no checkbox for fixed',
            );

            note 'Superuser logged in';
            $mech->log_in_ok( $superuser->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_like(
                qr/select.*id="state"/,
                'has state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_fixed"/,
                'no checkbox for fixed',
            );
        };

        subtest 'Closed report' => sub {
            $report->state('fixed');
            $report->update;
            ok !$report->is_open;

            note 'User not logged in';
            $mech->log_out_ok;
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_unlike(
                qr/select.*id="state"/,
                'no state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_reopen"/,
                'no checkbox for reopen',
            );

            note 'Original reporter logged in';
            $mech->log_in_ok( $standard_user_1->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_unlike(
                qr/select.*id="state"/,
                'no state dropdown',
            );
            $mech->content_like(
                qr/input.*id="form_reopen"/,
                'has checkbox for reopen',
            );

            note 'Another standard user logged in';
            $mech->log_in_ok( $standard_user_2->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_unlike(
                qr/select.*id="state"/,
                'no state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_reopen"/,
                'no checkbox for reopen',
            );

            note 'Staff logged in';
            $mech->log_in_ok( $staff_user->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_like(
                qr/select.*id="state"/,
                'has state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_reopen"/,
                'no checkbox for reopen',
            );

            note 'Superuser logged in';
            $mech->log_in_ok( $superuser->email );
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_like(
                qr/textarea.*id="form_update"/,
                'can leave text update',
            );
            $mech->content_like(
                qr/select.*id="state"/,
                'has state dropdown',
            );
            $mech->content_unlike(
                qr/input.*id="form_reopen"/,
                'no checkbox for reopen',
            );
        };

        $mech->delete_problems_for_body( $notts_police->id );
    }
};

done_testing();
