package FixMyStreet::Cobrand::Kingston;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;
with 'FixMyStreet::Roles::CobrandSLWP';
with 'FixMyStreet::Roles::Bottomline';
with 'FixMyStreet::Roles::SCP';

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }

sub admin_user_domain { ('kingston.gov.uk', 'sutton.gov.uk') }

sub dashboard_extra_bodies {
    my $sutton = FixMyStreet::Cobrand::Sutton->new->body;
    return $sutton;
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

has lpi_value => ( is => 'ro', default => 'KINGSTON UPON THAMES' );

sub waste_payment_ref_council_code { "RBK" }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return "$base/bin-grey-green-lid-recycling" if $container == 26 || $container == 27;
        return "";
    }
    my $service_id = $unit->{service_id};
    my $images = {
        2238 => "$base/bin-black", # refuse
        2239 => "$base/bin-brown", # food
        2240 => "$base/bin-grey-blue-lid-recycling", # paper and card
        2241 => "$base/bin-green", # dry mixed
        2242 => "$base/sack-clear-red", # domestic refuse bag
        2243 => "$base/large-communal-black", # Communal refuse
        2246 => "$base/sack-clear-blue", # domestic recycling bag
        2248 => "$base/bin-brown", # Communal food
        2249 => "$base/bin-grey-green-lid-recycling", # Communal paper
        2250 => "$base/large-communal-green", # Communal recycling
        2632 => "$base/sack-clear", # domestic paper bag
    };
    return $images->{$service_id};
}

sub garden_waste_dd_munge_form_details {
    my ($self, $c) = @_;

    $c->stash->{form_name} = $c->stash->{payment_details}->{form_name};
    if ( $c->stash->{staff_payments_allowed} ) {
        $c->stash->{form_name} = $c->stash->{payment_details}->{staff_form_name};
    }

    my $cfg = $self->feature('echo');
    if ($cfg->{nlpg} && $c->stash->{property}{uprn}) {
        my $uprn_data = get(sprintf($cfg->{nlpg}, $c->stash->{property}{uprn}));
        $uprn_data = JSON::MaybeXS->new->decode($uprn_data);
        my $address = $self->get_address_details_from_nlpg($uprn_data);
        if ( $address ) {
            $c->stash->{address1} = $address->{address1};
            $c->stash->{address2} = $address->{address2};
            $c->stash->{town} = $address->{town};
            $c->stash->{postcode} = $address->{postcode};
        }
    }
}

sub get_address_details_from_nlpg {
    my ( $self, $uprn_data) = @_;

    my $address;
    my $property = $uprn_data->{results}->[0]->{LPI};
    if ( $property ) {
        $address = {};
        my @namenumber = (_get_addressable_object($property, 'SAO'), _get_addressable_object($property, 'PAO'));
        $address->{address1} = join(", ", grep { /./ } map { FixMyStreet::Template::title($_) } @namenumber);
        $address->{address2} = FixMyStreet::Template::title($property->{STREET_DESCRIPTION});
        $address->{town} = FixMyStreet::Template::title($property->{TOWN_NAME});
        $address->{postcode} = $property->{POSTCODE_LOCATOR};
    }
    return $address;
}

sub _get_addressable_object {
    my ($property, $type) = @_;
    my $ao = $property->{$type . '_TEXT'} || '';
    $ao .= ' ' if $ao && $property->{$type . '_START_NUMBER'};
    $ao .= ($property->{$type . '_START_NUMBER'} || '') . ($property->{$type . '_START_SUFFIX'} || '');
    $ao .= '-' if $property->{$type . '_END_NUMBER'};
    $ao .= ($property->{$type . '_END_NUMBER'} || '') . ($property->{$type . '_END_SUFFIX'} || '');
    return $ao;
}

1;
