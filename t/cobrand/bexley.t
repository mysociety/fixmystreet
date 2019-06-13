use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

use_ok 'FixMyStreet::Cobrand::Bexley';

my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
$ukc->mock('lookup_site_code', sub {
    my ($self, $row, $buffer) = @_;
    is $row->latitude, 51.408484, 'Correct latitude';
    return "Road ID";
});

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        contact_email => {
            bexley => 'foo@bexley',
        }
    },
}, sub {
    my $cobrand = FixMyStreet::Cobrand::Bexley->new;
    like $cobrand->contact_email, qr/bexley/;
    is $cobrand->on_map_default_status, 'open';
    is_deeply $cobrand->disambiguate_location->{bounds}, [ 51.408484, 0.074653, 51.515542, 0.2234676 ];
};

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2494, 'London Borough of Bexley', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j' });
$mech->create_contact_ok(body_id => $body->id, category => 'Abandoned and untaxed vehicles', email => "ABAN");
$mech->create_contact_ok(body_id => $body->id, category => 'Lamp post', email => "LAMP");
$mech->create_contact_ok(body_id => $body->id, category => 'Parks and open spaces', email => "PARK");
$mech->create_contact_ok(body_id => $body->id, category => 'Dead animal', email => "ANIM");
$mech->create_contact_ok(body_id => $body->id, category => 'Something dangerous', email => "DANG");

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bexley' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => { open311_email => { bexley => { p1 => 'p1@bexley', lighting => 'thirdparty@notbexley.example.com' } } },
}, sub {

    subtest 'cobrand displays council name' => sub {
        ok $mech->host("bexley.fixmystreet.com"), "change host to bexley";
        $mech->get_ok('/');
        $mech->content_contains('Bexley');
    };

    subtest 'cobrand displays council name' => sub {
        $mech->get_ok('/reports/Bexley');
        $mech->content_contains('Bexley');
    };

    foreach my $test (
        { category => 'Abandoned and untaxed vehicles', email => 1, code => 'ABAN',
            extra => { 'name' => 'burnt', description => 'Was it burnt?', 'value' => 'Yes' } },
        { category => 'Abandoned and untaxed vehicles', code => 'ABAN',
            extra => { 'name' => 'burnt', description => 'Was it burnt?', 'value' => 'No' } },
        { category => 'Dead animal', email => 1, code => 'ANIM' },
        { category => 'Something dangerous', email => 1, code => 'DANG',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' } },
        { category => 'Something dangerous', code => 'DANG',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'No' } },
        { category => 'Parks and open spaces', email => 1, code => 'PARK',
            extra => { 'name' => 'reportType', description => 'Type of report', 'value' => 'Wild animal' } },
        { category => 'Parks and open spaces', code => 'PARK',
            extra => { 'name' => 'reportType', description => 'Type of report', 'value' => 'Maintenance' } },
        { category => 'Parks and open spaces', code => 'PARK',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' } },
        { category => 'Parks and open spaces', email => 1, code => 'PARK',
            extra => [
                { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' },
                { 'name' => 'reportType', description => 'Type of report', 'value' => 'Vandalism' },
            ] },
        { category => 'Lamp post', code => 'LAMP', email => 'thirdparty',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'No' } },
        { category => 'Lamp post', code => 'LAMP', email => 'p1.*thirdparty',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' } },
    ) {
        my ($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
            category => $test->{category}, cobrand => 'bexley',
            latitude => 51.408484, longitude => 0.074653,
        });
        if ($test->{extra}) {
            $report->set_extra_fields(ref $test->{extra} eq 'ARRAY' ? @{$test->{extra}} : $test->{extra});
            $report->update;
        }

        subtest 'NSGRef and correct email config' => sub {
            my $test_data = FixMyStreet::Script::Reports::send();
            my $req = $test_data->{test_req_used};
            my $c = CGI::Simple->new($req->content);
            is $c->param('service_code'), $test->{code};
            is $c->param('attribute[NSGRef]'), 'Road ID';

            if (my $t = $test->{email}) {
                my $email = $mech->get_email;
                if ($t eq 1) {
                    like $email->header('To'), qr/"Bexley P1 email".*bexley/;
                } else {
                    like $email->header('To'), qr/$t/;
                }
                like $mech->get_text_body_from_email($email), qr/NSG Ref: Road ID/;
                $mech->clear_emails_ok;
            } else {
                $mech->email_count_is(0);
            }
        };
    }

};

done_testing();
