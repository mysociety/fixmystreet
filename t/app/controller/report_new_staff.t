use FixMyStreet::TestMech;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my %body_ids;
for my $body (
    { area_id => 2651, name => 'City of Edinburgh Council' },
    { area_id => 2482, name => 'Bromley Council' },
    { area_id => 2237, name => 'Oxfordshire County Council' },
) {
    my $body_obj = $mech->create_body_ok($body->{area_id}, $body->{name});
    $body_ids{$body->{area_id}} = $body_obj->id;
}

# Let's make some contacts to send things to!
$mech->create_contact_ok( body_id => $body_ids{2651}, category => 'Street lighting', email => 'highways@example.com' );
my $edin_trees = $mech->create_contact_ok( body_id => $body_ids{2651}, category => 'Trees', email => 'trees@example.com' );
$mech->create_contact_ok( body_id => $body_ids{2482}, category => 'Trees', email => 'trees@example.com' );
$mech->create_contact_ok( body_id => $body_ids{2237}, category => 'Trees', email => 'trees-2247@example.com' );

my $private_perms = $mech->create_user_ok('private_perms@example.org', name => 'private', from_body => $body_ids{2651});
subtest "report_mark_private allows users to mark reports as private" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        BASE_URL => 'https://www.fixmystreet.com',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_out_ok;

        $private_perms->user_body_permissions->find_or_create({
            body_id => $body_ids{2651},
            permission_type => 'report_mark_private',
        });

        $mech->log_in_ok('private_perms@example.org');
        $mech->get_ok('/');
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
            "submit location" );
        $mech->follow_link_ok(
            { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link"
        );

        my $edin_cats = $mech->create_contact_ok( body_id => $body_ids{2651}, category => 'Cats', email => 'cats@example.com', non_public => 1 );
        $mech->submit_form_ok({
            button => 'submit_category_part_only',
            with_fields => { category => 'Cats' }
        });
        $mech->content_contains('id="form_non_public" value="1" checked disabled');
        $edin_cats->delete;

        $mech->submit_form_ok(
            {
                with_fields => {
                    title         => "Private report",
                    detail        => 'Private report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    may_show_name => '1',
                    phone         => '07903 123 456',
                    category      => 'Trees',
                    non_public    => 1,
                }
            },
            "submit good details"
        );

        $mech->content_contains('Great work. Now spread the word', 'shown confirmation page');
    }
};

my $inspector = $mech->create_user_ok('inspector@example.org', name => 'inspector', from_body => $body_ids{2651});
foreach my $test (
  { non_public => 0 },
  { non_public => 1 },
) {
  subtest "inspectors get redirected directly to the report page, non_public=$test->{non_public}" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        BASE_URL => 'https://www.fixmystreet.com',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_out_ok;

        $inspector->user_body_permissions->find_or_create({
            body_id => $body_ids{2651},
            permission_type => 'planned_reports',
        });
        $inspector->user_body_permissions->find_or_create({
            body_id => $body_ids{2651},
            permission_type => 'report_inspect',
        });

        $mech->log_in_ok('inspector@example.org');
        $mech->get_ok('/');
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB' } },
            "submit location" );
        $mech->follow_link_ok(
            { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link"
        );

        $mech->submit_form_ok(
            {
                with_fields => {
                    title         => "Inspector report",
                    detail        => 'Inspector report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    may_show_name => '1',
                    phone         => '07903 123 456',
                    category      => 'Trees',
                    non_public => $test->{non_public},
                }
            },
            "submit good details"
        );

        like $mech->uri->path, qr/\/report\/[0-9]+/, 'Redirects directly to report';
    }
  };
}

subtest "check map click ajax response for inspector" => sub {
    $mech->log_out_ok;

    my $extra_details;
    $inspector->user_body_permissions->find_or_create({
        body_id => $body_ids{2651},
        permission_type => 'planned_reports',
    });
    $inspector->user_body_permissions->find_or_create({
        body_id => $body_ids{2651},
        permission_type => 'report_inspect',
    });

    $mech->log_in_ok('inspector@example.org');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=55.952055&longitude=-3.189579' );
    };
    like $extra_details->{category}, qr/data-prefill="0/, 'inspector prefill not set';
    ok !$extra_details->{contribute_as}, 'no contribute as section';
};

