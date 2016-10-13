package FixMyStreet::App::Controller::My;
use Moose;
use namespace::autoclean;

use JSON::MaybeXS;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::My - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub begin : Private {
    my ($self, $c) = @_;
    $c->detach( '/auth/redirect' ) unless $c->user;
}

=head2 index

=cut

sub my : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{problems_rs} = $c->cobrand->problems->search(
        { user_id => $c->user->id });
    $c->forward('get_problems');
    $c->forward('get_updates');
    $c->forward('setup_page_data');
}

sub planned : Local : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach('/page_error_403_access_denied', [])
        unless $c->user->has_body_permission_to('planned_reports');

    $c->stash->{problems_rs} = $c->user->active_planned_reports;
    $c->forward('get_problems');
    $c->forward('setup_page_data');
}

sub get_problems : Private {
    my ($self, $c) = @_;

    my $p_page = $c->get_param('p') || 1;

    $c->forward( '/reports/stash_report_filter_status' );

    my $pins = [];
    my $problems = [];

    my $states = $c->stash->{filter_problem_states};
    my $params = {
        state => [ keys %$states ],
    };

    my $categories = [ $c->get_param_list('filter_category', 1) ];
    if ( @$categories ) {
        $params->{category} = $categories;
        $c->stash->{filter_category} = $categories;
    }

    my $rs = $c->stash->{problems_rs}->search( $params, {
        order_by => { -desc => 'confirmed' },
        rows => 50
    } )->page( $p_page );

    while ( my $problem = $rs->next ) {
        $c->stash->{has_content}++;
        push @$pins, $problem->pin_data($c, 'my', private => 1);
        push @$problems, $problem;
    }
    $c->stash->{problems_pager} = $rs->pager;
    $c->stash->{problems} = $problems;
    $c->stash->{pins} = $pins;
}

sub get_updates : Private {
    my ($self, $c) = @_;

    my $u_page = $c->get_param('u') || 1;
    my $rs = $c->user->comments->search(
        { state => 'confirmed' },
        {
            order_by => { -desc => 'confirmed' },
            rows => 50
        } )->page( $u_page );

    my @updates = $rs->all;
    $c->stash->{has_content} += scalar @updates;
    $c->stash->{updates} = \@updates;
    $c->stash->{updates_pager} = $rs->pager;
}

sub setup_page_data : Private {
    my ($self, $c) = @_;

    my @categories = $c->stash->{problems_rs}->search({}, {
        columns => [ 'category' ],
        distinct => 1,
        order_by => [ 'category' ],
    } )->all;
    @categories = map { $_->category } @categories;
    $c->stash->{filter_categories} = \@categories;

    $c->stash->{page} = 'my';
    my $pins = $c->stash->{pins};
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $pins->[0]{latitude},
        longitude => $pins->[0]{longitude},
        pins      => $pins,
        any_zoom  => 1,
    )
        if @$pins;
}

sub planned_change : Path('planned/change') {
    my ($self, $c) = @_;
    $c->forward('/auth/check_csrf_token');

    my $id = $c->get_param('id');
    $c->forward( '/report/load_problem_or_display_error', [ $id ] );

    my $change = $c->get_param('change');
    $c->detach('/page_error_403_access_denied', [])
        unless $change && $change =~ /add|remove/;

    if ($change eq 'add') {
        $c->user->add_to_planned_reports($c->stash->{problem});
    } elsif ($change eq 'remove') {
        $c->user->remove_from_planned_reports($c->stash->{problem});
    }

    if ($c->get_param('ajax')) {
        $c->res->content_type('application/json; charset=utf-8');
        $c->res->body(encode_json({ outcome => $change }));
    } else {
        $c->res->redirect( $c->uri_for_action('report/display', $id) );
    }
}

__PACKAGE__->meta->make_immutable;

1;
