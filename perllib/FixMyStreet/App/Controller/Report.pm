package FixMyStreet::App::Controller::Report;

use Moose;
use namespace::autoclean;
use JSON::MaybeXS;

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

    my $id = $c->get_param('id');

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

    $c->forward( '_display', [ $id ] );
}

=head2 ajax

Return JSON formatted details of a report

=cut

sub ajax : Path('ajax') : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->stash->{ajax} = 1;
    $c->forward( '_display', [ $id ] );
}

sub _display : Private {
    my ( $self, $c, $id ) = @_;

    $c->forward( 'load_problem_or_display_error', [ $id ] );
    $c->forward( 'load_updates' );
    $c->forward( 'format_problem_for_display' );
}

sub support : Path('support') : Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->get_param('id');

    my $uri =
        $id
      ? $c->uri_for( '/report', $id )
      : $c->uri_for('/');

    if ( $id && $c->cobrand->can_support_problems && $c->user && $c->user->from_body ) {
        $c->forward( 'load_problem_or_display_error', [ $id ] );
        $c->stash->{problem}->update( { interest_count => \'interest_count +1' } );
    }
    $c->res->redirect( $uri );
}

sub load_problem_or_display_error : Private {
    my ( $self, $c, $id ) = @_;

    # try to load a report if the id is a number
    my $problem
      = ( !$id || $id =~ m{\D} ) # is id non-numeric?
      ? undef                    # ...don't even search
      : $c->cobrand->problems->find( { id => $id } )
          or $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );

    # check that the problem is suitable to show.
    # hidden_states includes partial and unconfirmed, but they have specific handling,
    # so we check for them first.
    if ( $problem->state eq 'partial' ) {
        $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );
    }
    elsif ( $problem->state eq 'unconfirmed' ) {
        $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] )
            unless $c->cobrand->show_unconfirmed_reports ;
    }
    elsif ( $problem->hidden_states->{ $problem->state } or 
            (($problem->get_extra_metadata('closure_status')||'') eq 'hidden')) {
        $c->detach(
            '/page_error_410_gone',
            [ _('That report has been removed from FixMyStreet.') ]    #
        );
    } elsif ( $problem->non_public ) {
        if ( !$c->user || $c->user->id != $problem->user->id ) {
            $c->detach(
                '/page_error_403_access_denied',
                [ sprintf(_('That report cannot be viewed on %s.'), $c->stash->{site_name}) ]
            );
        }
    }

    $c->stash->{problem} = $problem;
    if ( $c->user_exists && $c->user->has_permission_to(moderate => $problem->bodies_str) ) {
        $c->stash->{problem_original} = $problem->find_or_new_related(
            moderation_original_data => {
                title => $problem->title,
                detail => $problem->detail,
                photo => $problem->photo,
                anonymous => $problem->anonymous,
            }
        );
    }

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

    if ($c->sessionid && $c->flash->{alert_to_reporter}) {
        $c->stash->{alert_to_reporter} = 1;
    }

    return 1;
}

sub format_problem_for_display : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    ( $c->stash->{latitude}, $c->stash->{longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $problem->latitude, $problem->longitude );

    unless ( $c->get_param('submit_update') ) {
        $c->stash->{add_alert} = 1;
    }

    $c->stash->{extra_name_info} = $problem->bodies_str && $problem->bodies_str eq '2482' ? 1 : 0;

    $c->forward('generate_map_tags');

    if ( $c->stash->{ajax} ) {
        $c->res->content_type('application/json; charset=utf-8');
        my $content = encode_json(
            {
                report => $c->cobrand->problem_as_hashref( $problem, $c ),
                updates => $c->cobrand->updates_as_hashref( $problem, $c ),
            }
        );
        $c->res->body( $content );
        return 1;
    }

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
            colour    => $c->cobrand->pin_colour($problem, 'report'),
            type      => 'big',
          } ]
        : [],
    );

    return 1;
}

=head2 delete

Endpoint for the council report hiding feature enabled for
C<users_can_hide> bodies, and Bromley. The latter is migrating
to moderation, however we'd need to inform all the other
users too about this change, at which point we can delete:

 - this method
 - the call to it in templates/web/base/report/display_tools.html
 - the users_can_hide cobrand method, in favour of user->has_permission_to

=cut

sub delete :Local :Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->forward( 'load_problem_or_display_error', [ $id ] );
    my $p = $c->stash->{problem};

    my $uri = $c->uri_for( '/report', $id );

    return $c->res->redirect($uri) unless $c->user_exists;

    my $body = $c->user->obj->from_body;
    return $c->res->redirect($uri) unless $body;

    return $c->res->redirect($uri) unless $p->bodies->{$body->id};

    $p->state('hidden');
    $p->lastupdate( \'current_timestamp' );
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
