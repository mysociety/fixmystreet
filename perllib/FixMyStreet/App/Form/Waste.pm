package FixMyStreet::App::Form::Waste;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';

has c => ( is => 'ro' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Waste' );

has finished_action => ( is => 'ro' );

before _process_page_array => sub {
    my ($self, $pages) = @_;
    foreach my $page (@$pages) {
        $page->{type} = $self->default_page_type
            unless $page->{type};
    }
};

# Add some functions to the form to pass through to the current page
has '+current_page' => (
    handles => {
        title => 'title',
        template => 'template',
    }
);

sub wizard_finished {
    my ($form, $action) = @_;
    my $c = $form->c;
    my $success = $c->forward($action, [ $form ]);
    if (!$success) {
        $form->add_form_error('Something went wrong, please try again');
        foreach (keys %{$c->stash->{field_errors}}) {
            $form->add_form_error("$_: " . $c->stash->{field_errors}{$_});
        }
    }
    return $success;
}

# Make sure we can have pre-ticked things on the first page
before after_build => sub {
    my $self = shift;

    my $saved_data = $self->previous_form ? $self->previous_form->saved_data : $self->saved_data;

    my $c = $self->c;

    map { $saved_data->{$_} = 1 } grep { /^(service|container)-/ && $c->req->params->{$_} } keys %{$c->req->params};
};

sub validate {
    my $self = shift;

    my $c = $self->c;
    my $is_staff_user = ($c->user_exists && ($c->user->from_body || $c->user->is_superuser));
    $self->add_form_error('Please specify an email address')
        unless $self->field('email')->is_inactive || $self->field('email')->value || $is_staff_user;

    $self->add_form_error('Please specify at least one of phone or email')
        unless $self->field('phone')->is_inactive || $self->field('phone')->value || $self->field('email')->value;
}

1;
