use utf8;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Path::Tiny;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");
ok $sample_file->exists, "sample file $sample_file exists";

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2217, 'Buckinghamshire Council');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'buckinghamshire',
    COBRAND_FEATURES => {
        claims => { buckinghamshire => 1 },
    },
    PHONE_COUNTRY => 'GB',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Report new vehicle claim, report id known' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 0, claimed_before => 'Yes' } }, "claim type screen");
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } }, "about you screen");
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'No' } }, "fault fixed");
        $mech->submit_form_ok({ with_fields => { fault_reported => 'Yes' } }, "fault reported");
        $mech->submit_form_ok({ with_fields => { report_id => 1 } }, "report id");
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } }, "incident time");
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', direction => 'east', details => 'some details', in_vehicle => 'Yes', speed => '20mph', actions => 'an action' } }, "incident details");
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } }, "witnesses etc");
        $mech->submit_form_ok({ with_fields => { what_cause => 'bollard', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause', photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } }, "cause screen");
        $mech->submit_form_ok({ with_fields => { make => 'a car', registration => 'rego!', mileage => '20', v5 => [ $sample_file, undef, Content_Type => 'application/octet-stream', filename => 'v5.jpg' ], v5_in_name => 'Yes', insurer_address => 'insurer address', damage_claim => 'No', vat_reg => 'No' } }, "car details");
        $mech->submit_form_ok({ with_fields => { vehicle_damage => 'the car was broken', vehicle_photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ], vehicle_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream', 'repairs.jpg' ], tyre_damage => 'Yes', tyre_mileage => 20, tyre_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } }, "damage details");
        $mech->content_contains('Review');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Claim submitted');

        #my $report = $user->problems->first;
        #is $report->title, "Noise report";
        #is $report->detail, "Kind of noise: music\nNoise details: Details\n\nWhere is the noise coming from? residence\nNoise source: 100000333\n\nIs the noise happening now? Yes\nDoes the time of the noise follow a pattern? Yes\nWhat days does the noise happen? monday, thursday\nWhat time does the noise happen? morning, evening\n";
        #is $report->latitude, 53;
    };

    subtest 'Report new vehicle claim, report fixed' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 0, claimed_before => 'No' } }, 'claim type');
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } }, 'about you details');
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'Yes' } }, 'fault fixed');
        $mech->submit_form_ok({ with_fields => { location => 'A location' } }, 'location details');
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } }, 'incident time');
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', direction => 'east', details => 'some details', in_vehicle => 'Yes', speed => '20mph', actions => 'an action' } }, 'incident details');
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } }, 'witnesses etc');
        $mech->submit_form_ok({ with_fields => { what_cause => 'bollard', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause', photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } }, 'cause details');
        $mech->submit_form_ok({ with_fields => { make => 'a car', registration => 'rego!', mileage => '20', v5 => [ $sample_file, undef, Content_Type => 'application/octet-stream' ], v5_in_name => 'Yes', insurer_address => 'insurer address', damage_claim => 'No', vat_reg => 'No' } }, 'vehicle details');
        $mech->submit_form_ok({ with_fields => { vehicle_damage => 'the car was broken', vehicle_photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ], vehicle_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream' ], tyre_damage => 'Yes', tyre_mileage => 20, tyre_receipts => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } }, 'damage details');
        $mech->content_contains('Review', "Review screen displayed");
        $mech->submit_form_ok({ with_fields => { process => 'summary' } }, "Claim submitted");
        $mech->content_contains('Claim submitted');
    };

    subtest 'Report new property claim, report id known' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 2, claimed_before => 'No' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } });
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'No' } });
        $mech->submit_form_ok({ with_fields => { fault_reported => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { report_id => 1 } });
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } });
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', direction => 'east', details => 'some details' } });
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } });
        $mech->submit_form_ok({ with_fields => { what_cause => 'bollard', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause', photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } });
        $mech->submit_form_ok({ with_fields => { property_insurance => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } });
        $mech->submit_form_ok({ with_fields => { property_damage_description => 'damage_description', property_photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ], property_invoices => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } });
        $mech->content_contains('Review');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Claim submitted');
    };

    subtest 'Report new injury claim, report id known' => sub {
        $mech->get_ok('/claims');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { what => 1, claimed_before => 'No' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => 'test@example.org', phone => '01234 567890', address => "12 A Street\nA Town" } });
        $mech->submit_form_ok({ with_fields => { fault_fixed => 'No' } });
        $mech->submit_form_ok({ with_fields => { fault_reported => 'Yes' } });
        $mech->submit_form_ok({ with_fields => { report_id => 1 } });
        $mech->submit_form_ok({ with_fields => { 'incident_date.year' => 2020, 'incident_date.month' => 10, 'incident_date.day' => 10, incident_time => 'morning' } });
        $mech->submit_form_ok({ with_fields => { weather => 'sunny', direction => 'east', details => 'some details' } });
        $mech->submit_form_ok({ with_fields => { witnesses => 'Yes', witness_details => 'some witnesses', report_police => 'Yes', incident_number => 23 } });
        $mech->submit_form_ok({ with_fields => { what_cause => 'bollard', aware => 'Yes', where_cause => 'bridge', describe_cause => 'a cause', photos => [ $sample_file, undef, Content_Type => 'application/octet-stream' ] } });
        $mech->submit_form_ok({ with_fields => { 'dob.year' => 1980, 'dob.month' => 5, 'dob.day' => 10, ni_number => 'ni number', occupation => 'occupation', 'employer_contact' => 'employer contact' } });
        $mech->submit_form_ok({ with_fields => { describe_injuries => 'describe injuries', medical_attention => 'Yes', 'attention_date.year' => 2020, 'attention_date.month' => 9, 'attention_date.day' => 23, gp_contact => 'GP contact', absent_work => 'Yes', absence_dates => 'absence dates', ongoing_treatment => 'Yes', treatment_details => 'treatment details' } });
        $mech->content_contains('Review');
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Claim submitted');
    };
};

done_testing;
