use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshirecontact = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

my $bromley = $mech->create_body_ok(2482, 'Bromley Council');

$mech->log_in_ok( $superuser->email );

subtest "response priorities can be added" => sub {
    is $oxfordshire->response_priorities->count, 0, "No response priorities yet";
    $mech->get_ok( "/admin/responsepriorities/" . $oxfordshire->id . "/create" );

    my $fields = {
        name => "Cat 1A",
        description => "Fixed within 24 hours",
        deleted => undef,
        is_default => undef,
        contacts => $oxfordshirecontact->id,
    };
    $mech->submit_form_ok( { with_fields => $fields } );

     is $oxfordshire->response_priorities->count, 1, "Response priority was added to body";
     is $oxfordshirecontact->response_priorities->count, 1, "Response priority was added to contact";
};

subtest "response priorities can set to default" => sub {
    my $priority_id = $oxfordshire->response_priorities->first->id;
    is $oxfordshire->response_priorities->count, 1, "Response priority exists";
    $mech->get_ok( "/admin/responsepriorities/" . $oxfordshire->id . "/$priority_id" );

    my $fields = {
        name => "Cat 1A",
        description => "Fixed within 24 hours",
        deleted => undef,
        is_default => 1,
        contacts => $oxfordshirecontact->id,
    };
    $mech->submit_form_ok( { with_fields => $fields } );

     is $oxfordshire->response_priorities->count, 1, "Still one response priority";
     is $oxfordshirecontact->response_priorities->count, 1, "Still one response priority";
     ok $oxfordshire->response_priorities->first->is_default, "Response priority set to default";
};

subtest "response priorities can be listed" => sub {
    $mech->get_ok( "/admin/responsepriorities" );

    $mech->content_contains( $oxfordshire->response_priorities->first->name );
    $mech->content_contains( $oxfordshire->response_priorities->first->description );
};

$mech->log_out_ok;

subtest "response priorities can't be viewed across councils" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        my $bromley_priority = $bromley->response_priorities->create( {
            deleted => 0,
            name => "Bromley Cat 0",
        } );

        is $bromley->response_priorities->count, 1, "Response priority was added to Bromley";
        is $oxfordshire->response_priorities->count, 1, "Response priority wasn't added to Oxfordshire";

        $oxfordshireuser->user_body_permissions->create({
            body => $oxfordshire,
            permission_type => 'responsepriority_edit',
        });
        $mech->log_in_ok( $oxfordshireuser->email );
        $mech->get_ok( "/admin/responsepriorities" );
        $mech->content_contains( $oxfordshire->response_priorities->first->name );
        $mech->content_lacks( $bromley_priority->name );

        $mech->get( "/admin/responsepriorities/" . $bromley->id . "/" . $bromley_priority->id );
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
    };
};

done_testing();
