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
        $c->res->redirect( $c->uri_for( '/admin/areastats/body', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub body : Path('body') : Args(1) {
    my ($self, $c, $body_id) = @_;
    $c->stash->{areas} = mySociety::MaPit::call('area/children', [ $body_id ] );
}

sub area : Path : Args(1) {
    my ($self, $c, $area_id) = @_;

    my $date = DateTime->now->subtract(days => 30);
    my $area = mySociety::MaPit::call('area', $area_id );
    my $user = $c->user;

    $c->forward('load_user_body', [ $user->from_body->id ]);
    $c->forward('/admin/fetch_contacts');

    if ($area->{name}) {
        $c->stash->{area} = $area;

        my @open = FixMyStreet::DB->resultset('Problem')->in_area($area_id, $date)->all;
        my @scheduled = FixMyStreet::DB->resultset('Problem')->planned_in_area($area_id, $date)->all;
        my @closed = FixMyStreet::DB->resultset('Problem')->closed_in_area($area_id, $date)->all;
        my @fixed = FixMyStreet::DB->resultset('Problem')->fixed_in_area($area_id, $date)->all;
        my $by_category = {};

        foreach my $contact ($c->stash->{live_contacts}->all) {
            $by_category->{$contact->category} = {};
            $by_category->{$contact->category}->{open} = scalar(grep { $_->category eq $contact->category } @open);
            $by_category->{$contact->category}->{scheduled} = scalar(grep { $_->category eq $contact->category } @scheduled);
            $by_category->{$contact->category}->{closed} = scalar(grep { $_->category eq $contact->category } @closed);
            $by_category->{$contact->category}->{fixed} = scalar(grep { $_->category eq $contact->category } @fixed);
            # Remove hash if count is zero for all states
            my $count = scalar(grep { $by_category->{$contact->category}{$_} == 0 } keys(%{$by_category->{$contact->category}}));
            if ($count == 4) {
                delete $by_category->{$contact->category};
            }
        }

        $c->stash->{open} = scalar(@open);
        $c->stash->{scheduled} = scalar(@scheduled);
        $c->stash->{closed} = scalar(@closed);
        $c->stash->{fixed} = scalar(@fixed);
        $c->stash->{by_category} = $by_category;
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
