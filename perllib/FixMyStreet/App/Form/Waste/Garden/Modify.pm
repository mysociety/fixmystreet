package FixMyStreet::App::Form::Waste::Garden::Modify;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden/modify_pick.html',
    fields => ['task', 'continue'],
    next => 'alter',
);

has_page alter => (
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden/modify.html',
    fields => ['bin_number', 'continue_review'],
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        my $data = $c->stash->{garden_form_data};
        return {
            bin_number => { default => $data->{bins} },
        };
    },
    next => 'summary',
);

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden/modify_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;
        my $current_bins = $c->stash->{garden_form_data}->{bins};
        my $new_bins = $data->{bin_number} - $current_bins;
        my $pro_rata = $c->cobrand->waste_get_pro_rata_cost( $new_bins, $c->stash->{garden_form_data}->{end_date});
        my $total = $c->cobrand->garden_waste_cost($data->{bin_number});

        $data->{payment_method} = $c->stash->{garden_form_data}->{payment_method};
        $data->{billing_address} = $c->stash->{garden_form_data}->{billing_address} || $c->stash->{property}{address};
        $data->{display_pro_rata} = $pro_rata / 100;
        $data->{display_total} = $total / 100;

        $data->{name} = $c->user->name;
        $data->{email} = $c->user->email;
        $data->{phone} = $c->user->phone;
        return {};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_modification');
    },
    next => 'done',
);

has_page done => (
    title => 'Subscription amended',
    template => 'waste/garden/amended.html',
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
    range_start => 1,
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
