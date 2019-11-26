use utf8;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new();

# this is the easiest way to make sure we're not going
# to get any emails sent by data kicking about in the database
FixMyStreet::DB->resultset('AlertType')->email_alerts();
$mech->clear_emails_ok;

my $user =
  FixMyStreet::DB->resultset('User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $user2 =
  FixMyStreet::DB->resultset('User')
  ->find_or_create( { email => 'commenter@example.com', name => 'Commenter' } );
ok $user2, "created comment user";

my $user3 =
  FixMyStreet::DB->resultset('User')
  ->find_or_create( { email => 'bystander@example.com', name => 'Bystander' } );
ok $user3, "created bystander";

my $body = $mech->create_body_ok(2504, 'Westminster');

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        bodies_str         => $body->id,
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Test 2',
        detail             => 'Test 2 Detail',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        state              => 'closed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

my $comment = FixMyStreet::DB->resultset('Comment')->find_or_create(
    {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Other User',
        mark_fixed => 'false',
        text       => 'This is some update text',
        state      => 'confirmed',
        confirmed  => $dt->ymd . ' ' . $dt->hms,
        anonymous  => 'f',
    }
);
my $comment2 = FixMyStreet::DB->resultset('Comment')->find_or_create(
    {
        problem_id => $report_id,
        user_id    => $user2->id,
        name       => 'Other User',
        mark_fixed => 'false',
        text       => 'This is other update text',
        state      => 'confirmed',
        confirmed  => $dt->ymd . ' ' . $dt->hms,
        anonymous  => 'f',
    }
);

$comment->confirmed( \"current_timestamp - '3 days'::interval" );
$comment->update;

my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
    {
        user => $user,
        parameter => $report_id,
        alert_type => 'new_updates',
        whensubscribed => $dt->ymd . ' ' . $dt->hms,
        confirmed => 1,
        cobrand => 'default',
    }
);

my $alert3 = FixMyStreet::DB->resultset('Alert')->find_or_create(
    {
        user => $user3,
        parameter => $report_id,
        alert_type => 'new_updates',
        whensubscribed => $dt->ymd . ' ' . $dt->hms,
        confirmed => 1,
        cobrand => 'default',
    }
);

for my $test (
    {
        state => 'closed',
        msg => 'This report is currently marked as closed',
    },
    {
        state => 'fixed',
        msg => 'This report is currently marked as fixed',
    },
    {
        state => 'confirmed',
        msg => 'This report is currently marked as open',
    },
) {
    subtest "correct summary for state of $test->{state}" => sub {
        $mech->clear_emails_ok;

        my $sent = FixMyStreet::DB->resultset('AlertSent')->search(
            {
                alert_id => [ $alert->id, $alert3->id ],
                parameter => $comment->id,
            }
        )->delete;

        $report->state( $test->{state} );
        $report->update;

        FixMyStreet::DB->resultset('AlertType')->email_alerts();

        $mech->email_count_is( 2 );
        my @emails = $mech->get_email;
        my $msg = $test->{msg};
        for my $email (@emails) {
            my $body = $mech->get_text_body_from_email($email);
            my $to = $email->header('To');

            like $body, qr/$msg/, 'email says problem is ' . $test->{state};
            if ($to eq $user->email) {
                like $body, qr{/R/}, 'contains problem login url';
            } elsif ($to eq $user3->email) {
                like $body, qr{/report/$report_id}, 'contains problem url';
            }
            like $body, qr/This is some update text/, 'contains update text';
            unlike $body, qr/This is other update text/, 'does not contains other update text';

            my $comments = $body =~ s/(------)//gs;
            is $comments, 1, 'only 1 update';
        }
    };
}

my $now = DateTime->now();
$report->confirmed( $now->ymd . ' ' . $now->hms );
$report->update();

my $council_alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
    {
        user => $user2,
        parameter => $body->id,
        parameter2 => $body->id,
        alert_type => 'council_problems',
        whensubscribed => $dt->ymd . ' ' . $dt->hms,
        confirmed => 1,
    }
);

subtest "correct text for title after URL" => sub {
    $mech->clear_emails_ok;

    my $sent = FixMyStreet::DB->resultset('AlertSent')->search(
        {
            alert_id => $council_alert->id,
            parameter => $report->id,
        }
    )->delete;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::DB->resultset('AlertType')->email_alerts();
    };

    (my $title = $report->title) =~ s/ /\\s+/;
    my $body = $mech->get_text_body_from_email;

    like $body, qr#report/$report_id\s+-\s+$title#, 'email contains expected title';
};

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

