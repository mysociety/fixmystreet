use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Potholes', email => 'potholes@example.com' );
$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Traffic lights', email => 'lights@example.com' );
$mech->create_contact_ok( body_id => $oxfordshire->id, category => 'Litter', email => 'litter@example.com' );

my $body_id = $oxfordshire->id;
my $area_id = '20720';
my $alt_area_id = '20721';

$mech->create_problems_for_body(2, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,2237,", created => \'current_timestamp', category => 'Potholes' });
$mech->create_problems_for_body(3, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,2237,", created => \'current_timestamp', category => 'Traffic lights' });
$mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",$alt_area_id,6753,2237,", created => \'current_timestamp', category => 'Litter' });

my @scheduled_problems = $mech->create_problems_for_body(7, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,2237,", created => \'current_timestamp', category => 'Traffic lights' });
my @fixed_problems = $mech->create_problems_for_body(4, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,2237,", created => \'current_timestamp', category => 'Potholes' });
my @closed_problems = $mech->create_problems_for_body(3, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,2237,", created => \'current_timestamp', category => 'Traffic lights' });

foreach my $problem (@scheduled_problems) {
    $problem->update({ state => 'planned' });
    $mech->create_comment_for_problem($problem, $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'planned', { confirmed => \'current_timestamp' });
}

foreach my $problem (@fixed_problems) {
    $problem->update({ state => 'fixed - council' });
    $mech->create_comment_for_problem($problem, $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'fixed', { confirmed => \'current_timestamp' });
}

foreach my $problem (@closed_problems) {
    $problem->update({ state => 'closed' });
    $mech->create_comment_for_problem($problem, $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'closed', { confirmed => \'current_timestamp' });
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

    subtest 'body user sees whole body stats page' => sub {
        $mech->log_in_ok( $oxfordshireuser->email );
        $mech->get_ok('/admin/areastats');
        $mech->content_contains("Area stats for Oxfordshire County Council");
        $mech->content_contains('Trowbridge');
        $mech->content_contains('Bradford-on-Avon');
    };

    subtest 'area user can only see their area' => sub {
        $oxfordshireuser->update({area_id => 20720});

        $mech->get("/admin/areastats/$body_id");
        is $mech->status, 404, 'area user cannot see parent area';

        $mech->get("/admin/areastats/$body_id?area=20721");
        is $mech->status, 404, 'area user cannot see another area';

        $mech->get_ok('/admin/areastats');
        $mech->text_contains('Area 20720', 'index page displays their area to area user');

        $oxfordshireuser->update({area_id => undef});
    };

    subtest 'gets an area' => sub {
        $mech->log_in_ok( $oxfordshireuser->email );
        $mech->get_ok("/admin/areastats/$body_id?area=20720");
        $mech->content_contains('Area 20720', 'Area name is shown on the page');

        $mech->get('/admin/areastats/999');
        is $mech->status, 404, 'Getting a non-existent body returns 404';

        $mech->get("/admin/areastats/$body_id/999");
        is $mech->status, 404, 'Getting a non-existent area returns 404';
    };

    subtest 'shows correct stats for ward' => sub {
        $mech->get_ok("/admin/areastats/$body_id?area=20720");
        $mech->content_contains('19 opened, 7 scheduled, 3 closed, 4 fixed');
        $mech->text_contains('Potholes2004');
        $mech->text_contains('Traffic lights3730');
        $mech->text_contains('Litter0000');

        $mech->text_contains('Potholes6');
        $mech->text_contains('Traffic lights13');
    };

    subtest 'shows correct stats to area user' => sub {
        $oxfordshireuser->update({area_id => 20720});

        $mech->get_ok("/admin/areastats");
        $mech->content_contains('19 opened, 7 scheduled, 3 closed, 4 fixed');
        $mech->text_contains('Potholes2004');
        $mech->text_contains('Traffic lights3730');
        $mech->text_contains('Litter0000');

        $mech->text_contains('Potholes6');
        $mech->text_contains('Traffic lights13');

        $oxfordshireuser->update({area_id => undef});
    };

    subtest 'shows correct stats for ward using area param' => sub {
        $mech->get_ok("/admin/areastats/$body_id?area=20720");
        $mech->content_contains('19 opened, 7 scheduled, 3 closed, 4 fixed');
        $mech->text_contains('Potholes2004');
        $mech->text_contains('Traffic lights3730');
        $mech->text_contains('Litter0000');

        $mech->text_contains('Potholes6');
        $mech->text_contains('Traffic lights13');
    };

    subtest 'shows correct stats for council' => sub {
        $mech->get_ok("/admin/areastats/$body_id");
        $mech->content_contains('20 opened, 7 scheduled, 3 closed, 4 fixed');
        $mech->text_contains('Potholes2004');
        $mech->text_contains('Traffic lights3730');
        $mech->text_contains('Litter1000');

        $mech->text_contains('Potholes6');
        $mech->text_contains('Traffic lights13');
    };

    subtest 'shows average correctly' => sub {
        $fixed_problems[0]->update({ confirmed => DateTime->now->subtract(days => 2) });
        $fixed_problems[1]->update({ confirmed => DateTime->now->subtract(days => 3) });
        $fixed_problems[2]->update({ confirmed => DateTime->now->subtract(days => 7) });
        $fixed_problems[3]->update({ confirmed => DateTime->now->subtract(days => 4) });
        $scheduled_problems[0]->update({ confirmed => DateTime->now->subtract(days => 2) });
        $scheduled_problems[1]->update({ confirmed => DateTime->now->subtract(days => 4) });
        $scheduled_problems[2]->update({ confirmed => DateTime->now->subtract(days => 6) });
        $scheduled_problems[3]->update({ confirmed => DateTime->now->subtract(days => 7) });
        $scheduled_problems[4]->update({ confirmed => DateTime->now->subtract(days => 1) });
        $scheduled_problems[6]->update({ confirmed => DateTime->now->subtract(days => 1) });
        $closed_problems[0]->update({ confirmed => DateTime->now->subtract(days => 6) });
        $closed_problems[1]->update({ confirmed => DateTime->now->subtract(days => 9) });
        $closed_problems[2]->update({ confirmed => DateTime->now->subtract(days => 12) });

        $mech->get_ok("/admin/areastats/$body_id?area=20720");
        $mech->text_contains('average time between issue being opened and set to another status was 5 days');
    };

    subtest 'shows this month stats correctly' => sub {
        $fixed_problems[0]->update({ confirmed => DateTime->now->subtract(days => 50) });
        $fixed_problems[1]->update({ confirmed => DateTime->now->subtract(days => 50) });
        $scheduled_problems[1]->update({ confirmed => DateTime->now->subtract(days => 50) });
        $scheduled_problems[2]->update({ confirmed => DateTime->now->subtract(days => 50) });

        $mech->get_ok("/admin/areastats/$body_id?area=20720");

        $mech->content_contains('15 opened, 7 scheduled, 3 closed, 4 fixed');
        $mech->text_contains('Potholes2004');
        $mech->text_contains('Traffic lights3730');

        $mech->text_contains('Potholes4');
        $mech->text_contains('Traffic lights11');

        $mech->text_contains('average time between issue being opened and set to another status was 5 days');
    };

    subtest 'ignores multiple comments with the same state' => sub {
        $mech->create_comment_for_problem($scheduled_problems[0], $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'planned', { confirmed => \'current_timestamp' });
        $mech->get_ok("/admin/areastats/$body_id?area=20720");

        $mech->content_contains('15 opened, 7 scheduled, 3 closed, 4 fixed');
        $mech->text_contains('Potholes2004');
        $mech->text_contains('Traffic lights3730');
    };

    subtest 'average is only to first state change' => sub {
        for my $i (0..4) {
            $scheduled_problems[$i]->comments->first->update({ confirmed => $scheduled_problems[$i]->confirmed });
            $mech->create_comment_for_problem($scheduled_problems[$i], $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'fixed', { confirmed => \'current_timestamp' });
        }

        $mech->get_ok("/admin/areastats/$body_id?area=20720");
        $mech->text_contains('average time between issue being opened and set to another status was 4 days');
    };

    subtest 'average only includes actual state changes' => sub {
        my @probs = $mech->create_problems_for_body(2, $oxfordshire->id, 'Title',
          { areas => ",$area_id,6753,2237,", created => DateTime->now->subtract(days => 12), confirmed => DateTime->now->subtract(days => 12), category => 'Potholes' });
        $mech->create_comment_for_problem($probs[0], $oxfordshireuser, 'Title', 'text', 0, 'confirmed', 'confirmed', { confirmed => \'current_timestamp' });

        $mech->get_ok("/admin/areastats/$body_id?area=20720");
        $mech->text_contains('average time between issue being opened and set to another status was 4 days');
    };
};

END {
    FixMyStreet::DB->resultset('UserPlannedReport')->delete_all;
    $mech->delete_user( $superuser );
    $mech->delete_user( $oxfordshireuser );
    done_testing();
}
