use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
use FixMyStreet::DB;

my $mech = FixMyStreet::TestMech->new();
$mech->log_in_ok('test@example.com');

my ($problem) = $mech->create_problems_for_body(1, '2504', 'Title', { anonymous => 'f' });
is $problem->user->latest_anonymity, 0, "User's last report was not anonymous";

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/around?pc=sw1a1aa');
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->content_like(qr/may_show_name[^>]*checked/);
};

($problem) = $mech->create_problems_for_body(1, '2504', 'Title', { anonymous => 't' });
is $problem->user->latest_anonymity, 1, "User's last report was anonymous";

create_update($problem, anonymous => 'f');
is $problem->user->latest_anonymity, 0, "User's last update was not anonyous";

create_update($problem, anonymous => 't');
is $problem->user->latest_anonymity, 1, "User's last update was anonymous";

subtest "Sign user up for alerts" => sub {
    my $user = $problem->user;

    my $alert_exists =  $user->alert_for_problem( $problem->id );
    is !defined( $alert_exists ), 1, "No current alerts exist";

    my $options = {
      cobrand      => 'default',
      lang         => 'en-gb',
    };
    $user->create_alert($problem->id, $options);
    my $alert = $user->alert_for_problem( $problem->id );

    is defined( $alert ), 1, "User is signed up for alerts";
    is $alert->confirmed, 1, "Alert is confirmed";

    $alert->delete();

    $user->alerts->create({
        alert_type   => 'new_updates',
        parameter    => $problem->id,
    });

    $user->create_alert($problem->id, $options);

    my $new_alert = $user->alert_for_problem( $problem->id );
    is $alert->confirmed, 1, "Already created alert is confirmed";
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/around?pc=sw1a1aa');
    $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
    $mech->content_like(qr/may_show_name[^>c]*>/);
};

subtest 'user with areas returns areas as an array' => sub {
    my $user = FixMyStreet::DB->resultset('User')->find_or_create(
        {
            email => 'testwithareas@example.com'
        }
    );

    is_deeply $user->area_ids, [], 'area_ids is an empty array when no areas present';

    $user->update({areas => ',123,456,789'});

    is_deeply $user->area_ids, [123,456,789], 'area_ids is an array of areas';
};

subtest 'reports_in_areas returns reports in a users areas' => sub {
    my $user = FixMyStreet::DB->resultset('User')->find_or_create(
        {
            email => 'testwithareas@example.com'
        }
    );
    $user->update({areas => ',123,456,789'});

    my ($problem1) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',123,6753,4324,' });
    my ($problem2) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',6753,456,4324,' });
    my ($problem3) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',6753,3433,789,' });
    my ($problem4) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',6753,3433,32324,' });

    my @reports = $user->reports_in_areas;

    is scalar(@reports), 3, 'Has correct number of problems';

    is $reports[0]->id, $problem1->id, 'Contains problem 1';
    is $reports[1]->id, $problem2->id, 'Contains problem 2';
    is $reports[2]->id, $problem3->id, 'Contains problem 3';
};

subtest 'reports_in_areas returns an empty array for a user without areas' => sub {
    my $newuser = FixMyStreet::DB->resultset('User')->find_or_create(
        {
            email => 'testwithoutareas@example.com'
        }
    );

    my ($problem1) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',123,6753,4324,' });
    my ($problem2) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',6753,456,4324,' });
    my ($problem3) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',6753,3433,789,' });
    my ($problem4) = $mech->create_problems_for_body(1, '2504', 'Title', { areas => ',6753,3433,32324,' });

    my $reports = $newuser->reports_in_areas;

    is $reports, undef, 'Has no problems';
};

END {
    $mech->delete_user( $problem->user ) if $problem;
    done_testing();
}

sub create_update {
    my ($problem, %params) = @_;
    my $dt = DateTime->now()->add(days => 1);
    return FixMyStreet::App->model('DB::Comment')->find_or_create({
        problem_id => $problem->id,
        user_id => $problem->user_id,
        name => 'Other User',
        mark_fixed => 'false',
        text => 'This is some update text',
        state => 'confirmed',
        anonymous => 'f',
        created => $dt->ymd . ' ' . $dt->hms,
        %params,
    });
}
