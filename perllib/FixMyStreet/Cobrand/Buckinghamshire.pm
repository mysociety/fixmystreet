package FixMyStreet::Cobrand::Buckinghamshire;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2217; }
sub council_area { return 'Buckinghamshire'; }
sub council_name { return 'Buckinghamshire County Council'; }
sub council_url { return 'buckinghamshire'; }

sub example_places {
    return ( 'HP19 7QF', "Walton Road" );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Buckinghamshire';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.7852948471218,-0.812140044990842',
        span   => '0.596065946222112,0.664092167105497',
        bounds => [ 51.4854160129405, -1.1406945585036, 52.0814819591626, -0.476602391398098 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub contact_email {
    my $self = shift;
    return join( '@', 'pjparfitt', 'buckscc.gov.uk' );
}

sub send_questionnaires {
    return 0;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    $row->set_extra_fields(@$extra);
}

sub map_type { 'Buckinghamshire' }

sub default_map_zoom { 3 }

sub category_extra_hidden {
    my ($self, $meta) = @_;
    return 1 if $meta eq 'site_code' || $meta eq 'central_asset_id';
    return 0;
}

1;
