use FixMyStreet::TestMech;
use Test::LongString;
use Web::Scraper;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2608, 'Borsetshire Council');
$body->update({
    endpoint => 'http://example.com/open311',
    jurisdiction => 'mySociety',
    api_key => 'apikey',
});

# Let's make some contacts to send things to!
my $contact1 = $mech->create_contact_ok(
    body_id => $body->id, # Edinburgh
    category => 'Street lighting',
    email => '100',
    extra => [ { description => 'Lamppost number', code => 'number', required => 'True' },
               { description => 'Lamppost type', code => 'type', required => 'False', values =>
                   { value => [ { name => ['Gas'], key => ['old'] }, { name => [ 'Yellow' ], key => [ 'modern' ] } ] }
               }
             ],
);
my $contact1b = $mech->create_contact_ok(
    body_id => $body->id, # Edinburgh
    category => 'Moon lighting',
    email => '100b',
    extra => [ { description => 'Moon type', code => 'type', required => 'False', values =>
                   [ { name => 'Full', key => 'full' }, { name => 'New', key => 'new' } ] }
             ],
);
my $contact2 = $mech->create_contact_ok(
    body_id => $body->id, # Edinburgh
    category => 'Graffiti Removal',
    email => '101',
);
$mech->create_contact_ok(
    body_id => $body->id, # Edinburgh
    category => 'Ball lighting',
    email => '102',
    extra => { _fields => [
        { description => 'Message', code => 'message', required => 'false', variable => 'false', order => '0' },
        { description => 'Size', code => 'size', required => 'True', automated => '' },
        { description => 'Speed', code => 'speed', required => 'True', automated => 'server_set' },
        { description => 'Colour', code => 'colour', required => 'True', automated => 'hidden_field' },
    ] },
);

my $body2 = $mech->create_body_ok(2651, 'Edinburgh Council');
my $contact4 = $mech->create_contact_ok(
    body_id => $body2->id, # Edinburgh
    category => 'Pothole',
    email => '103',
    extra => { _fields => [
        { description => 'USRN', code => 'usrn', required => 'true', automated => 'hidden_field', variable => 'true', order => '1' },
        { description => 'Asset ID', code => 'central_asset_id', required => 'true', automated => 'hidden_field', variable => 'true', order => '2' },
    ] },
);
# Another one to switch to in disable form test
$mech->create_contact_ok(
    body_id => $body2->id, # Edinburgh
    category => 'Something Other',
    email => '104',
);
$mech->create_contact_ok(
    body_id => $body2->id, # Edinburgh
    category => 'Abandoned vehicle',
    email => '105',
    extra => { _fields => [
        { description => 'This is a warning message.', code => 'notice', required => 'false', variable => 'false', order => '0' },
        { description => 'USRN', code => 'usrn', required => 'false', automated => 'hidden_field' },
    ] },
);
$mech->create_contact_ok(
    body_id => $body2->id, # Edinburgh
    category => 'Traffic signals',
    email => '106',
    extra => { _fields => [
        { description => 'This is a warning message for traffic signals.', code => 'notice', required => 'false', variable => 'false', order => '0' },
    ] },
);

my $staff_user = $mech->create_user_ok('staff@example.org', name => 'staff', from_body => $body->id);

my $body3 = $mech->create_body_ok(2234, 'Northamptonshire County Council');
my $ncc_staff_user = $mech->create_user_ok('ncc_staff@example.org', name => 'ncc staff', from_body => $body3->id);
$mech->create_contact_ok(
    body_id => $body3->id,
    category => 'Flooding',
    email => '104',
    extra => { _fields => [
        { description => 'Please ring us!', code => 'ring', variable => 'false', order => '0', disable_form => 'true' }
    ] },
);

