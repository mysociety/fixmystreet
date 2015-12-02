use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use FixMyStreet::App;

my $mech = FixMyStreet::TestMech->new;

my $dt = DateTime->new(
    year => 2011,
    month => 10,
    day     => 10
);

my $user1 = FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'reporter-rss@example.com', name => 'Reporter User' } );

my $dt_parser = FixMyStreet::App->model('DB')->schema->storage->datetime_parser;

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create( {
    postcode           => 'eh1 1BB',
    bodies_str         => '2651',
    areas              => ',11808,135007,14419,134935,2651,20728,',
    category           => 'Street lighting',
    title              => 'Testing',
    detail             => 'Testing Detail',
    used_map           => 1,
    name               => $user1->name,
    anonymous          => 0,
    state              => 'confirmed',
    confirmed          => $dt_parser->format_datetime($dt),
    lastupdate         => $dt_parser->format_datetime($dt),
    whensent           => $dt_parser->format_datetime($dt->clone->add( minutes => 5 )),
    lang               => 'en-gb',
    service            => '',
    cobrand            => 'default',
    cobrand_data       => '',
    send_questionnaire => 1,
    latitude           => '55.951963',
    longitude          => '-3.189944',
    user_id            => $user1->id,
} );

$mech->host('www.fixmystreet.com');
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.mysociety.org/',
}, sub {
    $mech->get_ok("/rss/pc/EH11BB/2");
};
$mech->content_contains( "Testing, 10th October" );
$mech->content_lacks( 'Nearest road to the pin' );

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
          'copyright' => "Copyright \x{a9} 2011 Microsoft and its suppliers. All rights reserved. This API cannot be accessed and the content and any results may not be used, reproduced or transmitted in any manner without express written permission from Microsoft Corporation.",
          'statusCode' => 200,
          'authenticationResultCode' => 'ValidCredentials'
        }
);
$report->update();

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.mysociety.org/',
}, sub {
    $mech->get_ok("/rss/pc/EH11BB/2");
};
$mech->content_contains( "Testing, 10th October" );
$mech->content_contains( '18 North Bridge, Edinburgh' );

$report->delete();

my $council = $mech->create_body_ok(2333, 'Hart Council');
my $county = $mech->create_body_ok(2227, 'Hampshire Council');

my $now = DateTime->now();
my $report_to_council = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'GU51 4AE',
        bodies_str         => $council->id,
        areas              => ',2333,2227,',
        category           => 'Other',
        title              => 'council report',
        detail             => 'Test 2 Detail',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        state              => 'closed',
        confirmed          => $now->ymd . ' ' . $now->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.279616',
        longitude          => '-0.846040',
        user_id            => $user1->id,
    }
);

my $report_to_county_council = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'GU51 4AE',
        bodies_str         => $county->id,
        areas              => ',2333,2227,',
        category           => 'Other',
        title              => 'county report',
        detail             => 'Test 2 Detail',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        state              => 'closed',
        confirmed          => $now->ymd . ' ' . $now->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.279616',
        longitude          => '-0.846040',
        user_id            => $user1->id,
    }
);

subtest "check RSS feeds on cobrand have correct URLs for non-cobrand reports" => sub {
    $mech->host('hart.fixmystreet.com');
    my $expected1 = FixMyStreet->config('BASE_URL') . '/report/' . $report_to_county_council->id;
    my $expected2;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'hart' ],
        MAPIT_URL => 'http://mapit.mysociety.org/',
    }, sub {
        $mech->get_ok("/rss/area/Hart");
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('hart')->new();
        $expected2 = $cobrand->base_url . '/report/' . $report_to_council->id;
    };

    $mech->content_contains($expected1, 'non cobrand area report point to fixmystreet.com');
    $mech->content_contains($expected2, 'cobrand area report point to cobrand url');
};

$mech->delete_user( $user1 );

done_testing();
