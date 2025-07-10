use FixMyStreet::Test;
use FixMyStreet::Geocode::Address::Bing;
use FixMyStreet::Geocode::Bing;
use FixMyStreet::Cobrand;
use t::Mock::Bing;

my $cobrand = FixMyStreet::Cobrand::Default->new;

FixMyStreet::override_config {
    GEOCODING_DISAMBIGUATION => { bing_culture => 'en-GB' }
}, sub {
    my $r = FixMyStreet::Geocode::Bing->string('a result', $cobrand);
    ok $r->{latitude};
    ok $r->{longitude};
};

FixMyStreet::override_config {
    GEOCODING_DISAMBIGUATION => { bing_country => 'United Kingdom' }
}, sub {
    my $r = FixMyStreet::Geocode::Bing->string('two results', $cobrand);
    is scalar @{$r->{error}}, 2;
    is $r->{error}[1]{address}, 'Constitution Hill again, London';
};

my $r = FixMyStreet::Geocode::Bing->string('two results andalow', $cobrand);
is scalar @{$r->{error}}, 2;

$r = FixMyStreet::Geocode::Bing->string('two results onlylow', $cobrand);
is scalar @{$r->{error}}, 3;

FixMyStreet::override_config {
    BING_MAPS_API_KEY => 'key',
}, sub {
    $r = FixMyStreet::Geocode::Bing->reverse_geocode($cobrand, "00", "00");
    my $a = FixMyStreet::Geocode::Address::Bing->new($r);
    is $a->summary, undef;
};

done_testing;
