use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $notts_police = $mech->create_body_ok(2236, 'Immediate Justice', {}, { cobrand => 'nottinghamshirepolice' });
my $contact = $mech->create_contact_ok( body_id => $notts_police->id, category => 'Graffiti', email => 'graffiti@example.org' );

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

done_testing();