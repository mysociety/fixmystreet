use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Catalyst::Test 'FixMyStreet::App';

set_fixed_time('2019-10-16T17:00:00Z'); # Out of hours

use_ok 'FixMyStreet::Cobrand::Bexley';
use_ok 'FixMyStreet::Geocode::Bexley';

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
$mech->create_contact_ok(body_id => $body->id, category => 'Abandoned and untaxed vehicles', email => "ConfirmABAN");
$mech->create_contact_ok(body_id => $body->id, category => 'Lamp post', email => "StreetLightingLAMP");
$mech->create_contact_ok(body_id => $body->id, category => 'Gulley covers', email => "GULL");
$mech->create_contact_ok(body_id => $body->id, category => 'Damaged road', email => "ROAD");
$mech->create_contact_ok(body_id => $body->id, category => 'Flooding in the road', email => "ConfirmFLOD");
$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => "UniformFLY");
$mech->create_contact_ok(body_id => $body->id, category => 'Dead animal', email => "ANIM");
$mech->create_contact_ok(body_id => $body->id, category => 'Street cleaning and litter', email => "STREET");
my $category = $mech->create_contact_ok(body_id => $body->id, category => 'Something dangerous', email => "DANG");
$category->set_extra_metadata(group => 'Danger things');
$category->update;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bexley' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => { open311_email => { bexley => {
        p1 => 'p1@bexley',
        p1confirm => 'p1confirm@bexley',
        lighting => 'thirdparty@notbexley.example.com,another@notbexley.example.com',
        outofhours => 'outofhours@bexley,ooh2@bexley',
        flooding => 'flooding@bexley',
        eh => 'eh@bexley',
    } } },
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

    my $report;
    foreach my $test (
        { category => 'Abandoned and untaxed vehicles', email => ['p1confirm'], code => 'ConfirmABAN',
            extra => { 'name' => 'burnt', description => 'Was it burnt?', 'value' => 'Yes' } },
        { category => 'Abandoned and untaxed vehicles', code => 'ConfirmABAN',
            extra => { 'name' => 'burnt', description => 'Was it burnt?', 'value' => 'No' } },
        { category => 'Dead animal', email => ['p1', 'outofhours', 'ooh2'], code => 'ANIM' },
        { category => 'Something dangerous', email => ['p1', 'outofhours', 'ooh2'], code => 'DANG',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' } },
        { category => 'Something dangerous', code => 'DANG',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'No' } },
        { category => 'Street cleaning and litter', email => ['p1', 'outofhours', 'ooh2'], code => 'STREET',
            extra => { 'name' => 'reportType', description => 'Type of report', 'value' => 'Oil spillage' } },
        { category => 'Gulley covers', email => ['p1', 'outofhours', 'ooh2'], code => 'GULL',
            extra => { 'name' => 'reportType', description => 'Type of report', 'value' => 'Cover missing' } },
        { category => 'Gulley covers', code => 'GULL',
            extra => { 'name' => 'reportType', description => 'Type of report', 'value' => 'Cover damaged' } },
        { category => 'Gulley covers', email => ['p1', 'outofhours', 'ooh2'], code => 'GULL',
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' } },
        { category => 'Damaged road', code => 'ROAD', email => ['p1', 'outofhours', 'ooh2'],
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'No' } },
        { category => 'Damaged road', code => 'ROAD', email => ['p1', 'outofhours', 'ooh2'],
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' } },
        { category => 'Lamp post', code => 'StreetLightingLAMP', email => ['thirdparty', 'another'],
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'No' } },
        { category => 'Lamp post', code => 'StreetLightingLAMP', email => ['thirdparty', 'another'],
            extra => { 'name' => 'dangerous', description => 'Was it dangerous?', 'value' => 'Yes' } },
        { category => 'Flytipping', code => 'UniformFLY', email => ['eh'] },
        { category => 'Flooding in the road', code => 'ConfirmFLOD', email => ['flooding'] },
    ) {
        ($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
            category => $test->{category}, cobrand => 'bexley',
            latitude => 51.408484, longitude => 0.074653, areas => '2494',
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
            if ($test->{code} =~ /Confirm/) {
                is $c->param('attribute[site_code]'), 'Road ID';
            } elsif ($test->{code} =~ /Uniform/) {
                is $c->param('attribute[uprn]'), 'Road ID';
            } else {
                is $c->param('attribute[NSGRef]'), 'Road ID';
            }

            if (my $t = $test->{email}) {
                my $email = $mech->get_email;
                $t = join('@[^@]*', @$t);
                like $email->header('To'), qr/^[^@]*$t@[^@]*$/;
                if ($test->{code} =~ /Confirm/) {
                    like $mech->get_text_body_from_email($email), qr/Site code: Road ID/;
                } elsif ($test->{code} =~ /Uniform/) {
                    like $mech->get_text_body_from_email($email), qr/UPRN: Road ID/;
                    like $mech->get_text_body_from_email($email), qr/Uniform ID: 248/;
                } else {
                    like $mech->get_text_body_from_email($email), qr/NSG Ref: Road ID/;
                }
                $mech->clear_emails_ok;
            } else {
                $mech->email_count_is(0);
            }
        };
    }

    subtest 'resend is disabled in admin' => sub {
        my $user = $mech->log_in_ok('super@example.org');
        $user->update({ from_body => $body, is_superuser => 1 });
        $mech->get_ok('/admin/report_edit/' . $report->id);
        $mech->content_contains('View report on site');
        $mech->content_lacks('Resend report');
    };

    subtest "resending of reports by changing category" => sub {
        $mech->get_ok('/admin/report_edit/' . $report->id);
        $mech->submit_form_ok({ with_fields => { category => 'Damaged road' } });
        my $test_data = FixMyStreet::Script::Reports::send();
        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'ROAD', 'Report resent in new category';

        $mech->submit_form_ok({ with_fields => { category => 'Gulley covers' } });
        $test_data = FixMyStreet::Script::Reports::send();
        is_deeply $test_data, {}, 'Report not resent';

        $mech->submit_form_ok({ with_fields => { category => 'Lamp post' } });
        $test_data = FixMyStreet::Script::Reports::send();
        $req = $test_data->{test_req_used};
        $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'StreetLightingLAMP', 'Report resent';
    };

    subtest 'extra CSV column present' => sub {
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains(',Category,Subcategory,');
        $mech->content_contains('"Danger things","Something dangerous"');
    };


    subtest 'testing special Open311 behaviour', sub {
        my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
            category => 'Flooding in the road', cobrand => 'bexley',
            latitude => 51.408484, longitude => 0.074653, areas => '2494',
            photo => '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg,74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg',
        });
        my $report = $reports[0];

        my $test_data = FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        ok $report->whensent, 'Report marked as sent';
        is $report->send_method_used, 'Open311', 'Report sent via Open311';
        is $report->external_id, 248, 'Report has right external ID';

        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[title]'), 'Test Test 1 for ' . $body->id, 'Request had correct title';
        is_deeply [ $c->param('media_url') ], [
            'http://bexley.example.org/photo/' . $report->id . '.0.full.jpeg?74e33622',
            'http://bexley.example.org/photo/' . $report->id . '.1.full.jpeg?74e33622',
        ], 'Request had multiple photos';
    };

};

