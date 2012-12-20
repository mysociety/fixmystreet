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
    my $children = $body->bodies;

    if (!$parent) {
        return 'super';
    } elsif ($parent && $children) {
        return 'dm';
    } elsif ($parent) {
        return 'sdm';
    }
}

sub admin {
    my $self = shift;
    my $c = $self->{c};
    my $type = $self->admin_type();

    if ($type eq 'dm') {
        $c->stash->{template} = 'admin/index-dm.html';

        my $body = $c->stash->{body};
        my @children = map { $_->id } $body->bodies;
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
    }
}

sub admin_bodies {
    my $self = shift;
    my $c = $self->{c};
    my $type = $self->admin_type();

    if ($type eq 'dm') {
        my $body = $c->stash->{body};
        my @bodies = $c->model('DB::Body')->search( [ { parent => $body->parent->id }, { parent => $body->id } ] );
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
        $c->stash->{bodies} = \@bodies;
    }
}

1;
