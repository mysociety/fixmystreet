package FixMyStreet::Cobrand::IsleOfWight;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2636 }
sub council_area { 'Isle of Wight' }
sub council_name { 'Isle of Wight Council' }
sub council_url { 'isleofwight' }
sub example_places { ( 'PO30 5XJ', "Daish Way" ) }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    # uncoverable statement
    return 'https://islandroads.fixmystreet.com';
}

sub on_map_default_status { 'open' }

sub contact_email {
    my $self = shift;
    return join( '@', 'info', 'islandroads.com' );
}

sub send_questionnaires { 0 }

sub enable_category_groups { 1 }

sub map_type { 'OSM' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '50.675761,-1.296571',
        bounds => [ 50.574653, -1.591732, 50.767567, -1.062957 ],
    };
}

# sub get_geocoder { 'OSM' }

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

1;
