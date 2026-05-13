use FixMyStreet::TestMech;
use Test::Exception;

use_ok 'FixMyStreet::Script::UpdateRoles';

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2651, 'TfL');
my $other_body = $mech->create_body_ok(2248, 'Northumberland');

sub create_roles() {
    my $no_permissions = FixMyStreet::DB->resultset("Role")->update_or_create({
        body => $body, name => 'No Permissions', permissions => []
    }, { key => 'roles_body_id_name_key'});
    my $one_permission = FixMyStreet::DB->resultset("Role")->update_or_create({
        body => $body, name => 'One', permissions => ['user_edit']
    }, { key => 'roles_body_id_name_key'});
    my $many_permissions = FixMyStreet::DB->resultset("Role")->update_or_create({
        body => $body, name => 'Many', permissions => ['user_edit', 'category_edit', 'report_edit']
    }, { key => 'roles_body_id_name_key'});
    my $other_one_permission = FixMyStreet::DB->resultset("Role")->update_or_create({
        body => $other_body, name => 'One', permissions => ['user_edit']
    }, { key => 'roles_body_id_name_key'});

    my %roles = (
        no_permissions => $no_permissions,
        one_permission => $one_permission,
        many_permissions => $many_permissions,
        other_one_permission => $other_one_permission
    );

    return \%roles;
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
        }
    },
    {
        title => 'add single permission for roles with permission',
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
        },
    },
) {
    subtest $test->{title} => sub {
        # reset to known state each time
        my $roles = create_roles();
        if ($test->{dies}) {
            dies_ok { FixMyStreet::Script::UpdateRoles::update($test->{opts}) };
            return;
        }
        lives_ok { FixMyStreet::Script::UpdateRoles::update($test->{opts}) };
        for my $r (keys %{$test->{permissions}}) {
            $roles->{$r}->discard_changes;
            my $perms = join ',', sort @{$roles->{$r}->permissions};
            is $perms, $test->{permissions}->{$r};
        }
    };
}

done_testing();
