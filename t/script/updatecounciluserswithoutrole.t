use FixMyStreet::TestMech;
use Test::Exception;

use_ok 'FixMyStreet::Script::UpdateCouncilUsersWithoutRole';

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2651, 'TfL');
my $other_body = $mech->create_body_ok(2248, 'Northumberland');

sub create_users() {
    my $no_permissions = $mech->create_user_ok('no_permissions@example.org', from_body => $body);
    $no_permissions->user_body_permissions->delete();

    my $one_permission = $mech->create_user_ok('one_permission@example.org', from_body => $body);
    $one_permission->user_body_permissions->delete();
    $one_permission->user_body_permissions->create({ body_id => $body->id, permission_type => 'user_edit'});

    my $many_permissions = $mech->create_user_ok('many_permissions@example.org', from_body => $body);
    $many_permissions->user_body_permissions->delete();
    for (qw/user_edit category_edit report_edit/) {
        $many_permissions->user_body_permissions->create({ body_id => $body->id, permission_type => $_});
    }

    my $other_one_permission = $mech->create_user_ok('other_one_permission@example.org', from_body => $other_body);
    $other_one_permission->user_body_permissions->delete();
    $other_one_permission->user_body_permissions->create({ body_id => $other_body->id, permission_type => 'user_edit'});

    my $role = FixMyStreet::DB->resultset("Role")->update_or_create({
        body => $body, name => 'One', permissions => ['user_edit']
    }, { key => 'roles_body_id_name_key'});
    my $has_role = $mech->create_user_ok('has_role@example.org', from_body => $body);
    $has_role->user_roles->find_or_create(role_id => $role->id);

    my $has_role_and_permissions = $mech->create_user_ok('has_role_and_permissions@example.org', from_body => $body);
    $has_role_and_permissions->user_roles->find_or_create(role_id => $role->id);
    $has_role_and_permissions->user_body_permissions->delete();
    $has_role_and_permissions->user_body_permissions->create({ body_id => $body->id, permission_type => 'report_edit'});

    my %users = (
        no_permissions => $no_permissions,
        one_permission => $one_permission,
        many_permissions => $many_permissions,
        other_one_permission => $other_one_permission,
        has_role => $has_role,
        has_role_and_permissions => $has_role_and_permissions,
    );

    return \%users;
}

for my $test (
    {
        title => 'add single permission everywhere',
        opts => {
            commit => 1,
            permissions => 'template_edit',
            mode => 'add',
        },
        permissions => {
            no_permissions => 'template_edit',
            one_permission => 'template_edit,user_edit',
            many_permissions => 'category_edit,report_edit,template_edit,user_edit',
            other_one_permission => 'template_edit,user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'remove single permission everywhere',
        opts => {
            commit => 1,
            permissions => 'user_edit',
            mode => 'remove',
        },
        permissions => {
            no_permissions => '',
            one_permission => '',
            many_permissions => 'category_edit,report_edit',
            other_one_permission => '',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'add multiple permissions everywhere',
        opts => {
            commit => 1,
            permissions => 'template_edit,moderate',
            mode => 'add',
        },
        permissions => {
            no_permissions => 'moderate,template_edit',
            one_permission => 'moderate,template_edit,user_edit',
            many_permissions => 'category_edit,moderate,report_edit,template_edit,user_edit',
            other_one_permission => 'moderate,template_edit,user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'remove multiple permissions everywhere',
        opts => {
            commit => 1,
            permissions => 'user_edit,report_edit',
            mode => 'remove',
        },
        permissions => {
            no_permissions => '',
            one_permission => '',
            many_permissions => 'category_edit',
            other_one_permission => '',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'remove multiple permissions everywhere with spaces',
        opts => {
            commit => 1,
            permissions => 'user_edit, report_edit',
            mode => 'remove',
        },
        permissions => {
            no_permissions => '',
            one_permission => '',
            many_permissions => 'category_edit',
            other_one_permission => '',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'permission not added twice',
        opts => {
            commit => 1,
            permissions => 'user_edit',
            mode => 'add',
        },
        permissions => {
            no_permissions => 'user_edit',
            one_permission => 'user_edit',
            many_permissions => 'category_edit,report_edit,user_edit',
            other_one_permission => 'user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'add single permission for body',
        opts => {
            commit => 1,
            permissions => 'template_edit',
            council => 'TfL',
            mode => 'add',
        },
        permissions => {
            no_permissions => 'template_edit',
            one_permission => 'template_edit,user_edit',
            many_permissions => 'category_edit,report_edit,template_edit,user_edit',
            other_one_permission => 'user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'add single permission for users with permission',
        opts => {
            commit => 1,
            permissions => 'template_edit',
            with_permission => 'report_edit',
            mode => 'add',
        },
        permissions => {
            no_permissions => '',
            one_permission => 'user_edit',
            many_permissions => 'category_edit,report_edit,template_edit,user_edit',
            other_one_permission => 'user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        }
    },
    {
        title => 'add single permission for missing body',
        opts => {
            commit => 1,
            permissions => 'template_edit',
            council => 'TfM',
            mode => 'add',
        },
        permissions => {
            no_permissions => '',
            one_permission => 'user_edit',
            many_permissions => 'category_edit,report_edit,user_edit',
            other_one_permission => 'user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        },
        dies => 1,
    },
    {
        title => 'remove single permission for body',
        opts => {
            commit => 1,
            permissions => 'user_edit',
            council => 'TfL',
            mode => 'remove',
        },
        permissions => {
            no_permissions => '',
            one_permission => '',
            many_permissions => 'category_edit,report_edit',
            other_one_permission => 'user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        },
    },
    {
        title => 'nothing happens without commit',
        opts => {
            permissions => 'user_edit',
            council => 'TfL',
            mode => 'remove',
        },
        permissions => {
            no_permissions => '',
            one_permission => 'user_edit',
            many_permissions => 'category_edit,report_edit,user_edit',
            other_one_permission => 'user_edit',
            has_role => '',
            has_role_and_permissions => 'report_edit',
        },
    },
) {
    subtest $test->{title} => sub {
        # reset to known state each time
        my $users = create_users();
        if ($test->{dies}) {
            dies_ok { FixMyStreet::Script::UpdateCouncilUsersWithoutRole::update($test->{opts}) };
            return;
        }
        lives_ok { FixMyStreet::Script::UpdateCouncilUsersWithoutRole::update($test->{opts}) };
        for my $u (keys %{$test->{permissions}}) {
            $users->{$u}->discard_changes;
            my $perms = join ',', sort map {$_->permission_type} $users->{$u}->user_body_permissions->all;
            is $perms, $test->{permissions}->{$u};
        }
    };
}

done_testing();
