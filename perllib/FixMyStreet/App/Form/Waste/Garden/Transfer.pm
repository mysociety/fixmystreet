package FixMyStreet::App::Form::Waste::Garden::Transfer;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Transfer garden waste subscription - check',
    fields => ['resident_moved', 'continue_address'],
    template => 'waste/garden/transfer.html',
    next => 'old_address',
);

has_page old_address => (
    title => 'Transfer garden waste subscription - old address',
    fields => ['postcode', 'continue_select'],
    next => 'select_old_address',
);

has_page select_old_address => (
    title => 'Transfer garden waste subscription - old address',
    fields => ['addresses', 'continue_confirm'],
    next => 'confirm',
);

has_page confirm => (
    title => 'Confirm transfer',
    fields => ['continue_done'],
    template => 'waste/garden/transfer_confirm.html',
    finished => sub {
        return $_[0]->wizard_finished('ggw_transfer_subscription');
    },
    next => 'done',
);

has_page done => (
    title => 'Transferred',
    template => 'waste/garden/transferred.html',
);

has_field resident_moved => (
    type => 'Checkbox',
    required => 1,
    option_label => 'Confirm that resident has moved to the address above and has brought their garden bins or bags with them',
);

has_field continue_address => (
    type => 'Submit',
    value => 'Find old address',
    element_attr => { class => 'govuk-button' },
);

has_field continue_select => (
    type => 'Submit',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field continue_confirm => (
    type => 'Submit',
    value => 'Select',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field continue_done => (
    type => 'Submit',
    value => 'Transfer',
    element_attr => { class => 'govuk-button' },
    order => 999
);

has_field postcode => (
    type => 'Postcode',
    value => 'Enter postcode',
    validate_method => sub {
        my $self = shift;
        my $c = $self->form->c;
        return if $self->has_errors; # Called even if already failed
        my $data = $c->cobrand->bin_addresses_for_postcode($self->value);
        if (!@$data) {
            my $error = 'Sorry, we did not find any results for that postcode';
            $self->add_error($error);
        }
        $self->form->saved_data->{addresses} = $data;
    }
);

has_field addresses => (
    label => 'Select previous address',
    type => 'Select',
    options_method => sub {
         my $form = shift;
         return $form->form->saved_data->{addresses};
    },
    validate_method => sub {
        my $self = shift;
        my $c = $self->form->c;

        my %messages = (
            'current' => 'There is currently a garden subscription at the new address',
            'no_previous' => 'There is no garden subscription at this address',
            'due_soon' => 'Subscription can not be transferred as is in the renewal period or expired',
            'duplicate' => "This should be the old address, not the new one",
        );

        if ($self->value == $c->stash->{property}{id}) {
            $self->add_error($messages{'duplicate'});
            return;
        }
        my $data = $c->cobrand->call_hook('check_ggw_transfer_applicable' => $self->value);
        if (my $error = $data->[0]) {
            $self->add_error($messages{$error});
        };
    $self->form->saved_data->{transfer_ggw_expiry} = $data->[1];
    @{$self->form->saved_data->{previous_ggw_address}} = grep { $_->{value} == $self->value } @{$self->form->saved_data->{addresses}};
    }
);

1;