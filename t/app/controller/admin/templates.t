use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshirecontact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
my $oxfordshirecontact2 = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Flytipping', email => 'flytipping@example.com' );
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

my $bromley = $mech->create_body_ok(2482, 'Bromley Borough Council');
my $bromleycontact = $mech->create_contact_ok( body_id => $bromley->id, category => 'Potholes', email => 'potholes@example.com' );
my $bromleyuser = $mech->create_user_ok('bromleyuser@example.com', name => 'Council User', from_body => $bromley);
$bromleyuser->user_body_permissions->find_or_create({
    body => $bromley,
    permission_type => 'report_inspect',
});
my $bromleytemplate = $bromley->response_templates->create({
    title => "Bromley-specific response template.",
    text => "This template will only appear on the Bromley cobrand.",
});

my $tfl = $mech->create_body_ok(2482, 'TfL');
my $tflcontact = $mech->create_contact_ok( body_id => $tfl->id, category => 'Potholes', email => 'potholes@example.com' );
my $tfluser = $mech->create_user_ok('tfluser@example.com', name => 'Council User', from_body => $tfl);
$tfluser->user_body_permissions->find_or_create({
    body => $tfl,
    permission_type => 'report_inspect',
});
my $tfltemplate = $tfl->response_templates->create({
    title => "TfL-specific response template.",
    text => "This template will only appear on the TfL cobrand.",
});

my $dt = DateTime->now();

my $report = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        bodies_str         => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Report to Edit',
        detail             => 'Detail for Report to Edit',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        external_id        => '13',
        state              => 'confirmed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => '',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
        whensent           => $dt->ymd . ' ' . $dt->hms,
    }
);

my $report_id = $report->id;
ok $report, "created test report - $report_id";

subtest "response templates can be added" => sub {
    is $oxfordshire->response_templates->count, 0, "No response templates yet";
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );

    my $fields = {
        title => "Report acknowledgement",
        text => "Thank you for your report. We will respond shortly.",
        auto_response => undef,
        "contacts[".$oxfordshirecontact->id."]" => 1,
    };
    $mech->submit_form_ok( { with_fields => $fields } );

    is $oxfordshire->response_templates->count, 1, "Response template was added";
};

subtest 'check log of the above' => sub {
    my $template_id = $oxfordshire->response_templates->first->id;
    $mech->get_ok('/admin/users/' . $superuser->id . '/log');
    $mech->content_contains('Added template <a href="/admin/templates/' . $oxfordshire->id . '/' . $template_id . '">Report acknowledgement</a>');
};

subtest "but not another with the same title" => sub {
    my $fields = {
        title => "Report acknowledgement",
        text => "Another report acknowledgement.",
        auto_response => undef,
        "contacts[".$oxfordshirecontact->id."]" => 1,
    };
    my $list_url = "/admin/templates/" . $oxfordshire->id;
    $mech->get_ok( "$list_url/new" );
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, "$list_url/new", 'not redirected';
    $mech->content_contains( 'Please correct the errors below' );
    $mech->content_contains( 'There is already a template with that title.' );

    my @ts = $oxfordshire->response_templates->all;
    is @ts, 1, "No new response template was added";

    my $url = "$list_url/" . $ts[0]->id;
    $mech->get_ok($url);
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, $list_url, 'redirected';
    is $oxfordshire->response_templates->count, 1, "No new response template was added";
};

subtest "response templates are included on page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $report->update({ category => $oxfordshirecontact->category, bodies_str => $oxfordshire->id });
        $mech->log_in_ok( $oxfordshireuser->email );

        $mech->get_ok("/report/" . $report->id);
        $mech->content_contains( $oxfordshire->response_templates->first->text );

        $mech->log_out_ok;
    };
};

subtest "auto-response templates that duplicate a single category can't be added" => sub {
    $mech->delete_response_template($_) for $oxfordshire->response_templates;
    my $template = $oxfordshire->response_templates->create({
        title => "Report fixed - potholes",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 1,
        state => 'fixed - council',
    });
    $template->contact_response_templates->find_or_create({
        contact_id => $oxfordshirecontact->id,
    });
    is $oxfordshire->response_templates->count, 1, "Initial response template was created";


    $mech->log_in_ok( $superuser->email );
    $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );

    # This response template has the same category & state as an existing one
    # so won't be allowed.
    my $fields = {
        title => "Report marked fixed - potholes",
        text => "Thank you for your report. This pothole has been fixed.",
        auto_response => 'on',
        state => 'fixed - council',
        "contacts[".$oxfordshirecontact->id."]" => 1,
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/templates/' . $oxfordshire->id . '/new', 'not redirected';
    $mech->content_contains( 'Please correct the errors below' );
    $mech->content_contains( 'There is already an auto-response template for this category/state.' );

    is $oxfordshire->response_templates->count, 1, "Duplicate response template wasn't added";
};

subtest "auto-response templates that duplicate all categories can't be added" => sub {
    $mech->delete_response_template($_) for $oxfordshire->response_templates;
    $oxfordshire->response_templates->create({
        title => "Report investigating - all cats",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 1,
        state => 'fixed - council',
    });
    is $oxfordshire->response_templates->count, 1, "Initial response template was created";


    $mech->log_in_ok( $superuser->email );
    $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );

    # There's already a response template for all categories and this state, so
    # this new template won't be allowed.
    my $fields = {
        title => "Report investigating - single cat",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 'on',
        state => 'fixed - council',
        "contacts[".$oxfordshirecontact->id."]" => 1,
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/templates/' . $oxfordshire->id . '/new', 'not redirected';
    $mech->content_contains( 'Please correct the errors below' );
    $mech->content_contains( 'There is already an auto-response template for this category/state.' );


    is $oxfordshire->response_templates->count, 1, "Duplicate response template wasn't added";
};

