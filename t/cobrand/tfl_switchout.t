use FixMyStreet::TestMech;
use File::Temp 'tempdir';
use Path::Tiny;
use DateTime;
use Encode;
use FixMyStreet::Script::Reports;

my $sample_pdf = path(__FILE__)->parent->parent->child("app/controller/sample.pdf");
my $mech = FixMyStreet::TestMech->new;
my $body = $mech->create_body_ok(2482, 'TfL', { cobrand => 'tfl' });
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Switch out application',
    email => 'switchout@tfl.gov.uk.example.org'
);

subtest 'Switch out application form submission' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl',
        PHONE_COUNTRY => 'GB',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            tfl_switch_out => { tfl => 1 },
            anonymous_account => { tfl => 'anon' },
        },
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/form/switchout');
        $mech->submit_form_ok({ button => 'start' });
        $mech->submit_form_ok({ with_fields => { location => 'BR1 3UH' }});

        $mech->submit_form_ok({ with_fields => {
            asset_location => 'Bromley High Street',
            asset_borough => 'Bromley',
            asset_site_id => '123/456',
            latitude => => 51.4021,
            longitude => 0.01578,
        }});

        $mech->submit_form_ok({ with_fields => { emergency => 'No' }});

        my $start_date = DateTime->today->add(weeks => 2);
        $mech->submit_form_ok({ with_fields => {
            'switch_out_date_1.day' => $start_date->day,
            'switch_out_date_1.month' => $start_date->month,
            'switch_out_date_1.year' => $start_date->year,
            'switch_out_time_1' => '00:30',
            'restore_date_1.day' => $start_date->day,
            'restore_date_1.month' => $start_date->month,
            'restore_date_1.year' => $start_date->year,
            'restore_time_1' => '01:30',
        }});

        $mech->submit_form_ok({ with_fields => {
            temporary_signal_company_name => 'Temporary Ltd',
            temporary_signal_phone => '01234 567890',
            site_contact_name => 'Site Contact',
            site_phone => '01234 567890',
        }});

        $mech->submit_form_ok({ with_fields => {
            organisation => 'Test Scaffolding Ltd',
            name => 'Test Person',
            email => 'test@example.com',
            phone => '01234 567890',
        }});

        $mech->submit_form_ok({ with_fields => {
            lead_same_as_applicant => 1,
        }});

        $mech->submit_form_ok({ with_fields => {
            permit_ha => 'TfL',
            permit_contact => 'London',
            permit_number => '2',
            permit_nature => 'Fixing green bulb',
        }});

        $mech->submit_form_ok({ with_fields => {
            upload_document_1 => [ $sample_pdf, encode_utf8('“insurance”.pdf'), Content_Type => 'application/pdf' ],
            additional_information => 'Additional',
        }});

        $mech->submit_form_ok({ with_fields => { payment => 'Invoice' }});

        $mech->submit_form_ok({ with_fields => {
            payment_company => 'Invoice',
            payment_name => 'Payment name',
            payment_email => 'payment@example.org',
            payment_phone => '01234 567890',
            payment_po => 'PO',
        }});

        $mech->form_with_fields('terms_accepted');
        $mech->current_form->find_input('terms_accepted', undef, 1)->value('TfL Traffic Signal Switch out terms & conditions');
        $mech->current_form->find_input('terms_accepted', undef, 2)->value('TfL Traffic Signal Switch out fee structure');
        $mech->submit_form_ok;

        $mech->content_contains('Application summary', 'Summary page rendered');
        $mech->content_lacks('Lead company name', 'Lead fields hidden when same as applicant');

        $mech->submit_form_ok({ with_fields => { confirmation => 1 } });

        $mech->content_contains('Application is pending', 'Shows confirmation page');

        my $problem = FixMyStreet::DB->resultset('Problem')
            ->search({ category => 'Switch out application' })
            ->order_by({ -desc => 'id' })->first;
        ok $problem, 'Problem record created';
        is $problem->cobrand_data, 'switchout';
        is $problem->non_public, 1, 'Problem is non-public';
        is $problem->areas, ',2482,';
        is $problem->user->email, 'test@example.com', 'User email set correctly';
        is $problem->user->name, 'Test Person', 'User name set correctly';

        # Detail string should group fields by section with headers and blank lines,
        # making it easier to distinguish e.g. applicant vs contractor answers
        my $detail = $problem->detail;
        like $detail, qr/\[Contacts for works on site\]/, 'Detail contains section header';
        like $detail, qr/\[Applicant details\]/, 'Detail contains Applicant section header';
        like $detail, qr/\n\n/, 'Detail has blank lines between sections';
        unlike $detail, qr/Lead company name/, 'Lead contact name hidden when same as applicant';

        # Verify uploads went to the right directory
        my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
        my $upload_dir = path($UPLOAD_DIR, "tfl-switchout")->absolute(FixMyStreet->path_to());

        ok -d $upload_dir, 'files directory exists';

        # Check each upload field has a file reference and the file exists
        my $extra = $problem->get_extra_metadata;
        for my $field (qw(upload_document_1)) {
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
            is $email_parts[0][0]{'Subject'}, 'Switch out application - 123/456';
            is $email_parts[0][0]{'To'}, 'TfL <switchout@tfl.gov.uk.example.org>';
            like $email_parts[1][0]{'Content-Type'}, qr{multipart/related};
            like $email_parts[2][0]{'Content-Type'}, qr{multipart/alternative};
            like $email_parts[3][0]{'Content-Type'}, qr{text/plain};
            like $email_parts[4][0]{'Content-Type'}, qr{text/html};
            like $email_parts[5][0]{'Content-Type'}, qr{image/gif};
            like $email_parts[5][0]{'Content-Disposition'}, qr{email-logo.gif};
            like $email_parts[6][0]{'Content-Type'}, qr{application/pdf};
            like $email_parts[6][0]{'Content-Disposition'}, qr{switchout-application-$id.pdf};
            like $email_parts[7][0]{'Content-Type'}, qr{application/pdf};
            like $email_parts[7][0]{'Content-Disposition'}, qr{inline; filename\*=UTF-8''%E2%80%9Cinsurance%E2%80%9D\.pdf; filename="\\\"insurance\\\"\.pdf"};

            @email_parts = ();
            $email[1]->walk_parts(sub {
                my ($part) = @_;
                push @email_parts, [ { $part->header_pairs }, $part->body ];
            });
            like $email_parts[0][0]{'Content-Type'}, qr{multipart/related};
            is $email_parts[0][0]{'Subject'}, 'Switch out application - FMS' . $id;
            is $email_parts[0][0]{'To'}, 'test@example.com';
            is $email_parts[0][0]{'Cc'}, 'switchout@tfl.gov.uk.example.org';
            like $email_parts[1][0]{'Content-Type'}, qr{multipart/alternative};
            like $email_parts[2][0]{'Content-Type'}, qr{text/plain};
				# could check text here
            like $email_parts[3][0]{'Content-Type'}, qr{text/html};
				# could check html here
            like $email_parts[4][0]{'Content-Type'}, qr{image/gif};
            like $email_parts[4][0]{'Content-Disposition'}, qr{email-logo.gif};
        };

        $problem->discard_changes;
        is $problem->state, 'internal referral';

        subtest 'PDF token access' => sub {
            my $id = $problem->id;

            my $pdf_link = "/form/switchout/pdf/$id?token=" . $problem->confirmation_token;
            $mech->content_contains($pdf_link, 'Confirmation page has PDF download link');
            $mech->content_contains("download=\"switchout-application-FMS$id.pdf\"", 'PDF link has download attribute');

            $mech->get_ok($pdf_link);
            is $mech->res->header('Content-Type'), 'application/pdf', 'Valid token returns PDF';

            $mech->get("/form/switchout/pdf/$id?token=wrong");
            is $mech->res->code, 404, 'Invalid token returns 404';

            $mech->log_out_ok;
            $mech->get("/form/switchout/pdf/$id");
            is $mech->res->code, 404, 'No token and not logged in returns 404';

            my $user = $problem->user;
            $user->password('secret');
            $user->update;
            $mech->get_ok('/auth');
            $mech->submit_form_ok(
                { with_fields => { username => $user->email, password_sign_in => 'secret' } },
                "sign in as problem creator"
            );
            $mech->get_ok("/form/switchout/pdf/$id");
            is $mech->res->header('Content-Type'), 'application/pdf', 'Logged-in creator gets PDF';
        };
    };
};

done_testing;
