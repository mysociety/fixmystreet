package FixMyStreet::App::Controller::Council;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Council - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 load_and_check_councils_and_wards

Try to load councils and wards for this location and check that we have at least one. If
there are no councils then return false.

=cut

sub load_and_check_councils_and_wards : Private {
    my ( $self, $c ) = @_;
    my @area_types = ( $c->cobrand->area_types(), @$mySociety::VotingArea::council_child_types );
    $c->stash->{area_types} = \@area_types;
    $c->forward('load_and_check_councils');
}

=head2 load_and_check_councils

Try to load councils for this location and check that we have at least one. If
there are no councils then return false.

=cut

sub load_and_check_councils : Private {
    my ( $self, $c ) = @_;
    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    # Look up councils and do checks for the point we've got
    my @area_types;
    if ( $c->stash->{area_types} and scalar @{ $c->stash->{area_types} } ) {
      @area_types = @{ $c->stash->{area_types} };
    } else {
      @area_types = $c->cobrand->area_types();
    }

    # TODO: I think we want in_gb_locale around the MaPit line, needs testing
    my $all_councils;
    if ( $c->stash->{fetch_all_areas} ) {
        my %area_types = map { $_ => 1 } @area_types;
        my $all_areas =
          mySociety::MaPit::call( 'point', "4326/$longitude,$latitude" );
        $c->stash->{all_areas} = $all_areas;
        $all_councils = {
            map { $_ => $all_areas->{$_} }
            grep { $area_types{ $all_areas->{$_}->{type} } }
            keys %$all_areas
        };
    } else {
        $all_councils =
          mySociety::MaPit::call( 'point', "4326/$longitude,$latitude",
            type => \@area_types );
    }

    # Let cobrand do a check
    my ( $success, $error_msg ) =
      $c->cobrand->council_check( { all_councils => $all_councils },
        $c->stash->{council_check_action} );
    if ( !$success ) {
        $c->stash->{location_error} = $error_msg;
        return;
    }

    # edit hash in-place
    $c->cobrand->remove_redundant_councils($all_councils) if $c->stash->{remove_redundant_councils};

    # If we don't have any councils we can't accept the report
    if ( !scalar keys %$all_councils ) {
        $c->stash->{location_offshore} = 1;
        return;
    }

    # all good if we have some councils left
    $c->stash->{all_councils} = $all_councils;
    $c->stash->{all_council_names} =
      [ map { $_->{name} } values %$all_councils ];
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