subtest "all-category auto-response templates that duplicate a single category can't be added" => sub {
    $mech->delete_response_template($_) for $oxfordshire->response_templates;
    my $template = $oxfordshire->response_templates->create({
        title => "Report fixed - potholes",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 1,
        state => 'fixed - council',
    });
    $template->contact_response_templates->find_or_create({
        contact_id => $oxfordshirecontact->id,
    });
    is $oxfordshire->response_templates->count, 1, "Initial response template was created";


    $mech->log_in_ok( $superuser->email );
    $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );

    # This response template is implicitly for all categories, but there's
    # already a template for a specific category in this state, so it won't be
    # allowed.
    my $fields = {
        title => "Report marked fixed - all cats",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 'on',
        state => 'fixed - council',
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/templates/' . $oxfordshire->id . '/new', 'not redirected';
    $mech->content_contains( 'Please correct the errors below' );
    $mech->content_contains( 'There is already an auto-response template for this category/state.' );

    is $oxfordshire->response_templates->count, 1, "Duplicate response template wasn't added";
};

subtest "auto-response templates that duplicate external_status_code can't be added" => sub {
    $mech->delete_response_template($_) for $oxfordshire->response_templates;
    my $template = $oxfordshire->response_templates->create({
        title => "Report fixed - potholes",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 1,
        external_status_code => '100',
    });
    $template->contact_response_templates->find_or_create({
        contact_id => $oxfordshirecontact->id,
    });
    is $oxfordshire->response_templates->count, 1, "Initial response template was created";

    $mech->log_in_ok( $superuser->email );
    $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );

    my $fields = {
        title => "Report marked fixed - all cats",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 'on',
        external_status_code => '100',
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/templates/' . $oxfordshire->id . '/new', 'not redirected';
    $mech->content_contains( 'Please correct the errors below' );
    $mech->content_contains( 'There is already an auto-response template for this category/state.' );

    is $oxfordshire->response_templates->count, 1, "Duplicate response template wasn't added";
};

subtest "templates that set state and external_status_code can't be added" => sub {
    $mech->delete_response_template($_) for $oxfordshire->response_templates;
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );

    my $fields = {
        title => "Report marked fixed - all cats",
        text => "Thank you for your report. This problem has been fixed.",
        auto_response => 'on',
        state => 'fixed - council',
        external_status_code => '100',
    };
    $mech->submit_form_ok( { with_fields => $fields } );
    is $mech->uri->path, '/admin/templates/' . $oxfordshire->id . '/new', 'not redirected';
    $mech->content_contains( 'Please correct the errors below' );
    $mech->content_contains( 'State and external status code cannot be used simultaneously.' );

    is $oxfordshire->response_templates->count, 0, "Invalid response template wasn't added";
};

subtest "category groups are shown" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        COBRAND_FEATURES => {
            category_groups => {
                oxfordshire => 1,
            },
            multiple_category_groups => {
                oxfordshire => 1,
            },
        },
    }, sub {

        $mech->log_in_ok( $superuser->email );

        $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );
        $mech->content_contains("No Group") or diag $mech->content;
        $mech->content_lacks("Multiple Groups");
        $mech->content_lacks("These categories appear in more than one group:");

        $oxfordshirecontact->set_extra_metadata( group => [ 'Highways' ] );
        $oxfordshirecontact->update;
        $oxfordshirecontact2->set_extra_metadata( group => [ 'Street Cleaning' ] );
        $oxfordshirecontact2->update;
        $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );
        $mech->content_lacks("No Group");
        $mech->content_lacks("Multiple Groups");
        $mech->content_lacks("These categories appear in more than one group:");
        $mech->content_contains("Highways");
        $mech->content_contains("Street Cleaning");

        $oxfordshirecontact->set_extra_metadata( group => [ 'Highways', 'Roads & Pavements' ] );
        $oxfordshirecontact->update;
        $oxfordshirecontact2->set_extra_metadata( group => [ 'Street Cleaning' ] );
        $oxfordshirecontact2->update;
        $mech->get_ok( "/admin/templates/" . $oxfordshire->id . "/new" );
        $mech->content_lacks("No Group");
        $mech->content_contains("Multiple Groups");
        $mech->content_contains("These categories appear in more than one group:");
        $mech->content_contains("Highways; Roads &amp; Pavements");
        $mech->content_contains("Street Cleaning");
    };
};

subtest "TfL cobrand only shows TfL templates" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'tfl' ],
        COBRAND_FEATURES => { internal_ips => { tfl => [ '127.0.0.1' ] } },
    }, sub {
        $report->update({
            category => $tflcontact->category,
            bodies_str => $tfl->id,
            latitude => 51.402096,
            longitude => 0.015784,
            state => 'confirmed',
            areas => ',2482,',
        });
        $mech->log_in_ok( $tfluser->email );

        $mech->get_ok("/report/" . $report->id);
        $mech->content_contains( $tfltemplate->text );
        $mech->content_contains( $tfltemplate->title );
        $mech->content_lacks( $bromleytemplate->text );
        $mech->content_lacks( $bromleytemplate->title );

        $mech->log_out_ok;
    };
};

subtest "Bromley cobrand only shows Bromley templates" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bromley', 'tfl' ],
    }, sub {
        $report->update({ category => $bromleycontact->category, bodies_str => $bromley->id });
        $mech->log_in_ok( $bromleyuser->email );

        $mech->get_ok("/report/" . $report->id);
        $mech->content_contains( $bromleytemplate->text );
        $mech->content_contains( $bromleytemplate->title );
        $mech->content_lacks( $tfltemplate->text );
        $mech->content_lacks( $tfltemplate->title );

        $mech->log_out_ok;
    };
};

done_testing();
