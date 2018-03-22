use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshirecontact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
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

$mech->log_in_ok( $superuser->email );

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

done_testing();
