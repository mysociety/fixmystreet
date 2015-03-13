use strict;
use warnings;
use Test::More;
use LWP::Protocol::PSGI;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use t::MapIt;
use mySociety::Locale;

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
$mech->create_contact_ok(
    body => $body,
    category => "Other",
    email => "other\@example.org",
);

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

subtest "Test ajax decimal points" => sub {
    # The following line is so we are definitely not in Swedish before
    # requesting the page, so that the code performs a full switch to Swedish
    mySociety::Locale::push('en-gb');

    # A note to the future - the run_if_script line must be within a subtest
    # otherwise it fails to work
    LWP::Protocol::PSGI->register(t::MapIt->run_if_script, host => 'mapit.sweden');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixamingata' ],
        MAPIT_URL => 'http://mapit.sweden/'
    }, sub {
        $mech->get_ok('/ajax/lookup_location?term=12345');
        # We want an actual decimal point in a JSON response...
        $mech->content_contains('51.5');
    };
};

END {
    $mech->delete_problems_for_body(1);
    ok $mech->host("www.fixmystreet.com"), "change host back";
    done_testing();
}
