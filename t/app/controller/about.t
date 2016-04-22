use utf8;
use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

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
    ALLOWED_COBRANDS => [ 'fiksgatami' ],
}, sub {
    ok $mech->host("www.fiksgatami.no"), 'host to fiksgatami';
    $mech->get_ok('/faq');
    $mech->content_like(qr{Ofte spurte spørsmål ::});
    $mech->content_contains('html class="no-js" lang="nb"');
};

done_testing();
