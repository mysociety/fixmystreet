use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

# check that we can get the page
$mech->get_ok('/about');
$mech->content_like(qr{About us ::\s+FixMyStreet});
$mech->content_contains('html class="no-js" lang="en-gb"');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'emptyhomes' ],
}, sub {
    # check that geting the page as EHA produces a different page
    ok $mech->host("reportemptyhomes.co.uk"), 'change host to reportemptyhomes';
    $mech->get_ok('/about');
    $mech->content_like(qr{About us ::\s+Report Empty Homes});
    $mech->content_contains('html lang="en-gb"');

    # check that geting the page as EHA in welsh produces a different page
    ok $mech->host("cy.reportemptyhomes.co.uk"), 'host to cy.reportemptyhomes';
    $mech->get_ok('/about');
    $mech->content_like(qr{Amdanom ni ::\s+Rhoi gwybod am eiddo gwag});
    $mech->content_contains('html lang="cy"');
};

done_testing();