# test that the various bit of form get filled in and errors correctly
# generated.
my $empty_form = {
    title         => '',
    detail        => '',
    photo1        => '',
    photo2        => '',
    photo3        => '',
    name          => '',
    may_show_name => '1',
    username      => '',
    phone         => '',
    category      => '',
    password_sign_in => '',
    password_register => '',
};
foreach my $test (
    {
        msg    => 'all fields empty',
        pc     => 'EH99 1SP',
        fields => {
            %$empty_form,
            category => 'Street lighting',
        },
        changes => {
            number => '',
            type   => '',
        },
        errors  => [
            'This information is required',
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
            'Please enter your name',
        ],
        submit_with => {
            title => 'test',
            detail => 'test detail',
            name => 'Test User',
            username => 'testopen311@example.com',
            category => 'Street lighting',
            number => 27,
            type => 'old',
        },
        extra => [
            {
                name => 'number',
                value => 27,
                description => 'Lamppost number',
            },
            {
                name => 'type',
                value => 'old',
                description => 'Lamppost type',
            }
        ]
    },
    {
        msg    => 'automated things',
        pc     => 'EH99 1SP',
        fields => {
            %$empty_form,
            category => 'Ball lighting',
        },
        changes => {
            size => '',
        },
        hidden => [ 'colour' ],
        errors  => [
            'This information is required',
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
            'Please enter your name',
        ],
        submit_with => {
            title => 'test',
            detail => 'test detail',
            name => 'Test User',
            username => 'testopen311@example.com',
            size => 'big',
            colour => 'red',
        },
        extra => [
            {
                name => 'size',
                value => 'big',
                description => 'Size',
            },
            {
                name => 'colour',
                value => 'red',
                description => 'Colour',
            }
        ]
    },
  )
{
    subtest "check form errors where $test->{msg}" => sub {
        $mech->log_out_ok;
        $mech->clear_emails_ok;

        # check that the user does not exist
        my $test_email = $test->{submit_with}->{username};
        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        if ( $user ) {
            $user->problems->delete;
            $user->comments->delete;
            $user->delete;
        }

        $mech->get_ok('/around');

        # submit initial pc form
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
                "submit location" );
            is_deeply $mech->page_errors, [], "no errors for pc '$test->{pc}'";

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            # submit the main form
            $mech->submit_form_ok( { with_fields => $test->{fields} },
                "submit form" );
        };

        # check that we got the errors expected
        is_deeply $mech->page_errors, $test->{errors}, "check errors";

        $mech->content_contains('Help <strong>Borsetshire Council</strong> resolve your problem quicker');

        # check that fields have changed as expected
        my $new_values = {
            %{ $test->{fields} },     # values added to form
            %{ $test->{changes} },    # changes we expect
        };
        is_deeply $mech->visible_form_values, $new_values,
          "values correctly changed";
        if ($test->{hidden}) {
            my %hidden_fields = map { $_->name => 1 } grep { $_->type eq 'hidden' } ($mech->forms)[0]->inputs;
            foreach (@{$test->{hidden}}) {
                is $hidden_fields{$_}, 1;
            }
        }

        if ( $test->{fields}->{category} eq 'Street lighting' ) {
            my $result = scraper {
                process 'select#form_type option', 'option[]' => '@value';
            }
            ->scrape( $mech->response );

            is_deeply $result->{option}, [ "", qw/old modern/], 'displayed streetlight type select';
        }

        $new_values = {
            %{ $test->{fields} },
            %{ $test->{submit_with} },
        };
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => $new_values } );
        };

        $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        ok $user, 'created user';
        my $prob = $user->problems->first;
        ok $prob, 'problem created';

        is_deeply $prob->get_extra_fields, $test->{extra}, 'extra open311 data added to problem';

        $user->problems->delete;
        $user->delete;
    };
}

subtest "Category extras omits description label when all fields are hidden" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        for (
          { url => '/report/new/ajax?' },
          { url => '/report/new/category_extras?category=Pothole' },
        ) {
            my $json = $mech->get_ok_json($_->{url} . '&latitude=55.952055&longitude=-3.189579');
            my $category_extra = $json->{by_category} ? $json->{by_category}{Pothole}{category_extra} : $json->{category_extra};
            contains_string($category_extra, "usrn");
            contains_string($category_extra, "central_asset_id");
            lacks_string($category_extra, "USRN", "Lacks 'USRN' label");
            lacks_string($category_extra, "Asset ID", "Lacks 'Asset ID' label");
            lacks_string($category_extra, "resolve your problem quicker, by providing some extra detail", "Lacks description text");
        }
    };
};

