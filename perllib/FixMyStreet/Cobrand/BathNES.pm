package FixMyStreet::Cobrand::BathNES;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2551; }
sub council_area { return 'Bath and North East Somerset'; }
sub council_name { return 'Bath and North East Somerset Council'; }
sub council_url { return 'bathnes'; }

sub contact_email {
    my $self = shift;
    return join( '@', 'fixmystreet', 'bathnes.gov.uk' );
}
sub map_type { 'BathNES' }

sub example_places {
    return ( 'BA1 1JQ', "Lansdown Grove" );
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bath and North East Somerset';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.3559192103294,-2.47522827137605',
        span   => '0.166437921041471,0.429359043406088',
        bounds => [ 51.2730478766607, -2.70792015294201, 51.4394857977022, -2.27856110953593 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires { 0 }

sub enable_category_groups { 1 }

sub default_show_name { 0 }

sub default_map_zoom { 3 }

sub map_js_extra {
    my ($self, $c) = @_;

    return unless $c->user_exists;

    my $banes_user = $c->user->from_body && $c->user->from_body->areas->{$self->council_area_id};
    if ( $banes_user || $c->user->is_superuser ) {
        return ['/cobrands/bathnes/staff.js'];
    }
}

sub category_extra_hidden {
    my ($self, $meta) = @_;
    return 1 if $meta eq 'unitid' || $meta eq 'asset_details';
    return 0;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    $row->set_extra_fields(@$extra);
}



1;
