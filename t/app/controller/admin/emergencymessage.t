use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $user = $mech->create_user_ok('user@example.com', name => 'Test User', from_body => $body);
$user->user_body_permissions->create({
    body => $body,
    permission_type => 'emergency_message_edit',
});

$mech->log_in_ok( $user->email );


subtest 'setting emergency message' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        ok $mech->host('oxfordshire.fixmystreet.com');
        $mech->get_ok('/admin/emergencymessage');
        $mech->submit_form_ok({  with_fields => { emergency_message => 'Testing emergency message' } });
        $mech->content_contains('Testing emergency message');
        $mech->get_ok('/');
        $mech->content_contains('Testing emergency message');
    };
};

done_testing;
