package FixMyStreet::App::Form::Waste::Garden::Sacks::Purchase;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';
use WasteWorks::Costs;

has_page intro => (
    title => 'Order more garden waste sacks',
    template => 'waste/garden/sacks/modify.html',
    fields => ['name', 'phone', 'email', 'continue_review'],
    field_ignore_list => sub {
        my $page = shift;
        return ['phone', 'email'] unless $page->form->c->stash->{is_staff};
        return [];
    },
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        my $costs = WasteWorks::Costs->new({ cobrand => $c->cobrand });
        $c->stash->{cost_pa} = $costs->sacks(1) / 100;
        return {
            name => { default => $c->stash->{is_staff} ? '' : $c->user->name },
        };
    },
    next => 'summary',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Order more garden waste sacks',
    template => 'waste/garden/sacks/modify_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;
        my $costs = WasteWorks::Costs->new({ cobrand => $c->cobrand });

        $data->{display_total} = $costs->sacks(1) / 100;

        unless ( $c->stash->{is_staff} ) {
            $data->{name} ||= $c->user->name;
            $data->{email} = $c->user->email;
            $data->{phone} ||= $c->user->phone;
        }

        my $button_text = 'Continue to payment';
        my $features = $form->{c}->cobrand->feature('waste_features');
        if ($c->stash->{is_staff} && $features->{text_for_waste_payment}) {
            $button_text = $features->{text_for_waste_payment};
        }
        return {submit => { value => $button_text }};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_modification');
    },
    next => 'done',
);

has_page done => (
    title => 'Order confirmed',
    template => 'waste/garden/sacks/modify_confirmed.html',
);

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
