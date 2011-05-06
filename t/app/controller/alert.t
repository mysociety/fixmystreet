use strict;
use warnings;
use Test::More;


use Catalyst::Test 'FixMyStreet::App';
use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

# check that we can get the page
$mech->get_ok('/alert');
$mech->title_like(qr/^Local RSS feeds and email alerts/);
$mech->content_contains('Local RSS feeds and email alerts');
$mech->content_contains('html lang="en-gb"');

# check that we can get list page
$mech->get_ok('/alert/list');
$mech->title_like(qr/^Local RSS feeds and email alerts/);
$mech->content_contains('Local RSS feeds and email alerts');
$mech->content_contains('html lang="en-gb"');

$mech->get_ok('/alert/list?pc=EH99 1SP');
$mech->title_like(qr/^Local RSS feeds and email alerts/);
$mech->content_contains('Local RSS feeds and email alerts for EH99&nbsp;1SP');
$mech->content_contains('html lang="en-gb"');

$mech->get_ok('/alert/list?pc=High Street');
$mech->content_contains('We found more than one match for that location');

$mech->get_ok('/alert/list?pc=');
$mech->content_contains('hat location does not appear to be covered by a council');
done_testing();
