package FixMyStreet::App::Controller::Report;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Report - display a report

=head1 DESCRIPTION

Show a report

=head1 ACTIONS

=head2 index

Redirect to homepage unless C<id> parameter in query, in which case redirect to
'/report/$id'.

=cut

sub index : Path('') : Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->req->param('id');

    my $uri =
        $id
      ? $c->uri_for( '/report', $id )
      : $c->uri_for('/');

    $c->res->redirect($uri);
}

=head2 report_display

Display a report.

=cut

sub display : Path('') : Args(1) {
    my ( $self, $c, $id ) = @_;

    if (
        $id =~ m{ ^ 3D (\d+) $ }x         # Some council with bad email software
        || $id =~ m{ ^(\d+) \D .* $ }x    # trailing garbage
      )
    {
        return $c->res->redirect( $c->uri_for($1), 301 );
    }

    $c->forward('load_problem_or_display_error', [ $id ] );
    $c->forward( 'load_updates' );
    $c->forward( 'format_problem_for_display' );
}

sub load_problem_or_display_error : Private {
    my ( $self, $c, $id ) = @_;

    # try to load a report if the id is a number
    my $problem
      = ( !$id || $id =~ m{\D} ) # is id non-numeric?
      ? undef                    # ...don't even search
      : $c->cobrand->problems->find( { id => $id } );

    # check that the problem is suitable to show.
    if ( !$problem || $problem->state eq 'unconfirmed' || $problem->state eq 'partial' ) {
        $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );
    }
    elsif ( $problem->state eq 'hidden' ) {
        $c->detach(
            '/page_error_410_gone',
            [ _('That report has been removed from FixMyStreet.') ]    #
        );
    }

    $c->stash->{problem} = $problem;
    return 1;
}

sub load_updates : Private {
    my ( $self, $c ) = @_;

    my $updates = $c->model('DB::Comment')->search(
        { problem_id => $c->stash->{problem}->id, state => 'confirmed' },
        { order_by => 'confirmed' }
    );

    $c->stash->{updates} = $updates;

    return 1;
}

sub format_problem_for_display : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    $c->stash->{banner} = $c->cobrand->generate_problem_banner($problem);

    $c->stash->{cobrand_alert_fields} = $c->cobrand->form_elements('/alerts');
    $c->stash->{cobrand_update_fields} =
      $c->cobrand->form_elements('/updateForm');

    ( $c->stash->{short_latitude}, $c->stash->{short_longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $problem->latitude, $problem->longitude );

    $c->stash->{report_name} = $c->req->param('name');

    unless ( $c->req->param('submit_update') ) {
        $c->stash->{add_alert} = 1;
    }

    $c->forward('generate_map_tags');

    return 1;
}

sub generate_map_tags : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    FixMyStreet::Map::display_map(
        $c,
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        pins      => $problem->used_map
        ? [ {
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            colour    => 'blue',
          } ]
        : [],
    );

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
