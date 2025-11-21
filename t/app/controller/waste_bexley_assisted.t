use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::Alerts;
use t::Mock::Bexley;

my $mech = FixMyStreet::TestMech->new;

my $comment_user = $mech->create_user_ok('bexley@example.org', name => 'London Borough of Bexley');

my $body = $mech->create_body_ok(
    2494,
    'London Borough of Bexley',
    { cobrand => 'bexley', comment_user => $comment_user, },
);
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $body, name => 'Staff User');

my $assisted_collection = $mech->create_contact_ok(
    body => $body,
    category => 'Request assisted collection',
    email => 'assisted@example.org',
    extra => { type => 'waste' },
    group => ['Waste'],
);

$assisted_collection->set_extra_fields(
    {
        code => "uprn",
        required => "false",
        automated => "hidden_field",
        description => "UPRN reference",
    },
    {
        code => "fixmystreet_id",
        required => "true",
        automated => "server_set",
        description => "external system ID",
    },
    {
        code => "reason_for_collection",
        required => "true",
        datatype => "singlevaluelist",
        description => "Why do you need an extra collection?",
        values => [
            map { { key => $_, name => $_ } } (
                "Property is unsuitable for collections from the front boundary",
                "Physical impairment/Elderly resident"
            )
        ],
    },
    {
        code => "bin_location",
        required => "true",
        datatype => "text",
        description => "Where are the bins located?",
    },
    {
        code => "permanent_or_temporary_help",
        required => "true",
        datatype => "singlevaluelist",
        description => "Is this request for permanent or temporary help?",
        values => [
            map { { key => $_, name => $_ } } (
                'Permanent',
                'Temporary'
            )
        ],
    },
    {
        code => "assisted_staff_notes",
        required => "false",
        datatype => "textarea",
        description => "Staff notes",
    },
);
$assisted_collection->update;

my $assisted_collection_approval = $mech->create_contact_ok(
    body => $body,
    category => 'Assisted collection add',
    email => 'assisted_collection',
    send_method => 'Open311',
    extra => { type => 'waste' },
    group => ['Waste'],
);

$assisted_collection_approval->set_extra_fields(
    {
        code => "uprn",
        required => "false",
        automated => "hidden_field",
        description => "UPRN reference",
    },
    {
        code => "fixmystreet_id",
        required => "true",
        automated => "server_set",
        description => "external system ID",
    },
    {
        code => "assisted_reason",
        required => "true",
        datatype => "singlevaluelist",
        description => "Why do you need an extra collection?",
        values => [
            map { { key => $_, name => $_ } } (
                "physical",
                "property"
            )
        ],
    },
    {
        code => "assisted_location",
        required => "true",
        datatype => "text",
        description => "Where are the bins located?",
    },
    {
        code => "assisted_duration",
        required => "true",
        datatype => "singlevaluelist",
        description => "Is this request for permanent or temporary help?",
        values => [
            map { { key => $_, name => $_ } } (
                '3 Months',
                '6 Months',
                '12 Months',
                'No End Date',
            )
        ],
    }
);
$assisted_collection_approval->update;

