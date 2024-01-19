package FixMyStreet::Cobrand::Bexley::Waste;

use Moo::Role;

use Integrations::Whitespace;
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

    # TODO: Filter out services with SiteServiceValidTo in the past or SiteServiceValidFrom in the future
    $site_services = [ grep { $_->{NextCollectionDate} } @$site_services ];

    my $services = [ map {
        {
            id => $_->{SiteServiceID},
            service_name => $_->{ServiceItemDescription},
            next => {
                date => $_->{NextCollectionDate},
                ordinal => 'th', # TODO!
                changed => 0,
            },
        }
    } @$site_services ];

    return $services;
}

1;
