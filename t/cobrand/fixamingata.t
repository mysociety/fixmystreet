use strict;
use warnings;
use Test::More;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Front page test

ok $mech->host("www.fixamingata.se"), "change host to FixaMinGata";
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixamingata' ],
}, sub {
    $mech->get_ok('/');
};
$mech->content_like( qr/FixaMinGata/ );

my $body = $mech->create_body_ok( 1, 'Body' );
FixMyStreet::App->model('DB::Contact')->find_or_create({
    body => $body,
    category => "Other",
    email => "other\@example.org",
    confirmed => 1,
    deleted => 0,
    editor => "Editor",
    whenedited => \'now()',
    note => 'Note',
});

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'fixamingata',
    latitude => '55.605833',
    longitude => '13.035833',
});
my $report = $reports[0];
$mech->get_ok( '/report/' . $report->id );

$mech->email_count_is(0);
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixamingata' ],
}, sub {
    FixMyStreet::App->model('DB::Problem')->send_reports();
};
my $email = $mech->get_email;
like $email->header('Content-Type'), qr/iso-8859-1/, 'encoding looks okay';
like $email->header('Subject'), qr/Ny rapport: Test Test/, 'subject looks okay';
like $email->header('To'), qr/other\@example.org/, 'to line looks correct';
like $email->body, qr/V=E4nligen,/, 'signature looks correct';
$mech->clear_emails_ok;

my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $user2 =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'commenter@example.com', name => 'Commenter' } );
ok $user2, "created comment user";

my $comment = FixMyStreet::App->model('DB::Comment')->find_or_create({
    problem_id => $report->id,
    user_id    => $user2->id,
    name       => 'Other User',
    mark_fixed => 'false',
    text       => 'This is some update text',
    state      => 'confirmed',
    anonymous  => 'f',
});
$comment->confirmed( \"ms_current_timestamp() - '3 days'::interval" );
$comment->update;

my $alert = FixMyStreet::App->model('DB::Alert')->find_or_create({
    user => $user,
    parameter => $report->id,
    alert_type => 'new_updates',
    whensubscribed => '2014-01-01 10:00:00',
    confirmed => 1,
    cobrand => 'fixamingata',
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixamingata' ],
}, sub {
    FixMyStreet::App->model('DB::AlertType')->email_alerts();
};

$mech->email_count_is(1);
$email = $mech->get_email;
like $email->header('Content-Type'), qr/iso-8859-1/, 'encoding looks okay';
like $email->body, qr/V=E4nligen,/, 'signature looks correct';
$mech->clear_emails_ok;

END {
    $mech->delete_problems_for_body(1);
    ok $mech->host("www.fixmystreet.com"), "change host back";
    done_testing();
}
