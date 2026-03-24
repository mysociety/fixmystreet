use FixMyStreet::Test;
use FixMyStreet::Geocode::Zurich;
use FixMyStreet::Cobrand;
use Test::MockModule;
use Test::MockObject;

my $cobrand = FixMyStreet::Cobrand::Default->new;

my $soap_data;
my $mock_result = Test::MockObject->new();
$mock_result->mock('result', sub { $soap_data });

my $soap_module = Test::MockModule->new('SOAP::Lite');
$soap_module->mock('call', sub { $mock_result });

FixMyStreet::override_config {
    GEOCODER => { url => 'http://localhost/', username => 'u', password => 'p' },
}, sub {
    $soap_data = { Location => [
        { text => 'Bahnhofstrasse', easting => '2683067.088', northing => '1247615.135' },
    ] };
    my $r = FixMyStreet::Geocode::Zurich->string('Bahnhofstrasse', $cobrand);
    ok $r->{latitude};
    ok $r->{longitude};
    ok !$r->{error};
    is $r->{geocoder_url}, 'Bahnhofstrasse';

    # allow_single returns even a single match as a results array, so autocomplete gets the address string.
    $r = FixMyStreet::Geocode::Zurich->string('Bahnhofstrasse', $cobrand, 1);
    is ref $r->{error}, 'ARRAY';
    is scalar @{$r->{error}}, 1;
    is $r->{error}[0]{address}, 'Bahnhofstrasse';

    $soap_data = { Location => [
        { text => 'Bahnhofpassage', easting => '2683154.537', northing => '1247962.624' },
        { text => 'Bahnhofplatz',   easting => '2683187.282', northing => '1247956.230' },
    ] };
    $r = FixMyStreet::Geocode::Zurich->string('Bahnhof', $cobrand);
    is ref $r->{error}, 'ARRAY';
    is scalar @{$r->{error}}, 2;

    # Empty response means no results found.
    $soap_data = '';
    $r = FixMyStreet::Geocode::Zurich->string('Bergweg', $cobrand);
    is $r->{error}, 'Sorry, we could not parse that location. Please try again.';

    $soap_module->mock('call', sub { die 'connection refused' });
    $r = FixMyStreet::Geocode::Zurich->string('Bahnhofstrasse', $cobrand);
    is $r->{error}, 'The geocoder appears to be down.';
};

done_testing;
