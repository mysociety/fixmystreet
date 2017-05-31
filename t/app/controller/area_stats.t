use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', { id => 2237 });
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );

my $area_id = '20720';

$mech->create_problems_for_body(2, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", created => \'current_timestamp', category => 'Potholes' });
$mech->create_problems_for_body(3, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", created => \'current_timestamp', category => 'Traffic lights' });

my @planned_problems = $mech->create_problems_for_body(7, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", created => \'current_timestamp', category => 'Traffic lights' });
my @fixed_problems = $mech->create_problems_for_body(4, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", created => \'current_timestamp', category => 'Potholes' });
my @closed_problems = $mech->create_problems_for_body(3, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", created => \'current_timestamp', category => 'Traffic lights' });

foreach my $problem (@planned_problems) {
    $oxfordshireuser->add_to_planned_reports($problem);
}

foreach my $problem (@fixed_problems) {
    $problem->update({ state => 'fixed - council' });
    $mech->create_comment_for_problem($problem, $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'fixed');
}

foreach my $problem (@closed_problems) {
    $problem->update({ state => 'closed' });
    $mech->create_comment_for_problem($problem, $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'closed');
}

$mech->log_in_ok( $superuser->email );

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
}, sub {
    subtest 'superuser gets areas listed' => sub {
        $mech->create_body_ok(1234, 'Some Other Council');
        $mech->get_ok('/admin/areastats');
        $mech->content_contains('Oxfordshire County Council', 'Oxfordshire is shown on the page');
        $mech->content_contains('Some Other Council', 'Some other council is shown on the page');
    };

    subtest 'body user gets areas listed' => sub {
        $mech->log_in_ok( $oxfordshireuser->email );
        $mech->get_ok('/admin/areastats');
        is $mech->res->previous->code, 302, "got 302 for redirect";
        is $mech->uri->path, '/admin/areastats/body/2237';
        $mech->content_contains('Trowbridge');
        $mech->content_contains('Bradford-on-Avon');
    };

    subtest 'gets an area' => sub {
        $mech->get_ok('/admin/areastats/20720', 'Returns OK if area exists');
        $mech->content_contains('Area 20720', 'Area name is shown on the page');

        $mech->get('/admin/areastats/XXX');
        is $mech->status, 404, 'Getting a non-existent area returns 404';
    };

    subtest 'shows correct stats' => sub {
        $mech->get_ok('/admin/areastats/20720');
        $mech->content_contains('In the last month 12 issues opened, 7 scheduled, 3 closed, 4 fixed');
        $mech->text_contains('Potholes2004');
        $mech->text_contains('Traffic lights10730');
    };

    subtest 'shows average correctly' => sub {
        $fixed_problems[0]->update({ confirmed => DateTime->now->subtract(days => 2) });
        $fixed_problems[1]->update({ confirmed => DateTime->now->subtract(days => 3) });
        $fixed_problems[2]->update({ confirmed => DateTime->now->subtract(days => 7) });
        $fixed_problems[3]->update({ confirmed => DateTime->now->subtract(days => 4) });
        $closed_problems[0]->update({ confirmed => DateTime->now->subtract(days => 6) });
        $closed_problems[1]->update({ confirmed => DateTime->now->subtract(days => 9) });
        $closed_problems[2]->update({ confirmed => DateTime->now->subtract(days => 12) });

        $mech->get_ok('/admin/areastats/20720');
        $mech->text_contains('average time between issue being opened and set to another status was 6 days');
    }
};

END {
    FixMyStreet::DB->resultset('UserPlannedReport')->delete_all;
    $mech->delete_user( $superuser );
    $mech->delete_user( $oxfordshireuser );
    done_testing();
}
