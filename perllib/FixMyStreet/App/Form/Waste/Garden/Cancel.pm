package FixMyStreet::App::Form::Waste::Garden::Cancel;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Cancel your garden waste subscription',
    template => 'waste/garden/cancel.html',
    fields => ['name', 'phone', 'email', 'confirm', 'submit'],
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        my $ask_staff = $c->cobrand->call_hook('waste_cancel_asks_staff_for_user_details');
        my $staff = $c->stash->{is_staff};
        return ['name', 'phone', 'email'] unless $staff && $ask_staff;
        return [];
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_cancellation');
    },
    next => 'done',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page done => (
    title => 'Subscription cancelled',
    template => 'waste/garden/cancel_confirmation.html',
);

has_field confirm => (
    type => 'Checkbox',
    option_label => 'I confirm I wish to cancel my subscription',
    required => 1,
    label => "Confirm",
);

has_field submit => (
    type => 'Submit',
    value => 'Cancel subscription',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