subtest "Category extras omits preamble when all fields are notices" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        for (
          { url => '/report/new/ajax?' },
          { url => '/report/new/category_extras?category=Traffic+signals' },
        ) {
            my $json = $mech->get_ok_json($_->{url} . '&latitude=55.952055&longitude=-3.189579');
            my $category_extra = $json->{by_category} ? $json->{by_category}{'Traffic signals'}{category_extra} : $json->{category_extra};
            contains_string($category_extra, "This is a warning message for traffic signals.");
            lacks_string($category_extra, "resolve your problem quicker, by providing some extra detail", "Lacks description text");
        }
    };
};

subtest "Category extras omits preamble when fields are only notices and hidden" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        for (
          { url => '/report/new/ajax?' },
          { url => '/report/new/category_extras?category=Abandoned+vehicle' },
        ) {
            my $json = $mech->get_ok_json($_->{url} . '&latitude=55.952055&longitude=-3.189579');
            my $category_extra = $json->{by_category} ? $json->{by_category}{'Abandoned vehicle'}{category_extra} : $json->{category_extra};
            contains_string($category_extra, "This is a warning message.");
            contains_string($category_extra, "usrn");
            lacks_string($category_extra, "USRN", "Lacks 'USRN' label");
            lacks_string($category_extra, "resolve your problem quicker, by providing some extra detail", "Lacks description text");
        }
    };
};

subtest "Category extras includes description label for user" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $contact4->push_extra_fields({ description => 'Size?', code => 'size', required => 'true', automated => '', variable => 'true', order => '3', values => undef });
        $contact4->update;
        for (
          { url => '/report/new/ajax?' },
          { url => '/report/new/category_extras?category=Pothole' },
        ) {
            my $json = $mech->get_ok_json($_->{url} . '&latitude=55.952055&longitude=-3.189579');
            my $category_extra = $json->{by_category} ? $json->{by_category}{Pothole}{category_extra} : $json->{category_extra};
            contains_string($category_extra, "usrn");
            contains_string($category_extra, "central_asset_id");
            lacks_string($category_extra, "USRN", "Lacks 'USRN' label");
            lacks_string($category_extra, "Asset ID", "Lacks 'Asset ID' label");
            contains_string($category_extra, "Size?");
            lacks_string($category_extra, '<option value=""');
            contains_string($category_extra, "resolve your problem quicker, by providing some extra detail", "Contains description text");
        }
    };
};

subtest "Category extras are correct even if category has an ampersand in it" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        for (
          { url => '/report/new/ajax?' },
          { url => '/report/new/category_extras?category=Potholes+%26+Road+Defects' },
        ) {
            my $category = "Potholes & Road Defects";
            $contact4->update({ category => $category });
            my $json = $mech->get_ok_json($_->{url} . '&latitude=55.952055&longitude=-3.189579');
            my $category_extra = $json->{by_category} ? $json->{by_category}{$category}{category_extra} : $json->{category_extra};
            contains_string($category_extra, "usrn") or diag $mech->content;
            contains_string($category_extra, "central_asset_id");
            lacks_string($category_extra, "USRN", "Lacks 'USRN' label");
            lacks_string($category_extra, "Asset ID", "Lacks 'Asset ID' label");
            contains_string($category_extra, "Size?");
            lacks_string($category_extra, '<option value=""');
            contains_string($category_extra, "resolve your problem quicker, by providing some extra detail", "Contains description text");
            $contact4->update({ category => "Pothole" });
        }
    };
};

