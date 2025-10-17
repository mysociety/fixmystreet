use FixMyStreet::TestMech;
use t::Mock::Bexley;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(
    2494,
    'London Borough of Bexley',
    { cobrand => 'bexley' },
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

    subtest 'Request assisted collection staff field' => sub {
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
        unlike $report->detail, qr/Stairs down to pavement/, "Staff Notes data not added to report";
    };

    subtest 'Remove assisted collection flow, logged out' => sub {
        $mech->log_out_ok;
        $mech->get_ok('/waste/10001');
        $mech->content_lacks('Remove assisted collection');
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

done_testing;
