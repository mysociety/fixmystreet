use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

# check that we can get the page
$mech->get_ok('/about');
$mech->content_contains('FixMyStreet.com');

# check that geting the page as EHA produces a different page
ok $mech->host("reportemptyhomes.co.uk"), 'change host to reportemptyhomes';
$mech->get_ok('/about');
$mech->content_contains('The Empty Homes Agency');

# check that geting the page as EHA in welsh produces a different page
ok $mech->host("cy.reportemptyhomes.co.uk"),
  'change host to cy.reportemptyhomes';
$mech->get_ok('/about');
$mech->content_contains('Yr Asiantaeth Tai Gwag');

done_testing();
