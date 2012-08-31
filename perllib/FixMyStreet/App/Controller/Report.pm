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

    $c->forward( 'load_problem_or_display_error', [ $id ] );
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
    } elsif ( $problem->non_public ) {
        $c->detach(
            '/page_error_403_access_denied',
            [ _('That report cannot be viewed on FixMyStreet.') ]    #
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

    my $questionnaires = $c->model('DB::Questionnaire')->search(
        {
            problem_id => $c->stash->{problem}->id,
            whenanswered => { '!=', undef },
            old_state => 'confirmed', new_state => 'confirmed',
        },
        { order_by => 'whenanswered' }
    );

    my @combined;
    while (my $update = $updates->next) {
        push @combined, [ $update->confirmed, $update ];
    }
    while (my $update = $questionnaires->next) {
        push @combined, [ $update->whenanswered, $update ];
    }
    @combined = map { $_->[1] } sort { $a->[0] <=> $b->[0] } @combined;
    $c->stash->{updates} = \@combined;

    return 1;
}

sub format_problem_for_display : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    ( $c->stash->{short_latitude}, $c->stash->{short_longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $problem->latitude, $problem->longitude );

    unless ( $c->req->param('submit_update') ) {
        $c->stash->{add_alert} = 1;
    }

    $c->stash->{extra_name_info} = $problem->council && $problem->council eq '2482' ? 1 : 0;

    $c->forward('generate_map_tags');

    return 1;
}

sub generate_map_tags : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    $c->stash->{page} = 'report';
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        pins      => $problem->used_map
        ? [ {
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            colour    => 'yellow',
            type      => 'big',
          } ]
        : [],
    );

    return 1;
}

sub delete :Local :Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->forward( 'load_problem_or_display_error', [ $id ] );
    my $p = $c->stash->{problem};

    my $uri = $c->uri_for( '/report', $id );

    return $c->res->redirect($uri) unless $c->user_exists;

    my $council = $c->user->obj->from_council;
    return $c->res->redirect($uri) unless $council;

    my %councils = map { $_ => 1 } @{$p->councils};
    return $c->res->redirect($uri) unless $councils{$council};

    $p->state('hidden');
    $p->lastupdate( \'ms_current_timestamp()' );
    $p->update;

    $c->model('DB::AdminLog')->create( {
        admin_user => $c->user->email,
        object_type => 'problem',
        action => 'state_change',
        object_id => $id,
    } );

    return $c->res->redirect($uri);
}

__PACKAGE__->meta->make_immutable;

1;
