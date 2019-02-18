use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $haringey = $mech->create_body_ok(2509, 'Haringey Borough Council');
my $southend = $mech->create_body_ok(2607, 'Southend-on-Sea Borough Council');

$mech->log_in_ok( $superuser->email );

subtest 'search abuse' => sub {
    my $abuse = FixMyStreet::App->model('DB::Abuse')->find_or_create( { email => $user->email } );
    $mech->get_ok( '/admin/users?search=example' );
    $mech->content_like(qr{test\@example.com.*</td>\s*<td>.*?</td>\s*<td>User in abuse table}s);
};

subtest 'remove user from abuse list from edit user page' => sub {
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_contains('User in abuse table');

    $mech->click_ok('unban');

    my $abuse = FixMyStreet::App->model('DB::Abuse')->find( { email => $user->email } );
    ok !$abuse, 'record removed from abuse table';
};

subtest 'remove user with phone account from abuse list from edit user page' => sub {
    my $abuse_user = $mech->create_user_ok('01234 456789');
    my $abuse = FixMyStreet::App->model('DB::Abuse')->find_or_create( { email => $abuse_user->phone } );
    $mech->get_ok( '/admin/users/' . $abuse_user->id );
    $mech->content_contains('User in abuse table');
    my $abuse_found = FixMyStreet::App->model('DB::Abuse')->find( { email => $abuse_user->phone } );
    ok $abuse_found, 'user in abuse table';

    $mech->click_ok('unban');

    $abuse = FixMyStreet::App->model('DB::Abuse')->find( { email => $user->phone } );
    ok !$abuse, 'record removed from abuse table';
};

subtest 'no option to remove user already in abuse list' => sub {
    my $abuse = FixMyStreet::App->model('DB::Abuse')->find( { email => $user->email } );
    $abuse->delete if $abuse;
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_lacks('User in abuse table');
};

subtest 'show flagged entries' => sub {
    $user->flagged( 1 );
    $user->update;

    $mech->get_ok('/admin/flagged');
    $mech->content_contains( $user->email );

    $user->flagged( 0 );
    $user->update;
};

subtest 'user search' => sub {
    $mech->get_ok('/admin/users');
    $mech->get_ok('/admin/users?search=' . $user->name);

    $mech->content_contains( $user->name);
    my $u_id = $user->id;
    $mech->content_like( qr{users/$u_id">Edit</a>} );

    $mech->get_ok('/admin/users?search=' . $user->email);

    $mech->content_like( qr{users/$u_id">Edit</a>} );

    $user->from_body($haringey->id);
    $user->update;
    $mech->get_ok('/admin/users?search=' . $haringey->id );
    $mech->content_contains('Haringey');
};

subtest 'search does not show user from another council' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->get_ok('/admin/users');
        $mech->get_ok('/admin/users?search=' . $user->name);

        $mech->content_contains( "Searching found no users." );

        $mech->get_ok('/admin/users?search=' . $user->email);
        $mech->content_contains( "Searching found no users." );
    };
};

subtest 'user_edit does not show user from another council' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->get('/admin/users/' . $user->id);
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
    };
};

for my $test (
    {
        desc => 'add user - blank form',
        fields => {
            email => '', email_verified => 0,
            phone => '', phone_verified => 0,
        },
        error => ['Please verify at least one of email/phone', 'Please enter a name'],
    },
    {
        desc => 'add user - blank, verify phone',
        fields => {
            email => '', email_verified => 0,
            phone => '', phone_verified => 1,
        },
        error => ['Please enter a valid email or phone number', 'Please enter a name'],
    },
    {
        desc => 'add user - bad email',
        fields => {
            name => 'Norman',
            email => 'bademail', email_verified => 0,
            phone => '', phone_verified => 0,
        },
        error => ['Please enter a valid email'],
    },
    {
        desc => 'add user - bad phone',
        fields => {
            name => 'Norman',
            phone => '01214960000000', phone_verified => 1,
        },
         error => ['Please check your phone number is correct'],
    },
    {
        desc => 'add user - landline',
        fields => {
            name => 'Norman Name',
            phone => '+441214960000',
            phone_verified => 1,
        },
        error => ['Please enter a mobile number'],
    },
    {
        desc => 'add user - good details',
        fields => {
            name => 'Norman Name',
            phone => '+61491570156',
            phone_verified => 1,
        },
    },
) {
    subtest $test->{desc} => sub {
        $mech->get_ok('/admin/users');
        $mech->submit_form_ok( { with_fields => $test->{fields} } );
        if ($test->{error}) {
            $mech->content_contains($_) for @{$test->{error}};
        } else {
            $mech->content_contains('Updated');
        }
    };
}

