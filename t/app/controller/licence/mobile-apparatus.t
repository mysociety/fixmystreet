use FixMyStreet::TestMech;
use File::Temp 'tempdir';
use Path::Tiny;
use DateTime;

my $sample_pdf = path(__FILE__)->parent->parent->child("sample.pdf");

# Calculate valid dates for the form (start date must be 4+ weeks from now)
my $start_date = DateTime->today->add(weeks => 5);
my $end_week = $start_date->clone->add(days => 6);
$end_week = join('/', $end_week->day, $end_week->month, $end_week->year);
my $end_fortnight = $start_date->clone->add(days => 13);
$end_fortnight = join('/', $end_fortnight->day, $end_fortnight->month, $end_fortnight->year);

my $mech = FixMyStreet::TestMech->new;

# Create TfL body (using 2482 like other TfL tests)
my $body = $mech->create_body_ok(2482, 'TfL', { cobrand => 'tfl' });

# Create the category for mobile apparatus licences
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Mobile apparatus licence',
    email => 'licence@tfl.gov.uk.example.org'
);

subtest 'Mobile apparatus form submission - smoke test' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        PHONE_COUNTRY => 'GB',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
            licencing_payment_links => { tfl => { 'mobile-apparatus' => {
                'Mobile Apparatus (Carriageway)-dates_2' => 'dates_2-link',
                'Mobile Apparatus (Carriageway)-week' => 'week-link',
                'Mobile Apparatus (Carriageway)-fortnight' => 'fortnight-link',
            } } },
        },
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        foreach (qw(dates_1 dates_2 dates_3 week fortnight)) {
            subtest "Testing with date choice $_" => sub {
                $mech->get_ok('/licence/mobile-apparatus');

                # Intro page
                $mech->submit_form_ok({ button => 'start' });

                # Location page
                $mech->content_contains('Step 1 of 17');
                $mech->submit_form_ok({ with_fields => {
                    street_name => 'Test Street',
                    building_name_number => '123',
                    borough => 'camden',
                    postcode => 'NW1 1AA',
                }});

                # Dates pages
                $mech->content_contains('Step 2 of 17');
                $mech->submit_form_ok({ with_fields => {
                    date_choice => $_,
                }});

                $mech->content_contains('Step 3 of 17');
                if ($_ eq 'week' || $_ eq 'fortnight') {
                    $mech->submit_form_ok({ with_fields => {
                        'proposed_start_date.day' => $start_date->day,
                        'proposed_start_date.month' => $start_date->month,
                        'proposed_start_date.year' => $start_date->year,
                        proposed_start_time => '9am',
                        proposed_end_time => '5pm',
                    }});
                } else {
                    $mech->submit_form_ok({ with_fields => {
                        'start_date_1.day' => $start_date->day,
                        'start_date_1.month' => $start_date->month,
                        'start_date_1.year' => $start_date->year,
                        start_time_1 => '9am',
                        'end_date_1.day' => $start_date->day,
                        'end_date_1.month' => $start_date->month,
                        'end_date_1.year' => $start_date->year,
                        end_time_1 => '5pm',
                    }});
                    if ($_ eq 'dates_1') {
                        $mech->content_contains('Applicant details');
                        return;
                    }

                    $mech->content_contains('Step 3 of 17');
                    $mech->submit_form_ok({ with_fields => {
                        'start_date_2.day' => $start_date->day,
                        'start_date_2.month' => $start_date->month,
                        'start_date_2.year' => $start_date->year,
                        start_time_2 => '9am',
                        'end_date_2.day' => $start_date->day,
                        'end_date_2.month' => $start_date->month,
                        'end_date_2.year' => $start_date->year,
                        end_time_2 => '5pm',
                    }});

                    if ($_ eq 'dates_3') {
                        $mech->content_contains('Step 3 of 17');
                        $mech->submit_form_ok({ with_fields => {
                            'start_date_3.day' => $start_date->day,
                            'start_date_3.month' => $start_date->month,
                            'start_date_3.year' => $start_date->year,
                            start_time_3 => '9am',
                            'end_date_3.day' => $start_date->day,
                            'end_date_3.month' => $start_date->month,
                            'end_date_3.year' => $start_date->year,
                            end_time_3 => '5pm',
                        }});
                        $mech->content_contains('Applicant details');
                        return;
                    }
                }

                # Applicant page
                $mech->content_contains('Step 4 of 17');
                $mech->submit_form_ok({ with_fields => {
                    organisation => 'Test Builder Ltd',
                    job_title => 'Builder',
                    name => 'Test Person',
                    address => '123 Test Street, London, NW1 1AA',
                    email => 'test@example.com',
                    phone => '01234 567890',
                    phone_24h => '07911 123456',
                }});

                # Contractor page - use "same as applicant"
                $mech->content_contains('Step 5 of 17');
                $mech->submit_form_ok({ with_fields => {
                    contractor_same_as_applicant => 1,
                }});

                # Details page
                $mech->content_contains('Step 6 of 17');
                $mech->submit_form_ok({ with_fields => {
                    model => 'Nokia',
                    weight => 24,
                    footprint => 'Small',
                    capacity => 15,
                }});

                # Activity page
                $mech->submit_form_ok({ with_fields => {
                    activity => 'Building repair',
                }});

                # Site specific pages (one question per page)
                $mech->submit_form_ok({ with_fields => {
                    footway_incursion => 'No footway incursion',
                    situated_on_footway => 'No',
                    site_adequate_space => 'Yes'
                }});
                $mech->submit_form_ok({ with_fields => {
                    carriageway_incursion => 'No carriageway incursion',
                    situated_on_carriageway => 'Yes',
                }});
                $mech->submit_form_ok({ with_fields => {
                    site_obstruct_infrastructure => 'No',
                    load_bearing_assessment => 'Yes',
                }});

                $mech->content_contains('tfl.gov.uk/modes/buses');
                $mech->content_contains('tfl.gov.uk/info-for');
                $mech->content_contains('www.met.police.uk/contact');
                $mech->submit_form_ok({ with_fields => {
                    buses_consulted => 'No',
                    underground_consulted => 'No',
                    police_consulted => 'No',
                    preapp_comments => 'No',
                }});

                $mech->content_contains('Mobile apparatus type');
                $mech->content_like(qr/value="Mobile Apparatus \(Footway\)".*disabled/s);
                $mech->content_like(qr/value="Mobile Apparatus \(Carriageway\)".*checked/s);
                $mech->submit_form_ok({ with_fields => {
                    apparatus_type => 'Mobile Apparatus (Carriageway)',
                }});

                # Have you considered page
                $mech->content_contains('Step 13 of 17');
                $mech->submit_form_ok({ with_fields => {
                    parking_dispensation => 'Yes',
                    parking_bay_suspension => 'No',
                    bus_stop_suspension => 'Yes',
                    bus_lane_suspension => 'No',
                    road_closure_required => 'No',
                }});

                $mech->form_with_fields('terms_accepted');
                $mech->current_form->find_input('terms_accepted', undef, 1)->value('Mobile apparatus guidance notes and terms & conditions - March 2026');
                $mech->current_form->find_input('terms_accepted', undef, 2)->value('Highway licensing and other consents policy - March 2026');
                $mech->current_form->find_input('terms_accepted', undef, 3)->value('Standard conditions for highway consents - March 2026');
                $mech->submit_form_ok;

                # Uploads page
                $mech->submit_form_ok({ with_fields => {
                    upload_insurance => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
                    insurance_validity => 'all year',
                    upload_rams => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
                    upload_site_drawing => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
                    upload_traffic_management => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
                }});

                # Payment page
                $mech->content_contains('Step 16 of 17');
                $mech->content_contains("$_-link");
                $mech->submit_form_ok({ with_fields => {
                    payment_transaction_id => 'TEST-TRANSACTION-12345',
                }});

                # Summary page - check it rendered
                $mech->content_contains('Application Summary', 'Summary page rendered');

                # Contractor fields should be hidden since "same as applicant" was checked
                # "Contact name" is unique to contractor section (applicant uses "Full name")
                $mech->content_lacks('Contact name', 'Contractor fields hidden when same as applicant');

                # Check date inputs
                if ($_ eq 'dates_2') {
                    $mech->content_contains('Proposed working dates (Operation 1)');
                    $mech->content_contains('Proposed working dates (Operation 2)');
                } elsif ($_ eq 'week') {
                    $mech->content_lacks('Proposed working dates (Operation 1)');
                    $mech->content_lacks('Proposed working dates (Operation 2)');
                    $mech->content_contains('Proposed working dates');
                    $mech->content_contains($end_week);
                } elsif ($_ eq 'fortnight') {
                    $mech->content_lacks('Proposed working dates (Operation 1)');
                    $mech->content_lacks('Proposed working dates (Operation 2)');
                    $mech->content_contains('Proposed working dates');
                    $mech->content_contains($end_fortnight);
                }
                $mech->content_lacks('Proposed working dates (Operation 3)');

                # Summary page - submit
                $mech->submit_form_ok({ with_fields => { confirmation => 1 } });

                # Check we're on confirmation page
                $mech->content_contains('This is not a licence', 'Shows confirmation page');

                # Verify Problem was created
                my $problem = FixMyStreet::DB->resultset('Problem')
                    ->search({ category => 'Mobile apparatus licence' })
                    ->order_by({ -desc => 'id' })->first;
                ok $problem, 'Problem record created';
                is $problem->cobrand_data, 'licence', 'cobrand_data is licence';
                is $problem->non_public, 1, 'Problem is non-public';
                is $problem->user->email, 'test@example.com', 'User email set correctly';
                is $problem->user->name, 'Test Person', 'User name set correctly';

                # Detail string should group fields by section with headers and blank lines,
                # making it easier to distinguish e.g. applicant vs contractor answers
                my $detail = $problem->detail;
                like $detail, qr/\[Location of mobile apparatus\]/, 'Detail contains Location section header';
                like $detail, qr/\[Applicant details\]/, 'Detail contains Applicant section header';
                like $detail, qr/\n\n/, 'Detail has blank lines between sections';
                unlike $detail, qr/Contact name:/, 'Contractor contact name hidden when same as applicant';

                if ($_ eq 'dates_2') {
                    like $detail, qr/Proposed working dates \(Operation 1\)/;
                    like $detail, qr/Proposed working dates \(Operation 2\)/;
                } elsif ($_ eq 'week') {
                    like $detail, qr{$end_week};
                } elsif ($_ eq 'fortnight') {
                    like $detail, qr{$end_fortnight};
                }
                unlike $detail, qr/Proposed working dates \(Operation 3\)/;

                # Verify uploads went to the licence_files directory
                my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
                my $upload_dir = path($UPLOAD_DIR, "tfl-licence-mobile-apparatus")->absolute(FixMyStreet->path_to());

                ok -d $upload_dir, 'licence_files directory exists';

                # Check each upload field has a file reference and the file exists
                my $extra = $problem->get_extra_metadata;
                for my $field (qw(upload_insurance upload_rams upload_traffic_management upload_site_drawing)) {
                    ok $extra->{$field}, "Extra metadata contains $field";
                    ok $extra->{$field}->{files}, "$field has files key";
                    my $file_path = $upload_dir->child($extra->{$field}->{files});
                    ok -f $file_path, "Uploaded file exists at $file_path";
                }
            };
        }
    };
};

done_testing;
