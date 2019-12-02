use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

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

my $superuser = $mech->create_user_ok('superuser@example.net', name => "Super", is_superuser => 1);

my ($report_to_update) = $mech->create_problems_for_body(1, $body->id, 'Title', { category => 'Potholes' });

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

subtest "Body user, has permission to add report as another user with email" => sub {
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
};

subtest "Body user, has permission to add report as another user with mobile phone number" => sub {
    my $report = add_report(
        'contribute_as_another_user',
        form_as => 'another_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Potholes',
        name => 'Another User',
        username => '07906 111111',
    );
    is $report->name, 'Another User', 'report name is given name';
    is $report->user->name, 'Another User', 'user name matches';
    is $report->user->phone, '+447906111111', 'user phone correct';
    is $report->user->phone_verified, 1, 'user phone verified';
    is $report->user->email, undef, 'user email correct';
    is $report->user->email_verified, 0, 'user email not verified';
    isnt $report->user->id, $user->id, 'user does not match';
    $mech->email_count_is(0);
};

subtest "Body user, has permission to add report as another user with landline number" => sub {
    my $report = add_report(
        'contribute_as_another_user',
        form_as => 'another_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Potholes',
        name => 'Another User',
        username => '01685 222222',
    );
    is $report->name, 'Another User', 'report name is given name';
    is $report->user->name, 'Another User', 'user name matches';
    is $report->user->phone, '+441685222222', 'user phone correct';
    is $report->user->phone_verified, 1, 'user phone verified';
    is $report->user->email, undef, 'user email correct';
    is $report->user->email_verified, 0, 'user email not verified';
    isnt $report->user->id, $user->id, 'user does not match';
    $mech->email_count_is(0);
};

subtest "Body user, has permission to add report as another user with only name" => sub {
    my $report = add_report(
        'contribute_as_another_user',
        form_as => 'another_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Potholes',
        name => 'Another User',
        username => '',
        may_show_name => undef,
    );
    is $report->name, 'Another User', 'report name is name given';
    is $report->user->name, 'Body User', 'user name unchanged';
    is $report->user->id, $user->id, 'user matches';
    is $report->anonymous, 1, 'report anonymous';
};

subtest "Body user, has permission to add report as another (existing) user with email" => sub {
    FixMyStreet::Script::Reports::send();
    $mech->clear_emails_ok;

    my $existing = $mech->create_user_ok('existing@example.net', name => 'Existing User');
    my $report = add_report(
        'contribute_as_another_user',
        form_as => 'another_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Potholes',
        name => 'Existing Yooser',
        username => $existing->email,
    );
    is $report->name, 'Existing Yooser', 'report name is given name';
    is $report->user->name, 'Existing User', 'user name remains same';
    is $report->user->email, $existing->email, 'user email correct';
    isnt $report->user->id, $user->id, 'user does not match';
    like $mech->get_text_body_from_email, qr/Your report to Oxfordshire County Council has been logged/;

    my $send_confirmation_mail_override = Sub::Override->new(
        "FixMyStreet::Cobrand::Default::report_sent_confirmation_email",
        sub { return 'external_id'; }
    );
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(2);
    $mech->clear_emails_ok;
    $send_confirmation_mail_override->restore();
};

subtest "Body user, has permission to add report as another (existing) user with phone" => sub {
    $mech->create_user_ok('+447906333333', name => 'Existing User');
    my $report = add_report(
        'contribute_as_another_user',
        form_as => 'another_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Potholes',
        name => 'Existing Yooser',
        username => '07906 333333',
    );
    is $report->name, 'Existing Yooser', 'report name is given name';
    is $report->user->name, 'Existing User', 'user name remains same';
    is $report->user->phone, '+447906333333', 'user phone correct';
    isnt $report->user->id, $user->id, 'user does not match';
    $mech->email_count_is(0);
};

subtest "Superuser, can add report as anonymous user" => sub {
    FixMyStreet::Script::Reports::send();
    $mech->clear_emails_ok;

    my $user = $mech->log_in_ok($superuser->email);
    my $report = add_report(
        'contribute_as_anonymous_user',
        form_as => 'anonymous_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Street lighting',
    );
    is $report->name, 'an administrator', 'report name is admin';
    is $report->user->name, 'Super', 'user name unchanged';
    is $report->user->id, $user->id, 'user matches';
    is $report->anonymous, 1, 'report anonymous';
    is $report->get_extra_metadata('contributed_as'), 'anonymous_user';
    is $report->get_extra_metadata('contributed_by'), undef;

    my $send_confirmation_mail_override = Sub::Override->new(
        "FixMyStreet::Cobrand::Default::report_sent_confirmation_email",
        sub { return 'external_id'; }
    );

    FixMyStreet::Script::Reports::send();
    my $email = $mech->get_email;
    like $email->header('Subject'), qr/Problem Report: Test Report/, 'report email title correct';
    $mech->clear_emails_ok;
    $send_confirmation_mail_override->restore();

    $mech->log_in_ok($test_email);
};

