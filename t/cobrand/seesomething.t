use strict;
use warnings;
use DateTime;
use Test::More;

use FixMyStreet;
use FixMyStreet::TestMech;

my $EMAIL = 'seesomething@example.com';

my $mech = FixMyStreet::TestMech->new;
my $db = FixMyStreet::DB->storage->schema;
my $dt_parser = $db->storage->datetime_parser;

$db->txn_begin;

$db->resultset('Comment')->delete;
$db->resultset('Problem')->delete;

my $user = $mech->create_user_ok( $EMAIL );

my $body = $mech->create_body_ok( 2520, 'Coventry City Council', id => 2520 );
$mech->create_body_ok( 2522, 'Dudley Borough Council' );
$mech->create_body_ok( 2514, 'Birmingham City Council' );
$mech->create_body_ok( 2546, 'Walsall Borough Council' );
$mech->create_body_ok( 2519, 'Wolverhampton City Council' );
$mech->create_body_ok( 2538, 'Solihull Borough Council' );
$mech->create_body_ok( 2535, 'Sandwell Borough Council' );

$user->update({ from_body => $body });

my $date = $dt_parser->format_datetime(DateTime->now);

my $report = FixMyStreet::DB->resultset('Problem')->find_or_create( {
    postcode           => 'EH1 1BB',
    bodies_str         => '2520',
    areas              => ',2520,',
    service            => 'Android',
    category           => 'Bus',
    subcategory        => 'Loud Music',
    title              => 'Loud Music',
    detail             => 'Loud Music',
    used_map           => 1,
    name               => 'SeeSomething Test User',
    anonymous          => 0,
    state              => 'confirmed',
    confirmed          => $date,
    lang               => 'en-gb',
    cobrand            => 'default',
    cobrand_data       => '',
    send_questionnaire => 1,
    latitude           => '52.4081',
    longitude          => '-1.5106',
    user_id            => $user->id,
} );

subtest 'admin/stats' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'seesomething' ],
    }, sub {
        my $user = $mech->log_in_ok( $EMAIL );

        $mech->get( '/admin/stats' );
        if (ok $mech->success) {

            $date =~s/ /&nbsp;/;
            $date =~s/\+0000//;
            my $xml = <<EOXML;
        <tr>
            <td>Android</td>
            <td>Bus</td>
            <td class="nowrap">Loud Music</td>
            <td class="nowrap">Coventry </td>
            <td class="nowrap">$date</td>
        </tr>
EOXML
            $mech->content_contains($xml);
        }
        else {
            diag $mech->content;
            diag $mech->status;
        };
    }
};

$db->txn_rollback;
done_testing;