subtest 'nearest road returns correct road' => sub {
    my $cobrand = FixMyStreet::Cobrand::Bexley->new;
    my $cfg = {
        accept_feature => sub { 1 },
        property => 'fid',
    };
    my $features = [
        { geometry => { type => 'Polygon' } },
        { geometry => { type => 'MultiLineString',
            coordinates => [ [ [ 545499, 174361 ], [ 545420, 174359 ], [ 545321, 174352 ] ] ] },
          properties => { fid => '20101226' } },
        { geometry => { type => 'LineString',
            coordinates => [ [ 545420, 174359 ], [ 545419, 174375 ], [ 545418, 174380 ], [ 545415, 174391 ] ] },
          properties => { fid => '20100024' } },
    ];
    is $cobrand->_nearest_feature($cfg, 545451, 174380, $features), '20101226';
};

my $geo = Test::MockModule->new('FixMyStreet::Geocode');
$geo->mock('cache', sub {
    my $typ = shift;
    return [] if $typ eq 'osm';
    return {
        features => [
            {
                properties => { ADDRESS => 'BRAMPTON ROAD', TOWN => 'BEXLEY' },
                geometry => { type => 'LineString', coordinates => [ [ 1, 2 ], [ 3, 4] ] },
            },
            {
                properties => { ADDRESS => 'FOOTPATH TO BRAMPTON ROAD', TOWN => 'BEXLEY' },
                geometry => { type => 'MultiLineString', coordinates => [ [ [ 1, 2 ], [ 3, 4 ] ], [ [ 5, 6 ], [ 7, 8 ] ] ] },
            },
        ],
    } if $typ eq 'bexley';
});

subtest 'geocoder' => sub {
    my $c = ctx_request('/');
    my $results = FixMyStreet::Geocode::Bexley->string("Brampton Road", $c);
    is_deeply $results, { error => [
        {
            'latitude' => '49.766844',
            'longitude' => '-7.557122',
            'address' => 'Brampton Road, Bexley'
        }, {
            'address' => 'Footpath to Brampton Road, Bexley',
            'longitude' => '-7.557097',
            'latitude' => '49.766863'
        }
    ] };
};

my $bex = Test::MockModule->new('FixMyStreet::Cobrand::Bexley');
$bex->mock('get', sub {
    return <<EOF
{
    "england-and-wales": {
        "events": [
            { "date": "2019-12-25", "title": "Christmas Day", "notes": "", "bunting": true }
        ]
    }
}
EOF
});

subtest 'out of hours' => sub {
    my $cobrand = FixMyStreet::Cobrand::Bexley->new;
    set_fixed_time('2019-10-16T12:00:00Z');
    is $cobrand->_is_out_of_hours(), 0, 'not out of hours in the day';
    set_fixed_time('2019-10-16T04:00:00Z');
    is $cobrand->_is_out_of_hours(), 1, 'out of hours early in the morning';
    set_fixed_time('2019-10-13T12:00:00Z');
    is $cobrand->_is_out_of_hours(), 1, 'out of hours at weekends';
    set_fixed_time('2019-12-25T12:00:00Z');
    is $cobrand->_is_out_of_hours(), 1, 'out of hours on bank holiday';
};

done_testing();