subtest "Body user, can add report as anonymous user" => sub {
    FixMyStreet::Script::Reports::send();
    $mech->clear_emails_ok;

    my $user = $mech->log_in_ok($user->email);
    my $report = add_report(
        'contribute_as_anonymous_user',
        form_as => 'anonymous_user',
        title => "Test Report",
        detail => 'Test report details.',
        category => 'Street lighting',
    );
    is $report->name, $body->name, 'report name is OK';
    is $report->user->name, 'Body User', 'user name unchanged';
    is $report->user->id, $user->id, 'user matches';
    is $report->anonymous, 1, 'report anonymous';
    is $report->get_extra_metadata('contributed_as'), 'anonymous_user';
    is $report->get_extra_metadata('contributed_by'), $user->id;

    $mech->log_in_ok($test_email);
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

subtest "Body user, has permission to add update as another user with email" => sub {
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
};

subtest "Body user, has permission to add update as another user with mobile phone" => sub {
    my $update = add_update(
        'contribute_as_another_user',
        form_as => 'another_user',
        update => 'Test Update',
        name => 'Another User',
        username => '07906 444444',
    );
    is $update->name, 'Another User', 'update name is given name';
    is $update->user->name, 'Another User', 'user name matches';
    is $update->user->phone, '+447906444444', 'user phone correct';
    isnt $update->user->id, $user->id, 'user does not match';
    $mech->email_count_is(0);
};

subtest "Body user, has permission to add update as another user with landline phone" => sub {
    my $update = add_update(
        'contribute_as_another_user',
        form_as => 'another_user',
        update => 'Test Update',
        name => 'Another User',
        username => '01685 555555',
    );
    is $update->name, 'Another User', 'update name is given name';
    is $update->user->name, 'Another User', 'user name matches';
    is $update->user->phone, '+441685555555', 'user phone correct';
    isnt $update->user->id, $user->id, 'user does not match';
    $mech->email_count_is(0);
};

subtest "Body user, has permission to add update as another (existing) user with email" => sub {
    my $existing = $mech->create_user_ok('existing@example.net', name => 'Existing User');
    my $update = add_update(
        'contribute_as_another_user',
        form_as => 'another_user',
        update => 'Test Update',
        name => 'Existing Yooser',
        username => $existing->email,
    );
    is $update->name, 'Existing Yooser', 'update name is given name';
    is $update->user->name, 'Existing User', 'user name remains same';
    is $update->user->email, $existing->email, 'user email correct';
    isnt $update->user->id, $user->id, 'user does not match';
    like $mech->get_text_body_from_email, qr/Your update has been logged/;
};

subtest "Body user, has permission to add update as another (existing) user with phone" => sub {
    my $update = add_update(
        'contribute_as_another_user',
        form_as => 'another_user',
        update => 'Test Update',
        name => 'Existing Yooser',
        username => '07906 333333',
    );
    is $update->name, 'Existing Yooser', 'update name is given name';
    is $update->user->name, 'Existing User', 'user name remains same';
    is $update->user->phone, '+447906333333', 'user phone correct';
    isnt $update->user->id, $user->id, 'user does not match';
    $mech->email_count_is(0);
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

for my $test_permission ( qw/planned_reports default_to_body/ ) {
    subtest "$test_permission user defaults to reporting as body" => sub {
        $_->delete for $user->user_body_permissions;
        for my $permission ( 'contribute_as_another_user', 'contribute_as_anonymous_user', 'contribute_as_body', $test_permission ) {
            $user->user_body_permissions->create({ body => $body, permission_type => $permission })
        }
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ 'fixmystreet' ],
            MAPIT_URL => 'http://mapit.uk/',
            PHONE_COUNTRY => 'GB',
        }, sub {
            $mech->get_ok('/report/new?latitude=51.7549262252&longitude=-1.25617899435');
        };

        is $mech->visible_form_values()->{form_as}, 'body', 'report as body is default';
    };
}

done_testing();

sub start_report {
    my $permission = shift;
    $_->delete for $user->user_body_permissions;
    $user->user_body_permissions->create({ body => $body, permission_type => $permission })
        if $permission;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
        PHONE_COUNTRY => 'GB',
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
        PHONE_COUNTRY => 'GB',
    }, sub {
        dropdown_shown(1);
        $mech->submit_form_ok({
            with_fields => \%fields,
        }, "submit details");
    };
    # Anonymous test done as superuser, which redirects
    $mech->content_contains('Thank you for reporting this issue')
        unless $permission eq 'contribute_as_anonymous_user';
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
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
        PHONE_COUNTRY => 'GB',
    }, sub {
        $mech->get_ok('/report/' . $report_to_update->id);
    };
}

sub add_update {
    my ($permission, %fields) = @_;
    start_update($permission);
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
        PHONE_COUNTRY => 'GB',
    }, sub {
        dropdown_shown(1, 'updateForm');
        $mech->submit_form_ok({
            with_fields => \%fields,
        }, "submit details");
    };
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
