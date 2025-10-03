package FixMyStreet::App::Form::Waste::Garden::Transfer;

use utf8;
use HTML::FormHandler::Moose;
use JSON;
extends 'FixMyStreet::App::Form::Waste';

has original_subscriber => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $c = $self->{c};

        my $p = $c->cobrand->problems->search({
        category => 'Garden Subscription',
        title => ['Garden Subscription - New', 'Garden Subscription - Renew', 'Garden Subscription - Transfer'],
        extra => { '@>' => encode_json({ "_fields" => [ { name => "property_id", value => ($self->saved_data->{previous_ggw_address}->{value}) } ] }) },
        state => [ FixMyStreet::DB::Result::Problem->open_states ]
        })->order_by('-id')->to_body($c->cobrand->body)->first;

        my $user;
        ($user) = $c->model('DB::User')->find({ id => $p->user_id }) if $p;
        return $user;
    },
);

has_page intro => (
    title => 'Transfer garden waste subscription - check',
    fields => ['resident_moved', 'continue_address'],
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
    intro => 'garden/transfer_confirm_addresses.html',
    title => 'Confirm transfer',
    fields => ['email', 'phone', 'name', 'continue_done'],
    finished => sub {
        return $_[0]->wizard_finished('process_garden_transfer');
    },
    next => 'done',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

sub default_name {
    my $self = shift;

    return $self->original_subscriber ? $self->original_subscriber->name : '';
}

sub default_phone {
    my $self = shift;

    return $self->original_subscriber ? $self->original_subscriber->phone : '';
}

sub default_email {
    my $self = shift;

    return $self->original_subscriber ? $self->original_subscriber->email : '';
}

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
         my $field = shift;
         return $field->form->saved_data->{addresses};
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
        if ($data->{error}) {
            $self->add_error($messages{ $data->{error} });
            return;
        };
        $self->form->saved_data->{transfer_old_ggw_sub} = $data;
        ($self->form->saved_data->{previous_ggw_address}) = (grep { $_->{value} == $self->value } @{$self->form->saved_data->{addresses}})[0];
    }
);

1;
