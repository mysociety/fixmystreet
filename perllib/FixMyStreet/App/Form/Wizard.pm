package FixMyStreet::App::Form::Wizard;
# ABSTRACT: create a multi-page form, based on HTML::FormHandler::Wizard, but not numbered

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with ('HTML::FormHandler::BuildPages', 'HTML::FormHandler::Pages' );

sub is_wizard { 1 } # So build_active is called

sub build_page_name_space { 'FixMyStreet::App::Form::Page' }
has '+field_name_space' => ( default => 'FixMyStreet::App::Form::Field' );

# Internal attributes and fields to handle multi-page forms
has page_name => ( is => 'ro', isa => 'Str' );
has current_page => ( is => 'ro', lazy => 1,
    default => sub { $_[0]->page($_[0]->page_name) },
    predicate => 'has_current_page',
);

has c => ( is => 'ro', weak_ref => 1 );

has saved_data_encoded => ( is => 'ro', isa => 'Maybe[Str]' );
has saved_data => ( is => 'rw', lazy => 1, isa => 'HashRef', default => sub {
    $_[0]->field('saved_data')->inflate_json($_[0]->saved_data_encoded) || {};
});
has previous_form => ( is => 'ro', isa => 'Maybe[HTML::FormHandler]', weak_ref => 1 );
has csrf_token => ( is => 'ro', isa => 'Str' );

has already_submitted_error => ( is => 'rw', isa => 'Bool', default => 0 );

has_field saved_data => ( type => 'JSON' );
has_field token => ( type => 'Hidden', required => 1 );
has_field process => ( type => 'Hidden', required => 1 );

has unique_id_session => ( is => 'ro', isa => 'Maybe[Str]' );
has unique_id_form => ( is => 'ro', isa => 'Maybe[Str]' );
has_field unique_id => ( type => 'Hidden', required => 0 );

sub has_page_called {
    my ($self, $page_name) = @_;

    return grep { $_->name eq $page_name } $self->all_pages;
}

sub get_params {
    my ($self, $c) = @_;

    return $c->req->body_params;
}

sub next {
    my $self = shift;
    my $next = $self->current_page->next;
    if (ref $next eq 'CODE') {
        $next = $next->(
            $self->saved_data,
            $self->c->req->params,
        );
    }
    return $next;
}

# Override HFH default and set current page only to active
sub build_active {
    my $self = shift;

    my %active;
    foreach my $fname ($self->current_page->all_fields) {
        $active{$fname} = 1;
    }

    foreach my $page ( $self->all_pages ) {
        foreach my $fname ( $page->all_fields_copy ) {
            my $field = $self->field($fname);
            $field->inactive(1) unless $active{$fname};
        }
    }
}

# Stuff to set up as soon as we have a form
sub after_build {
    my $self = shift;
    my $page = $self->current_page;

    my $saved_data = $self->previous_form ? $self->previous_form->saved_data : $self->saved_data;

    $self->init_object($saved_data); # For filling in existing values
    $self->saved_data($saved_data);

    # Fill in internal fields
    $self->update_field(saved_data => { default => $saved_data });
    $self->update_field(token => { default => $self->csrf_token });
    $self->update_field(process => { default => $page->name });
    $self->update_field(unique_id => { default => $self->unique_id_session });

    # Update field list with any dynamic things (eg user-based, address lookup, geocoding)
    my $updates = {};
    if ($page->has_update_field_list) {
        $updates = $page->update_field_list->($self) || {};
    }
    foreach my $fname ($self->current_page->all_fields) {
        if ($self->field($fname)->type eq 'Photo') {
            $self->update_photo($fname, $updates);
        }
    }
    foreach my $field_name (keys %$updates) {
        $self->update_field($field_name, $updates->{$field_name});
    }
}

# After a form has been processed, run any post process functions
after 'process' => sub {
    my $self = shift;
    my $page = $self->current_page;
    $page->post_process->($self) if $page->post_process;
};

after 'validate_form' => sub {
    my $self = shift;

    if ($self->validated) {
        my $page = $self->current_page;

        # Mismatch of unique ID, resubmission?
        if ($self->unique_id_session && $page->check_unique_id && $self->unique_id_session ne ($self->unique_id_form || '')) {
            $self->add_form_error('You have already submitted this form.');
            $self->already_submitted_error(1);
            return;
        }

        # Update saved_data for the next page
        my $saved_data = { %{$self->saved_data}, %{$self->value} };
        delete $saved_data->{process};
        delete $saved_data->{token};
        delete $saved_data->{saved_data};
        delete $saved_data->{unique_id};
        $self->saved_data($saved_data);
        $self->field('saved_data')->_set_value($saved_data);

        # A pre_finished lets a form pass validation but not actually finish
        if ($page->pre_finished) {
            my $success = $page->pre_finished->($self);
            return unless $success;
        }

        # And check to see if there is a function to call on the page
        if ($page->finished) {
            my $success = $page->finished->($self);
            if (!$success) {
                $self->add_form_error('Something went wrong, please try again')
                    unless $self->has_form_errors;
            } else {
                delete $self->c->session->{form_unique_id};
            }
        }
    }
};

sub process_photo {
    my ($form, $field) = @_;

    my $saved_data = $form->saved_data;
    my $fileid = $field . '_fileid';
    my $c = $form->{c};
    $c->stash->{photo_upload_prefix} = $field;
    $c->stash->{photo_upload_fileid_field} = $fileid;
    $c->forward('/photo/process_photo');
    $saved_data->{$field} = $c->stash->{$fileid};
    $saved_data->{$fileid} = '';
}

sub update_photo {
    my ($form, $field, $fields) = @_;
    my $saved_data = $form->saved_data;

    if ($saved_data->{$field}) {
        my $fileid = $field . '_fileid';
        $saved_data->{$fileid} = $saved_data->{$field};
        $fields->{$fileid} = { default => $saved_data->{$field} };
    }
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
