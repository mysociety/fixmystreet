use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');
my $original_user_id = $user->id; # For log later
my $user2 = $mech->create_user_ok('test2@example.com', name => 'Test User 2');
my $user3 = $mech->create_user_ok('test3@example.com', name => 'Test User 3');
my $user4 = $mech->create_user_ok('test4@example.com', name => 'Test User 4');
my $user5 = $mech->create_user_ok('test5@example.com', name => 'Test User 5');

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', {}, { cobrand => 'oxfordshire' });
my $haringey = $mech->create_body_ok(2509, 'Haringey Borough Council');
my $southend = $mech->create_body_ok(2607, 'Southend-on-Sea Borough Council');

$user4->from_body( $oxfordshire->id );
$user4->update;
$user4->user_body_permissions->create( {
    body => $oxfordshire,
    permission_type => 'user_edit',
} );
$user5->from_body( $oxfordshire->id );
$user5->update;
my $occ_role = $user5->roles->create({
    body => $oxfordshire,
    name => 'Role A',
    permissions => ['moderate', 'user_edit'],
});
$user5->add_to_roles($occ_role);

$mech->log_in_ok( $superuser->email );

subtest 'add user to abuse list from edit user page' => sub {
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_lacks('User in abuse table');
    $mech->click_ok('banuser');
    my $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $user->email } );
    ok $abuse, 'record added to abuse table';
};


subtest 'search abuse' => sub {
    $mech->get_ok( '/admin/users?search=example' );
    $mech->content_like(qr{test\@example.com.*</td>\s*<td>.*?</td>\s*<td>User in abuse table}s);
};

subtest 'remove user from abuse list from edit user page' => sub {
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_contains('User in abuse table');

    $mech->click_ok('unban');

    my $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $user->email } );
    ok !$abuse, 'record removed from abuse table';
};

subtest 'remove user with phone account from abuse list from edit user page' => sub {
    my $abuse_user = $mech->create_user_ok('01234 456789');
    my $abuse = FixMyStreet::DB->resultset('Abuse')->find_or_create( { email => $abuse_user->phone } );
    $mech->get_ok( '/admin/users/' . $abuse_user->id );
    $mech->content_contains('User in abuse table');
    my $abuse_found = FixMyStreet::DB->resultset('Abuse')->find( { email => $abuse_user->phone } );
    ok $abuse_found, 'user in abuse table';

    $mech->click_ok('unban');

    $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $user->phone } );
    ok !$abuse, 'record removed from abuse table';
};

subtest 'no option to remove user already in abuse list' => sub {
    my $abuse = FixMyStreet::DB->resultset('Abuse')->find( { email => $user->email } );
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

my $role;
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
    $role = $user->roles->create({
        body => $haringey,
        name => 'Role A',
        permissions => ['moderate', 'user_edit'],
    });
    $user->add_to_roles($role);
    $mech->get_ok('/admin/users?role=' . $role->id);
    $mech->content_contains('selected>Role A');
    $mech->content_contains('test@example.com');
};

subtest 'user assign role' => sub {
    $user->remove_from_roles($role);
    is $user->roles->count, 0;
    $mech->get_ok('/admin/users');
    $mech->submit_form_ok({ with_fields => { uid => $user->id, roles => $role->id } });
    is $user->roles->count, 1;
};

subtest 'remove users from staff' => sub {
    is $user4->from_body->id, $oxfordshire->id, 'user4 has a body';
    is $user4->email_verified, 1, 'user4 email is verified';
    is $user4->user_body_permissions->count, 1, 'user4 has permissions';
    is $user5->from_body->id, $oxfordshire->id, 'user5 has a body';
    is $user5->email_verified, 1, 'user5 email is verified';
    is $user5->user_roles->count, 1, 'user5 has a role';

    $mech->get_ok('/admin/users');
    $mech->content_contains($user4->email);
    $mech->content_contains($user5->email);

    $mech->submit_form_ok({ with_fields => { uid => $user4->id, 'remove-staff' => 'remove-staff'} });
    $mech->content_lacks($user4->email);
    $mech->content_contains($user5->email);
    $user4->discard_changes;
    $user5->discard_changes;
    is $user4->from_body, undef, 'user4 removed from body';
    is $user4->email_verified, 0, 'user4 email unverified';
    is $user4->user_body_permissions->count, 0, 'no user4 permissions';
    is $user5->from_body->id, $oxfordshire->id, 'user5 has a body';
    is $user5->email_verified, 1, 'user5 email is verified';
    is $user5->user_roles->count, 1, 'user5 has a role';

    $mech->submit_form_ok({ with_fields => { uid => $user5->id, 'remove-staff' => 'remove-staff'} });
    $mech->content_lacks($user5->email);
    $user5->discard_changes;
    is $user5->from_body, undef, 'user5 has no body';
    is $user5->email_verified, 0, 'user5 email unverified';
    is $user5->user_roles->count, 0, 'no user5 roles';
};

