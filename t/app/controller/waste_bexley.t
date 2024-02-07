use utf8;
use Test::Deep;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

set_fixed_time('2024-03-31T01:00:00'); # March 31st, 02:00 BST

my $mech = FixMyStreet::TestMech->new;

my $mock = Test::MockModule->new('FixMyStreet::Cobrand::Bexley');
$mock->mock('_fetch_features', sub { [] });

my $whitespace_mock = Test::MockModule->new('Integrations::Whitespace');
$whitespace_mock->mock('call' => sub {
  my ($whitespace, $method, @args) = @_;

  if ($method eq 'GetAddresses') {
    my %args = @args;
    &_addresses_for_postcode($args{getAddressInput});
  }
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'bexley',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => { whitespace => { bexley => {
        url => 'http://example.org/',
        } },
        waste => { bexley => 1 },
    },
}, sub {
    subtest 'Postcode search page is shown' => sub {
        $mech->get_ok('/waste');
        $mech->content_contains('Bins, rubbish and recycling');
        $mech->content_contains('Find your bin collection days');
        $mech->content_contains('Report a missed bin collection');
        $mech->content_lacks('Order new or additional bins');
        $mech->content_lacks('Subscribe to garden waste collection service');
    };

    subtest 'False postcode shows error' => sub {
      $mech->submit_form_ok({ with_fields => {postcode => 'PC1 1PC'} });
      $mech->content_contains('Sorry, we did not recognise that postcode');
    };

    subtest 'Postcode with multiple addresses progresses to selecting an address' => sub {
      $mech->submit_form_ok({ with_fields => {postcode => 'DA1 3LD'} });
      $mech->content_contains('Select an address');
      $mech->content_contains('<option value="1">1, The Avenue, DA1 3LD</option>');
      $mech->content_contains('<option value="2">2, The Avenue, DA1 3LD</option>');
  };

  subtest 'Postcode with one address progresses to selecting an address' => sub {
      $mech->get_ok('/waste');
      $mech->submit_form_ok({ with_fields => {postcode => 'DA1 3NP'} });
      $mech->content_contains('Select an address');
      $mech->content_contains('<option value="1">1, The Avenue, DA1 3NP</option>');
  };

    $whitespace_mock->mock('GetSiteInfo', &_site_info );
    $whitespace_mock->mock('GetSiteCollections', &_site_collections );

    subtest 'Correct services are shown for address' => sub {
        $mech->submit_form_ok( { with_fields => { address => 1 } } );

        $mech->content_contains('Service 1');
        $mech->content_contains('Tuesday, 30th April 2024');
        $mech->content_lacks('Service 2');
        $mech->content_lacks('Service 3');
        $mech->content_lacks('Service 4');
        $mech->content_lacks('Service 5');
        $mech->content_contains('Service 6');
        $mech->content_contains('Wednesday, 1st May 2024');
        $mech->content_lacks('Service 7');
        $mech->content_contains('Service 8');
        $mech->content_contains('Monday, 1st April 2024');
        $mech->content_contains('Another service (9)');
        $mech->content_contains('Monday, 1st April 2024');

        subtest 'service_sort sorts correctly' => sub {
            my $cobrand = FixMyStreet::Cobrand::Bexley->new;
            $cobrand->{c} = Test::MockObject->new;
            $cobrand->{c}->mock( stash => sub { {} } );

            my @sorted = $cobrand->service_sort(
                @{ $cobrand->bin_services_for_address( {} ) } );
            my %defaults = (
                service_id => ignore(),
                next => {
                    changed => 0,
                    ordinal => ignore(),
                    date => ignore(),
                },
            );
            cmp_deeply \@sorted, [
                {   id           => 9,
                    service_name => 'Another service (9)',
                    %defaults,
                },
                {   id           => 8,
                    service_name => 'Service 8',
                    %defaults,
                },
                {   id           => 1,
                    service_name => 'Service 1',
                    %defaults,
                },
                {   id           => 6,
                    service_name => 'Service 6',
                    %defaults,
                },
            ];
        };
    };
};

done_testing;

sub _addresses_for_postcode {

  my $data = shift;

  if ($data->{Postcode} eq 'DA1 3LD') {
    return
    { Addresses =>
      { Address =>
        [
          {
            'SiteShortAddress' => ', 1, THE AVENUE, DA1 3LD',
            'AccountSiteId' => '1',
          },
          {
            'SiteShortAddress' => ', 2, THE AVENUE, DA1 3LD',
            'AccountSiteId' => '2',
          },
        ]
      }
    }
  } elsif ($data->{Postcode} eq 'DA1 3NP') {
    return
    { Addresses => {
        Address =>
          {
            'SiteShortAddress' => ', 1, THE AVENUE, DA1 3NP',
            'AccountSiteId' => '1',
          }
      }
    }
  }
}

sub _site_info {
    return {
        AccountSiteID   => 1,
        AccountSiteUPRN => 10001,
        Site            => {
            SiteShortAddress => ', 1, THE AVENUE, DA1 3NP',
            SiteLatitude     => 51,
            SiteLongitude    => -0.1,
        },
    };
}

sub _site_collections {
    return [
        {
            SiteServiceID => 1,
            ServiceItemDescription => 'Service 1',

            NextCollectionDate => '2024-04-30T00:00:00',
            SiteServiceValidFrom => '2024-03-31T00:59:59',
            SiteServiceValidTo => '2024-03-31T03:00:00',
        },
        {
            SiteServiceID => 2,
            ServiceItemDescription => 'Service 2',

            NextCollectionDate => undef,
            SiteServiceValidFrom => '2024-03-31T00:59:59',
            SiteServiceValidTo => '2024-03-31T03:00:00',
        },
        {
            SiteServiceID => 3,
            ServiceItemDescription => 'Service 3',

            # No NextCollectionDate
            SiteServiceValidFrom => '2024-03-31T00:59:59',
            SiteServiceValidTo => '2024-03-31T03:00:00',
        },
        {
            SiteServiceID => 4,
            ServiceItemDescription => 'Service 4',

            NextCollectionDate => '2024-04-01T00:00:00',
            SiteServiceValidFrom => '2024-03-31T03:00:00', # Future
            SiteServiceValidTo => '2024-03-31T04:00:00',
        },
        {
            SiteServiceID => 5,
            ServiceItemDescription => 'Service 5',

            NextCollectionDate => '2024-04-01T00:00:00',
            SiteServiceValidFrom => '2024-03-31T00:00:00',
            SiteServiceValidTo => '2024-03-31T00:59:59', # Past
        },
        {
            SiteServiceID => 6,
            ServiceItemDescription => 'Service 6',

            NextCollectionDate => '2024-05-01T00:00:00',
            SiteServiceValidFrom => '2024-03-31T00:59:59',
            SiteServiceValidTo => '0001-01-01T00:00:00',
        },
        {
            SiteServiceID => 7,
            ServiceItemDescription => 'Service 7',

            NextCollectionDate => '20240-04-02T00:00:00',
            SiteServiceValidFrom => '2024-03-31T00:59:59',
            SiteServiceValidTo => '0001-01-01T00:00:00',
        },
        {
            SiteServiceID => 8,
            ServiceItemDescription => 'Service 8',

            NextCollectionDate => '2024-04-01T00:00:00',
            SiteServiceValidFrom => '2024-03-31T00:59:59',
            SiteServiceValidTo => '0001-01-01T00:00:00',
        },
        {
            SiteServiceID => 9,
            ServiceItemDescription => 'Another service (9)',

            NextCollectionDate => '2024-04-01T00:00:00',
            SiteServiceValidFrom => '2024-03-31T00:59:59',
            SiteServiceValidTo => '0001-01-01T00:00:00',
        },
    ];
}