$mech->create_contact_ok(
    body => $body,
    category => 'Assisted collection remove',
    email => 'assistedremove@example.org',
    extra => {
        type => 'waste',
        _fields => [ {
            code => "uprn",
            required => "false",
            automated => "hidden_field",
            description => "UPRN reference",
        } ],
    },
    group => ['Waste'],
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        whitespace => { bexley => { url => 'http://example.org/' } },
        waste => { bexley => 1 },
    },
}, sub {
    subtest 'Request assisted collection form' => sub {
        my @fields = ('reason_for_collection', 'bin_location', 'permanent_or_temporary_help', 'assisted_staff_notes');
        $mech->get_ok('/waste/10006');
        $mech->content_contains('enquiry?category=Request+assisted+collection', "Page contains link to assisted collection form");
        $mech->content_contains('Get help with putting your bins out', "Page contains label for link to assisted collection form");
        $mech->get_ok('/waste/10006/enquiry?category=Request+assisted+collection');
        my $staff_field = pop(@fields);
        for my $field (@fields) {
            $mech->content_contains($field, "$field is present");
        }
        $mech->content_lacks($staff_field, "$staff_field is not present");
        $mech->submit_form_ok( {
            with_fields => {
                extra_reason_for_collection => 'Physical impairment/Elderly resident',
                extra_bin_location => "Behind the blue gate",
                extra_permanent_or_temporary_help => "Permanent",
            }
        }, 'Submit request details page');
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Gary Green',
                email => 'gg@example.com',
            }
        }, 'Submit about you page');
        subtest 'Summary page contains questions but not Staff Notes field' => sub {
            $mech->content_contains('Permanent Or Temporary Help');
            $mech->content_contains('Reason For Collection');
            $mech->content_contains('Bin Location');
            $mech->content_lacks('Assisted Staff Notes');
        };

        $mech->submit_form_ok({form_number => 3});
        $mech->content_lacks('Respond to this request', "Link to approve not present for public");
    };

    subtest 'Request assisted collection report' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        my $id = $report->id;
        $mech->content_contains('Your enquiry has been submitted');
        $mech->content_contains('A copy has been sent to your email address, gg@example.com.');
        $mech->content_contains("Your reference number is <strong>$id</strong>.");
        is $report->title, 'Request assisted collection';
        is $report->detail, "Behind the blue gate\n\nPermanent\n\nPhysical impairment/Elderly resident\n\nFlat, 98a-99b The Court, 1a-2b The Avenue, Little Bexlington, Bexley, DA1 3NP";
    };

    subtest 'Request assisted collection emails' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();

        my @emails = $mech->get_email;
        my ($customer_email) = grep { $_->header('to') eq 'gg@example.com' } @emails;
        is $customer_email->header('subject'), 'Thank you for your request for an assisted collection', "Correct customer email subject";
        my ($bexley_email) = grep { $_->header('to') eq '"London Borough of Bexley" <assisted@example.org>' } @emails;
        is $bexley_email->header('subject'), 'New Request assisted collection - Reference number: ' . $report->id, , "Correct council email subject";
        my $customer_text = $mech->get_text_body_from_email($customer_email);
        my $customer_html = $mech->get_html_body_from_email($customer_email);
        my $council_text  = $mech->get_text_body_from_email($bexley_email);
        my $council_html  = $mech->get_html_body_from_email($bexley_email);

        subtest 'Both council and public emails contain request data' => sub {
            for my $email ($customer_text, $customer_html, $council_text, $council_html) {
                like $email, qr#Why do you need an extra collection\?: Physical impairment/Elderly resident#, "Question and answer present";
                like $email, qr/Where are the bins located\?: Behind the blue gate/, "Question and answer present";
                like $email, qr/Is this request for permanent or temporary help\?: Permanent/, "Question and answer present";
                like $email, qr/Flat, 98a-99b The Court, 1a-2b The Avenue, Little Bexlington, Bexley, DA1 3NP/, "Address present";
            };
        };
        subtest 'Customer emails have correct data' => sub {
            for my $email ($customer_text, $customer_html) {
                like $email, qr/Thank you for your request for an assisted collection/;
                like $email, qr/We will look into your request and get back to you as soon as possible/;
                like $email, qr/If you need to contact us about this enquiry, please quote your reference number/;
                unlike $email, qr/Staff notes/, "Staff notes field not included";
            }
        };
        subtest 'Council emails contain reporters information and approval form link' => sub {
            my $report_id = $report->id;
            for my $email ($council_text, $council_html) {
                    like $email, qr/Gary Green/, 'Name included';
                    like $email, qr/gg\@example.com/, 'Email address included';
                    like $email, qr#Staff notes: N/A - public request#, 'Staff notes populated for a public made request';
                    like $email, qr/assisted\/$report_id/, 'Staff emails include link to approval form';
                }
        };
        like $council_html, qr/for back office only/, "Back office notice included in council email";
    };

    subtest 'Request assisted collection staff field' => sub {
        &_delete_all_assisted_collection_reports;
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/10006/enquiry?category=Request+assisted+collection');
        $mech->submit_form_ok( {
            with_fields => {
                extra_reason_for_collection => 'Physical impairment/Elderly resident',
                extra_bin_location => "Behind the blue gate",
                extra_permanent_or_temporary_help => "Permanent",
                extra_assisted_staff_notes => "Stairs down to pavement"
            }
        });
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Glenda Green',
                email => 'gg@example.com',
            }
        });
        $mech->content_contains('Assisted Staff Notes', "Summary data has Staff Notes key");
        $mech->content_contains('Stairs down to pavement', "Summary data has Staff Notes contents");

        $mech->submit_form_ok({ form_number => 3 });

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        my $report_id = $report->id;
        $mech->content_contains("<a href=\"http://bexley.example.org/waste/10006/assisted/$report_id\">Respond to this request</a>", "Link for staff to approve/deny request present");
        unlike $report->detail, qr/Stairs down to pavement/, "Staff Notes data not added to report";

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my ($customer_email) = grep { $_->header('to') eq 'gg@example.com' } @emails;
        my ($bexley_email) = grep { $_->header('to') eq '"London Borough of Bexley" <assisted@example.org>' } @emails;
        for my $email ($mech->get_html_body_from_email($customer_email), $mech->get_text_body_from_email($customer_email)) {
            unlike $email, qr/Staff Notes/, "Customer email has no Staff Notes field";
            unlike $email, qr/Stairs down to pavement/, "Customer email has no Staff Notes data";
        };
        for my $email ($mech->get_html_body_from_email($bexley_email), $mech->get_text_body_from_email($bexley_email)) {
            like $email, qr/Staff notes/, "Council email has Staff Notes field";
            like $email, qr/Stairs down to pavement/, "Council email has Staff Notes data";;
        };
    };

    subtest 'Request assisted collection approval' => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        $mech->get_ok('/waste/10006/assisted/' . $report->id);
        $mech->submit_form_ok( { with_fields => {outcome_choice => 'Approve'} } );
        $mech->submit_form_ok( {
            with_fields => {
                assisted_duration => '3 Months',
                assisted_reason => 'property',
                assisted_location => 'Behind the back gate',
            }
        });

        like $mech->content, qr/Assisted collection summary/, "On summary page";
        like $mech->content, qr#Assisted collection approve/deny#, "Approve/deny section shown";
        like $mech->content, qr#Approve/deny</dt>#, "Approve/deny choice shown";
        like $mech->content, qr#Approve</dd>#, "Option shown: approve";
        like $mech->content, qr/Approval submission/, 'Approval submission section shown';
        like $mech->content, qr#Reason for assistance</dt>#, "Reason choice shown";
        like $mech->content, qr#property</dd>#, "Option shown: property";
        like $mech->content, qr#Duration of assistance</dt>#, "Duration choice shown";
        like $mech->content, qr#3 Months</dd>#, "Option shown: 3 Months";
        like $mech->content, qr#Location of bins</dt>#, "Location shown";
        like $mech->content, qr#Behind the back gate</dd>#, "Location notes shown";

        $mech->submit_form_ok( { form_number => 1 } );
        $mech->content_contains('Assisted collection outcome', "Returned to outcome choice page");
        $mech->submit_form_ok();
        $mech->submit_form_ok();

        $mech->submit_form_ok( { form_number => 2 } );
        $mech->content_contains('Assisted collection details', "Returned to details page");
        $mech->submit_form_ok();

        is $mech->submit_form_ok( { form_number => 3 } ), 1, "Submission form is third form as two change options";

        $mech->clear_emails_ok;
        FixMyStreet::Script::Alerts::send_updates();
        my $email = $mech->get_email;
        is $email->header('to'), 'gg@example.com', "Update sent to customer";
        my $email_html = $mech->get_html_body_from_email($email);
        like $email_html, qr/Your request for an assisted collection has been approved/, 'Approval update text sent to customer';

        $report->discard_changes;
        is $report->state, 'fixed - council', "Request report marked fixed";

        my $open311_report = FixMyStreet::DB->resultset('Problem')->search( { category => 'Assisted collection add' } )->first;
        is $open311_report->get_extra_field_value('assisted_reason'), 'property';
        is $open311_report->get_extra_field_value('assisted_duration'), '3 Months';
        is $open311_report->get_extra_field_value('assisted_location'), 'Behind the back gate';
    };

    subtest 'Remove assisted collection flow, requester' => sub {
        my $report = FixMyStreet::DB->resultset('Problem')->search( { category => 'Request assisted collection' } )->order_by('-id')->first;
        my $user = $mech->log_in_ok($report->user->email);
        $report->update_extra_field({ name => 'uprn', value => '10001' });
        $report->update({ user => $user }); # Because of uniqueify
        $mech->get_ok('/waste/10001');
        $mech->follow_link_ok({ text => 'Remove assisted collection' });
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org' } });
        $mech->submit_form_ok({ with_fields => { submit => "Submit" } });;
        $mech->content_contains('Your enquiry has been submitted');
    };

    subtest 'Request assisted collection denial' => sub {
        &_delete_all_assisted_collection_reports;
        $mech->log_out_ok;
        $mech->get_ok('/waste/10006/enquiry?category=Request+assisted+collection');
        $mech->submit_form_ok( {
            with_fields => {
                extra_reason_for_collection => 'Physical impairment/Elderly resident',
                extra_bin_location => "Behind the blue gate",
                extra_permanent_or_temporary_help => "Permanent",
            }
        });
        $mech->submit_form_ok( {
            with_fields => {
                name => 'Glenda Green',
                email => 'gg@example.com',
            }
        });
        $mech->submit_form_ok({ form_number => 3 });
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;

        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/10006/assisted/' . $report->id);
        $mech->submit_form_ok( { with_fields => { outcome_choice => 'Deny' }} );
        like $mech->content, qr#Assisted collection approve/deny#, "On summary page";
        like $mech->content, qr#Approve/deny</dt>#, "Can change approve/deny choice";
        is $mech->submit_form_ok( { form_number => 2 } ), 1, "Submission form is second form as only one change option";

        $mech->clear_emails_ok;
        FixMyStreet::Script::Alerts::send_updates();
        my $email = $mech->get_email;
        is $email->header('to'), 'gg@example.com', "Update sent to customer";
        my $email_html = $mech->get_html_body_from_email($email);
        like $email_html, qr/Your request for an assisted collection has been denied/, 'Denial update text sent to customer';

        $report->discard_changes;
        is $report->state, 'closed', 'Request report has been closed';

        my $open311_report = FixMyStreet::DB->resultset('Problem')->search( { category => 'Assisted collection add' } )->first;
        is $open311_report, undef, "No approval report created";
    };

    subtest 'Remove assisted collection flow, logged out' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Remove assisted collection');
        $mech->get_ok('/waste/10001/enquiry?category=Assisted+collection+remove');
        is $mech->uri->path, '/auth';
    };

    subtest 'Remove assisted collection flow, staff' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/10001');
        $mech->follow_link_ok({ text => 'Remove assisted collection' });
        $mech->submit_form_ok({ with_fields => { name => 'Test McTest', email => 'test@example.org' } });
        $mech->submit_form_ok({ with_fields => { submit => "Submit" } });;
        $mech->content_contains('Your enquiry has been submitted');
    };
};

sub _delete_all_assisted_collection_reports {
    my @reports = FixMyStreet::DB->resultset('Problem')->search({ -or => [
        category => 'Assisted collection add',
        category => 'Request assisted collection'
    ]})->all;
    for my $report (@reports) {
        my @comments = $report->comments->search()->all;
        for my $comment (@comments) {
            $comment->delete;
            $comment->update;
        }
        $report->delete;
        $report->update;
    };
}

done_testing;
