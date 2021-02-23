package FixMyStreet::App::Form::Waste::Garden::Modify;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden_modify_pick.html',
    fields => ['task', 'continue'],
    next => 'alter',
);

has_page alter => (
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden_modify.html',
    fields => ['bin_number', 'continue_review'],
    next => 'summary',
);

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Modify your green garden waste subscription',
    template => 'waste/summary_garden_modify.html',
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        # TODO needs to work out amount to pay now? pro-rata?
        # Can't be editable so don't really want it as a hidden form field
        #my $cost = $form->{c}->cobrand->feature('payment_gateway')->{ggw_cost};
        #my $total = ( $data->{new_bins} + $data->{current_bins} ) * $cost;
        #$data->{total} = $total;
        #return {
        #    total => { default => $total },
        #};
        return {};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_modification');
    },
    next => 'done',
);

has_page done => (
    title => 'Subscription amended',
    template => 'waste/garden_amended.html',
);

has_field task => (
    type => 'Select',
    label => 'What do you want to do?',
    required => 1,
    widget => 'RadioGroup',
    options => [
        { value => 'modify', label => 'Increase or reduce the number of bins in your subscription' },
        { value => 'problem', label => 'Request a replacement for a broken or stolen bin' },
        { value => 'cancel', label => 'Cancel your green garden waste subscription' },
    ],
);

has_field bin_number => (
    type => 'Integer',
    label => 'How many bins do you need in your subscription?',
    tags => { number => 1 },
    required => 1,
    range_start => 0,
    range_end => 3,
);

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="" target="_blank">terms and conditions</a>',
    ),
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

has_field continue_review => (
    type => 'Submit',
    value => 'Review subscription',
    element_attr => { class => 'govuk-button' },
);

has_field submit => (
    type => 'Submit',
    value => 'Continue to payment',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
