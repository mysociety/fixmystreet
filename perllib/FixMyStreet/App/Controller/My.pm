package FixMyStreet::App::Controller::My;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::My - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub my : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach( '/auth/redirect' ) unless $c->user;

    my $p_page = $c->req->params->{p} || 1;
    my $u_page = $c->req->params->{u} || 1;

    my $states = $c->cobrand->on_map_default_states;
    $c->stash->{filter_status} = $c->cobrand->on_map_default_status;
    my $status = $c->req->param('status') || '';
    if ( !defined $states || $status eq 'all' ) {
        $states = FixMyStreet::DB::Result::Problem->visible_states();
        $c->stash->{filter_status} = 'all';
    } elsif ( $status eq 'open' ) {
        $states = FixMyStreet::DB::Result::Problem->open_states();
        $c->stash->{filter_status} = 'open';
    } elsif ( $status eq 'fixed' ) {
        $states = FixMyStreet::DB::Result::Problem->fixed_states();
        $c->stash->{filter_status} = 'fixed';
    }

    my $pins = [];
    my $problems = {};


    my $params = {
        state => [ keys %$states ],
    };
    $params = {
        %{ $c->cobrand->problems_clause },
        %$params
    } if $c->cobrand->problems_clause;

    my $category = $c->req->param('category');
    if ( $category ) {
        $params->{category} = $category;
        $c->stash->{filter_category} = $category;
    }

    my $rs = $c->user->problems->search( $params, {
        order_by => { -desc => 'confirmed' },
        rows => 50
    } )->page( $p_page );

    while ( my $problem = $rs->next ) {
        $c->stash->{has_content}++;
        push @$pins, {
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            colour    => $c->cobrand->pin_colour( $problem, 'my' ),
            id        => $problem->id,
            title     => $problem->title,
        };
        my $state = $problem->is_fixed ? 'fixed' : $problem->is_closed ? 'closed' : 'confirmed';
        push @{ $problems->{$state} }, $problem;
        push @{ $problems->{all} }, $problem;
    }
    $c->stash->{problems_pager} = $rs->pager;
    $c->stash->{problems} = $problems;

    $rs = $c->user->comments->search(
        { state => 'confirmed' },
        {
            order_by => { -desc => 'confirmed' },
            rows => 50
        } )->page( $u_page );

    my @updates = $rs->all;
    $c->stash->{has_content} += scalar @updates;
    $c->stash->{updates} = \@updates;
    $c->stash->{updates_pager} = $rs->pager;

    my @categories = $c->user->problems->search( undef, {
        columns => [ 'category' ],
        distinct => 1,
        order_by => [ 'category' ],
    } )->all;
    @categories = map { $_->category } @categories;
    $c->stash->{filter_categories} = \@categories;

    $c->stash->{page} = 'my';
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $pins->[0]{latitude},
        longitude => $pins->[0]{longitude},
        pins      => $pins,
        any_zoom  => 1,
    )
        if @$pins;
}

__PACKAGE__->meta->make_immutable;

1;
