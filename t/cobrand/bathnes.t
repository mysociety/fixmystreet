use Test::MockModule;
use FixMyStreet::TestMech;
use File::Temp 'tempdir';
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::BathNES');
$cobrand->mock('area_types', sub { [ 'UTA' ] });
$cobrand->mock('lookup_site_code', sub { return '12345' });

my $body = $mech->create_body_ok(2551, 'Bath and North East Somerset Council', {
    send_method => 'Open311',
    api_key => 'key',
    endpoint => 'endpoint',
    jurisdiction => 'bathnes',
    cobrand => 'bathnes'
});
my @cats = ('Litter', 'Other', 'Potholes', 'Traffic lights', 'Disabled');
for my $contact ( @cats ) {
   my $c =  $mech->create_contact_ok(body_id => $body->id, category => $contact, email => "$contact\@example.org");
    if ($contact eq 'Disabled') {
        $c->push_extra_fields({
            code => '_fms_disable_',
            'disable_form' => 'true',
            description => 'form_disabled',
        });
        $c->update;
    }
}
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
my $normaluser = $mech->create_user_ok('normaluser@example.com', name => 'Normal User');
$normaluser->update({ phone => "+447123456789" });

my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Potholes', cobrand => 'fixmystreet',
    user => $normaluser, service => 'iOS', extra => {
        _fields => [
            {
                description => 'Width of pothole?',
                name => "width",
                value => "10cm"
            },
            {
                description => 'Depth of pothole?',
                name => "depth",
                value => "25cm"
            },
        ]
    }
});
$mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Traffic lights', cobrand => 'bathnes',
    user => $counciluser, extra => {
        contributed_as => 'body',
        contributed_by => $counciluser->id,
    }
});
$mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Litter', cobrand => 'bathnes',
    user => $normaluser, extra => {
        contributed_as => 'another_user',
        contributed_by => $counciluser->id,
    }
});
$mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Other', cobrand => 'bathnes',
    user => $counciluser, extra => {
        contributed_as => 'anonymous_user',
    }
});

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bathnes' ],
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
}, sub {

subtest 'cobrand displays council name' => sub {
    $mech->get_ok('/');
    $mech->content_like( qr/Bath and North East Somerset\b/ );
};

subtest 'check override contact display name' => sub {
    $mech->log_in_ok( $superuser->email );
    $mech->get_ok("/admin/body/" . $body->id . '/Litter');
    $mech->content_contains('<h1>Litter</h1>');
    $mech->content_contains('extra[display_name]');
    $mech->submit_form_ok({ with_fields => {
        'extra[display_name]' => 'Wittering'
    }});
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_like(qr/Traffic lights<\/option>\s*<option value="Litter">\s*Wittering<\/option>/);
    $mech->content_lacks('Litter</option>');
};

subtest 'extra CSV columns are absent if permission not granted' => sub {
    $mech->log_in_ok( $counciluser->email );

    $mech->get_ok('/dashboard?export=1');

    my @rows = $mech->content_as_csv;
    is scalar @rows, 5, '1 (header) + 4 (reports) = 5 lines';

    is scalar @{$rows[0]}, 21, '21 columns present';

    is_deeply $rows[0],
        [
            'Report ID',
            'Title',
            'Detail',
            'User Name',
            'Category',
            'Created',
            'Confirmed',
            'Acknowledged',
            'Fixed',
            'Closed',
            'Status',
            'Latitude',
            'Longitude',
            'Query',
            'Ward',
            'Easting',
            'Northing',
            'Report URL',
            'Device Type',
            'Site Used',
            'Reported As',
        ],
        'Column headers look correct';

    # And if pre-generated, is the same
    FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
    $mech->get_ok('/dashboard?export=1');
    @rows = $mech->content_as_csv;
    is scalar @rows, 5, '1 (header) + 4 (reports) = 5 lines';
    is scalar @{$rows[0]}, 21, '21 columns present';
};

subtest "Custom CSV fields permission can be granted" => sub {
    $mech->log_in_ok( $superuser->email );

    is $counciluser->user_body_permissions->count, 0, 'counciluser has no permissions';

    $mech->get_ok("/admin/users/" . $counciluser->id);
    $mech->content_contains('Extra columns in CSV export');

    $mech->submit_form_ok( { with_fields => {
        name => $counciluser->name,
        email => $counciluser->email,
        body => $counciluser->from_body->id,
        phone => '',
        flagged => undef,
        "permissions[export_extra_columns]" => 'on',
    } } );

    ok $counciluser->has_body_permission_to("export_extra_columns"), "counciluser has been granted CSV extra fields permission";
};

subtest 'extra CSV columns are present if permission granted' => sub {
    $mech->log_in_ok( $counciluser->email );

    $mech->get_ok('/dashboard?export=1');

    my @rows = $mech->content_as_csv;
    is scalar @rows, 5, '1 (header) + 4 (reports) = 5 lines';

    is scalar @{$rows[0]}, 25, '25 columns present';

    is_deeply $rows[0],
        [
            'Report ID',
            'Title',
            'Detail',
            'User Name',
            'Category',
            'Created',
            'Confirmed',
            'Acknowledged',
            'Fixed',
            'Closed',
            'Status',
            'Latitude',
            'Longitude',
            'Query',
            'Ward',
            'Easting',
            'Northing',
            'Report URL',
            'Device Type',
            'Site Used',
            'Reported As',
            'User Email',
            'User Phone',
            'Staff User',
            'Attribute Data',
        ],
        'Column headers look correct';

    is $rows[1]->[18], 'iOS', 'Device Type shows whether report made via app';
    is $rows[1]->[19], 'fixmystreet', 'Site Used shows cobrand';
    is $rows[1]->[20], '', 'Reported As is empty if not made on behalf of another user/body';
    is $rows[1]->[21], $normaluser->email, 'User email is correct';
    is $rows[1]->[22], '+447123456789', 'User phone number is correct';
    is $rows[1]->[23], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[1]->[24], 'width = 10cm; depth = 25cm', 'Attribute Data is correct';

    is $rows[2]->[18], 'website', 'No device type';
    is $rows[2]->[19], 'bathnes', 'Site Used shows correct cobrand';
    is $rows[2]->[20], 'body', 'Reported As is correct if made on behalf of body';
    is $rows[2]->[21], $counciluser->email, 'User email is correct';
    is $rows[2]->[22], '', 'User phone number is correct';
    is $rows[2]->[23], $counciluser->email, 'Staff User is correct is made on behalf of body';
    is $rows[2]->[24], '', 'Attribute Data is correct';

    is $rows[3]->[18], 'website', 'No device type';
    is $rows[3]->[19], 'bathnes', 'Site Used shows correct cobrand';
    is $rows[3]->[20], 'another_user', 'Reported As is set if reported on behalf of another user';
    is $rows[3]->[21], $normaluser->email, 'User email is correct';
    is $rows[3]->[22], '+447123456789', 'User phone number is correct';
    is $rows[3]->[23], $counciluser->email, 'Staff User is correct if made on behalf of another user';
    is $rows[3]->[24], '', 'Attribute Data is correct';

    is $rows[4]->[18], 'website', 'No device type';
    is $rows[4]->[19], 'bathnes', 'Site Used shows correct cobrand';
    is $rows[4]->[20], 'anonymous_user', 'Reported As is set if reported on behalf of another user';
    is $rows[4]->[21], $counciluser->email, 'User email is correct';
    is $rows[4]->[22], '', 'User phone number is correct';
    is $rows[4]->[23], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[4]->[24], '', 'Attribute Data is correct';

    $mech->get_ok('/dashboard?export=1&updates=1');

    @rows = $mech->content_as_csv;
    is scalar @rows, 1, '1 (header) + 0 (updates)';
    is scalar @{$rows[0]}, 10, '10 columns present';
    is_deeply $rows[0],
        [
            'Report ID', 'Update ID', 'Date', 'Status', 'Problem state',
            'Text', 'User Name', 'Reported As', 'Staff User',
            'User Email',
        ],
        'Column headers look correct';
};

subtest 'report a problem link post-report is not location-specific' => sub {
        $mech->log_in_ok( $normaluser->email );
        $mech->get_ok('/report/new?longitude=-2.364050&latitude=51.386269');
        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test',
                    detail        => 'Detail',
                    photo1        => '',
                    name          => $normaluser->name,
                    may_show_name => '1',
                    phone         => '',
                    category      => 'Other',
                }
            },
            'submit report form ok'
        );
        $mech->content_like(qr/Your reference for this report is (\d+),/);
        like $mech->uri->path, qr{/report/confirmation/(\d+)}, "ended up at the confirmation page";

        my $tree = HTML::TreeBuilder->new_from_content($mech->content());
        my $report_link = $tree->look_down(
            '_tag' => 'li',
            'class' => 'navigation-primary-list__item',
        )->look_down(
            '_tag' => 'a',
            'class' => 'report-a-problem-btn'
        );
        is ($report_link->as_text, 'Report a problem', 'RAP link has correct text');
        is ($report_link->attr('href'), '/', 'report link href should be /');
    }
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bathnes' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

