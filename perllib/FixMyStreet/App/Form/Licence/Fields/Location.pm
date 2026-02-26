package FixMyStreet::App::Form::Licence::Fields::Location;

use utf8;
use HTML::FormHandler::Moose::Role;
use Try::Tiny;
use FixMyStreet::Geocode;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::Location - Location fields for licence forms

=head1 DESCRIPTION

Provides standard location fields used by all TfL licence forms:
street_name, building_name_number, borough, postcode

Also provides geocoding via post_process_location() which can be called
from the page's post_process hook.

=cut

has_field building_name_number => (
    type => 'Text',
    label => 'Building name / number',
    required => 1,
);

has_field street_name => (
    type => 'Text',
    label => 'Street name',
    required => 1,
);

has_field borough => (
    type => 'Text',
    label => 'Borough',
    required => 1,
);

has_field postcode => (
    type => 'Text',
    label => 'Postcode',
    required => 1,
);

=head2 post_process_location

Geocodes the postcode and stores latitude/longitude in saved_data.
Call this from the location page's post_process hook:

    post_process => sub {
        my $form = shift;
        $form->post_process_location;
    },

=cut

sub post_process_location {
    my $form = shift;
    my $c = $form->c;
    my $saved_data = $form->saved_data;

    my $postcode = $saved_data->{postcode};
    return unless $postcode;

    try {
        my ($latitude, $longitude, $error) = FixMyStreet::Geocode::lookup($postcode, $c);
        if (defined $latitude && defined $longitude) {
            $saved_data->{latitude} = $latitude;
            $saved_data->{longitude} = $longitude;
        }
    } catch {
        # If geocoding fails, we'll use the default coordinates in the controller
    };
}

1;