my %default_perms = (
    "permissions[moderate]" => undef,
    "permissions[planned_reports]" => undef,
    "permissions[report_mark_private]" => undef,
    "permissions[report_edit]" => undef,
    "permissions[report_edit_category]" => undef,
    "permissions[report_edit_priority]" => undef,
    "permissions[report_inspect]" => undef,
    "permissions[report_instruct]" => undef,
    "permissions[report_prefill]" => undef,
    "permissions[contribute_as_another_user]" => undef,
    "permissions[contribute_as_anonymous_user]" => undef,
    "permissions[contribute_as_body]" => undef,
    "permissions[default_to_body]" => undef,
    "permissions[view_body_contribute_details]" => undef,
    "permissions[user_edit]" => undef,
    "permissions[user_manage_permissions]" => undef,
    "permissions[user_assign_body]" => undef,
    "permissions[user_assign_areas]" => undef,
    "permissions[template_edit]" => undef,
    "permissions[responsepriority_edit]" => undef,
    "permissions[category_edit]" => undef,
    trusted_bodies => undef,
);

# Start this section with user having no name
# Regression test for mysociety/fixmystreetforcouncils#250
$user->update({ name => '' });

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    for my $test (
        {
            desc => 'edit user name',
            fields => {
                name => '',
                email => 'test@example.com',
                email_verified => 1,
                body => $haringey->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => undef,
                area_ids => undef,
                %default_perms,
            },
            changes => {
                name => 'Changed User',
            },
            log_count => 1,
            log_entries => [qw/edit/],
        },
        {
            desc => 'edit user email',
            fields => {
                name => 'Changed User',
                email => 'test@example.com',
                email_verified => 1,
                body => $haringey->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => undef,
                area_ids => undef,
                %default_perms,
            },
            changes => {
                email => 'changed@example.com',
            },
            log_count => 2,
            log_entries => [qw/edit edit/],
        },
        {
            desc => 'edit user body',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                email_verified => 1,
                body => $haringey->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => undef,
                area_ids => undef,
                %default_perms,
            },
            changes => {
                body => $southend->id,
            },
            log_count => 3,
            log_entries => [qw/edit edit edit/],
        },
        {
            desc => 'edit user flagged',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                email_verified => 1,
                body => $southend->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => undef,
                area_ids => undef,
                %default_perms,
            },
            changes => {
                flagged => 'on',
            },
            log_count => 4,
            log_entries => [qw/edit edit edit edit/],
        },
        {
            desc => 'edit user remove flagged',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                email_verified => 1,
                body => $southend->id,
                phone => '',
                phone_verified => undef,
                flagged => 'on',
                is_superuser => undef,
                area_ids => undef,
                %default_perms,
            },
            changes => {
                flagged => undef,
            },
            log_count => 4,
            log_entries => [qw/edit edit edit edit/],
        },
        {
            desc => 'edit user add is_superuser',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                email_verified => 1,
                body => $southend->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => undef,
                area_ids => undef,
                %default_perms,
            },
            changes => {
                is_superuser => 'on',
            },
            removed => [
                keys %default_perms,
            ],
            log_count => 5,
            log_entries => [qw/edit edit edit edit edit/],
        },
        {
            desc => 'edit user remove is_superuser',
            fields => {
                name => 'Changed User',
                email => 'changed@example.com',
                email_verified => 1,
                body => $southend->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => 'on',
                area_ids => undef,
            },
            changes => {
                is_superuser => undef,
            },
            added => {
                %default_perms,
            },
            log_count => 5,
            log_entries => [qw/edit edit edit edit edit/],
        },
    ) {
        subtest $test->{desc} => sub {
            $mech->get_ok( '/admin/users/' . $user->id );

            my $visible = $mech->visible_form_values;
            is_deeply $visible, $test->{fields}, 'expected user';

            my $expected = {
                %{ $test->{fields} },
                %{ $test->{changes} }
            };

            $mech->submit_form_ok( { with_fields => $expected } );

            # Some actions cause visible fields to be added/removed
            foreach my $x (@{ $test->{removed} }) {
                delete $expected->{$x};
            }
            if ( $test->{added} ) {
                $expected = {
                    %$expected,
                    %{ $test->{added} }
                };
            }

            $visible = $mech->visible_form_values;
            is_deeply $visible, $expected, 'user updated';

            $mech->content_contains( 'Updated!' );
        };
    }
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    SMS_AUTHENTICATION => 1,
}, sub {
    subtest "Test edit user add verified phone" => sub {
        $mech->get_ok( '/admin/users/' . $user->id );
        $mech->submit_form_ok( { with_fields => {
            phone => '+61491570157',
            phone_verified => 1,
        } } );
        $mech->content_contains( 'Updated!' );
    };

    subtest "Test changing user to an existing one" => sub {
        my $existing_user = $mech->create_user_ok('existing@example.com', name => 'Existing User');
        $mech->create_problems_for_body(2, 2514, 'Title', { user => $existing_user });
        my $count = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id })->count;
        $mech->get_ok( '/admin/users/' . $user->id );
        $mech->submit_form_ok( { with_fields => { email => 'existing@example.com' } }, 'submit email change' );
        is $mech->uri->path, '/admin/users/' . $existing_user->id, 'redirected';
        my $p = FixMyStreet::DB->resultset('Problem')->search({ user_id => $existing_user->id })->count;
        is $p, $count + 2, 'reports merged';
    };

};

