package FixMyStreet::Cobrand::Bexley::Waste;

use Moo::Role;

use Integrations::Whitespace;
use DateTime;
use DateTime::Format::W3CDTF;
use FixMyStreet;
use FixMyStreet::Template;
use Sort::Key::Natural qw(natkeysort_inplace);

has 'whitespace' => (
    is => 'lazy',
    default => sub { Integrations::Whitespace->new(%{shift->feature('whitespace')}) },
);

sub bin_addresses_for_postcode {
    my ($self, $postcode) = @_;

    my $addresses = $self->whitespace->GetAddresses($postcode);

    my $data = [ map {
        {
            value => $_->{AccountSiteId},
            label => FixMyStreet::Template::title($_->{SiteShortAddress}) =~ s/^, //r,
        }
    } @$addresses ];

    natkeysort_inplace { $_->{label} } @$data;

    return $data;
}

sub look_up_property {
    my ($self, $id) = @_;

    my $site = $self->whitespace->GetSiteInfo($id);

    return {
        id => $site->{AccountSiteID},
        uprn => $site->{AccountSiteUPRN},
        address => FixMyStreet::Template::title($site->{Site}->{SiteShortAddress}),
        latitude => $site->{Site}->{SiteLatitude},
        longitude => $site->{Site}->{SiteLongitude},
    };
}

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        # TODO
    };

    my $site_services = $self->whitespace->GetSiteCollections($property->{uprn});
    my @site_services_filtered;

    my $now_dt = DateTime->now->set_time_zone( FixMyStreet->local_time_zone );
    for my $service (@$site_services) {
        next if !$service->{NextCollectionDate};

        my $from_dt = eval {
            DateTime::Format::W3CDTF->parse_datetime(
                $service->{SiteServiceValidFrom} );
        };
        if ($@) {
            warn $@;
            next;
        }
        next if $now_dt < $from_dt;

        # 0001-01-01T00:00:00 seems to represent an undefined date
        if ( $service->{SiteServiceValidTo} ne '0001-01-01T00:00:00' ) {
            my $to_dt = eval {
                DateTime::Format::W3CDTF->parse_datetime(
                    $service->{SiteServiceValidTo} );
            };
            if ($@) {
                warn $@;
                next;
            }
            next if $now_dt > $to_dt;
        }

        push @site_services_filtered, $service;
    }

    my $services = [ map {
        {
            id => $_->{SiteServiceID},
            service_id => $_->{SiteServiceID},
            service_name => $_->{ServiceItemDescription},
            next => {
                date => $_->{NextCollectionDate},
                ordinal => 'th', # TODO!
                changed => 0,
            },
        }
    } @site_services_filtered ];

    return $services;
}

1;