subtest 'search does not show user from another council' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $superuser->update({ from_body => $oxfordshire->id });
        $mech->get_ok('/admin/users');
        $mech->content_lacks('Super User');
        $superuser->update({ from_body => undef });

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

$mech->log_out_ok;

subtest 'user_edit redirects appropriately' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $user2->update({ from_body => $oxfordshire->id });
        $user3->update({ from_body => $oxfordshire->id });
        $user3->user_body_permissions->create( {
            body => $oxfordshire,
            permission_type => 'user_edit',
        } );
        $user3->user_body_permissions->create( {
            body => $oxfordshire,
            permission_type => 'user_assign_body',
        } );
        $mech->log_in_ok( $user3->email );

        $mech->get_ok('/admin/users/' . $user2->id);
        $mech->submit_form_ok( { with_fields => {
            name => "Updated Name"
        } } );
        $user2->discard_changes;
        is $user2->name, "Updated Name", "Name set correctly";
        is $mech->uri->path, '/admin/users/' . $user2->id, 'redirected back to user form';

        $mech->get_ok('/admin/users/' . $user2->id);
        $mech->submit_form_ok( { with_fields => {
            body => undef
        } } );
        $user2->discard_changes;
        is $user2->from_body, undef, "from_body unset";
        is $mech->uri->path, '/admin/users', 'redirected back to users list';

        $mech->log_out_ok;
    };
};

subtest 'user categories are cleared when from_body is unset' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_in_ok( $user3->email );

        my $cat1 = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );
        my $cat2 = $mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
        $user2->set_extra_metadata('categories', [ $cat1->id, $cat2->id ]);
        $user2->from_body($oxfordshire->id);
        $user2->update;

        $mech->get_ok('/admin/users/' . $user2->id);
        $mech->submit_form_ok( { with_fields => {
            body => undef
        } } );

        $user2->discard_changes;
        is $user2->from_body, undef, "from_body unset";
        is $user2->get_extra_metadata('categories'), undef, "categories unset";
    };
};

$mech->log_in_ok( $superuser->email );

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
        $mech->content_contains('Norman') if $test->{fields}{name};
        if ($test->{error}) {
            $mech->content_contains($_) for @{$test->{error}};
        } else {
            $mech->content_contains('Updated');
        }
    };
}

{
    note 'Staff user for a council:';

    my $config = {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    };

    my $oxfordshireuser = $mech->create_user_ok(
        'counciluser@example.com',
        name => 'Council User',
        from_body => $oxfordshire,
    );
    $mech->log_in_ok( $oxfordshireuser->email );

    $oxfordshireuser->user_body_permissions->create({
        body => $oxfordshire,
        permission_type => 'user_edit',
    });

    subtest 'add user - body not explicitly provided' => sub {
        FixMyStreet::override_config $config, sub {
            $mech->get_ok('/admin/users');
            $mech->submit_form_ok( { with_fields => {
                name => 'No Body',
                email => 'nobody@email.com',
                email_verified => 1,
            } } );

            $mech->base_like(qr{/admin/users/\d+},
                'should redirect to /admin/users/<id>');

            # Check if user appears in list
            $mech->get_ok('/admin/users');
            $mech->content_contains(
                'No Body',
                'user should appear in /admin/users list',
            );
        };
    };

    my $test_body_user = $mech->create_user_ok(
        'bod@gmail.com',
        name => 'Bod Acious',
    );

    subtest 'add existing user who does not have a body' => sub {
        FixMyStreet::override_config $config, sub {
            is $test_body_user->from_body, undef,
                'check user does not have body initially';

            $mech->get_ok('/admin/users');
            $mech->content_lacks(
                $test_body_user->email,
                'check user is not in /admin/users list initially',
            );

            $mech->submit_form_ok( { with_fields => {
                name => $test_body_user->name,
                email => $test_body_user->email,
                email_verified => 1,
            } }, "should submit 'add user' form" );

            $mech->base_like(qr{/admin/users/\d+},
                'should redirect to /admin/users/<id>');

            # Check if user appears in list
            $mech->get_ok('/admin/users');
            $mech->content_contains(
                $test_body_user->email,
                'user should appear in /admin/users list',
            );

            $test_body_user->discard_changes;
            is $test_body_user->from_body->id, $oxfordshire->id,
                'user should be assigned to a body';
        };
    };

    subtest 'add existing user who has a body' => sub {
        FixMyStreet::override_config $config, sub {
            $mech->get_ok('/admin/users');
            $mech->content_contains(
                $test_body_user->email,
                'check user is in /admin/users list initially',
            );

            $mech->submit_form_ok( { with_fields => {
                name => $test_body_user->name,
                email => $test_body_user->email,
                email_verified => 1,
            } }, "should submit 'add user' form" );

            $mech->base_like(qr{/admin/users/add},
                'should redirect to /admin/users/add');
            $mech->content_contains('User already exists',
                'should display existence error');
        };
    };

    subtest 'remove staff status from user' => sub {
        FixMyStreet::override_config $config, sub {
            $oxfordshireuser->user_body_permissions->create(
                {   body            => $oxfordshire,
                    permission_type => 'user_assign_body',
                }
            );

            $mech->get_ok( '/admin/users/' . $test_body_user->id );

            $mech->submit_form_ok(
                { with_fields => { body => undef } },
                'should submit "edit user" form',
            );
            $mech->base_like( qr{/admin/users},
                'should redirect to /admin/users' );

            $mech->content_lacks( $test_body_user->email,
                'user should no longer be in /admin/users list' );

            # Refresh user object by fetching data from DB
            $test_body_user = $mech->create_user_ok( $test_body_user->email );
            is $test_body_user->from_body, undef,
                'user should no longer have body';
        };
    };


    # Revert changes
    $mech->log_in_ok( $superuser->email );
}

