package FixMyStreet::Cobrand::Zurich;
use base 'FixMyStreet::Cobrand::Default';

use POSIX qw(strcoll);

use strict;
use warnings;

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Enter a Z&uuml;rich street name');
}

sub example_places {
    return [ 'Langstrasse', 'Basteiplatz' ];
}

# If lat/lon are in the URI, we must have zoom as well, otherwise OpenLayers defaults to 0.
sub uri {
    my ( $self, $uri ) = @_;

    $uri->query_param( zoom => 7 )
      if $uri->query_param('lat') && !$uri->query_param('zoom');
    return $uri;
}

sub remove_redundant_areas {
    my $self = shift;
    my $all_areas = shift;

    # Remove all except Zurich
    foreach (keys %$all_areas) {
        delete $all_areas->{$_} unless $_ eq 274456;
    }
}

sub show_unconfirmed_reports {
    1;
}

sub get_body_sender {
    my ( $self, $body, $category ) = @_;
    return { method => 'Zurich' };
}

# Specific administrative displays

sub admin_pages {
    my $self = shift;
    my $c = $self->{c};

    my $type = $c->stash->{admin_type};
    my $pages = {
        'summary' => [_('Summary'), 0],
        'reports' => [_('Reports'), 2],
        'report_edit' => [undef, undef],
        'update_edit' => [undef, undef],
    };
    return $pages if $type eq 'sdm';

    $pages = { %$pages,
        'bodies' => [_('Bodies'), 1],
        'body' => [undef, undef],
        'body_edit' => [undef, undef],
    };
    return $pages if $type eq 'dm';

    $pages = { %$pages,
        'users' => [_('Users'), 3],
        'user_edit' => [undef, undef],
    };
    return $pages if $type eq 'super';
}

sub admin_type {
    my $self = shift;
    my $c = $self->{c};
    my $body = $c->user->from_body;
    $c->stash->{body} = $body;

    my $parent = $body->parent;
    my $children = $body->bodies->count;

    my $type;
    if (!$parent) {
        $type = 'super';
    } elsif ($parent && $children) {
        $type = 'dm';
    } elsif ($parent) {
        $type = 'sdm';
    }

    $c->stash->{admin_type} = $type;
    return $type;
}

sub admin {
    my $self = shift;
    my $c = $self->{c};
    my $type = $c->stash->{admin_type};

    if ($type eq 'dm') {
        $c->stash->{template} = 'admin/index-dm.html';

        my $body = $c->stash->{body};
        my @children = map { $_->id } $body->bodies->all;
        my @all = (@children, $body->id);

        # XXX No multiples or missing bodies
        $c->stash->{unconfirmed} = $c->cobrand->problems->search({
            state => [ 'unconfirmed', 'confirmed' ],
            bodies_str => $c->stash->{body}->id,
        });
        $c->stash->{approval} = $c->cobrand->problems->search({
            state => 'planned',
            bodies_str => $c->stash->{body}->id,
        });
        $c->stash->{other} = $c->cobrand->problems->search({
            state => { -not_in => [ 'unconfirmed', 'confirmed', 'planned' ] },
            bodies_str => \@all,
        });
    } elsif ($type eq 'sdm') {
        $c->stash->{template} = 'admin/index-sdm.html';

        my $body = $c->stash->{body};

        # XXX No multiples or missing bodies
        $c->stash->{reports_new} = $c->cobrand->problems->search( {
            state => 'in progress',
            bodies_str => $body->id,
        } );
        $c->stash->{reports_unpublished} = $c->cobrand->problems->search( {
            state => 'planned',
            bodies_str => $body->parent->id,
        } );
        $c->stash->{reports_published} = $c->cobrand->problems->search( {
            state => 'fixed - council',
            bodies_str => $body->parent->id,
        } );
    }
}

