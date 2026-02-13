use FixMyStreet::TestMech;
use File::Temp 'tempdir';
use Path::Tiny;
use DateTime;
use FixMyStreet::Script::Reports;

my $sample_pdf = path(__FILE__)->parent->parent->child("sample.pdf");

# Calculate valid dates for the form (start date must be 4+ weeks from now)
my $start_date = DateTime->today->add(weeks => 5);

my $mech = FixMyStreet::TestMech->new;

# Create TfL body (using 2482 like other TfL tests)
my $body = $mech->create_body_ok(2482, 'TfL', { cobrand => 'tfl' });

# Create the category for scaffold licences
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Scaffold licence',
    email => 'licence@tfl.gov.uk.example.org'
);

subtest 'Scaffold form submission - smoke test' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        PHONE_COUNTRY => 'GB',
        COBRAND_FEATURES => {
            licencing_forms => { tfl => 1 },
            anonymous_account => { tfl => 'anon' },
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

        $mech->content_contains('2 weeks (mobile scaffold only)');

        # Dates page (using dynamic dates calculated at test start)
        $mech->submit_form_ok({ with_fields => {
            'proposed_start_date.day' => $start_date->day,
            'proposed_start_date.month' => $start_date->month,
            'proposed_start_date.year' => $start_date->year,
            proposed_duration => 4,
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
            contractor_authorised => 1,
        }});

        # Dimensions page
        $mech->submit_form_ok({ with_fields => {
            scaffold_height => '10',
            scaffold_length => '20',
            scaffold_width => '2',
        }});

        # Scaffold type page
        $mech->submit_form_ok({ with_fields => {
            scaffold_type => 'Scaffold',
            scaffold_configured => 'Independent',
        }});

        # Activity page
        $mech->submit_form_ok({ with_fields => {
            activity => 'Building repair',
        }});

        # Site specific pages (one question per page)
        $mech->submit_form_ok({ with_fields => {
            footway_incursion => 'No footway incursion',
            site_adequate_space => 'Yes'
        }});
        $mech->submit_form_ok({ with_fields => {
            carriageway_incursion => 'No carriageway incursion',
            site_within_450mm => 'No'
        }});
        $mech->submit_form_ok({ with_fields => {
            site_obstruct_infrastructure => 'No',
            site_trees_nearby => 'No',
        }});
        $mech->submit_form_ok({ with_fields => {
            site_protection_fan => 'No',
            site_foundations_surveyed => 'Yes',
        }});
        $mech->submit_form_ok({ with_fields => { site_hoarding_attached => 'No' }});

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
            upload_scaffold_drawing => [ $sample_pdf, undef, Content_Type => 'application/pdf' ],
        }});

        # Payment page
        $mech->content_contains('1S1H8a', 'Correct payment link');
        $mech->submit_form_ok({ with_fields => {
            payment_transaction_id => 'TEST-TRANSACTION-12345',
        }});

        # Summary page - check it rendered
        $mech->content_contains('Application Summary', 'Summary page rendered');

        # Contractor fields should be hidden since "same as applicant" was checked
        # "Contact name" is unique to contractor section (applicant uses "Full name")
        $mech->content_lacks('Contact name', 'Contractor fields hidden when same as applicant');

        # Summary page - submit
        $mech->submit_form_ok({ with_fields => { confirmation => 1 } });

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
        my $upload_dir = path($UPLOAD_DIR, "tfl-licence-scaffold")->absolute(FixMyStreet->path_to());

        ok -d $upload_dir, 'licence_files directory exists';

        # Check each upload field has a file reference and the file exists
        my $extra = $problem->get_extra_metadata;
        for my $field (qw(upload_insurance upload_rams upload_scaffold_drawing)) {
            ok $extra->{$field}, "Extra metadata contains $field";
            ok $extra->{$field}->{files}, "$field has files key";
            my $file_path = $upload_dir->child($extra->{$field}->{files});
            ok -f $file_path, "Uploaded file exists at $file_path";
        }

        subtest 'sent emails' => sub {
            FixMyStreet::Script::Reports::send();
            my $id = $problem->id;

            my @email = $mech->get_email;
            my @email_parts;
            $email[0]->walk_parts(sub {
                my ($part) = @_;
                push @email_parts, [ { $part->header_pairs }, $part->body ];
            });
            like $email_parts[0][0]{'Content-Type'}, qr{multipart/mixed};
            is $email_parts[0][0]{'Subject'}, 'Problem Report: Scaffold licence';
            is $email_parts[0][0]{'To'}, 'TfL <licence@tfl.gov.uk.example.org>';
            like $email_parts[1][0]{'Content-Type'}, qr{multipart/related};
            like $email_parts[2][0]{'Content-Type'}, qr{multipart/alternative};
            like $email_parts[3][0]{'Content-Type'}, qr{text/plain};
				# could check text here
            like $email_parts[4][0]{'Content-Type'}, qr{text/html};
				# could check html here
            like $email_parts[5][0]{'Content-Type'}, qr{image/gif};
            like $email_parts[5][0]{'Content-Disposition'}, qr{email-logo.gif};
            my $next = 6;
            if (@email_parts == 11) {
                # IM installed, so there is a map attachment
                like $email_parts[6][0]{'Content-Type'}, qr{image/jpeg};
                like $email_parts[6][0]{'Content-Disposition'}, qr{map.jpeg};
                $next++;
            }
            like $email_parts[$next][0]{'Content-Type'}, qr{application/pdf};
            like $email_parts[$next++][0]{'Content-Disposition'}, qr{scaffold-licence-application-$id.pdf};
            like $email_parts[$next][0]{'Content-Type'}, qr{application/pdf};
            like $email_parts[$next++][0]{'Content-Disposition'}, qr{sample.pdf};
            like $email_parts[$next][0]{'Content-Type'}, qr{application/pdf};
            like $email_parts[$next++][0]{'Content-Disposition'}, qr{sample.pdf};
            like $email_parts[$next][0]{'Content-Type'}, qr{application/pdf};
            like $email_parts[$next++][0]{'Content-Disposition'}, qr{sample.pdf};

            @email_parts = ();
            $email[1]->walk_parts(sub {
                my ($part) = @_;
                push @email_parts, [ { $part->header_pairs }, $part->body ];
            });
            like $email_parts[0][0]{'Content-Type'}, qr{multipart/related};
            is $email_parts[0][0]{'Subject'}, 'Your report has been logged: Scaffold licence';
            is $email_parts[0][0]{'To'}, 'test@example.com';
            like $email_parts[1][0]{'Content-Type'}, qr{multipart/alternative};
            like $email_parts[2][0]{'Content-Type'}, qr{text/plain};
				# could check text here
            like $email_parts[3][0]{'Content-Type'}, qr{text/html};
				# could check html here
            like $email_parts[4][0]{'Content-Type'}, qr{image/gif};
            like $email_parts[4][0]{'Content-Disposition'}, qr{email-logo.gif};
        };

        subtest 'PDF token access' => sub {
            my $id = $problem->id;

            my $pdf_link = "/licence/pdf/$id?token=" . $problem->confirmation_token;
            $mech->content_contains($pdf_link, 'Confirmation page has PDF download link');
            $mech->content_contains("download=\"scaffold-licence-application-FMS$id.pdf\"", 'PDF link has download attribute');

            $mech->get_ok($pdf_link);
            is $mech->res->header('Content-Type'), 'application/pdf', 'Valid token returns PDF';

            $mech->get("/licence/pdf/$id?token=wrong");
            is $mech->res->code, 404, 'Invalid token returns 404';

            $mech->log_out_ok;
            $mech->get("/licence/pdf/$id");
            is $mech->res->code, 404, 'No token and not logged in returns 404';

            my $user = $problem->user;
            $user->password('secret');
            $user->update;
            $mech->get_ok('/auth');
            $mech->submit_form_ok(
                { with_fields => { username => $user->email, password_sign_in => 'secret' } },
                "sign in as problem creator"
            );
            $mech->get_ok("/licence/pdf/$id");
            is $mech->res->header('Content-Type'), 'application/pdf', 'Logged-in creator gets PDF';
        };
    };
};

done_testing;
