package FixMyStreet::App::Controller::Admin::AreaStats;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->forward('/admin/begin');
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->forward('/admin/fetch_all_bodies');
    } elsif ( $user->from_body ) {
        $c->forward('load_user_body', [ $user->from_body->id ]);
        $c->res->redirect( $c->uri_for( '', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub area : Path : Args(1) {
    my ($self, $c, $area_id) = @_;

    my $date = DateTime->now->subtract(days => 30);
    my $area = mySociety::MaPit::call('area', $area_id );

    if ($area->{name}) {
        $c->stash->{area} = $area;

        $c->stash->{open} = FixMyStreet::DB->resultset('Problem')->in_area($area_id, $date)->count;
        $c->stash->{scheduled} = FixMyStreet::DB->resultset('Problem')->planned_in_area($area_id, $date)->count;
        $c->stash->{closed} = FixMyStreet::DB->resultset('Problem')->closed_in_area($area_id, $date)->count;
        $c->stash->{fixed} = FixMyStreet::DB->resultset('Problem')->fixed_in_area($area_id, $date)->count;
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub load_user_body : Private {
    my ($self, $c, $body_id) = @_;

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found' );
}

1;
