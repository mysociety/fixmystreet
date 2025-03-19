use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use Test::MockTime ':all';

package FixMyStreet::Cobrand::No2FA;
use parent 'FixMyStreet::Cobrand::FixMyStreet';
sub must_have_2fa { 0 }

package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::Default';
# Allow access if CSV export for a body, otherwise deny
sub dashboard_permission {
    my $self = shift;
    my $c = $self->{c};
    return 0 unless $c->get_param('export');
    return $c->get_param('body') || 0;
}

package main;

use FixMyStreet::TestMech;
use File::Temp 'tempdir';
use Path::Tiny;
use Web::Scraper;

set_absolute_time('2014-02-01T12:00:00');

my $mech = FixMyStreet::TestMech->new;

my $other_body = $mech->create_body_ok(1234, 'Some Other Council');
my $body = $mech->create_body_ok(2651, 'City of Edinburgh Council');
my @cats = ('Litter', 'Other', 'Potholes', 'Traffic lights & bells', 'White lines');
for my $contact ( @cats ) {
    my $c = $mech->create_contact_ok(body_id => $body->id, category => $contact, email => "$contact\@example.org");
    if ($contact eq 'Potholes' || $contact eq 'White lines') {
        $c->set_extra_metadata(group => ['Road & more', 'Pavements']);
        $c->update;
    }
}

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $body,
    name => 'Role A',
    permissions => ['report_inspect', 'planned_reports'],
});
$counciluser->add_to_roles($role);
my $normaluser = $mech->create_user_ok('normaluser@example.com', name => 'Normal User');

my $body_id = $body->id;
my $area_id = '60705';
my $alt_area_id = '62883';
my $old_area_id = '58805';