foreach my $test (
    {
        desc        => 'all fields',
        addressLine => '18 North Bridge',
        locality    => 'Edinburgh',
        nearest     => qr/18 North Bridge, Edinburgh/,
    },
    {
        desc        => 'address with Street only',
        addressLine => 'Street',
        locality    => 'Edinburgh',
        nearest     => qr/: Edinburgh/,
    },
    {
        desc        => 'locality only',
        addressLine => undef,
        locality    => 'Edinburgh',
        nearest     => qr/: Edinburgh/,
    },
    {
        desc        => 'address only',
        addressLine => '18 North Bridge',
        locality    => undef,
        nearest     => qr/: 18 North Bridge\r?\n/,
    },
    {
        desc        => 'no fields',
        addressLine => undef,
        locality    => undef,
        nearest     => '',
    },
    {
        desc        => 'no address',
        no_address  => 1,
        nearest     => '',
    },
) {
    subtest "correct Nearest Road text with $test->{desc}" => sub {
        $mech->clear_emails_ok;

        my $sent = FixMyStreet::DB->resultset('AlertSent')->search(
            {
                alert_id => $council_alert->id,
                parameter => $report->id,
            }
        )->delete;

        my $g = $report->geocode;
        if ( $test->{no_address} ) {
            $g->{resourceSets}[0]{resources}[0]{address} = undef;
        } else {
            $g->{resourceSets}[0]{resources}[0]{address}->{addressLine} = $test->{addressLine};
            $g->{resourceSets}[0]{resources}[0]{address}->{locality} = $test->{locality};
        }

        # if we don't do this then it ignores the change
        $report->geocode( undef );
        $report->geocode( $g );
        $report->update();

        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            FixMyStreet::DB->resultset('AlertType')->email_alerts();
        };

        my $body = $mech->get_text_body_from_email;

        if ( $test->{nearest} ) {
            like $body, $test->{nearest}, 'correct nearest line';
        } else {
            unlike $body, qr/Nearest Road/, 'no nearest line';
        }
    };
}

my $hart = $mech->create_body_ok(2333, 'Hart');

my $ward_alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
    {
        user => $user,
        parameter => 7117,
        alert_type => 'area_problems',
        whensubscribed => $dt->ymd . ' ' . $dt->hms,
        confirmed => 1,
        cobrand => 'hart',
    }
);

my $report_to_council = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'WS13 6YY',
        bodies_str         => $hart->id,
        areas              => ',105255,11806,11828,2247,2504,7117,',
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
        latitude           => '52.727588',
        longitude          => '-1.731322',
        user_id            => $user2->id,
    }
);

my $report_to_county_council = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'WS13 6YY',
        bodies_str         => '2227',
        areas              => ',105255,11806,11828,2247,2504,7117,',
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
        latitude           => '52.727588',
        longitude          => '-1.731322',
        user_id            => $user2->id,
    }
);

my $report_outside_district = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'WS13 6YY',
        bodies_str         => '2221',
        areas              => ',105255,11806,11828,2247,2504,7117,',
        category           => 'Other',
        title              => 'outside district report',
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
        latitude           => '52.7352866189',
        longitude          => '-1.69540489214',
        user_id            => $user2->id,
    }
);

subtest "check alerts from cobrand send main site url for alerts for different council" => sub {
    $mech->clear_emails_ok;

    my $sent = FixMyStreet::DB->resultset('AlertSent')->search(
        {
            alert_id => $ward_alert->id,
        }
    )->delete;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['hart', 'fixmystreet'],
        BASE_URL => 'https://national.example.org',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::DB->resultset('AlertType')->email_alerts();

        my $body = $mech->get_text_body_from_email;

        my $expected1 = FixMyStreet->config('BASE_URL') . '/report/' . $report_to_county_council->id;
        my $expected3 = FixMyStreet->config('BASE_URL') . '/report/' . $report_outside_district->id;
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('hart')->new();
        my $expected2 = $cobrand->base_url . '/report/' . $report_to_council->id;
        like $body, qr#$expected1#, 'non cobrand area report point to fixmystreet.com';
        like $body, qr#$expected2#, 'cobrand area report point to cobrand url';
        like $body, qr#$expected3#, 'report outside district report point to fixmystreet.com';
    };
};


my $local_alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
    {
        user => $user,
        parameter => -1.731322,
        parameter2 => 52.727588,
        alert_type => 'local_problems',
        whensubscribed => $dt->ymd . ' ' . $dt->hms,
        cobrand     => 'hart',
        confirmed => 1,
    }
);

subtest "check local alerts from cobrand send main site url for alerts for different council" => sub {
    $mech->clear_emails_ok;

    my $sent = FixMyStreet::DB->resultset('AlertSent')->search(
        {
            alert_id => $local_alert->id,
        }
    )->delete;

    FixMyStreet::DB->resultset('AlertType')->email_alerts();

    my $body = $mech->get_text_body_from_email;

    my $expected1 = FixMyStreet->config('BASE_URL') . '/report/' . $report_to_county_council->id;
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('hart')->new();
    my $expected2 = $cobrand->base_url . '/report/' . $report_to_council->id;

    like $body, qr#$expected1#, 'non cobrand area report point to fixmystreet.com';
    like $body, qr#$expected2#, 'cobrand area report point to cobrand url';
};

# Test that email alerts are sent in the right language.
subtest "correct i18n-ed summary for state of closed" => sub {
    $mech->clear_emails_ok;

    $report->update( { state => 'closed' } );
    $alert->update( { lang => 'sv', cobrand => 'fixamingata' } );

    FixMyStreet::DB->resultset('AlertSent')->search( {
        alert_id => $alert->id,
        parameter => $comment->id,
    } )->delete;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixamingata' ],
    }, sub {
        FixMyStreet::DB->resultset('AlertType')->email_alerts();
    };

    my $body = $mech->get_text_body_from_email;
    my $msg = 'Den här rapporten är markerad som stängd';
    like $body, qr/$msg/, 'email says problem is closed, in Swedish';
};

END {
    done_testing();
}
