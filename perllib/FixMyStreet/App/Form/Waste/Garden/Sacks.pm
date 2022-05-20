package FixMyStreet::App::Form::Waste::Garden::Sacks;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_field service_id => ( type => 'Hidden' );

sub details_update_fields {
    my $form = shift;
    my $data = $form->saved_data;
    my $c = $form->{c};

    my $cost_pa = $form->{c}->cobrand->garden_waste_sacks_cost_pa();
    $form->{c}->stash->{cost_pa} = $cost_pa / 100;

    return {};
}

has_page intro => (
    title_ggw => 'Subscribe to the %s',
    template => 'waste/garden/sacks/subscribe_intro.html',
    fields => ['continue'],
    next => 'details',
);

has_page details => (
    title_ggw => 'Subscribe to the %s',
    template => 'waste/garden/sacks/subscribe_details.html',
    fields => ['payment_method', 'name', 'email', 'phone', 'continue_review'],
    field_ignore_list => sub {
        my $page = shift;
        return ['payment_method'] if $page->form->c->stash->{staff_payments_allowed};
    },
    update_field_list => \&details_update_fields,
    next => 'summary',
);


has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Submit container request',
    template => 'waste/garden/sacks/subscribe_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $cost_pa = $form->{c}->cobrand->garden_waste_sacks_cost_pa();
        $data->{cost_pa} = $cost_pa / 100;
        return {};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_data');
    },
    next => 'done',
);

has_page done => (
    title => 'Container request sent',
    template => 'waste/confirmation.html',
);

with 'FixMyStreet::App::Form::Waste::Billing';

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a>',
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
