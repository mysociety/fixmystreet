use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $notts_police = $mech->create_body_ok(2236, 'Immediate Justice', {}, { cobrand => 'nottinghamshirepolice' });
my $contact = $mech->create_contact_ok( body_id => $notts_police->id, category => 'Graffiti', email => 'graffiti@example.org' );
my $contact_referral = $mech->create_contact_ok( body_id => $notts_police->id, category => 'Council referral', email => 'council-referral' );
my $staff = $mech->create_user_ok( 'staff@example.org', from_body => $notts_police->id );
$staff->user_body_permissions->create({ body => $notts_police, permission_type => 'report_edit' });

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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'nottinghamshirepolice',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        borough_email_addresses => {
            nottinghamshirepolice => {
                'council-referral' => [
                    { email => 'gedling@gov.uk.example.net', areas => [ 2412 ] },
                    { email => 'nottingham@gov.uk.example.net', areas => [ 2565 ] },
                ]
            }
        }
    }
}, sub {
    subtest 'Get error when email included in report' => sub {
        $mech->get_ok('/report/new?longitude=-1.151204&latitude=52.956196');
        $mech->submit_form_ok({ with_fields => { category => 'Graffiti', title => 'Graffiti', detail => 'On subway wall', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains('Click the link in our confirmation email to publish your problem', 'Detail field without email proceeds normally');
        $mech->get_ok('/report/new?longitude=-1.151204&latitude=52.956196');
        $mech->submit_form_ok({ with_fields => { category => 'Graffiti', title => 'Graffiti', detail => 'On subway wall. Contact me at user@example.org', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains("<p class='form-error'>Please remove any email addresses from report", "Report detail with email gives error");
        $mech->get_ok('/report/new?longitude=-1.151204&latitude=52.956196');
        $mech->submit_form_ok({ with_fields => { category => 'Graffiti', title => 'Graffiti contact me me@me.co.uk', detail => 'On subway wall', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains("<p class='form-error'>Please remove any email addresses from report", "Report title with email gives error");
        $mech->clear_emails_ok;
    };

    subtest 'check redirecting to councils' => sub {
        my ($report) = $mech->create_problems_for_body(1, $notts_police->id, 'Title', {
            category => 'Graffiti',
            areas => ',2236,2412,',
            cobrand => 'nottinghamshirepolice',
            latitude => 52.956196,
            longitude => -1.151204,
        });
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        is $email->header('To'), '"Immediate Justice" <graffiti@example.org>';
        $mech->clear_emails_ok;

        $mech->log_in_ok($staff->email);
        $mech->get_ok('/admin/report_edit/' . $report->id);
        $mech->submit_form_ok({ with_fields => { category => 'Council referral' } });

        $report->discard_changes;
        is $report->whensent, undef;
        is $report->category, 'Council referral';
        is $report->get_extra_metadata('sent_to_council'), undef;

        FixMyStreet::Script::Reports::send();
        $email = $mech->get_email;
        is $email->header('To'), '"Gedling Borough Council" <gedling@gov.uk.example.net>';

        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('Sent to Gedling Borough Council');
        $report->discard_changes;
        is $report->get_extra_metadata('sent_to_council'), 'Gedling Borough Council';
    };
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