my %default_perms = (
    "permissions[moderate]" => 'on',
    "permissions[planned_reports]" => undef,
    "permissions[report_mark_private]" => undef,
    "permissions[report_edit]" => undef,
    "permissions[report_edit_category]" => undef,
    "permissions[report_edit_priority]" => undef,
    "permissions[report_inspect]" => undef,
    "permissions[report_instruct]" => undef,
    "permissions[assign_report_to_user]" => undef,
    "permissions[report_prefill]" => undef,
    "permissions[contribute_as_another_user]" => undef,
    "permissions[contribute_as_anonymous_user]" => undef,
    "permissions[contribute_as_body]" => undef,
    "permissions[default_to_body]" => undef,
    "permissions[view_body_contribute_details]" => undef,
    "permissions[user_edit]" => 'on',
    "permissions[user_manage_permissions]" => undef,
    "permissions[user_assign_body]" => undef,
    "permissions[user_assign_areas]" => undef,
    "permissions[template_edit]" => undef,
    "permissions[responsepriority_edit]" => undef,
    "permissions[category_edit]" => undef,
    "permissions[emergency_message_edit]" => undef,
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
                email => $user->email,
                email_verified => 1,
                body => $haringey->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => undef,
                area_ids => undef,
                assigned_categories_only => undef,
                %default_perms,
                roles => $role->id,
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
                email => $user->email,
                email_verified => 1,
                body => $haringey->id,
                phone => '',
                phone_verified => undef,
                flagged => undef,
                is_superuser => undef,
                area_ids => undef,
                assigned_categories_only => undef,
                %default_perms,
                roles => $role->id,
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
                assigned_categories_only => undef,
                %default_perms,
                roles => $role->id,
            },
            changes => {
                body => $southend->id,
            },
            removed => [
                'roles',
            ],
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
                assigned_categories_only => undef,
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
                assigned_categories_only => undef,
                %default_perms,
            },
            changes => {
                flagged => undef,
            },
            log_count => 4,
            log_entries => [qw/edit edit edit edit/],
        },
        {
            desc => 'edit user add is_superuser and assigned_categories_only',
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
                assigned_categories_only => undef,
                %default_perms,
            },
            changes => {
                is_superuser => 'on',
                assigned_categories_only => 'on',
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
                assigned_categories_only => 'on',
            },
            changes => {
                is_superuser => undef,
            },
            added => {
                %default_perms,
                'permissions[moderate]' => undef,
                'permissions[user_edit]' => undef,
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

    subtest "Test edit user name with phone number unchanged who has verified landline" => sub {
        my $existing_user = $mech->create_user_ok('existing@example.com', name => 'Existing User', phone => '01184960017', phone_verified => 1 );
	$mech->get_ok( '/admin/users/' . $existing_user->id );
	$mech->submit_form_ok( { with_fields => {
            name => 'Existing E. User',
        } } );
	$mech->content_contains( 'Updated!' );
    };

    subtest "Test edit user change phone number who has verified landline" => sub {
        my $existing_user = $mech->create_user_ok('existing@example.com', name => 'Existing User', phone => '01184960017', phone_verified => 1 );
	$mech->get_ok( '/admin/users/' . $existing_user->id );
	$mech->submit_form_ok( { with_fields => {
            phone => '01184960018',
	} } );
	$mech->content_lacks( 'Updated!' );
	$mech->content_contains( 'Please check your phone number is correct' );
    };



    subtest "Test changing user to an existing one" => sub {
        my $existing_user = $mech->create_user_ok('existing@example.com', name => 'Existing User');
        $mech->create_problems_for_body(2, 2514, 'Title', { user => $existing_user });
        my $count = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id })->count;
        $mech->get_ok( '/admin/users/' . $user->id );
        $mech->submit_form_ok( { with_fields => { email => $existing_user->email } }, 'submit email change' );
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
    is $email->header('To'), $user->email, "to is correct";

    my $link = $mech->get_link_from_email($email);

    my $mech2 = FixMyStreet::TestMech->new;
    $mech2->not_logged_in_ok;
    $mech2->get_ok($link);
    $mech2->logged_in_ok;

    my $test_user = FixMyStreet::DB->resultset('User')->search({
        email => $user->email
    })->order_by('-id');
    $user->discard_changes;

    is $test_user->count, 1, "only one user";
    is $test_user->first->id, $user->id, "User is same";
    ok $user->email_verified, 'email is verified now';
    $mech2->log_out_ok;
    $user->update( { email_verified => 1 } );
};

