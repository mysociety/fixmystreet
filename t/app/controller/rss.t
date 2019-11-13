use utf8;
use open ':std', ':locale';
use FixMyStreet::TestMech;
use FixMyStreet::App;

my $mech = FixMyStreet::TestMech->new;

my $dt = DateTime->new(
    year => 2011,
    month => 10,
    day     => 10
);

my $user1 = $mech->create_user_ok('reporter-rss@example.com', name => 'Reporter User');

my $dt_parser = FixMyStreet::App->model('DB')->schema->storage->datetime_parser;

my ($report) = $mech->create_problems_for_body(1, 2651, '', {
    postcode           => 'eh1 1BB',
    areas              => ',11808,135007,14419,134935,2651,20728,',
    category           => 'Street lighting',
    title              => '&Test’i<n>g \'☃"',
    detail             => 'Testing Detail',
    name               => $user1->name,
    confirmed          => $dt_parser->format_datetime($dt),
    lastupdate         => $dt_parser->format_datetime($dt),
    whensent           => $dt_parser->format_datetime($dt->clone->add( minutes => 5 )),
    latitude           => '55.951963',
    longitude          => '-3.189944',
    user => $user1,
} );

$mech->host('www.fixmystreet.com');
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok("/rss/pc/EH11BB/2");
};
$mech->content_contains( "&amp;Test’i&lt;n&gt;g &#39;☃&quot;, 10th October" );
$mech->content_lacks( 'Nearest road to the pin' );
is $mech->response->header('Access-Control-Allow-Origin'), '*';

$report->geocode( 
{
          'traceId' => 'ae7c4880b70b423ebc8ab4d80961b3e9|LTSM001158|02.00.71.1600|LTSMSNVM002010, LTSMSNVM001477',
          'statusDescription' => 'OK',
          'brandLogoUri' => 'http://dev.virtualearth.net/Branding/logo_powered_by.png',
          'resourceSets' => [
                              {
                                'resources' => [
                                                 {
                                                   'geocodePoints' => [
                                                                        {
                                                                          'calculationMethod' => 'Interpolation',
                                                                          'coordinates' => [
                                                                                             '55.9532357007265',
                                                                                             '-3.18906001746655'
                                                                                           ],
                                                                          'usageTypes' => [
                                                                                            'Display',
                                                                                            'Route'
                                                                                          ],
                                                                          'type' => 'Point'
                                                                        }
                                                                      ],
                                                   'entityType' => 'Address',
                                                   'name' => '18 N Bridge, Edinburgh EH1 1',
                                                   'point' => {
                                                                'coordinates' => [
                                                                                   '55.9532357007265',
                                                                                   '-3.18906001746655'
                                                                                 ],
                                                                'type' => 'Point'
                                                              },
                                                   'bbox' => [
                                                               '55.9493729831558',
                                                               '-3.19825819222605',
                                                               '55.9570984182972',
                                                               '-3.17986184270704'
                                                             ],
                                                   'matchCodes' => [
                                                                     'Good'
                                                                   ],
                                                   'address' => {
                                                                  'countryRegion' => 'United Kingdom',
                                                                  'adminDistrict2' => 'Edinburgh City',
                                                                  'adminDistrict' => 'Scotland',
                                                                  'addressLine' => '18 North Bridge',
                                                                  'formattedAddress' => '18 N Bridge, Edinburgh EH1 1',
                                                                  'postalCode' => 'EH1 1',
                                                                  'locality' => 'Edinburgh'
                                                                },
                                                   'confidence' => 'Medium',
                                                   '__type' => 'Location:http://schemas.microsoft.com/search/local/ws/rest/v1'
                                                 }
                                               ],
                                'estimatedTotal' => 1
                              }
                            ],
          'copyright' => "Copyright © 2011 Microsoft and its suppliers. All rights reserved. This API cannot be accessed and the content and any results may not be used, reproduced or transmitted in any manner without express written permission from Microsoft Corporation.",
          'statusCode' => 200,
          'authenticationResultCode' => 'ValidCredentials'
        }
);
$report->update();

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok("/rss/pc/EH11BB/2");
};
$mech->content_contains( "&amp;Test’i&lt;n&gt;g &#39;☃&quot;, 10th October" );
$mech->content_contains( '18 North Bridge, Edinburgh' );

$report->delete();

my $council = $mech->create_body_ok(2333, 'Hart Council');
my $county = $mech->create_body_ok(2227, 'Hampshire Council');

my ($report_to_council) = $mech->create_problems_for_body(1, $council->id, '', {
        user => $user1,
        areas              => ',2333,2227,',
        latitude           => '51.279616',
        longitude          => '-0.846040',
});

my ($report_to_county_council) = $mech->create_problems_for_body(1, $county->id, '', {
        user => $user1,
        areas              => ',2333,2227,',
        latitude           => '51.279616',
        longitude          => '-0.846040',
});

subtest "check RSS feeds on cobrand have correct URLs for non-cobrand reports" => sub {
    $mech->host('hart.fixmystreet.com');
    my $expected1 = FixMyStreet->config('BASE_URL') . '/report/' . $report_to_county_council->id;
    my $expected2;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'hart' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/rss/area/Hart");
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('hart')->new();
        $expected2 = $cobrand->base_url . '/report/' . $report_to_council->id;
    };

    $mech->content_contains($expected1, 'non cobrand area report point to fixmystreet.com');
    $mech->content_contains($expected2, 'cobrand area report point to cobrand url');
};

subtest 'Check XSL' => sub {
    $mech->host('www.fixmystreet.com');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        $mech->get_ok('/rss/xsl');
    };
    $mech->content_contains('/cobrands/fixmystreet.com/images/email-logo.gif');
    $mech->content_contains('FixMyStreet');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bexley',
    }, sub {
        $mech->get_ok('/rss/xsl');
    };
    $mech->content_contains('/cobrands/bexley/images/logo.png');
};

done_testing();
