package FixMyStreet::App::Controller::Council;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Council - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 load_and_check_councils

Try to load councils for this location and check that we have at least one. If
there are no councils then return false.

=cut

sub load_and_check_councils : Private {
    my ( $self, $c, $action ) = @_;
    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    # Look up councils and do checks for the point we've got
    my @area_types = $c->cobrand->area_types();

    # TODO: I think we want in_gb_locale around the next line, needs testing
    my $all_councils =
      mySociety::MaPit::call( 'point', "4326/$longitude,$latitude",
        type => \@area_types );

    # Let cobrand do a check
    my ( $success, $error_msg ) =
      $c->cobrand->council_check( { all_councils => $all_councils },
        $action );
    if ( !$success ) {
        $c->stash->{location_error} = $error_msg;
        return;
    }

    # edit hash in-place
    _remove_redundant_councils($all_councils);

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

# TODO - should not be here.
# These are country specific tweaks that should be in the cobrands
sub _remove_redundant_councils {
    my $all_councils = shift;

    # UK specific tweaks
    if ( FixMyStreet->config('COUNTRY') eq 'GB' ) {

        # Ipswich & St Edmundsbury are responsible for everything in their
        # areas, not Suffolk
        delete $all_councils->{2241}
          if $all_councils->{2446}    #
              || $all_councils->{2443};

        # Norwich is responsible for everything in its areas, not Norfolk
        delete $all_councils->{2233}    #
          if $all_councils->{2391};
    }

    # Norway specific tweaks
    if ( FixMyStreet->config('COUNTRY') eq 'NO' ) {

        # Oslo is both a kommune and a fylke, we only want to show it once
        delete $all_councils->{301}     #
          if $all_councils->{3};
    }

}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
