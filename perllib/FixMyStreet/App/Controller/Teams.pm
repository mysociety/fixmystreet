package FixMyStreet::App::Controller::Admin::Teams;
use Moose;
use Data::Dumper;
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
        $c->forward('/admin/load_user_body', [ $user->from_body->id, 'user_edit' ]);
        $c->res->redirect( $c->uri_for( '', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub search : Path : Args(1) {
    my ($self, $c, $body_id) = @_;

    $c->forward('/admin/load_user_body', [ $body_id, 'user_edit' ]);
    $c->forward('/admin/fetch_contacts');
    $c->forward('/admin/fetch_body_areas', [ $c->stash->{body} ]);
    my %area_ids = map { $_->{id} => $_ } @{ $c->stash->{areas} };
    $c->log->debug(Dumper(\%area_ids));
    $c->stash->{areas_by_id} = \%area_ids;

    my $users = $c->cobrand->users->search({ from_body => $body_id });

    my @area_ids = $c->get_param_list("areas", 1);
    if ( @area_ids ) {
        $users = $users->search({ area_id => \@area_ids });
        my %area_ids = map { $_ => 1 } @area_ids;
        $c->stash->{selected_area_ids} = \%area_ids;
        $c->log->debug(Dumper([$c->stash->{selected_area_ids}]));
    }

    my @categories = $c->get_param_list("categories", 1);
    if ( @categories ) {
        my %categories = map { $_ => 1 } @categories;
        $c->stash->{selected_categories} = \%categories;
    }

    my @users = $users->all;
    $c->stash->{users} = [ @users ];

}

__PACKAGE__->meta->make_immutable;

1;