subtest "Category extras includes form disabling string" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $contact4->push_extra_fields({ description => 'Please ring us!', code => 'ring', variable => 'false', order => '0', disable_form => 'true' });
        $contact4->push_extra_fields({ datatype_description => 'Please please ring', description => 'Is it dangerous?', code => 'dangerous',
            variable => 'true', order => '0', values => [ { name => 'Yes', key => 'yes', disable => 1 }, { name => 'No', key => 'no' } ]
        });
        $contact4->update;
        for (
          { url => '/report/new/ajax?' },
          { url => '/report/new/category_extras?category=Pothole' },
        ) {
            my $json = $mech->get_ok_json($_->{url} . '&latitude=55.952055&longitude=-3.189579');
            my $output = $json->{by_category} ? $json->{by_category}{Pothole}{disable_form} : $json->{disable_form};
            is_deeply $output, {
                all => 'Please ring us!',
                questions => [
                    {
                        message => 'Please please ring',
                        code => 'dangerous',
                        answers => [ 'yes' ],
                    },
                ],
            };
        }

        # Test new non-JS form disabling flow
        $mech->get_ok('/report/new?latitude=55.952055&longitude=-3.189579');
        $mech->content_contains('name="submit_category_part_only"');
        $mech->submit_form_ok({ with_fields => { category => 'Pothole' } });
        $mech->content_contains('<div id="js-category-stopper" class="box-warning" role="alert" aria-live="assertive">');
        $mech->content_contains('Please ring us!');
        # Switch to another, okay, category
        $mech->submit_form_ok({ with_fields => { category => 'Something Other' } });
        $mech->content_lacks('<div id="js-category-stopper" class="box-warning" role="alert" aria-live="assertive">');
        $mech->content_lacks('Please ring us!');

        # Remove the required extra field so its error checking doesn't get in the way
        my $extra = $contact4->get_extra_fields;
        @$extra = grep { $_->{code} ne 'size' } @$extra;
        $contact4->set_extra_fields(@$extra);
        $contact4->update;

        # Test submission of whole form, switching back to a blocked category at the same time
        $mech->submit_form_ok({ with_fields => {
            category => 'Pothole', title => 'Title', detail => 'Detail',
            username => 'testing@example.org', name => 'Testing Example',
        } });
        $mech->content_contains('<div id="js-category-stopper" class="box-warning" role="alert" aria-live="assertive">');
        $mech->content_contains('Please ring us!');

        # Test special answer disabling of form
        $extra = $contact4->get_extra_fields;
        @$extra = grep { $_->{code} ne 'ring' } @$extra; # Remove that all-category one
        $contact4->set_extra_fields(@$extra);
        $contact4->update;
        $mech->get_ok('/report/new?latitude=55.952055&longitude=-3.189579');
        $mech->content_contains('name="submit_category_part_only"');
        $mech->submit_form_ok({ with_fields => { category => 'Pothole' } });
        $mech->content_contains('name="submit_category_part_only"');
        $mech->submit_form_ok({ with_fields => { dangerous => 'no' } });
        $mech->content_lacks('<div id="js-category-stopper" class="box-warning" role="alert" aria-live="assertive">');
        $mech->content_lacks('Please please ring');
        $mech->submit_form_ok({ with_fields => { dangerous => 'yes' } });
        $mech->content_contains('<div id="js-category-stopper" class="box-warning" role="alert" aria-live="assertive">');
        $mech->content_contains('Please please ring');
    };
};

subtest "Staff users still see disable form categories" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'borsetshire',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {

        $mech->log_in_ok($staff_user->email);

        $contact2->push_extra_fields({ description => 'Please ring us!', code => 'ring', variable => 'false', order => '0', disable_form => 'true' });
        $contact2->update;

        # Test new non-JS form disabling flow
        $mech->get_ok('/report/new?latitude=51.496194&longitude=-2.603439');
        $mech->submit_form_ok({ with_fields => { category => 'Graffiti Removal' } });
        $mech->content_contains('<div id="js-category-stopper" class="box-warning" role="alert" aria-live="assertive">');
        $mech->content_contains('Please ring us!');
    };
};

subtest "Staff users disable form categories" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_out_ok;
        $mech->log_in_ok($ncc_staff_user->email);

        $mech->get_ok('/report/new?latitude=52.236251&longitude=-0.892052');
        $mech->submit_form_ok({ with_fields => {
            category => 'Flooding', title => 'Title', detail => 'Detail',
        } });

        my $prob = $ncc_staff_user->problems->first;
        ok $prob, 'problem created';
        is $prob->title, "Title", 'Report title correct';
    };
};

done_testing();
