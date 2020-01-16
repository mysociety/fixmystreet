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

use strict;
use warnings;

use FixMyStreet::TestMech;
use Web::Scraper;

set_absolute_time('2014-02-01T12:00:00');

my $mech = FixMyStreet::TestMech->new;

my $other_body = $mech->create_body_ok(1234, 'Some Other Council');
my $body = $mech->create_body_ok(2651, 'City of Edinburgh Council');
my @cats = ('Litter', 'Other', 'Potholes', 'Traffic lights');
for my $contact ( @cats ) {
    my $c = $mech->create_contact_ok(body_id => $body->id, category => $contact, email => "$contact\@example.org");
    if ($contact eq 'Potholes') {
        $c->set_extra_metadata(group => ['Road']);
        $c->update;
    }
}

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
my $normaluser = $mech->create_user_ok('normaluser@example.com', name => 'Normal User');

my $body_id = $body->id;
my $area_id = '60705';
my $alt_area_id = '62883';

my $last_month = DateTime->now->subtract(months => 2);
$mech->create_problems_for_body(2, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Potholes', cobrand => 'no2fat' });
$mech->create_problems_for_body(3, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Traffic lights', cobrand => 'no2fa', dt => $last_month });
$mech->create_problems_for_body(1, $body->id, 'Title', { areas => ",$alt_area_id,2651,", category => 'Litter', cobrand => 'no2fa' });

my @scheduled_problems = $mech->create_problems_for_body(7, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Traffic lights', cobrand => 'no2fa' });
my @fixed_problems = $mech->create_problems_for_body(4, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Potholes', cobrand => 'no2fa' });
my @closed_problems = $mech->create_problems_for_body(3, $body->id, 'Title', { areas => ",$area_id,2651,", category => 'Traffic lights', cobrand => 'no2fa' });

my $first_problem_id;
my $first_update_id;
foreach my $problem (@scheduled_problems) {
    $problem->update({ state => 'action scheduled' });
    my ($update) = $mech->create_comment_for_problem($problem, $counciluser, 'Title', 'text', 0, 'confirmed', 'action scheduled');
    $first_problem_id = $problem->id unless $first_problem_id;
    $first_update_id = $update->id unless $first_update_id;
}

foreach my $problem (@fixed_problems) {
    $problem->update({ state => 'fixed - council' });
    $mech->create_comment_for_problem($problem, $counciluser, 'Title', 'text', 0, 'confirmed', 'fixed');
}

foreach my $problem (@closed_problems) {
    $problem->update({ state => 'closed' });
    $mech->create_comment_for_problem($problem, $counciluser, 'Title', 'text', 0, 'confirmed', 'closed');
}

my $categories = scraper {
    process "select[name=category] option", 'cats[]' => 'TEXT',
    process "table[id=overview] > tr", 'rows[]' => scraper {
        process 'td', 'cols[]' => 'TEXT'
    },
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'no2fa',
    MAPIT_URL => 'http://mapit.uk/',
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
        my $expected_cats = [ 'All', 'Litter', 'Other', 'Traffic lights', 'Potholes' ];
        my $res = $categories->scrape( $mech->content );
        $mech->content_contains('<optgroup label="Road">');
        is_deeply( $res->{cats}, $expected_cats, 'correct list of categories' );
        # Three missing as more than a month ago
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 2, 0, 4, 6, 7, 3, 0, 10, 10, 3, 4, 17);
    };

    subtest 'test filters' => sub {
        $mech->get_ok("/dashboard");
        $mech->submit_form_ok({ with_fields => { category => 'Litter' } });
        test_table($mech->content, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1);
        $mech->submit_form_ok({ with_fields => { category => '', state => 'fixed - council' } });
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0, 0, 4, 4);
        $mech->submit_form_ok({ with_fields => { state => 'action scheduled' } });
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 7, 7, 0, 0, 7);
        my $start = DateTime->now->subtract(months => 3)->strftime('%Y-%m-%d');
        my $end = DateTime->now->subtract(months => 1)->strftime('%Y-%m-%d');
        $mech->submit_form_ok({ with_fields => { state => '', start_date => $start, end_date => $end } });
        test_table($mech->content, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 3, 3, 0, 0, 3);
    };

    subtest 'test grouping' => sub {
        $mech->get_ok("/dashboard?group_by=category");
        test_table($mech->content, 1, 0, 6, 10, 17);
        $mech->get_ok("/dashboard?group_by=state");
        test_table($mech->content, 3, 7, 4, 3, 17);
        $mech->get_ok("/dashboard?start_date=2000-01-01&group_by=month");
        test_table($mech->content, 0, 17, 17, 3, 0, 3, 3, 17, 20);
    };

    subtest 'export as csv' => sub {
        $mech->create_problems_for_body(1, $body->id, 'Title', {
            detail => "this report\nis split across\nseveral lines",
            areas => ",$alt_area_id,2651,",
        });
        $mech->get_ok('/dashboard?export=1');
        my @rows = $mech->content_as_csv;
        is scalar @rows, 19, '1 (header) + 18 (reports) = 19 lines';

        is scalar @{$rows[0]}, 20, '20 columns present';

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
                'Site Used',
                'Reported As',
            ],
            'Column headers look correct';

        is $rows[5]->[14], 'Trowbridge', 'Ward column is name not ID';
        is $rows[5]->[15], '529025', 'Correct Easting conversion';
        is $rows[5]->[16], '179716', 'Correct Northing conversion';
    };

    subtest 'export updates as csv' => sub {
        $mech->get_ok('/dashboard?updates=1&export=1');
        my @rows = $mech->content_as_csv;
        is scalar @rows, 15, '1 (header) + 14 (updates) = 15 lines';
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

        $counciluser->set_extra_metadata('access_token', '1234567890abcdefgh');
        $counciluser->update();

        $mech->get_ok('/dashboard?export=1');
        like $mech->res->header('Content-type'), qr'text/html';
        $mech->content_lacks('Report ID');

        $mech->add_header('Authorization', 'Bearer 1234567890abcdefgh');
        $mech->get_ok('/dashboard?export=1');
        like $mech->res->header('Content-type'), qr'text/csv';
        $mech->content_contains('Report ID');
        $mech->delete_header('Authorization');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'tester',
    MAPIT_URL => 'http://mapit.uk/',
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
}

restore_time;
done_testing();