subtest 'geo-located /around is zoomed in further' => sub {
        $mech->get_ok('/around?longitude=-2.364050&latitude=51.386269');
        $mech->content_contains("data-zoom=3");
        $mech->get_ok('/around?longitude=-2.364050&latitude=51.386269&geolocate=1');
        $mech->content_contains("data-zoom=5");
}

};

subtest 'check cobrand correctly reset on each request' => sub {
    FixMyStreet::override_config {
        'ALLOWED_COBRANDS' => [ 'bathnes', 'fixmystreet' ],
    }, sub {
        $mech->log_in_ok( $superuser->email );
        $mech->host('www.fixmystreet.com');
        $mech->get_ok( '/contact?id=' . $problem->id );
        $mech->host('bathnes.fixmystreet.com');
        $mech->get_ok( '/contact?reject=1&id=' . $problem->id );
        $mech->content_contains('Reject report');
    }
};

subtest "staff can't allocate a report to a disabled category" => sub {
    FixMyStreet::override_config {
        'ALLOWED_COBRANDS' => [ 'bathnes' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my ($p) = $mech->create_problems_for_body(1, $body->id, 'Title', {
            areas => ",2551,", category => 'Potholes', cobrand => 'bathnes',
            user => $normaluser, service => 'iOS'
        });
        $mech->log_in_ok( $superuser->email );
        $mech->get_ok('/admin/report_edit/' . $p->id);
        $mech->content_contains('<option value="Disabled" disabled>Disabled (disabled)</option>');
    }
};

my ($confirm_contact) = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Faded road markings',
    email => 'NM_FM',
);

my ($email_contact) = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Replace litter bin',
    email => 'Passthrough-test@example.org',
);

FixMyStreet::override_config {
    STAGING_FLAGS => { send_reports => 1 },
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bathnes',
}, sub {
    subtest "email category emails sent" => sub {
        $mech->clear_emails_ok;
        my @problems = FixMyStreet::DB->resultset('Problem')->search({ })->all;
        for my $problem (@problems) {
            $problem->whensent(DateTime->now);
            $problem->send_state('sent');
            $problem->update;
        };

        my ($confirm_problem) = $mech->create_problems_for_body(1, $body->id, 'Faded road markings', {
            cobrand => 'bathnes',
            category => $confirm_contact->category,
        } );
        my ($email_problem) = $mech->create_problems_for_body(1, $body->id, 'Title', {
            category => $email_contact->category, cobrand => 'bathnes', user => $normaluser
        });

        FixMyStreet::Script::Reports::send();
        is $mech->email_count_is(3), 1, 'Email sent to both contact email and to user for email report, just to user for Confirm report';
        my @emails = $mech->get_email;
        my $email = grep { $_->header('To') eq 'test@example.org' } @emails;
        is $email, 1, "Email address modified to remove Passthrough prefix";
    }
};

done_testing();
