use FixMyStreet::Test;
use FixMyStreet::Geocode::Address::Bing;
use FixMyStreet::Geocode::Bing;
use Catalyst::Test 'FixMyStreet::App';
use t::Mock::Bing;

my $c = ctx_request('/');

FixMyStreet::override_config {
    GEOCODING_DISAMBIGUATION => { bing_culture => 'en-GB' }
}, sub {
    my $r = FixMyStreet::Geocode::Bing->string('a result', $c);
    ok $r->{latitude};
    ok $r->{longitude};
};

FixMyStreet::override_config {
    GEOCODING_DISAMBIGUATION => { bing_country => 'United Kingdom' }
}, sub {
    my $r = FixMyStreet::Geocode::Bing->string('two results', $c);
    is scalar @{$r->{error}}, 2;
    is $r->{error}[1]{address}, 'Constitution Hill again, London';
};

my $r = FixMyStreet::Geocode::Bing->string('two results andalow', $c);
is scalar @{$r->{error}}, 2;

$r = FixMyStreet::Geocode::Bing->string('two results onlylow', $c);
is scalar @{$r->{error}}, 3;

FixMyStreet::override_config {
    BING_MAPS_API_KEY => 'key',
}, sub {
    $r = FixMyStreet::Geocode::Bing->reverse_geocode($c->cobrand, "00", "00");
    my $a = FixMyStreet::Geocode::Address::Bing->new($r);
    is $a->summary, undef;
};

done_testing;