my $last_month = DateTime->now->subtract(months => 2);
$mech->create_problems_for_body(2, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Potholes', cobrand => 'no2fat' });
$mech->create_problems_for_body(3, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Traffic lights & bells', cobrand => 'no2fa', dt => $last_month });
$mech->create_problems_for_body(1, $body->id, 'Title', { areas => ",$alt_area_id,2651,", category => 'Litter', cobrand => 'no2fa' });
$mech->create_problems_for_body(1, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'White lines', cobrand => 'no2fat' });

my @scheduled_problems = $mech->create_problems_for_body(7, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Traffic lights & bells', cobrand => 'no2fa' });
my @fixed_problems = $mech->create_problems_for_body(4, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Potholes', cobrand => 'no2fa' });
my @closed_problems = $mech->create_problems_for_body(3, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Traffic lights & bells', cobrand => 'no2fa' });

my $first_problem_id;
my $first_update_id;
foreach my $problem (@scheduled_problems) {
    $problem->update({ state => 'action scheduled' });
    my ($update) = $mech->create_comment_for_problem($problem, $counciluser, 'Title', 'text', 0, 'confirmed', 'action scheduled');
    $first_problem_id = $problem->id unless $first_problem_id;
    $first_update_id = $update->id unless $first_update_id;
}

foreach my $problem (@fixed_problems) {
    $problem->set_extra_metadata(contributed_by => $counciluser->id);
    $problem->update({ state => 'fixed - council' });
    $mech->create_comment_for_problem($problem, $counciluser, 'Title', 'text', 0, 'confirmed', 'fixed');
}

foreach my $problem (@closed_problems) {
    $problem->update({ state => 'closed' });
    $mech->create_comment_for_problem($problem, $counciluser, 'Name', 'in progress text', 0, 'confirmed', 'in progress');
    $mech->create_comment_for_problem($problem, $counciluser, 'Title', 'text', 0, 'confirmed', 'closed');
}

my $categories = scraper {
    process "select[name=category] option", 'cats[]' => 'TEXT',
    process "table[id=overview] > tr", 'rows[]' => scraper {
        process 'td', 'cols[]' => 'TEXT'
    },
    process 'th[scope=colgroup]', 'top_level[]' => 'TEXT'
};

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'no2fa',
    COBRAND_FEATURES => { category_groups => { no2fa => 1 } },
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
}, sub {

    subtest 'not logged in, redirected to login' => sub {
        $mech->not_logged_in_ok;
        $mech->get_ok('/dashboard');
        $mech->content_contains( 'sign in' );
    };

    subtest 'normal user, 404' => sub {
        $mech->log_in_ok( $normaluser->email );
        $mech->get('/dashboard');
        is $mech->status, '404', 'If not council user get 404';
    };

    subtest 'superuser, body list' => sub {
        $mech->log_in_ok( $superuser->email );
        $mech->get_ok('/dashboard');
        # Contains body name, in list of bodies
        $mech->content_contains('Some Other Council');
        $mech->content_contains('Edinburgh Council');
        $mech->content_lacks('Category:');
        $mech->get_ok('/dashboard?body=' . $body->id);
        $mech->content_lacks('Some Other Council');
        $mech->content_contains('Edinburgh Council');
        $mech->content_contains('Trowbridge');
        $mech->content_contains('Category:');
    };

    subtest 'council user, ward list' => sub {
        $mech->log_in_ok( $counciluser->email );
        $mech->get_ok('/dashboard');
        $mech->content_lacks('Some Other Council');
        $mech->content_contains('Edinburgh Council');
        $mech->content_contains('Trowbridge');
        $mech->content_contains('Category:');
    };

    subtest 'area user can only see their area' => sub {
        $counciluser->update({area_ids => [ $area_id ]});

        $mech->get_ok("/dashboard");
        $mech->content_contains('<h1>Trowbridge</h1>');
        $mech->get_ok("/dashboard?body=" . $other_body->id);
        $mech->content_contains('<h1>Trowbridge</h1>');
        $mech->get_ok("/dashboard?ward=$alt_area_id");
        $mech->content_contains('<h1>Trowbridge</h1>');

        $counciluser->update({area_ids => [ $area_id, $alt_area_id ]});
        $mech->get_ok("/dashboard");
        $mech->content_contains('<h1>Bradford-on-Avon / Trowbridge</h1>');

        $counciluser->update({area_ids => undef});
    };

    subtest 'The correct categories and totals shown by default' => sub {
        $mech->get_ok("/dashboard");
        my $expected_cats = [ 'Litter', 'Other', 'Traffic lights & bells', 'All Pavements', 'Potholes', 'White lines', 'All Road & more', 'Potholes', 'White lines' ];
        my $res = $categories->scrape( $mech->content );
        $mech->content_contains('<optgroup label="Road &amp; more">');
        $mech->content_contains('<option value="group-Road &amp; more"');
        is_deeply( $res->{cats}, $expected_cats, 'correct list of categories' );
        # Three missing as more than a month ago
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 7, 3, 0, 10, 2, 0, 4, 6, 1, 0, 0, 1, 11, 3, 4, 18);
    };

    subtest 'test filters' => sub {
        $mech->get_ok("/dashboard");
        $mech->submit_form_ok({ with_fields => { category => 'Litter' } });
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1);
        $mech->submit_form_ok({ with_fields => { category => '', state => 'fixed - council' } });
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0, 0, 4, 4);
        $mech->submit_form_ok({ with_fields => { state => 'action scheduled' } });
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7);
        my $start = DateTime->now->subtract(months => 3)->strftime('%Y-%m-%d');
        my $end = DateTime->now->subtract(months => 1)->strftime('%Y-%m-%d');
        $mech->submit_form_ok({ with_fields => { state => '', start_date => $start, end_date => $end } });
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 3);
        $mech->get_ok("/dashboard?category=Litter-group-&category=Potholes-group-");
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 4, 6, 0, 0, 0, 0, 3, 0, 4, 7);
        $mech->get_ok("/dashboard?category=Traffic+lights+%26+bells-group-");
        $mech->content_contains("<option value='Traffic lights &amp; bells-group-' selected>");
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 7, 3, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 7, 3, 0, 10);
        $mech->get_ok("/dashboard?category=group-Road+%26+more");
        $mech->content_contains('<option value="group-Road &amp; more" selected>');
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 4, 6, 1, 0, 0, 1, 3, 0, 4, 7);
        $mech->get_ok("/dashboard?category=group-Road+%26+more&category=Potholes-group-");
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 4, 6, 1, 0, 0, 1, 3, 0, 4, 7);
        $mech->get_ok("/dashboard?category=group-Road+%26+more&category=Litter-group-");
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 4, 6, 1, 0, 0, 1, 4, 0, 4, 8);
        my ($sub_pothole_pavement) = $mech->create_problems_for_body(1, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Potholes', cobrand => 'no2fat' });
        $sub_pothole_pavement->set_extra_metadata( group => 'Pavements');
        $sub_pothole_pavement->update;
        $mech->get_ok("/dashboard?category=group-Road+%26+more&category=Litter-group-");
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 4, 6, 1, 0, 0, 1, 4, 0, 4, 8);
        my ($sub_pothole_road) = $mech->create_problems_for_body(1, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Potholes', cobrand => 'no2fat' });
        $sub_pothole_road->set_extra_metadata( group => 'Road & more');
        $sub_pothole_road->state('closed');
        $sub_pothole_road->update;
        $mech->get_ok("/dashboard?category=group-Road+%26+more&category=Litter-group-");
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 2, 0, 4, 6, 1, 0, 0, 1, 4, 1, 4, 9);
        $sub_pothole_pavement->delete;
        $sub_pothole_road->delete;
    };

    subtest 'test grouping' => sub {
        my $contacts = FixMyStreet::DB->resultset('Contact')->search( { body_id => $body->id } );
        while (my $contact = $contacts->next) {
            if ($contact->category eq 'Potholes' || $contact->category eq 'White lines') {
                $contact->set_extra_metadata(group => ['Road & more']);
                $contact->update;
            }
        }
        $mech->get_ok("/dashboard?group_by=category");
        my $top_level = test_table($mech->content, 1, 0, 10, 6, 1, 18);
        is_deeply $top_level, ['Road & more'], 'Road group created';
        $mech->get_ok("/dashboard?group_by=state");
        test_table($mech->content, 4, 7, 4, 3, 18);
        $mech->get_ok("/dashboard?start_date=2000-01-01&group_by=month");
        test_table($mech->content, 0, 18, 18, 3, 0, 3, 3, 18, 21);
        my $pothole = FixMyStreet::DB->resultset('Contact')->find_or_create({ category => 'Potholes'});
        $pothole->set_extra_metadata(group => ['Road & more', 'Pavement']);
        $pothole->update;
        $mech->get_ok("/dashboard?group_by=category");
        $top_level = test_table($mech->content, 1, 0, 10, 1, 6, 18);
        is_deeply $top_level, ['Road & more', 'Multiple'], 'Road and Multiple groups created';
        $pothole->set_extra_metadata(group => ['Road & more']);
        $pothole->update;
    };

    subtest 'test roles' => sub {
        # All the fixed (Pothole) reports only
        $mech->get_ok("/dashboard?group_by=category&role=" . $role->id);
        test_table($mech->content, 0, 0, 0, 4, 0, 4);
        $mech->get_ok("/dashboard?export=2&group_by=category&role=" . $role->id);
        $mech->content_contains('role-' . $role->id, "File link created with role");
    };

    subtest 'csv for multiple categories' => sub {
        $mech->get_ok("/dashboard?category=Litter&category=Potholes&export=2");
        $mech->content_contains('www.example.org-body-' . $body->id . '-category-Litter,Potholes-start_date-2014-01-02.csv');
        $mech->get_ok("/dashboard?category=Litter&category=Potholes&category=Traffic+lights+%26+bells&export=2");
        $mech->content_contains('www.example.org-body-' . $body->id . '-category-multiple-categories-start_date-2014-01-02.csv');
        $mech->get_ok("/dashboard?category=Litter&category=Potholes&export=1");
        my @rows = $mech->content_as_csv;
        is scalar @rows, 8, '1 (header) + 7 (reports) found = 8 lines';
        $mech->get_ok("/dashboard?category=group-Road+%26+more&export=1");
        @rows = $mech->content_as_csv;
        is scalar @rows, 8, '1 (header) + 7 (reports) found = 8 lines';
        $mech->get_ok("/dashboard?category=group-Road+%26+more&category=Potholes&export=1");
        @rows = $mech->content_as_csv;
        is scalar @rows, 8, '1 (header) + 7 (reports) found = 8 lines';
        $mech->get_ok("/dashboard?category=group-Road+%26+more&category=Litter&export=1");
        @rows = $mech->content_as_csv;
        is scalar @rows, 9, '1 (header) + 8 (reports) found = 9 lines';
    };

    subtest 'export as csv' => sub {
        $mech->create_problems_for_body(1, $body->id, 'Title', {
            detail => "this report\nis split across\nseveral lines",
            category => 'Problem one',
            areas => ",$old_area_id,2651,",
        });
        $mech->get_ok('/dashboard?export=1');
        my @rows = $mech->content_as_csv;
        is scalar @rows, 20, '1 (header) + 19 (reports) = 20 lines';

        is scalar @{$rows[0]}, 22, '22 columns present';

        is_deeply $rows[0],
            [
                'Report ID',
                'Title',
                'Detail',
                'User Name',
                'Category',
                'Subcategory',
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

        is $rows[5]->[15], 'Trowbridge', 'Ward column is name not ID';
        is $rows[5]->[16], '529025', 'Correct Easting conversion';
        is $rows[5]->[17], '179716', 'Correct Northing conversion';
        is $rows[19]->[15], 'Bishops Cannings', 'Can see old ward';
    };

    subtest 'export updates as csv' => sub {
        $mech->get_ok('/dashboard?updates=1&export=1');
        my @rows = $mech->content_as_csv;
        is scalar @rows, 18, '1 (header) + 17 (updates) = 18 lines';
        is scalar @{$rows[0]}, 8, '8 columns present';

        is_deeply $rows[0],
            [
                'Report ID', 'Update ID', 'Date', 'Status', 'Problem state',
                'Text', 'User Name', 'Reported As',
            ],
            'Column headers look correct';

        is $rows[1]->[0], $first_problem_id, 'Correct report ID';
        is $rows[1]->[1], $first_update_id, 'Correct update ID';
        is $rows[1]->[3], 'confirmed', 'Correct state';
        is $rows[1]->[4], 'action scheduled', 'Correct problem state';
        is $rows[1]->[5], 'text', 'Correct text';
        is $rows[1]->[6], 'Title', 'Correct name';
    };

    subtest 'export as csv using token' => sub {
        $mech->log_out_ok;

        my $u = FixMyStreet::DB->resultset("User")->new({ password => '1234567890abcdefgh' });
        $counciluser->set_extra_metadata('access_token', $u->password);
        $counciluser->update();

        $mech->get_ok('/dashboard?export=1');
        like $mech->res->header('Content-type'), qr'text/html';
        $mech->content_lacks('Report ID');

        $mech->add_header('Authorization', 'Bearer ' . $counciluser->id . '-1234567890abcdefgh');
        $mech->get_ok('/dashboard?export=1');
        like $mech->res->header('Content-type'), qr'text/csv';
        $mech->content_contains('Report ID');
        $mech->delete_header('Authorization');

        my $token = 'access_token=' . $counciluser->id . '-1234567890abcdefgh';
        $mech->get_ok("/dashboard?export=2&$token");
        is $mech->res->code, 202;
        my $loc = $mech->res->header('Location');
        like $loc, qr{/dashboard/csv/.*\.csv$};
        $mech->get_ok("$loc?$token");
        like $mech->res->header('Content-type'), qr'text/csv';
        $mech->content_contains('Report ID');
    };

    subtest 'export CSV with slash in category name' => sub {
        $mech->create_contact_ok(body_id => $body->id, category => "This/That", email => "this\@example.org");
        my $token = 'access_token=' . $counciluser->id . '-1234567890abcdefgh';
        $mech->get_ok("/dashboard?export=2&$token&category=This/That");
    };

    subtest 'view status page' => sub {
        # Simulate a partly done file
        my $f = Path::Tiny->tempfile(SUFFIX => '.csv-part', DIR => path($UPLOAD_DIR, 'dashboard_csv', $counciluser->id));
        (my $name = $f->basename) =~ s/-part$//;;

        my $token = 'access_token=' . $counciluser->id . '-1234567890abcdefgh';
        $mech->get_ok("/dashboard/csv/$name?$token");
        is $mech->res->code, 202;

        $mech->log_in_ok( $counciluser->email );
        $mech->get_ok('/dashboard/status');
        $mech->content_contains('/dashboard/csv/www.example.org-body-' . $body->id . '-start_date-2014-01-02.csv');
        $mech->content_like(qr/$name\s*<br>0KB\s*<i>In progress/);

        $f->remove;
        $mech->get_ok('/dashboard/status');
        $mech->content_contains('/dashboard/csv/www.example.org-body-' . $body->id . '-start_date-2014-01-02.csv');
        $mech->content_lacks('In progress');
        $mech->content_lacks('setTimeout');
    }
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'tester',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
}, sub {
    subtest 'no body or export, 404' => sub {
        $mech->get('/dashboard');
        is $mech->status, '404', 'No parameters, 404';
        $mech->get('/dashboard?export=1');
        is $mech->status, '404', 'If no body, 404';
        $mech->get("/dashboard?body=$body_id");
        is $mech->status, '404', 'If no export, 404';
    };

    subtest 'body and export, okay' => sub {
        $mech->get_ok("/dashboard?body=$body_id&export=1");
    };
};

sub test_table {
    my ($content, @expected) = @_;

    my $res = $categories->scrape( $mech->content );
    my @actual;
    foreach my $row ( @{ $res->{rows} }[1 .. 11] ) {
        push @actual, @{$row->{cols}} if $row->{cols};
    }
    is_deeply \@actual, \@expected;
    return $res->{top_level};
}

restore_time;
done_testing();
