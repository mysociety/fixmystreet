package FixMyStreet::App::Controller::Admin::Templates;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Admin::Templates - Catalyst Controller

=head1 DESCRIPTION

Admin pages for response templates

=head1 METHODS

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->forward('/admin/fetch_all_bodies');
    } elsif ( $user->from_body ) {
        $c->forward('load_template_body', [ $user->from_body->id ]);
        $c->res->redirect( $c->uri_for_action( '/admin/templates/view', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found', [] );
    }
}

sub view : Path : Args(1) {
    my ($self, $c, $body_id) = @_;

    $c->forward('load_template_body', [ $body_id ]);

    my @templates = $c->stash->{body}->response_templates->search(
        undef,
        {
            order_by => 'title'
        }
    );

    $c->stash->{response_templates} = \@templates;
}

sub edit : Path : Args(2) {
    my ( $self, $c, $body_id, $template_id ) = @_;

    $c->forward('load_template_body', [ $body_id ]);

    my $template;
    if ($template_id eq 'new') {
        $template = $c->stash->{body}->response_templates->new({});
    }
    else {
        $template = $c->stash->{body}->response_templates->find( $template_id )
            or $c->detach( '/page_error_404_not_found', [] );
    }

    $c->forward('/admin/fetch_contacts');
    my @contacts = $template->contacts->all;
    my @live_contacts = $c->stash->{live_contacts}->all;
    my %active_contacts = map { $_->id => 1 } @contacts;
    my @all_contacts = map { {
        id => $_->id,
        category => $_->category_display,
        active => $active_contacts{$_->id},
        email => $_->email,
        group => $_->get_extra_metadata('group') // '',
    } } @live_contacts;
    $c->stash->{contacts} = \@all_contacts;
    $c->forward('/report/stash_category_groups', [ \@all_contacts, 1 ]) if $c->cobrand->enable_category_groups;

    # bare block to use 'last' if form is invalid.
    if ($c->req->method eq 'POST') { {
        if ($c->get_param('delete_template') && $c->get_param('delete_template') eq _("Delete template")) {
            $template->contact_response_templates->delete_all;
            $template->delete;
            $c->forward('/admin/log_edit', [ $template->id, 'template', 'delete' ]);
        } else {
            my @live_contact_ids = map { $_->id } @live_contacts;
            my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @live_contact_ids;
            my %new_contacts = map { $_ => 1 } @new_contact_ids;
            for my $contact (@all_contacts) {
                $contact->{active} = $new_contacts{$contact->{id}};
            }

            $template->title( $c->get_param('title') );
            my $query = { title => $template->title };
            if ($template->in_storage) {
                $query->{id} = { '!=', $template->id };
            }
            if ($c->stash->{body}->response_templates->search($query)->count) {
                $c->stash->{errors} ||= {};
                $c->stash->{errors}->{title} = _("There is already a template with that title.");
            }

            $template->text( $c->get_param('text') );
            $template->state( $c->get_param('state') );
            $template->external_status_code( $c->get_param('external_status_code') );

            if ( $template->state && $template->external_status_code ) {
                $c->stash->{errors} ||= {};
                $c->stash->{errors}->{state} = _("State and external status code cannot be used simultaneously.");
                $c->stash->{errors}->{external_status_code} = _("State and external status code cannot be used simultaneously.");
            }

            $template->auto_response( $c->get_param('auto_response') && ( $template->state || $template->external_status_code ) ? 1 : 0 );
            if ($template->auto_response) {
                my @check_contact_ids = @new_contact_ids;
                # If the new template has not specific categories (i.e. it
                # applies to all categories) then we need to check each of those
                # category ids for existing auto-response templates.
                if (!scalar @check_contact_ids) {
                    @check_contact_ids = @live_contact_ids;
                }
                my $query = {
                    'auto_response' => 1,
                    'contact.id' => [ @check_contact_ids, undef ],
                    -or => {
                        $template->state ? ('me.state' => $template->state) : (),
                        $template->external_status_code ? ('me.external_status_code' => $template->external_status_code) : (),
                    },
                };
                if ($template->in_storage) {
                    $query->{'me.id'} = { '!=', $template->id };
                }
                if ($c->stash->{body}->response_templates->search($query, {
                    join => { 'contact_response_templates' => 'contact' },
                })->count) {
                    $c->stash->{errors} ||= {};
                    $c->stash->{errors}->{auto_response} = _("There is already an auto-response template for this category/state.");
                }
            }

            last if $c->stash->{errors};

            $template->update_or_insert;
            $template->contact_response_templates->search({
                contact_id => { -not_in => \@new_contact_ids },
            })->delete;
            foreach my $contact_id (@new_contact_ids) {
                $template->contact_response_templates->find_or_create({
                    contact_id => $contact_id,
                });
            }
            my $action = $template_id eq 'new' ? 'add' : 'edit';
            $c->forward('/admin/log_edit', [ $template->id, 'template', $action ]);
        }

        $c->res->redirect( $c->uri_for_action( '/admin/templates/view', $c->stash->{body}->id ) );
    } }

    $c->stash->{response_template} = $template;
}

sub load_template_body : Private {
    my ($self, $c, $body_id) = @_;

    my $zurich_user = $c->user->from_body && $c->cobrand->moniker eq 'zurich';
    my $has_permission = $c->user->has_body_permission_to('template_edit', $body_id);

    unless ( $zurich_user || $has_permission ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    # Regular users can only view their own body's templates
    if ( !$c->user->is_superuser && $body_id ne $c->user->from_body->id ) {
        $c->res->redirect( $c->uri_for_action( '/admin/templates/view', $c->user->from_body->id ) );
    }

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found', [] );
}

__PACKAGE__->meta->make_immutable;

1;