subtest "check map click ajax response for inspector and uk cobrand" => sub {
    $mech->log_out_ok;

    my $extra_details;
    $inspector->user_body_permissions->find_or_create({
        body_id => $body_ids{2482},
        permission_type => 'planned_reports',
    });
    $inspector->user_body_permissions->find_or_create({
        body_id => $body_ids{2482},
        permission_type => 'report_inspect',
    });

    $mech->log_in_ok('inspector@example.org');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.402096&longitude=0.015784' );
    };
    like $extra_details->{category}, qr/data-prefill="0/, 'inspector prefill not set';
};

for my $test (
    {
        desc => 'map click ajax for contribute_as_another_user',
        permissions => {
            contribute_as_another_user => 1,
            contribute_as_anonymous_user => undef,
            contribute_as_body => undef,
        }
    },
    {
        desc => 'map click ajax for contribute_as_anonymous_user',
        permissions => {
            contribute_as_another_user => undef,
            contribute_as_anonymous_user => 1,
            contribute_as_body => undef,
        }
    },
    {
        desc => 'map click ajax for contribute_as_body',
        permissions => {
            contribute_as_another_user => undef,
            contribute_as_anonymous_user => undef,
            contribute_as_body => 1,
        }
    },
) {
    subtest $test->{desc} => sub {
        $mech->log_out_ok;
        my $extra_details;
        (my $name = $test->{desc}) =~ s/.*(contri.*)/$1/;
        my $user = $mech->create_user_ok("$name\@example.org", name => 'test user', from_body => $body_ids{2651});
        for my $p ( keys %{$test->{permissions}} ) {
            next unless $test->{permissions}->{$p};
            $user->user_body_permissions->find_or_create({
                body_id => $body_ids{2651},
                permission_type => $p,
            });
        }
        $mech->log_in_ok("$name\@example.org");
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'fixmystreet',
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=55.952055&longitude=-3.189579' );
        };
        for my $p ( keys %{$test->{permissions}} ) {
            (my $key = $p) =~ s/contribute_as_//;
            is $extra_details->{contribute_as}->{$key}, $test->{permissions}->{$p}, "$key correctly set";
        }

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'fixmystreet',
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.754926&longitude=-1.256179' );
        };
        ok !$extra_details->{contribute_as}, 'no contribute as section for other council';
    };
}

subtest 'staff-only categories when reporting' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        MAPIT_TYPES => ['UTA'],
    }, sub {
        $inspector->update({ is_superuser => 1 });
        $mech->log_in_ok('inspector@example.org');

        $mech->get_ok('/admin/body/' . $body_ids{2651} . '/Trees');
        $mech->submit_form_ok({ with_fields => { state => 'staff' } }, 'mark Trees as staff-only');
        $edin_trees->discard_changes;
        is $edin_trees->state, 'staff', 'category is staff only';

        $mech->get_ok('/admin/templates/' . $body_ids{2651} . '/new');
        $mech->content_contains('Trees');

        my $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=55.952055&longitude=-3.189579' );
        is_deeply [ sort keys %{$extra_details->{by_category}} ], [ 'Street lighting', 'Trees' ], 'Superuser can see staff-only category';

        $inspector->update({ is_superuser => 0 });
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=55.952055&longitude=-3.189579' );
        is_deeply [ sort keys %{$extra_details->{by_category}} ], [ 'Street lighting', 'Trees' ], 'Body staff user can see staff-only category';

        $inspector->update({ from_body => $body_ids{2482} });
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=55.952055&longitude=-3.189579' );
        is_deeply [ sort keys %{$extra_details->{by_category}} ], [ 'Street lighting' ], 'Different body staff user cannot see staff-only category';

        $mech->log_out_ok;
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=55.952055&longitude=-3.189579' );
        is_deeply [ sort keys %{$extra_details->{by_category}} ], [ 'Street lighting' ], 'Normal user cannot see staff-only category';
    };
};

done_testing;
