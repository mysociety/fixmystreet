use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');
my $user2 = $mech->create_user_ok('test2@example.com', name => 'Test User 2');
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

my $bromley = $mech->create_body_ok(2482, 'Bromley Council');

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my ($report) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Test', {
    areas => ',2237,',
});
my $report_id = $report->id;
ok $report, "created test report - $report_id";

$mech->log_in_ok( $oxfordshireuser->email );

subtest "Users can't edit report without report_edit permission" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->get("/admin/report_edit/$report_id");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404, can't edit report without report_edit permission";
    };
};

subtest "Users can edit report with report_edit permission" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $oxfordshireuser->user_body_permissions->create({
            body => $oxfordshire,
            permission_type => 'report_edit',
        });

        $mech->get_ok("/admin/report_edit/$report_id");
        $mech->content_contains( $report->title );
    };
};

subtest "Users can't edit another council's reports with their own council's report_edit permission" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $report->bodies_str($bromley->id);
        $report->cobrand('bromley');
        $report->update;

        $mech->get("/admin/report_edit/$report_id");
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404, can't edit report with incorrect body in report_edit permission";
    };
};


FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
}, sub {
    my $user2_id = $user2->id;
    $report->update({ bodies_str => $oxfordshire->id });

    foreach my $perm (0, 1) {
        if ($perm) {
            $oxfordshireuser->user_body_permissions->find_or_create({
                body => $oxfordshire,
                permission_type => 'user_edit',
            });
        }
        foreach my $report_user ($user, $user2) {
            $report->update({ user => $report_user });
            foreach my $from_body (undef, $bromley, $oxfordshire) {
                $user2->update({ from_body => $from_body });
                my $result = ($from_body || '') eq $oxfordshire || $report->user eq $user2 ? ($perm ? 200 : 404 ) : 404;
                my $u = $result == 200 ? 'can' : 'cannot';
                my $b = $from_body ? $from_body->name : 'no body';
                my $p = $perm ? 'with' : 'without';
                my $r = $report->user eq $user2 ? 'with' : 'without';
                subtest "User $u edit user for $b $p permission, $r cobrand relation" => sub {
                    $mech->get("/admin/users/$user2_id");
                    my $success = $mech->res->is_success();
                    ok $result == 200 ? $success : !$success, "got correct response";
                    is $mech->res->code, $result, "got $result";
                };
            }
        }
    }

    subtest "Users can't edit users of their own council without permission" => sub {
        $mech->get_ok("/admin/users/$user2_id");
        $mech->submit_form_ok( { with_fields => {
            email => $user2->email,
        } } );
        $user2->discard_changes;
        # Make sure we haven't lost the from_body info
        is $user2->from_body->id, $oxfordshire->id;
    };

    $oxfordshireuser->user_body_permissions->create({
        body => $oxfordshire,
        permission_type => 'user_assign_body',
    });

    subtest "Users can edit users of their own council" => sub {
        $mech->get_ok("/admin/users/$user2_id");
        $mech->content_contains( $user2->name );

        # We shouldn't be able to see the permissions tick boxes
        $mech->content_lacks('Moderate report details');

        $mech->submit_form_ok( { with_fields => {
            name => 'Test Updated User 2',
            email => $user2->email,
            body => $user2->from_body->id,
            phone => '',
            flagged => undef,
        } } );
        $user2->discard_changes;
        is $user2->name, 'Test Updated User 2', 'name changed';
    };

    $oxfordshireuser->user_body_permissions->create({
        body => $oxfordshire,
        permission_type => 'user_manage_permissions',
    });

    subtest "Users can edit permissions" => sub {
        is $user2->user_body_permissions->count, 0, 'user2 has no permissions';

        $mech->get_ok("/admin/users/$user2_id");
        $mech->content_contains('Moderate report details');

        $mech->submit_form_ok( { with_fields => {
            name => $user2->name,
            email => $user2->email,
            body => $user2->from_body->id,
            phone => '',
            flagged => undef,
            "permissions[moderate]" => 'on',
            "permissions[report_edit_category]" => undef,
            "permissions[report_edit_priority]" => undef,
            "permissions[report_inspect]" => undef,
            "permissions[report_instruct]" => undef,
            "permissions[contribute_as_another_user]" => undef,
            "permissions[contribute_as_anonymous_user]" => undef,
            "permissions[contribute_as_body]" => undef,
            "permissions[user_edit]" => undef,
            "permissions[user_manage_permissions]" => undef,
            "permissions[user_assign_areas]" => undef,
        } } );

        ok $user2->has_body_permission_to("moderate"), "user2 has been granted moderate permission";
    };

    $oxfordshireuser->user_body_permissions->create({
        body => $oxfordshire,
        permission_type => 'user_assign_areas',
    });

    subtest "Unsetting user from_body removes all permissions and area " => sub {
        is $user2->user_body_permissions->count, 1, 'user2 has 1 permission';
        $user2->update({ area_ids => [123] }); # Set to check cleared

        $mech->get_ok("/admin/users/$user2_id");
        $mech->content_contains('Moderate report details');

        $mech->submit_form_ok( { with_fields => {
            name => $user2->name,
            email => $user2->email,
            body => undef,
            phone => '',
            flagged => undef,
            "permissions[moderate]" => 'on', # NB tick box is left on deliberately
            "permissions[report_edit_category]" => undef,
            "permissions[report_edit_priority]" => undef,
            "permissions[report_inspect]" => undef,
            "permissions[report_instruct]" => undef,
            "permissions[contribute_as_another_user]" => undef,
            "permissions[contribute_as_anonymous_user]" => undef,
            "permissions[contribute_as_body]" => undef,
            "permissions[user_edit]" => undef,
            "permissions[user_manage_permissions]" => undef,
            "permissions[user_assign_areas]" => undef,
        } } );

        $user2->discard_changes;
        is $user2->user_body_permissions->count, 0, 'user2 has had permissions removed';
        is $user2->area_ids, undef, 'user2 has had area removed';
    };
};

$mech->log_out_ok;

done_testing();
