use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $body2 = $mech->create_body_ok(2482, 'Bromley Council');
my $editor = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
my $user = $mech->create_user_ok('staffuser@example.com', name => 'Other Council User', from_body => $body);

$editor->user_body_permissions->create({
    body => $body,
    permission_type => 'user_edit',
});
$editor->user_body_permissions->create({
    body => $body,
    permission_type => 'user_manage_permissions',
});
$user->user_body_permissions->create({
    body => $body,
    permission_type => 'report_edit_priority',
});

my $role_a = FixMyStreet::DB->resultset("Role")->create({
    body => $body,
    name => 'Role A',
    permissions => ['moderate', 'user_edit'],
});
FixMyStreet::DB->resultset("Role")->create({
    body => $body2,
    name => 'Role Z',
    permissions => ['report_inspect', 'planned_reports'],
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'oxfordshire',
    MAPIT_URL => 'http://mapit.uk',
}, sub {

    $mech->log_in_ok( $editor->email );

    subtest 'role index page' => sub {
        $mech->get_ok("/admin/roles");
        $mech->content_contains('Role A');
        $mech->content_contains('Moderate report details');
        $mech->content_lacks('Role Z');
        $mech->content_lacks('Manage shortlist');
        $mech->content_lacks('Add/edit response templates'); # About to be added
    };

    subtest 'create a role' => sub {
        $mech->follow_link_ok({ text => 'Create' });
        $mech->content_lacks('Body');
        $mech->submit_form_ok({ with_fields => { name => 'Role A' }});
        $mech->content_contains('Role names must be unique');
        $mech->submit_form_ok({ with_fields => {
            name => 'Role B',
            permissions => [ ['template_edit', 'user_manage_permissions'] ],
        }});

        $mech->content_contains('Role B');
        $mech->content_contains('Add/edit response templates');
    };

    subtest 'editing a role preselects correct options' => sub {
        $mech->follow_link_ok({ text => 'Edit' });
        $mech->content_like(qr/value="moderate"[^>]*checked/);
        $mech->content_like(qr/value="user_edit"[^>]*checked/);
    };

    subtest 'editing a role to same name as another fails' => sub {
        $mech->submit_form_ok({ with_fields => { name => 'Role B' }});
        $mech->content_contains('Role names must be unique');
    };

    subtest 'delete a role' => sub {
        $mech->submit_form_ok({ button => 'delete_role' });
        $mech->content_lacks('Role A');
    };

    subtest 'assign a user to a role' => sub {
        $mech->get_ok('/admin/users/' . $user->id);
        $mech->content_contains('Role B');
        $mech->content_lacks('Role Z');
        $mech->submit_form_ok({ with_fields => {
            roles => 'Role B',
        }});
        $mech->content_like(qr/<option[^>]*selected>Role B/);
        $mech->content_like(qr/<input[^>]*checkbox[^>]*template_edit[^>]*checked/);
        is $user->roles->count, 1, 'in one role';
        is $user->user_body_permissions->count, 0, 'permissions removed';
    };

    subtest 'check user has the permissions of the role' => sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/admin/templates');
    };

    subtest 'remove user from role' => sub {
        $mech->log_in_ok( $editor->email );
        $mech->get_ok('/admin/users/' . $user->id);
        $mech->submit_form_ok({ with_fields => {
            roles => undef,
        }}, 'remove role');
    };
};

subtest 'superuser can see all bodies' => sub {
    $mech->log_in_ok( $superuser->email );

    $mech->get_ok("/admin/roles");
    $mech->content_contains('Oxfordshire');
    $mech->content_contains('Bromley');
    $mech->content_contains('Role B');
    $mech->content_contains('Role Z');
    $mech->follow_link_ok({ text => 'Create' });
    $mech->content_contains('Body');
    $mech->content_contains('Bromley');

    $mech->submit_form_ok({ with_fields => { body => $body->id, name => 'Role B' }});
    $mech->content_contains('Role names must be unique');

    $mech->submit_form_ok({ with_fields => {
        name => 'Role C',
        body => $body2->id,
        permissions => 'contribute_as_body',
    }});
    $mech->content_contains('Role C');
};

subtest 'check log of the above' => sub {
    my $id = FixMyStreet::DB->resultset("Role")->find({ name => "Role B" })->id;
    $mech->get_ok('/admin/users/' . $editor->id . '/log');
    $mech->content_contains('Added role <a href="/admin/roles/' . $id . '">Role B</a>');
    $mech->content_contains('Deleted role ' . $role_a->id);
};

done_testing();
