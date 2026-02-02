use FixMyStreet::TestMech;
use File::Temp 'tempdir';
use Path::Tiny;
use DateTime;

my $sample_pdf = path(__FILE__)->parent->parent->child("sample.pdf");

# Calculate valid dates for the form (start date must be 4+ weeks from now)
my $start_date = DateTime->today->add(weeks => 5);

my $mech = FixMyStreet::TestMech->new;

# Create TfL body (using 2482 like other TfL tests)
my $body = $mech->create_body_ok(2482, 'TfL', { cobrand => 'tfl' });

# Create the category for excavation licences
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Excavation licence',
    email => 'licence@tfl.gov.uk'
);

subtest 'Excavation form submission - smoke test' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        PHONE_COUNTRY => 'GB',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
        },
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/licence/excavation');

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
            proposed_duration => 4,
        }});

        # Applicant page
        $mech->submit_form_ok({ with_fields => {
            organisation => 'Test Excavation Ltd',
            job_title => 'Excavator',
            name => 'Test Person',
            address => '123 Test Street, London, NW1 1AA',
            email => 'test@example.com',
            phone => '01234 567890',
            phone_24h => '07911 123456',
        }});

        # Contractor page - use "same as applicant"
        $mech->submit_form_ok({ with_fields => {
            contractor_same_as_applicant => 1,
            contractor_authorised => 1,
        }});

        # Activity page
        $mech->submit_form_ok({ with_fields => {
            licence_activity => 'Building repair',
            excavation_position => 'Corner, 1m square',
        }});

        # Site specific pages (one question per page)
        $mech->submit_form_ok({ with_fields => {
            footway_incursion => 'No footway incursion',
            site_adequate_space => 'Yes'
        }});
        $mech->submit_form_ok({ with_fields => {
            carriageway_incursion => 'No carriageway incursion',
            site_within_450mm => 'Yes',
        }});
        $mech->submit_form_ok({ with_fields => {
            site_obstruct_infrastructure => 'No',
        }});

        # Have you considered page
        $mech->submit_form_ok({ with_fields => {
            parking_dispensation => 'Yes',
            parking_bay_suspension => 'No',
            bus_stop_suspension => 'Yes',
            bus_lane_suspension => 'No',
            road_closure_required => 'No',
        }});

        $mech->form_with_fields('terms_accepted');
        $mech->current_form->find_input('terms_accepted', undef, 1)->value('Applicant');
        $mech->current_form->find_input('terms_accepted', undef, 2)->value('Highway licensing policy');
        $mech->current_form->find_input('terms_accepted', undef, 3)->value('Standard conditions');
        $mech->submit_form_ok;

        # Uploads page
        $mech->submit_form_ok({ with_fields => {
            upload_insurance => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
            upload_rams => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
            upload_site_drawing => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
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
            ->search({ category => 'Excavation licence' })
            ->order_by({ -desc => 'id' })->first;
        ok $problem, 'Problem record created';
        is $problem->cobrand_data, 'licence', 'cobrand_data is licence';
        is $problem->non_public, 1, 'Problem is non-public';
        is $problem->user->email, 'test@example.com', 'User email set correctly';
        is $problem->user->name, 'Test Person', 'User name set correctly';

        # Detail string should group fields by section with headers and blank lines,
        # making it easier to distinguish e.g. applicant vs contractor answers
        my $detail = $problem->detail;
        like $detail, qr/\[Location of the excavation\]/, 'Detail contains Location section header';
        like $detail, qr/\[Applicant details\]/, 'Detail contains Applicant section header';
        like $detail, qr/\n\n/, 'Detail has blank lines between sections';
        unlike $detail, qr/Contact name:/, 'Contractor contact name hidden when same as applicant';

        # Verify uploads went to the licence_files directory
        my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
        my $upload_dir = path($UPLOAD_DIR, "tfl_licence_excavation_files")->absolute(FixMyStreet->path_to());

        ok -d $upload_dir, 'licence_files directory exists';

        # Check each upload field has a file reference and the file exists
        my $extra = $problem->get_extra_metadata;
        for my $field (qw(upload_insurance upload_rams upload_site_drawing)) {
            ok $extra->{$field}, "Extra metadata contains $field";
            ok $extra->{$field}->{files}, "$field has files key";
            my $file_path = $upload_dir->child($extra->{$field}->{files});
            ok -f $file_path, "Uploaded file exists at $file_path";
        }
    };
};

done_testing;
