package FixMyStreet::App::Controller::Admin::ResponsePriorities;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }


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

sub list : Path : Args(1) {
    my ($self, $c, $body_id) = @_;

    $c->forward('load_user_body', [ $body_id ]);

    my @priorities = $c->stash->{body}->response_priorities->search(
        undef,
        {
            order_by => 'name'
        }
    );

    $c->stash->{response_priorities} = \@priorities;
}

sub edit : Path : Args(2) {
    my ( $self, $c, $body_id, $priority_id ) = @_;

    $c->forward('load_user_body', [ $body_id ]);

    my $priority;
    if ($priority_id eq 'new') {
        $priority = $c->stash->{body}->response_priorities->new({});
    }
    else {
        $priority = $c->stash->{body}->response_priorities->find( $priority_id )
            or $c->detach( '/page_error_404_not_found' );
    }

    $c->forward('/admin/fetch_contacts');
    my @contacts = $priority->contacts->all;
    my @live_contacts = $c->stash->{live_contacts}->all;
    my %active_contacts = map { $_->id => 1 } @contacts;
    my @all_contacts = map { {
        id => $_->id,
        category => $_->category,
        active => $active_contacts{$_->id},
    } } @live_contacts;
    $c->stash->{contacts} = \@all_contacts;

    if ($c->req->method eq 'POST') {
        $priority->deleted( $c->get_param('deleted') ? 1 : 0 );
        $priority->name( $c->get_param('name') );
        $priority->description( $c->get_param('description') );
        $priority->external_id( $c->get_param('external_id') );
        $priority->is_default( $c->get_param('is_default') ? 1 : 0 );
        $priority->update_or_insert;

        my @live_contact_ids = map { $_->id } @live_contacts;
        my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @live_contact_ids;
        $priority->contact_response_priorities->search({
            contact_id => { '!=' => \@new_contact_ids },
        })->delete;
        foreach my $contact_id (@new_contact_ids) {
            $priority->contact_response_priorities->find_or_create({
                contact_id => $contact_id,
            });
        }

        $c->res->redirect( $c->uri_for( '', $c->stash->{body}->id ) );
    }

    $c->stash->{response_priority} = $priority;
}

sub load_user_body : Private {
    my ($self, $c, $body_id) = @_;

    my $has_permission = $c->user->has_body_permission_to('responsepriority_edit', $body_id);

    unless ( $has_permission ) {
        $c->detach( '/page_error_404_not_found' );
    }

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found' );
}

__PACKAGE__->meta->make_immutable;

1;
