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

# Specific administrative displays
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
            state => 'unconfirmed',
            bodies_str => $c->stash->{body}->id,
        });
        $c->stash->{approval} = $c->model('DB::Comment')->search({
            'problem.state' => 'in progress',
            'problem.bodies_str' => \@children,
            'me.state' => 'unconfirmed'
        }, { join => 'problem' } );
        $c->stash->{other} = $c->cobrand->problems->search({
            state => { '!=', 'unconfirmed' },
            bodies_str => \@all,
        });
    } elsif ($type eq 'sdm') {
        $c->stash->{template} = 'admin/index-sdm.html';

        my $body = $c->stash->{body};

        # XXX No multiples or missing bodies
        my $p = $c->cobrand->problems->search({
            'me.state' => [ 'in progress', 'fixed - council' ],
            bodies_str => $body->id,
        } );
        $c->stash->{reports_new} = $p->search({
            'comments.state' => undef
        }, { join => 'comments', distinct => 1 } );
        $c->stash->{reports_unpublished} = $p->search({
            'comments.state' => 'unconfirmed'
        }, { join => 'comments', distinct => 1 } );
        $c->stash->{reports_published} = $p->search({
            'comments.state' => 'confirmed'
        }, { join => 'comments', distinct => 1 } );
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

    } elsif ($type eq 'dm') {

        # Can assign to:
        my @bodies = $c->model('DB::Body')->search( [
            { 'me.parent' => $body->parent->id }, # Other DMs on the same level
            { 'me.parent' => $body->id }, # Their subdivisions
            { 'me.parent' => undef, 'bodies.id' => undef }, # External bodies
        ], { join => 'bodies', distinct => 1 } );
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;

    } elsif ($type eq 'sdm') {

        # Has cut-down edit template for adding update and sending back up only
        $c->stash->{template} = 'admin/report_edit-sdm.html';

        if ($c->req->param('send_back')) {
            $c->forward('check_token');

            $problem->bodies_str( $body->parent->id );
            $problem->state( 'unconfirmed' );
            $problem->update;

            # log here

            $c->res->redirect( '/admin/summary' );
            return 1;

        } elsif ($c->req->param('submit')) {
            $c->forward('check_token');

            # Add new update from status_update
            my $update = $c->req->param('status_update');
            FixMyStreet::App->model('DB::Comment')->create( {
                text => $update,
                user => $c->user->obj,
                state => 'unconfirmed',
                problem => $problem,
                mark_fixed => 0,
                problem_state => 'fixed - council',
                anonymous => 1,
            } );

            $c->stash->{status_message} = '<p><em>' . _('Updated!') . '</em></p>';

            $c->stash->{updates} = [ $c->model('DB::Comment')
                ->search( { problem_id => $problem->id }, { order_by => 'created' } )
                ->all ];

            return 1;
        }
    }

    return 0;

}

1;
