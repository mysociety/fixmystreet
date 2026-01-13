use FixMyStreet::TestMech;
use File::Temp 'tempdir';
use Path::Tiny;
use DateTime;

my $sample_pdf = path(__FILE__)->parent->child("sample.pdf");

# Calculate valid dates for the form (start date must be 4+ weeks from now,
# end date must be within 1 year)
my $today = DateTime->today;
my $start_date = $today->clone->add(weeks => 5);
my $end_date = $start_date->clone->add(weeks => 4);

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
        my $too_far = $valid_start->clone->add(years => 1, days => 10);  # More than 1 year
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
            'proposed_end_date.day' => $valid_end->day,
            'proposed_end_date.month' => $valid_end->month,
            'proposed_end_date.year' => $valid_end->year,
        }});
        $mech->content_contains('Start date must be at least 4 weeks from today',
            'Error shown when start date is less than 4 weeks away');

        # Test 2: End date too far (more than 1 year)
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $valid_start->day,
            'proposed_start_date.month' => $valid_start->month,
            'proposed_start_date.year' => $valid_start->year,
            'proposed_end_date.day' => $too_far->day,
            'proposed_end_date.month' => $too_far->month,
            'proposed_end_date.year' => $too_far->year,
        }});
        $mech->content_contains('End date must be within 1 year from the start date',
            'Error shown when end date is more than 1 year away');

        # Test 3: End date before start date
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $valid_end->day,
            'proposed_start_date.month' => $valid_end->month,
            'proposed_start_date.year' => $valid_end->year,
            'proposed_end_date.day' => $valid_start->day,
            'proposed_end_date.month' => $valid_start->month,
            'proposed_end_date.year' => $valid_start->year,
        }});
        $mech->content_contains('End date must be after start date',
            'Error shown when end date is before start date');

        # Test 4: Valid dates should proceed to next page
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $valid_start->day,
            'proposed_start_date.month' => $valid_start->month,
            'proposed_start_date.year' => $valid_start->year,
            'proposed_end_date.day' => $valid_end->day,
            'proposed_end_date.month' => $valid_end->month,
            'proposed_end_date.year' => $valid_end->year,
        }});
        $mech->content_contains('Applicant details',
            'Valid dates proceed to next page');
    };
};

subtest 'Scaffold form submission - smoke test' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        PHONE_COUNTRY => 'GB',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
        },
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/licence/scaffold');

        # Intro page
        $mech->submit_form_ok({ button => 'start' });

        # Location page
        $mech->submit_form_ok({ with_fields => {
            street_name => 'Test Street',
            building_name_number => '123',
            borough => 'camden',
            postcode => 'NW1 1AA',
        }});

        # Dates page (using dynamic dates calculated at test start)
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $start_date->day,
            'proposed_start_date.month' => $start_date->month,
            'proposed_start_date.year' => $start_date->year,
            'proposed_end_date.day' => $end_date->day,
            'proposed_end_date.month' => $end_date->month,
            'proposed_end_date.year' => $end_date->year,
        }});

        # Applicant page
        $mech->submit_form_ok({ with_fields => {
            organisation => 'Test Scaffolding Ltd',
            job_title => 'Scaffolder',
            name => 'Test Person',
            address => '123 Test Street, London, NW1 1AA',
            email => 'test@example.com',
            phone => '01234 567890',
            phone_24h => '07911 123456',
        }});

        # Contractor page - use "same as applicant"
        $mech->submit_form_ok({ with_fields => {
            contractor_same_as_applicant => 1,
            contractor_nasc_member => 'Yes',
            contractor_meeting => 1,
        }});

        # Dimensions page
        $mech->submit_form_ok({ with_fields => {
            scaffold_height => '10',
            scaffold_length => '20',
            scaffold_width => '2',
        }});

        # Activity page
        $mech->submit_form_ok({ with_fields => {
            scaffold_activity => 'Building repair',
        }});

        # Scaffold type page
        $mech->submit_form_ok({ with_fields => {
            scaffold_type => 'Independent',
        }});

        # Incursion page
        $mech->submit_form_ok({ with_fields => {
            footway_incursion => 'No footway incursion',
            carriageway_incursion => 'No carriageway incursion',
        }});

        # Site specific pages (one question per page)
        $mech->submit_form_ok({ with_fields => { site_adequate_space => 'Yes' }});
        $mech->submit_form_ok({ with_fields => { site_within_450mm => 'No' }});
        $mech->submit_form_ok({ with_fields => { site_obstruct_infrastructure => 'No' }});
        $mech->submit_form_ok({ with_fields => { site_protection_fan => 'No' }});
        $mech->submit_form_ok({ with_fields => { site_foundations_surveyed => 'Yes' }});
        $mech->submit_form_ok({ with_fields => { site_hoarding_attached => 'No' }});
        $mech->submit_form_ok({ with_fields => { site_trees_nearby => 'No' }});

        # Have you considered page
        $mech->submit_form_ok({ with_fields => {
            parking_bay_suspension => 'No',
            road_closure_required => 'No',
            terms_accepted => 1,
        }});

        # Uploads page
        $mech->submit_form_ok({ with_fields => {
            upload_insurance => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
            upload_rams => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
            upload_scaffold_drawing => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
        }});

        # Payment page
        $mech->submit_form_ok({ with_fields => {
            payment_transaction_id => 'TEST-TRANSACTION-12345',
        }});

        # Summary page - check it rendered
        $mech->content_contains('Application Summary', 'Summary page rendered');

        # Contractor fields should be hidden since "same as applicant" was checked
        # "Contact name" is unique to contractor section (applicant uses "Full name")
        $mech->content_lacks('Contact name', 'Contractor fields hidden when same as applicant');

        # Summary page - submit (need to specify process field for wizard forms)
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });

        # Check we're on confirmation page
        $mech->content_contains('This is not a licence', 'Shows confirmation page');

        # Verify Problem was created
        my $problem = FixMyStreet::DB->resultset('Problem')
            ->search({ category => 'Scaffold licence' })
            ->order_by({ -desc => 'id' })->first;
        ok $problem, 'Problem record created';
        is $problem->cobrand_data, 'licence', 'cobrand_data is licence';
        is $problem->non_public, 1, 'Problem is non-public';
        is $problem->user->email, 'test@example.com', 'User email set correctly';
        is $problem->user->name, 'Test Person', 'User name set correctly';

        # Detail string should group fields by section with headers and blank lines,
        # making it easier to distinguish e.g. applicant vs contractor answers
        my $detail = $problem->detail;
        like $detail, qr/\[Location of the scaffold\]/, 'Detail contains Location section header';
        like $detail, qr/\[Applicant details\]/, 'Detail contains Applicant section header';
        like $detail, qr/\n\n/, 'Detail has blank lines between sections';
        unlike $detail, qr/Contact name:/, 'Contractor contact name hidden when same as applicant';

        # Verify uploads went to the licence_files directory
        my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
        my $upload_dir = path($UPLOAD_DIR, "tfl_licence_scaffold_files")->absolute(FixMyStreet->path_to());

        ok -d $upload_dir, 'licence_files directory exists';

        # Check each upload field has a file reference and the file exists
        my $extra = $problem->get_extra_metadata;
        for my $field (qw(upload_insurance upload_rams upload_scaffold_drawing)) {
            ok $extra->{$field}, "Extra metadata contains $field";
            ok $extra->{$field}->{files}, "$field has files key";
            my $file_path = $upload_dir->child($extra->{$field}->{files});
            ok -f $file_path, "Uploaded file exists at $file_path";
        }
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