sub admin_report_edit {
    my $self = shift;
    my $c = $self->{c};
    my $type = $c->stash->{admin_type};

    my $problem = $c->stash->{problem};
    my $body = $c->stash->{body};

    if ($type ne 'super') {
        my %allowed_bodies = map { $_->id => 1 } ( $body->bodies->all, $body );
        $c->detach( '/page_error_404_not_found' )
          unless $allowed_bodies{$problem->bodies_str};
    }

    if ($type eq 'super') {

        my @bodies = $c->model('DB::Body')->all();
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;

        # Can change category to any other
        my @categories = $c->model('DB::Contact')->not_deleted->all;
        $c->stash->{categories} = [ map { $_->category } @categories ];

    } elsif ($type eq 'dm') {

        # Can assign to:
        my @bodies = $c->model('DB::Body')->search( [
            { 'me.parent' => $body->parent->id }, # Other DMs on the same level
            { 'me.parent' => $body->id }, # Their subdivisions
            { 'me.parent' => undef, 'bodies.id' => undef }, # External bodies
        ], { join => 'bodies', distinct => 1 } );
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;

        # Can change category to any other
        my @categories = $c->model('DB::Contact')->not_deleted->all;
        $c->stash->{categories} = [ map { $_->category } @categories ];

    }

    # Problem updates upon submission
    if ( ($type eq 'super' || $type eq 'dm') && $c->req->param('submit') ) {
        $c->forward('check_token');

        # Predefine the hash so it's there for lookups
        # XXX Note you need to shallow copy each time you set it, due to a bug? in FilterColumn.
        my $extra = $problem->extra || {};
        $extra->{internal_notes} = $c->req->param('internal_notes');
        $extra->{publish_photo} = $c->req->params->{publish_photo} || 0;
        $extra->{third_personal} = $c->req->params->{third_personal} || 0;
        # Make sure we have a copy of the original detail field
        $extra->{original_detail} = $problem->detail unless $extra->{original_detail};
        $problem->extra( { %$extra } );

        # Workflow things
        my $redirect = 0;
        my $new_cat = $c->req->params->{category};
        if ( $new_cat && $new_cat ne $problem->category ) {
            my $cat = $c->model('DB::Contact')->search( { category => $c->req->params->{category} } )->first;
            $problem->category( $new_cat );
            $problem->bodies_str( $cat->body_id );
            $problem->whensent( undef );
            $redirect = 1 if $cat->body_id ne $body->id;
        } elsif ( my $subdiv = $c->req->params->{body_subdivision} ) {
            $problem->state( 'in progress' );
            $problem->bodies_str( $subdiv );
            $problem->whensent( undef );
            $redirect = 1;
        } elsif ( my $external = $c->req->params->{body_external} ) {
            $problem->state( 'closed' );
            $problem->bodies_str( $external );
            $problem->whensent( undef );
            $redirect = 1;
        } else {
            $problem->state( $c->req->params->{state} ) if $c->req->params->{state};
        }

        $problem->title( $c->req->param('title') );
        $problem->detail( $c->req->param('detail') );

        # Final, public, Update from DM
        if (my $update = $c->req->param('status_update')) {
            $extra->{public_response} = $update;
            $problem->extra( { %$extra } );
            if ($c->req->params->{publish_response}) {
                $problem->state( 'fixed - council' );
            }
        }

        $problem->lastupdate( \'ms_current_timestamp()' );
        $problem->update;

        $c->stash->{status_message} =
          '<p><em>' . _('Updated!') . '</em></p>';

        # do this here otherwise lastupdate and confirmed times
        # do not display correctly
        $problem->discard_changes;

        if ( $redirect ) {
            $c->detach('index');
        }

        $c->stash->{updates} = [ $c->model('DB::Comment')
          ->search( { problem_id => $problem->id }, { order_by => 'created' } )
          ->all ];

        return 1;
    }

    if ($type eq 'sdm') {

        # Has cut-down edit template for adding update and sending back up only
        $c->stash->{template} = 'admin/report_edit-sdm.html';

        if ($c->req->param('send_back')) {
            $c->forward('check_token');

            $problem->bodies_str( $body->parent->id );
            $problem->state( 'confirmed' );
            $problem->update;
            # log here
            $c->res->redirect( '/admin/summary' );

        } elsif ($c->req->param('submit')) {
            $c->forward('check_token');

            my $extra = $problem->extra || {};
            $extra->{internal_notes} ||= '';
            if ($c->req->param('internal_notes') && $c->req->param('internal_notes') ne $extra->{internal_notes}) {
                $extra->{internal_notes} = $c->req->param('internal_notes');
                $problem->extra( { %$extra } );
                $problem->update;
            }

            # Add new update from status_update
            if (my $update = $c->req->param('status_update')) {
                FixMyStreet::App->model('DB::Comment')->create( {
                    text => $update,
                    user => $c->user->obj,
                    state => 'unconfirmed',
                    problem => $problem,
                    mark_fixed => 0,
                    problem_state => 'fixed - council',
                    anonymous => 1,
                } );
            }

            $c->stash->{status_message} = '<p><em>' . _('Updated!') . '</em></p>';

            # If they clicked the no more updates button, we're done.
            if ($c->req->param('no_more_updates')) {
                $problem->bodies_str( $body->parent->id );
                $problem->whensent( undef );
                $problem->state( 'planned' );
                $problem->update;
                # log here
                $c->res->redirect( '/admin/summary' );
            }
        }

        $c->stash->{updates} = [ $c->model('DB::Comment')
            ->search( { problem_id => $problem->id }, { order_by => 'created' } )
            ->all ];

        return 1;

    }

    return 0;

}

1;