$user = $mech->create_user_ok('test@example.com', name => 'Test User');

subtest "Send login email from admin" => sub {
    $mech->email_count_is(0);
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->submit_form_ok(
        {
            button => 'send_login_email'
        },
        "send login email form submitted"
    );

    my $email = $mech->get_email;
    ok $email, "got an email";

    is $email->header('Subject'), "Your FixMyStreet account details",
      "subject is correct";
    is $email->header('To'), $user->email, "to is correct";

    my $link = $mech->get_link_from_email($email);

    my $mech2 = FixMyStreet::TestMech->new;
    $mech2->not_logged_in_ok;
    $mech2->get_ok($link);
    $mech2->logged_in_ok;
    $mech2->log_out_ok;

    $mech->clear_emails_ok;
};

subtest "Send login email from admin for unverified email" => sub {
    $user->update( { email_verified => 0 } );
    $mech->email_count_is(0);
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->submit_form_ok(
        {
            button => 'send_login_email'
        },
        "send login email form submitted"
    );

    my $email = $mech->get_email;
    ok $email, "got an email";

    is $email->header('Subject'), "Your FixMyStreet account details",
      "subject is correct";
    is $email->header('To'), 'test@example.com', "to is correct";

    my $link = $mech->get_link_from_email($email);

    my $mech2 = FixMyStreet::TestMech->new;
    $mech2->not_logged_in_ok;
    $mech2->get_ok($link);
    $mech2->logged_in_ok;

    my $test_user = FixMyStreet::DB->resultset('User')->search({
        email => $user->email
    }, { order_by => [ { -desc => 'id' } ] } );
    $user->discard_changes;

    is $test_user->count, 1, "only one user";
    is $test_user->first->id, $user->id, "User is same";
    ok $user->email_verified, 'email is verified now';
    $mech2->log_out_ok;
    $user->update( { email_verified => 1 } );
};

