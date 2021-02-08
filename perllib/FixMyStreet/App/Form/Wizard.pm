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

has saved_data_encoded => ( is => 'ro', isa => 'Maybe[Str]' );
has saved_data => ( is => 'rw', lazy => 1, isa => 'HashRef', default => sub {
    $_[0]->field('saved_data')->inflate_json($_[0]->saved_data_encoded) || {};
});
has previous_form => ( is => 'ro', isa => 'Maybe[HTML::FormHandler]' );
has csrf_token => ( is => 'ro', isa => 'Str' );

has_field saved_data => ( type => 'JSON' );
has_field token => ( type => 'Hidden', required => 1 );
has_field process => ( type => 'Hidden', required => 1 );

sub get_params {
    my ($self, $c) = @_;

    return $c->req->body_params;
}

sub next {
    my $self = shift;
    my $next = $self->current_page->next;
    if (ref $next eq 'CODE') {
        $next = $next->($self->saved_data);
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
        foreach my $fname ( $page->all_fields ) {
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

    # Update field list with any dynamic things (eg user-based, address lookup, geocoding)
    if ($page->has_update_field_list) {
        my $updates = $page->update_field_list->($self) || {};
        foreach my $field_name (keys %$updates) {
            $self->update_field($field_name, $updates->{$field_name});
        }
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
        # Update saved_data for the next page
        my $saved_data = { %{$self->saved_data}, %{$self->value} };
        delete $saved_data->{process};
        delete $saved_data->{token};
        delete $saved_data->{saved_data};
        $self->saved_data($saved_data);
        $self->field('saved_data')->_set_value($saved_data);

        # And check to see if there is a function to call on the page
        my $page = $self->current_page;
        if ($page->finished) {
            my $success = $page->finished->($self);
            if (!$success) {
                $self->add_form_error('Something went wrong, please try again')
                    unless $self->has_form_errors;
                $self->validated(0);
            }
        }
    }
};

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
