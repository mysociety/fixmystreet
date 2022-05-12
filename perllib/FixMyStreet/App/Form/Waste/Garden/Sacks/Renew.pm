package FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/sacks/renew.html',
    fields => ['payment_method', 'name', 'phone', 'email', 'continue_review'],
    field_ignore_list => sub {
        my $page = shift;
        return ['payment_method'] if $page->form->c->stash->{staff_payments_allowed};
    },
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};

        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa();
        $form->{c}->stash->{cost_pa} = $cost_pa / 100;
        $form->{c}->stash->{cost_now} = $cost_pa / 100;
        return {};
    },
    next => 'summary',
);

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/sacks/renew_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;

        my $cost_pa = $form->{c}->cobrand->garden_waste_sacks_cost_pa();
        my $total = $cost_pa;

        $data->{cost_pa} = $cost_pa / 100;
        $data->{display_total} = $total / 100;

        if (!$c->stash->{is_staff} && $c->user_exists) {
            $data->{name} ||= $c->user->name;
            $data->{email} = $c->user->email;
            $data->{phone} ||= $c->user->phone;
        }
        return {};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_renew');
    },
    next => 'done',
);

has_page done => (
    title => 'Subscription renewed',
    template => 'waste/garden/renewed.html',
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
