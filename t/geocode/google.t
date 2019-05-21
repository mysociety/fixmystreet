package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::Default';
sub country { 'GB' }
sub disambiguate_location { { components => 'country:IE' } }

package main;

use FixMyStreet::Test;
use FixMyStreet::Geocode::Google;
use Catalyst::Test 'FixMyStreet::App';
use t::Mock::GoogleGeocoder;

my $c = ctx_request('/');
my $r = FixMyStreet::Geocode::Google->string("one result", $c);
ok $r->{latitude};
ok $r->{longitude};

$c->stash->{cobrand} = FixMyStreet::Cobrand::Tester->new;
$r = FixMyStreet::Geocode::Google->string("two results", $c);
is scalar @{$r->{error}}, 2;

done_testing;
