use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::Default';
sub country { 'GB' }
sub disambiguate_location { { components => 'country:IE' } }

package main;

use FixMyStreet::Test;
use FixMyStreet::Geocode::Google;
use FixMyStreet::Cobrand;
use t::Mock::GoogleGeocoder;

my $cobrand = FixMyStreet::Cobrand::Default->new;
my $r = FixMyStreet::Geocode::Google->string("one result", $cobrand);
ok $r->{latitude};
ok $r->{longitude};

$cobrand = FixMyStreet::Cobrand::Tester->new;
$r = FixMyStreet::Geocode::Google->string("two results", $cobrand);
is scalar @{$r->{error}}, 2;

done_testing;
