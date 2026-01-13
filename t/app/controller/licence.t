use FixMyStreet::TestMech;
use DateTime;

# Calculate valid dates for the form (start date must be 4+ weeks from now)
my $today = DateTime->today;

my $mech = FixMyStreet::TestMech->new;

# Create TfL body (using 2482 like other TfL tests)
my $body = $mech->create_body_ok(2482, 'TfL', { cobrand => 'tfl' });

# Create the category for scaffold licences
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Scaffold licence',
    email => 'licence@tfl.gov.uk'
);

subtest 'Feature flag disabled returns 404' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 0 },
        },
    }, sub {
        $mech->get('/licence/scaffold');
        is $mech->res->code, 404, 'Returns 404 when feature disabled';
    };
};

subtest 'Feature flag missing returns 404' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        COBRAND_FEATURES => {},
    }, sub {
        $mech->get('/licence/scaffold');
        is $mech->res->code, 404, 'Returns 404 when feature not configured';
    };
};

subtest 'Invalid licence type returns 404' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
        },
    }, sub {
        $mech->get('/licence/invalid-type');
        is $mech->res->code, 404, 'Returns 404 for invalid licence type';
    };
};

subtest 'Valid licence type loads form' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
        },
    }, sub {
        $mech->get_ok('/licence/scaffold');
        $mech->content_contains('Scaffold', 'Page contains licence type name');
    };
};

subtest 'Date validation' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
        },
    }, sub {
        # Calculate test dates
        my $too_soon = $today->clone->add(weeks => 2);  # Only 2 weeks away (need 4+)
        my $valid_start = $today->clone->add(weeks => 5);
        my $valid_end = $valid_start->clone->add(weeks => 4);

        $mech->get_ok('/licence/scaffold');
        $mech->submit_form_ok({ button => 'start' });

        # Location page
        $mech->submit_form_ok({ with_fields => {
            street_name => 'Test Street',
            building_name_number => '123',
            borough => 'Camden',
            postcode => 'NW1 1AA',
        }});

        # Test 1: Start date too soon (less than 4 weeks)
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $too_soon->day,
            'proposed_start_date.month' => $too_soon->month,
            'proposed_start_date.year' => $too_soon->year,
            proposed_duration => 4,
        }});
        $mech->content_contains('Start date must be at least 4 weeks from today',
            'Error shown when start date is less than 4 weeks away');

        # Test 2: End date too far (more than 1 year)
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $valid_start->day,
            'proposed_start_date.month' => $valid_start->month,
            'proposed_start_date.year' => $valid_start->year,
            proposed_duration => 54,
        }});
        $mech->content_contains('is not a valid value',
            'Error shown when end date is more than 1 year away');

        # Test 3: End date before start date
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $valid_end->day,
            'proposed_start_date.month' => $valid_end->month,
            'proposed_start_date.year' => $valid_end->year,
            'proposed_duration' => -4,
        }});
        $mech->content_contains('is not a valid value',
            'Error shown when end date is before start date');

        # Test 4: Valid dates should proceed to next page
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $valid_start->day,
            'proposed_start_date.month' => $valid_start->month,
            'proposed_start_date.year' => $valid_start->year,
            'proposed_duration' => 4,
        }});
        $mech->content_contains('Applicant details',
            'Valid dates proceed to next page');
    };
};

subtest 'Index page returns 404' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
        },
    }, sub {
        $mech->get('/licence');
        is $mech->res->code, 404, '/licence without type returns 404';
    };
};

done_testing;
