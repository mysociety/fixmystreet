package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::Default';
sub path_to_web_templates { [ FixMyStreet->path_to( 't', 'app', 'controller', 'templates') ] }

package main;

use utf8;
use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

# check that we can get the page
$mech->get_ok('/faq');
$mech->content_like(qr{Frequently Asked Questions ::\s+FixMyStreet});
$mech->content_contains('html class="no-js" lang="en-gb"');

$mech->get_ok('/privacy');
is $mech->res->code, 200, "got 200 for final destination";
is $mech->res->previous->code, 302, "got 302 for redirect";
is $mech->uri->path, '/about/privacy';

$mech->get('/about/page-that-does-not-exist');
ok !$mech->res->is_success(), "want a bad response";
is $mech->res->code, 404, "got 404";

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixamingata' ],
}, sub {
    ok $mech->host("www.fixamingata.se"), 'host to fixamingata';
    $mech->get_ok('/faq');
    $mech->content_like(qr{Vanliga frågor ::});
    $mech->content_contains('html class="no-js" lang="sv"');
};

$mech->get_ok('/');
$mech->content_contains('Report a problem');
$mech->content_lacks('STATIC FRONT PAGE');
$mech->get('/report');
is $mech->res->code, 200, "got 200";
is $mech->res->previous->code, 302, "got 302 for redirect";
is $mech->uri->path, '/', 'redirected to front page';

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'tester' ],
}, sub {
    $mech->get_ok('/');
    $mech->content_contains('STATIC FRONT PAGE');
    $mech->get_ok('/report');
    is $mech->res->previous, undef, 'No redirect';
    $mech->content_contains('Report a problem');
};

done_testing();
