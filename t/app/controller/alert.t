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
$mech->content_contains('Problems within 8.5km');
$mech->content_contains('rss/pc/EH991SP/2');
$mech->content_contains('rss/pc/EH991SP/5');
$mech->content_contains('rss/pc/EH991SP/10');
$mech->content_contains('rss/pc/EH991SP/20');
$mech->content_contains('Problems within City of Edinburgh');
$mech->content_contains('Problems within City Centre ward');
$mech->content_contains('/rss/reports/City+of+Edinburgh');
$mech->content_contains('/rss/reports/City+of+Edinburgh/City+Centre');
$mech->content_contains('council:2651:City_of_Edinburgh');
$mech->content_contains('ward:2651:20728:City_of_Edinburgh:City_Centre');

$mech->get_ok('/alert/list?pc=High Street');
$mech->content_contains('We found more than one match for that location');

$mech->get_ok('/alert/list?pc=');
$mech->content_contains('hat location does not appear to be covered by a council');

$mech->get_ok('/alert/list?pc=GL502PR');
$mech->content_contains('Problems within the boundary of');

$mech->get_ok('/alert/subscribe?rss=1&type=local&pc=ky16+8yg&rss=Give+me+an+RSS+feed&rznvy=' );
$mech->content_contains('Please select the feed you want');

$mech->get_ok('/alert/subscribe?rss=1&feed=invalid:1000:A_Locationtype=local&pc=ky16+8yg&rss=Give+me+an+RSS+feed&rznvy=');
$mech->content_contains('Illegal feed selection');

TODO: {
  local $TODO = 'not implemented rss feeds yet';

  $mech->get_ok('/alert/subscribe?rss=1&feed=area:1000:A_Location');
  $mech->uri->path('/rss/area/A+Location');

  $mech->get_ok('/alert/subscribe?rss=1&feed=area:1000:1001:A_Location:Diff_Location');
  $mech->uri->path('/rss/area/A+Location/Diff+Location');

  $mech->get_ok('/alert/subscribe?rss=1&feed=council:1000:A_Location');
  $mech->uri->path('/rss/reports/A+Location');

  $mech->get_ok('/alert/subscribe?rss=1&feed=ward:1000:1001:A_Location:Diff_Location');
  $mech->uri->path('/rss/ward/A+Location/Diff+Location');
}

done_testing();
