package FixMyStreet::App::Controller::Admin::DefectTypes;
use Moose;
use namespace::autoclean;
use mySociety::ArrayUtils;

BEGIN { extends 'Catalyst::Controller'; }


sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->stash->{with_defect_type_count} = 1;
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

    my @defect_types = $c->stash->{body}->defect_types->search(
        undef,
        {
            order_by => 'name'
        }
    );

    $c->stash->{defect_types} = \@defect_types;
}

sub edit : Path : Args(2) {
    my ( $self, $c, $body_id, $defect_type_id ) = @_;

    $c->forward('load_user_body', [ $body_id ]);

    my $defect_type;
    if ($defect_type_id eq 'new') {
        $defect_type = $c->stash->{body}->defect_types->new({});
    }
    else {
        $defect_type = $c->stash->{body}->defect_types->find( $defect_type_id )
            or $c->detach( '/page_error_404_not_found' );
    }

    $c->forward('/admin/fetch_contacts');
    my @contacts = $defect_type->contacts->all;
    my @live_contacts = $c->stash->{live_contacts}->all;
    my %active_contacts = map { $_->id => 1 } @contacts;
    my @all_contacts = map { {
        id => $_->id,
        category => $_->category_display,
        active => $active_contacts{$_->id},
    } } @live_contacts;
    $c->stash->{contacts} = \@all_contacts;

    if ($c->req->method eq 'POST') {
        $defect_type->name( $c->get_param('name') );
        $defect_type->description( $c->get_param('description') );

        my @extra_fields = @{ $c->cobrand->call_hook('defect_type_extra_fields') || [] };
        foreach ( @extra_fields ) {
            $defect_type->set_extra_metadata( $_ => $c->get_param("extra[$_]") );
        }

        $defect_type->update_or_insert;
        my @live_contact_ids = map { $_->id } @live_contacts;
        my @new_contact_ids = $c->get_param_list('categories');
        @new_contact_ids = @{ mySociety::ArrayUtils::intersection(\@live_contact_ids, \@new_contact_ids) };
        $defect_type->contact_defect_types->search({
            contact_id => { -not_in => \@new_contact_ids },
        })->delete;
        foreach my $contact_id (@new_contact_ids) {
            $defect_type->contact_defect_types->find_or_create({
                contact_id => $contact_id,
            });
        }

        $c->res->redirect( $c->uri_for( '', $c->stash->{body}->id ) );
    }

    $c->stash->{defect_type} = $defect_type;
}

sub load_user_body : Private {
    my ($self, $c, $body_id) = @_;

    my $has_permission = $c->user->has_body_permission_to('defect_type_edit', $body_id);

    unless ( $has_permission ) {
        $c->detach( '/page_error_404_not_found' );
    }

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found' );
}

__PACKAGE__->meta->make_immutable;

1;