subtest "Anonymizing user from admin" => sub {
    $mech->create_problems_for_body(4, 2237, 'Title');
    my $count_p = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id })->count;
    my $count_u = FixMyStreet::DB->resultset('Comment')->search({ user_id => $user->id })->count;
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->submit_form_ok({ button => 'anon_everywhere' });
    my $c = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id, anonymous => 1 })->count;
    is $c, $count_p;
    $c = FixMyStreet::DB->resultset('Comment')->search({ user_id => $user->id, anonymous => 1 })->count;
    is $c, $count_u;
};

subtest "Hiding user's reports from admin" => sub {
    my $count_p = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id })->count;
    my $count_u = FixMyStreet::DB->resultset('Comment')->search({ user_id => $user->id })->count;
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->submit_form_ok({ button => 'hide_everywhere' });
    my $c = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id, state => 'hidden' })->count;
    is $c, $count_p;
    $c = FixMyStreet::DB->resultset('Comment')->search({ user_id => $user->id, state => 'hidden' })->count;
    is $c, $count_u;
};

subtest "Logging user out" => sub {
    my $mech2 = FixMyStreet::TestMech->new;
    $mech2->log_in_ok($user->email);
    $mech2->logged_in_ok;

    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->submit_form_ok({ button => 'logout_everywhere' }, 'Logging user out');
    $mech2->not_logged_in_ok;
};

subtest "Removing account from admin" => sub {
    $mech->create_problems_for_body(4, 2237, 'Title');
    my $count_p = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id })->count;
    my $count_u = FixMyStreet::DB->resultset('Comment')->search({ user_id => $user->id })->count;
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->submit_form_ok({ button => 'remove_account' }, 'Removing account');
    my $c = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id, anonymous => 1, name => '' })->count;
    is $c, $count_p, 'All reports anon/nameless';
    $c = FixMyStreet::DB->resultset('Comment')->search({ user_id => $user->id, anonymous => 1, name => '' })->count;
    is $c, $count_u, 'All updates anon/nameless';
    $user->discard_changes;
    is $user->name, '', 'Name gone';
    is $user->password, '', 'Password gone';
    is $user->email, 'removed-' . $user->id . '@example.org', 'Email gone'
};

subtest "can view list of user's alerts" => sub {
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_lacks("User's alerts", 'no list of alerts');

    $mech->create_problems_for_body(1, 2514, 'Title', { user => $user });
    my $p = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id })->first;

    my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create({
        user_id => $user->id,
        alert_type => 'new_updates',
        parameter => $p->id
    });


    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_contains("User's alerts", 'has list of alerts');
    $mech->content_contains($alert->id, 'lists alert');
};

subtest "can edit list of user's alerts" => sub {
    $mech->get_ok( '/admin/users/' . $user->id );

    my $alert = FixMyStreet::DB->resultset('Alert')->search({
        user_id => $user->id,
        alert_type => 'new_updates',
    })->first;

    $mech->content_like(qr[<td>${\$alert->id}</td>\s*<td>new_updates</td>]m, 'alert on page');

    $mech->submit_form_ok( {
        with_fields => {
            'edit_alert[' . $alert->id . ']' => 'disable'
        }
    }, 'disabling alert');

    $alert->discard_changes;
    ok $alert->whendisabled, 'alert disabled';

    $mech->submit_form_ok( {
        with_fields => {
            'edit_alert[' . $alert->id . ']' => 'enable'
        }
    }, 'enabling alert');

    $alert->discard_changes;
    is $alert->whendisabled, undef, 'alert enabled';

    $mech->submit_form_ok( {
        with_fields => {
            'edit_alert[' . $alert->id . ']' => 'delete',
        }
    }, 'deleting alert');

    $mech->content_unlike(qr[<td>${\$alert->id}</td>\s*<td>new_updates</td>]m, 'alert not on page');

    is $user->alerts->count, 0, 'alert deleted';
};

subtest "View timeline" => sub {
    $mech->get_ok('/admin/timeline');
};

done_testing();
