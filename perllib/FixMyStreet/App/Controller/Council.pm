package FixMyStreet::App::Controller::Council;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Council - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 load_and_check_areas_and_wards

Try to load areas and wards for this location and check that we have at least one. If
there are no areas then return false.

=cut

sub load_and_check_areas_and_wards : Private {
    my ( $self, $c ) = @_;
    my $area_types = [ @{$c->cobrand->area_types}, @{$c->cobrand->area_types_children} ];
    $c->stash->{area_types} = $area_types;
    $c->forward('load_and_check_areas');
}

=head2 load_and_check_areas

Try to load areas for this location and check that we have at least one. If
there are no areas then return false.

=cut

sub load_and_check_areas : Private {
    my ( $self, $c ) = @_;

    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    # Look up areas and do checks for the point we've got
    my $area_types;
    if ( $c->stash->{area_types} and scalar @{ $c->stash->{area_types} } ) {
        $area_types = $c->stash->{area_types};
    } else {
        $area_types = $c->cobrand->area_types;
    }

    my $all_areas;

    my %params;
    $params{generation} = $c->config->{MAPIT_GENERATION}
        if $c->config->{MAPIT_GENERATION};

    if ( $c->stash->{fetch_all_areas} ) {
        my %area_types = map { $_ => 1 } @$area_types;
        $all_areas =
          mySociety::MaPit::call( 'point',
            "4326/$longitude,$latitude", %params );
        $c->stash->{all_areas_mapit} = $all_areas;
        $all_areas = {
            map { $_ => $all_areas->{$_} }
            grep { $area_types{ $all_areas->{$_}->{type} } }
            keys %$all_areas
        };
    } else {
        $all_areas =
          mySociety::MaPit::call( 'point',
            "4326/$longitude,$latitude", %params,
            type => $area_types );
    }
    if ($all_areas->{error}) {
        $c->stash->{location_error_mapit_error} = 1;
        $c->stash->{location_error} = $all_areas->{error};
        return;
    }

    # Let cobrand do a check
    my ( $success, $error_msg ) =
      $c->cobrand->area_check( { all_areas => $all_areas },
        $c->stash->{area_check_action} );
    if ( !$success ) {
        $c->stash->{location_error_cobrand_check} = 1;
        $c->stash->{location_error} = $error_msg;
        return;
    }

    # edit hash in-place
    $c->cobrand->remove_redundant_areas($all_areas) if $c->stash->{remove_redundant_areas};

    # If we don't have any areas we can't accept the report
    if ( !scalar keys %$all_areas ) {
        $c->stash->{location_error_no_areas} = 1;
        $c->stash->{location_error} = _('That location does not appear to be covered by a council; perhaps it is offshore or outside the country. Please try again.');
        return;
    }

    # all good if we have some areas left
    $c->stash->{all_areas} = $all_areas;
    $c->stash->{all_area_names} =
      [ map { $_->{name} } values %$all_areas ];
    return 1;
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
