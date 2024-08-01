use Test::MockModule;
use File::Temp 'tempdir';
use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::Script::Reports;
use Open311::PostServiceRequestUpdates;

use_ok 'FixMyStreet::Cobrand::Northamptonshire';

my $mech = FixMyStreet::TestMech->new;

use open ':std', ':encoding(UTF-8)';

my $nh = $mech->create_body_ok(164186, 'Northamptonshire Highways', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', send_comments => 1, can_be_devolved => 1 }, { cobrand => 'northamptonshire' });
# Associate body with North Northamptonshire area
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 164185,
    body_id => $nh->id,
});

my $wnc = $mech->create_body_ok(164186, 'West Northamptonshire Council');
my $po = $mech->create_body_ok(164186, 'Northamptonshire Police');

my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $nh);
my $user = $mech->create_user_ok('user@example.com', name => 'User');

my $nh_contact = $mech->create_contact_ok(
    body_id => $nh->id,
    category => 'Trees',
    email => 'trees-nh@example.com',
);

$mech->create_contact_ok(
    body_id => $nh->id,
    category => 'Hedges',
    email => 'hedges-nh@example.com',
    send_method => 'Email',
);

my $wnc_contact = $mech->create_contact_ok(
    body_id => $wnc->id,
    category => 'Flytipping',
    email => 'flytipping-west-northants@example.com',
);

my $po_contact = $mech->create_contact_ok(
    body_id => $po->id,
    category => 'Abandoned vehicles',
    email => 'vehicles-northants-police@example.com',
);

my ($report) = $mech->create_problems_for_body(1, $nh->id, 'Defect Problem', {
    whensent => DateTime->now()->subtract( minutes => 5 ),
    cobrand => 'northamptonshire',
    external_id => 'CRM123',
    send_method_used => 'Open311',
    user => $counciluser
});

my $comment = FixMyStreet::DB->resultset('Comment')->create( {
    mark_fixed => 0,
    user => $user,
    problem => $report,
    anonymous => 0,
    text => 'this is a comment',
    confirmed => DateTime->now,
    state => 'confirmed',
    problem_state => 'confirmed',
    cobrand => 'default',
} );

$nh->update( { comment_user_id => $counciluser->id } );

FixMyStreet::override_config {
    ALLOWED_COBRANDS=> [ 'northamptonshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Check report emails to county use correct branding' => sub {
        my ($wnc_report) = $mech->create_problems_for_body(1, $wnc->id, 'West Northants Problem', {
            cobrand => 'fixmystreet',
            category => 'Flytipping',
        });

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Dear West Northamptonshire Council,/;
        like $body, qr/http:\/\/www\.example\.org/, 'correct link';
        like $body, qr/FixMyStreet is an independent service/, 'Has FMS promo text';
    };

    subtest 'Check report emails to police use correct branding' => sub {
        my ($po_report) = $mech->create_problems_for_body(1, $po->id, 'Northants Police Problem', {
            cobrand => 'fixmystreet',
            category => 'Abandoned vehicles',
        });

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Dear Northamptonshire Police,/;
        like $body, qr/http:\/\/www\.example\.org/, 'correct link';
        like $body, qr/FixMyStreet is an independent service/, 'Has FMS promo text';
    };
};

subtest 'Old report cutoff' => sub {
    my ($report1) = $mech->create_problems_for_body(1, $nh->id, 'West Northants Problem 1', { whensent => '2022-09-11 10:00' });
    my ($report2) = $mech->create_problems_for_body(1, $nh->id, 'West Northants Problem 2', { whensent => '2022-09-12 10:00' });
    my $update1 = $mech->create_comment_for_problem($report1, $user, 'Anonymous User', 'Update text', 't', 'confirmed', undef);
    my $update2 = $mech->create_comment_for_problem($report2, $user, 'Anonymous User', 'Update text', 't', 'confirmed', undef);
    my $cobrand = FixMyStreet::Cobrand::Northamptonshire->new;
    is $cobrand->should_skip_sending_update($update1), 1;
    is $cobrand->should_skip_sending_update($update2), 0;
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest 'All reports page working' => sub {
        $mech->get_ok("/reports/Northamptonshire+Highways");
        $mech->content_contains('Sulgrave');
        $mech->content_contains('Weston');
        $mech->get_ok("/reports/Northamptonshire+Highways/Weston+By+Welland");
        $mech->content_lacks('Sulgrave');
        $mech->content_contains('Weston');
        $mech->get_ok("/reports/Northamptonshire+Highways/Sulgrave");
        $mech->content_contains('Sulgrave');
        $mech->content_lacks('Weston');
    };
};

done_testing();
