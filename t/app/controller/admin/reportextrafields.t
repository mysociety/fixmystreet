use strict;
use warnings;

package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub allow_report_extra_fields { 1 }

sub area_types { [ 'UTA' ] }


package FixMyStreet::Cobrand::SecondTester;

use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub allow_report_extra_fields { 1 }

sub area_types { [ 'UTA' ] }


package FixMyStreet::Cobrand::NoExtras;

use parent 'FixMyStreet::Cobrand::FixMyStreet';

sub allow_report_extra_fields { 0 }

sub area_types { [ 'UTA' ] }

package main;

use FixMyStreet::TestMech;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $contact = $mech->create_contact_ok( body_id => $body->id, category => 'Potholes', email => 'potholes@example.com' );

my $body2 = $mech->create_body_ok(2651, 'Edinburgh City Council');
my $contact2 = $mech->create_contact_ok( body_id => $body2->id, category => 'Potholes', email => 'potholes@example.com' );


FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'tester' => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
    LANGUAGES => [
        'en-gb,English,en_GB',
        'de,German,de_DE'
    ]
}, sub {
    $mech->log_in_ok( $user->email );

    subtest 'add extra fields to Contacts' => sub {
        my $contact_extra_fields = [];

        is_deeply $contact->get_extra_fields, $contact_extra_fields, 'contact has empty extra fields';
        $mech->get_ok("/admin/body/" . $body->id . "/" . $contact->category);

        $mech->submit_form_ok( { with_fields => {
            "metadata[0].order" => "1",
            "metadata[0].code" => "string_test",
            "metadata[0].required" => "on",
            "metadata[0].notice" => "",
            "metadata[0].description" => "this is a test description",
            "metadata[0].datatype_description" => "hint here",
            "metadata[0].datatype" => "string",
            "note" => "Added extra field",
        }});
        $mech->content_contains('Values updated');

        push @$contact_extra_fields, {
            order => "1",
            code => "string_test",
            required => "true",
            variable => "true",
            description => "this is a test description",
            datatype_description => "hint here",
            datatype => "string",
        };
        $contact->discard_changes;
        is_deeply $contact->get_extra_fields, $contact_extra_fields, 'new string field was added';


        $mech->get_ok("/admin/body/" . $body->id . "/" . $contact->category);
        $mech->submit_form_ok( { with_fields => {
            "metadata[1].order" => "2",
            "metadata[1].code" => "list_test",
            "metadata[1].required" => undef,
            "metadata[1].notice" => "",
            "metadata[1].description" => "this field is a list",
            "metadata[1].datatype_description" => "",
            "metadata[1].datatype" => "list",
            "metadata[1].values[0].key" => "key1",
            "metadata[1].values[0].name" => "name1",
            "note" => "Added extra list field",
        }});
        $mech->content_contains('Values updated');

        push @$contact_extra_fields, {
            order => "2",
            code => "list_test",
            required => "false",
            variable => "true",
            description => "this field is a list",
            datatype_description => "",
            datatype => "singlevaluelist",
            values => [
                { name => "name1", key => "key1" },
            ]
        };
        $contact->discard_changes;
        is_deeply $contact->get_extra_fields, $contact_extra_fields, 'new list field was added';

        $contact->set_extra_fields();
        $contact->update;
    };

    subtest 'check contact updating does not remove server_set' => sub {
        $contact->set_extra_fields(({ code => 'POT', automated => 'server_set' }));
        $contact->update;

        $mech->get_ok("/admin/body/" . $body->id . "/" . $contact->category);
        $mech->submit_form_ok( { with_fields => {
            email    => 'test4@example.com',
            note     => 'test4 note',
        } } );

        $mech->content_like(qr'test4@example.com's);

        $contact->discard_changes;
        my $meta_data = $contact->get_extra_fields;
        is $contact->email, 'test4@example.com', 'contact updated';
        is_deeply $meta_data, [ {
            order => 0,
            datatype => 'string',
            datatype_description => '',
            description => '',
            required => 'false',
            variable => 'true',
            code => 'POT',
            automated => 'server_set'
        } ], "automated fields not unset";
    };


    subtest 'Create and update new ReportExtraFields' => sub {
        my $extra_fields = [];

        my $model = FixMyStreet::App->model('DB::ReportExtraField');
        is $model->count, 0, 'no ReportExtraFields yet';

        $mech->get_ok("/admin/reportextrafields");

        $mech->get_ok("/admin/reportextrafields/new");
        $mech->submit_form_ok({ with_fields => {
            name => "Test extra fields",
            cobrand => "tester",
            language => undef,
            "metadata[0].order" => "1",
            "metadata[0].code" => "string_test",
            "metadata[0].required" => "on",
            "metadata[0].notice" => "",
            "metadata[0].description" => "this is a test description",
            "metadata[0].datatype_description" => "hint here",
            "metadata[0].datatype" => "string",
        }});
        is $model->count, 1, 'new ReportExtraFields created';

        my $object = $model->first;
        push @$extra_fields, {
            order => "1",
            code => "string_test",
            required => "true",
            variable => "true",
            description => "this is a test description",
            datatype_description => "hint here",
            datatype => "string",
        };
        is_deeply $object->get_extra_fields, $extra_fields, 'new string field was added';
        is $object->cobrand, 'tester', 'Correct cobrand set';
        is $object->language, undef, 'Correct language set';

        $mech->get_ok("/admin/reportextrafields/" . $object->id);
        $mech->submit_form_ok( { with_fields => {
            "language" => "en-gb",
            "metadata[1].order" => "2",
            "metadata[1].code" => "list_test",
            "metadata[1].required" => undef,
            "metadata[1].notice" => "",
            "metadata[1].description" => "this field is a list",
            "metadata[1].datatype_description" => "",
            "metadata[1].datatype" => "list",
            "metadata[1].values[0].key" => "key1",
            "metadata[1].values[0].name" => "name1",
        }});

        push @$extra_fields, {
            order => "2",
            code => "list_test",
            required => "false",
            variable => "true",
            description => "this field is a list",
            datatype_description => "",
            datatype => "singlevaluelist",
            values => [
                { name => "name1", key => "key1" },
            ]
        };

        $object->discard_changes;
        is_deeply $object->get_extra_fields, $extra_fields, 'new list field was added';
        is $object->language, "en-gb", "Correct language was set";

        $mech->get_ok("/admin/reportextrafields/" . $object->id);
        $mech->submit_form_ok({ with_fields => {
            "metadata[2].order" => "3",
            "metadata[2].code" => "automated_test",
            "metadata[2].required" => undef,
            "metadata[2].notice" => "",
            "metadata[2].description" => "",
            "metadata[2].datatype_description" => "",
            "metadata[2].datatype" => "string",
            "metadata[2].automated" => "server_set",
        }});

        push @$extra_fields, {
            order => "3",
            code => "automated_test",
            required => "false",
            variable => "true",
            description => "",
            datatype_description => "",
            datatype => "string",
            automated => "server_set",
        };

        $object->discard_changes;
        is_deeply $object->get_extra_fields, $extra_fields, 'new automated field was added';
        is $object->language, "en-gb", "Correct language was set";

        $mech->get_ok("/admin/reportextrafields/" . $object->id);
        $mech->submit_form_ok( { with_fields => {
            "metadata[1].values[1].key" => "key2",
            "metadata[1].values[1].name" => "name2",
        }});

        push @{$extra_fields->[1]->{values}}, { name => "name2", key => "key2" };
        $object->discard_changes;
        is_deeply $object->get_extra_fields, $extra_fields, 'options can be added to list field';
    };

    subtest 'Fields appear on /report/new' => sub {
        $mech->get_ok("/report/new?longitude=-1.351488&latitude=51.847235&category=" . $contact->category);
        $mech->content_contains("this is a test description");
        $mech->content_contains("this field is a list");
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'tester' => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
    LANGUAGES => [ 'de,German,de_DE' ]
}, sub {
    subtest 'Language-specific fields are missing from /report/new for other language' => sub {
        $mech->get_ok("/report/new?longitude=-1.351488&latitude=51.847235&category=" . $contact->category);
        $mech->content_lacks("this is a test description");
        $mech->content_lacks("this field is a list");
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'secondtester' => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
    LANGUAGES => [ 'en-gb,English,en_GB' ]
}, sub {
    subtest 'Cobrand-specific fields are missing from /report/new for other cobrand' => sub {
        $mech->get_ok("/report/new?longitude=-1.351488&latitude=51.847235&category=" . $contact->category);
        $mech->content_lacks("this is a test description");
        $mech->content_lacks("this field is a list");
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'noextras' => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
    LANGUAGES => [ 'en-gb,English,en_GB' ]
}, sub {
    subtest "Extra fields are missing from cobrand that doesn't allow them" => sub {
        my $object = FixMyStreet::App->model('DB::ReportExtraField')->first;
        $object->update({ language => "", cobrand => ""});

        $mech->get_ok("/report/new?longitude=-1.351488&latitude=51.847235&category=" . $contact->category);
        $mech->content_lacks("this is a test description");
        $mech->content_lacks("this field is a list");
    };
};

FixMyStreet::App->model('DB::ReportExtraField')->delete_all;
$mech->log_out_ok;

subtest 'Reports are created with correct extra metadata' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'tester' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $model = FixMyStreet::App->model('DB::ReportExtraField');
        my $extra_fields = $model->find_or_create({
            name => "Test extra fields",
            language => "",
            cobrand => ""
        });
        $extra_fields->push_extra_fields({
            order => "1",
            code => "string_test",
            required => "true",
            variable => "true",
            description => "this is a test description",
            datatype_description => "hint here",
            datatype => "string",
        });
        $extra_fields->push_extra_fields({
            order => "2",
            code => "list_test",
            required => "false",
            variable => "true",
            description => "this field is a list",
            datatype_description => "",
            datatype => "singlevaluelist",
            values => [
                { name => "name1", key => "key1" },
            ]
        });
        $extra_fields->update;

        my $user = $mech->create_user_ok('testuser@example.com', name => 'Test User');
        $mech->log_in_ok($user->email);

        $mech->get_ok('/report/new?latitude=55.952055&longitude=-3.189579');
        $mech->content_contains($contact2->category);

        my $extra_id = $extra_fields->id;
        $mech->submit_form_ok( {
            with_fields => {
                title => "Test Report",
                detail => "This is a test report",
                category => $contact2->category,
                "extra[$extra_id]string_test" => "Problem meta string",
                "extra[$extra_id]list_test" => "key1",
            }
        } );

        my $report = $user->problems->first;
        is_deeply $report->get_extra_fields, [
            {
                name => 'string_test',
                description => 'this is a test description',
                value => 'Problem meta string',
            },
            {
                name => 'list_test',
                description => 'this field is a list',
                value => 'key1',
            }
        ], 'Report has correct extra data';
    };
};


done_testing();
