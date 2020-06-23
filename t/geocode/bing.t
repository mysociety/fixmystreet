use FixMyStreet::Test;
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

done_testing;
