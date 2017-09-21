use FixMyStreet::TestMech;
use FixMyStreet::App;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $contact1 = $mech->create_contact_ok( body_id => $body->id, category => 'Street lighting', email => 'highways@example.com' );
my $contact2 = $mech->create_contact_ok( body_id => $body->id, category => 'Potholes', email => 'potholes@example.com' );

my $test_email = 'body-user@example.net';
my $user = $mech->log_in_ok($test_email);
$user->update({ from_body => $body->id, name => 'Body User' });

my ($report_to_update) = $mech->create_problems_for_body(1, $body->id, 'Title');

subtest "Body user, no permissions, no special reporting tools shown" => sub {
    start_report();
    dropdown_shown(0);
    start_update();
    dropdown_shown(0, 'updateForm');
};

subtest "Body user, has permission to add report as council" => sub {
    my $report = add_report(
        'contribute_as_body',
        form_as => 'body',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Street lighting',
    );
    is $report->name, 'Oxfordshire County Council', 'report name is body';
    is $report->user->name, 'Body User', 'user name unchanged';
    is $report->user->id, $user->id, 'user matches';
    is $report->anonymous, 0, 'report not anonymous';
};

my @users;
subtest "Body user, has permission to add report as another user" => sub {
    my $report = add_report(
        'contribute_as_another_user',
        form_as => 'another_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Potholes',
        name => 'Another User',
        username => 'another@example.net',
    );
    is $report->name, 'Another User', 'report name is given name';
    is $report->user->name, 'Another User', 'user name matches';
    is $report->user->email, 'another@example.net', 'user email correct';
    isnt $report->user->id, $user->id, 'user does not match';
    like $mech->get_text_body_from_email, qr/Your report to Oxfordshire County Council has been logged/;
    push @users, $report->user;
};

subtest "Body user, has permission to add report as another (existing) user" => sub {
    $mech->create_user_ok('existing@example.net', name => 'Existing User');
    my $report = add_report(
        'contribute_as_another_user',
        form_as => 'another_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Potholes',
        name => 'Existing Yooser',
        username => 'existing@example.net',
    );
    is $report->name, 'Existing Yooser', 'report name is given name';
    is $report->user->name, 'Existing User', 'user name remains same';
    is $report->user->email, 'existing@example.net', 'user email correct';
    isnt $report->user->id, $user->id, 'user does not match';
    like $mech->get_text_body_from_email, qr/Your report to Oxfordshire County Council has been logged/;
    push @users, $report->user;
};

subtest "Body user, has permission to add report as anonymous user" => sub {
    my $report = add_report(
        'contribute_as_anonymous_user',
        form_as => 'anonymous_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Street lighting',
    );
    is $report->name, 'Oxfordshire County Council', 'report name is body';
    is $report->user->name, 'Body User', 'user name unchanged';
    is $report->user->id, $user->id, 'user matches';
    is $report->anonymous, 1, 'report anonymous';
};

subtest "Body user, has permission to add update as council" => sub {
    my $update = add_update(
        'contribute_as_body',
        form_as => 'body',
        update => 'Test Update',
    );
    is $update->name, 'Oxfordshire County Council', 'update name is body';
    is $update->user->name, 'Body User', 'user name unchanged';
    is $update->user->id, $user->id, 'user matches';
    is $update->anonymous, 0, 'update not anonymous';
};

subtest "Body user, has permission to add update as another user" => sub {
    my $update = add_update(
        'contribute_as_another_user',
        form_as => 'another_user',
        update => 'Test Update',
        name => 'Another User',
        username => 'another2@example.net',
    );
    is $update->name, 'Another User', 'update name is given name';
    is $update->user->name, 'Another User', 'user name matches';
    is $update->user->email, 'another2@example.net', 'user email correct';
    isnt $update->user->id, $user->id, 'user does not match';
    like $mech->get_text_body_from_email, qr/Your update has been logged/;
    push @users, $update->user;
};

subtest "Body user, has permission to add update as another (existing) user" => sub {
    my $update = add_update(
        'contribute_as_another_user',
        form_as => 'another_user',
        update => 'Test Update',
        name => 'Existing Yooser',
        username => 'existing@example.net',
    );
    is $update->name, 'Existing Yooser', 'update name is given name';
    is $update->user->name, 'Existing User', 'user name remains same';
    is $update->user->email, 'existing@example.net', 'user email correct';
    isnt $update->user->id, $user->id, 'user does not match';
    like $mech->get_text_body_from_email, qr/Your update has been logged/;
};

subtest "Body user, has permission to add update as anonymous user" => sub {
    my $update = add_update(
        'contribute_as_anonymous_user',
        form_as => 'anonymous_user',
        update => 'Test Update',
    );
    is $update->name, 'Oxfordshire County Council', 'update name is body';
    is $update->user->name, 'Body User', 'user name unchanged';
    is $update->user->id, $user->id, 'user matches';
    is $update->anonymous, 1, 'update anonymous';
};

done_testing();

sub start_report {
    my $permission = shift;
    $_->delete for $user->user_body_permissions;
    $user->user_body_permissions->create({ body => $body, permission_type => $permission })
        if $permission;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/report/new?latitude=51.7549262252&longitude=-1.25617899435');
    };
}

sub add_report {
    my ($permission, %fields) = @_;
    start_report($permission);
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        dropdown_shown(1);
        $mech->submit_form_ok({
            with_fields => \%fields,
        }, "submit details");
    };
    $mech->content_contains('Thank you for reporting this issue');
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->state, 'confirmed', "report is now confirmed";
    return $report;
}

sub start_update {
    my $permission = shift;
    $_->delete for $user->user_body_permissions;
    $user->user_body_permissions->create({ body => $body, permission_type => $permission })
        if $permission;
    $mech->get_ok('/report/' . $report_to_update->id);
}

sub add_update {
    my ($permission, %fields) = @_;
    start_update($permission);
    dropdown_shown(1, 'updateForm');
    $mech->submit_form_ok({
        with_fields => \%fields,
    }, "submit details");
    $mech->content_contains('Thank you for updating this issue');
    my $update = FixMyStreet::DB->resultset("Comment")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $update, "Found the update";
    is $update->state, 'confirmed', "update is now confirmed";
    return $update;
}

sub dropdown_shown {
    my ($shown, $name) = @_;
    is grep({ $_ eq 'form_as' } keys %{$mech->visible_form_values($name)}), $shown, "Dropdown shown = $shown";
}