subtest "Anonymizing user from admin" => sub {
    my ($problem) = $mech->create_problems_for_body(4, 2237, 'Title');
    $mech->create_comment_for_problem($problem, $user, $user->name, 'An update', 'f', 'confirmed', 'confirmed');
    $mech->create_comment_for_problem($problem, $user, $user->name, '2nd update', 't', 'confirmed', 'fixed - user');
    $mech->create_comment_for_problem($problem, $user, $user->name, '3rd update', 'f', 'unconfirmed', 'confirmed');
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

subtest "Hiding user with only unconfirmed updates does not error" => sub {
    FixMyStreet::DB->resultset('Comment')->search({ user_id => $user->id, state => 'hidden' })->update({ state => 'unconfirmed' });
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->submit_form_ok({ button => 'hide_everywhere' });
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
    is $user->email, 'removed-' . $user->id . '@example.org', 'Email gone';
    $mech->get_ok( '/admin/report_edit/' . $user->problems->first->id );
    $mech->content_contains("name='username' value=''>");
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

subtest "can view pagination on list of user's alerts" => sub {
    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_lacks("User's alerts", 'no list of alerts');

    my @problems = $mech->create_problems_for_body(110, 2514, 'Title', { user => $user });

    my $alert;
    foreach my $p ( @problems ) {
        $alert = FixMyStreet::DB->resultset('Alert')->create({
            user_id => $user->id,
            alert_type => 'new_updates',
            parameter => $p->id
        });
    }
    my $first_alert = $user->alerts->first;
    my $last_alert = $alert;
    $last_alert->update({ whensubscribed => DateTime->now->add(minutes => 5) });

    $mech->get_ok( '/admin/users/' . $user->id );
    $mech->content_contains("User's alerts", 'has list of alerts');
    $mech->content_contains("1 to 100 of 110", 'has pagination bar');
    $mech->content_like(qr[<td>${\$first_alert->id}</td>\s*<td>new_updates</td>]m, 'first alert on page');
    $mech->content_unlike(qr[<td>${\$last_alert->id}</td>\s*<td>new_updates</td>]m, 'last alert not on page');

    $mech->get_ok( '/admin/users/' . $user->id . '?p=2' );
    $mech->content_contains("User's alerts", 'has list of alerts');
    $mech->content_contains("101 to 110 of 110", 'has pagination bar');
    $mech->content_unlike(qr[<td>${\$first_alert->id}</td>\s*<td>new_updates</td>]m, 'first alert not on page');
    $mech->content_like(qr[<td>${\$last_alert->id}</td>\s*<td>new_updates</td>]m, 'last alert on page');

    $user->alerts->delete_all;
};


subtest "View timeline" => sub {
    $mech->get_ok('/admin/timeline');
};

subtest 'View user log' => sub {
    my $p = FixMyStreet::DB->resultset('Problem')->search({ user_id => $user->id })->first;
    $user->add_to_planned_reports($p);

    # User 1 created all the reports
    my $id = $p->id;
    $mech->get_ok('/admin/users?search=' . $user->email);
    $mech->follow_link_ok({ text => 'Timeline', n => 2 });
    $mech->content_like(qr/Problem.*?>$id<\/a> created/);
    $mech->content_like(qr/Problem.*?>$id<\/a> added to shortlist/);

    # User 3 edited user 2 above
    $mech->get_ok('/admin/users/' . $user3->id . '/log');
    $mech->content_like(qr/Edited user.*?test2\@example/);

    # Superuser added a user, and merged one
    $mech->get_ok('/admin/users/' . $superuser->id . '/log');
    $mech->content_like(qr/Added user.*?0156/);
    $mech->content_like(qr/Merged user $original_user_id/);
};

done_testing();
