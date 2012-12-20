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
    my $user = $c->user;
    my $body = $user->from_body;
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
    my $type = $self->admin_type();

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
        $c->stash->{approval} = $c->cobrand->problems->search({
            'me.state' => 'in progress',
            bodies_str => \@children,
            'comments.state' => 'unconfirmed'
        }, { join => 'comments', distinct => 1 } );
        $c->stash->{other} = $c->cobrand->problems->search({
            state => { '!=', 'unconfirmed' },
            bodies_str => \@all,
        });
    } elsif ($type eq 'sdm') {
        $c->stash->{template} = 'admin/index-sdm.html';

        my $body = $c->stash->{body};

        # XXX No multiples or missing bodies
        my $p = $c->cobrand->problems->search({
            'me.state' => 'in progress',
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
    my $type = $self->admin_type();

    my $problem = $c->stash->{problem};
    my $body = $c->stash->{body};

    my %allowed_bodies = map { $_->id => 1 } ( $body->bodies->all, $body );
    $c->detach( '/page_error_404_not_found' )
      unless $allowed_bodies{$problem->bodies_str};

    if ($type eq 'dm') {
        my @bodies = $c->model('DB::Body')->search( [ { parent => $body->parent->id }, { parent => $body->id } ] );
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;
    } elsif ($type eq 'sdm') {
        $c->stash->{template} = 'admin/report_edit-sdm.html';
        my @bodies = $c->model('DB::Body')->search( [ { id => $body->parent->id }, { id => $body->id } ] );
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;
    }

}

1;
