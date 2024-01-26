use utf8;
use Test::MockModule;
use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

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
