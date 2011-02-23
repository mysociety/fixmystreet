use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

# check that we can get the page
$mech->get_ok('/about');
$mech->content_contains('FixMyStreet.com');

# check that geting the page as EHA produces a different page
ok $mech->host("www.reportemptyhomes.co.uk"), 'change host to reportemptyhomes';
$mech->get_ok('/about');
$mech->content_lacks('FixMyStreet.com');

done_testing();
