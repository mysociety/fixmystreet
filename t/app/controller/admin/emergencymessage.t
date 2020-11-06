use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $user = $mech->create_user_ok('user@example.com', name => 'Test User', from_body => $body);

$mech->log_in_ok( $user->email );
ok $mech->host('oxfordshire.fixmystreet.com');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
}, sub {
    subtest 'setting emergency message' => sub {
        $user->user_body_permissions->create({
            body => $body,
            permission_type => 'emergency_message_edit',
        });

        $mech->get_ok('/admin/emergencymessage');
        $mech->submit_form_ok({ with_fields => { emergency_message => 'Testing emergency message' } });
        $mech->content_contains('Testing emergency message');
        $mech->get_ok('/');
        $mech->content_contains('Testing emergency message');

        # Check removing message
        $mech->get_ok('/admin/emergencymessage');
        $mech->submit_form_ok({ with_fields => { emergency_message => '' } });
        $mech->content_lacks('Testing emergency message');
        $mech->get_ok('/');
        $mech->content_lacks('Testing emergency message');
    };

    subtest "user without permissions can't set emergency message" => sub {
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({
            body => $body,
            permission_type => 'report_edit',
        });

        $mech->get('/admin/emergencymessage');
        ok !$mech->res->is_success, "want a bad response";
        is $mech->res->code, 404, "got 404";
    };
};

done_testing;
