package FixMyStreet::App::Form::Waste::Garden::Kingston::Subscribe;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden';

has_page intro => (
    title_ggw => 'Subscribe to the %s',
    template => 'waste/garden/subscribe_intro.html',
    fields => ['continue'],
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;
        $data->{garden_sacks} = $c->stash->{garden_sacks};
        return {};
    },
    next => sub {
        return 'choice' if $_[0]->{garden_sacks};
        'existing';
    }
);

has_page choice => (
    title_ggw => 'Subscribe to the %s',
    fields => ['container_choice', 'continue'],
    next => sub {
        return 'sacks_details' if $_[0]->{container_choice} eq 'sack';
        return 'existing';
    }
);

has_field container_choice => (
    type => 'Select',
    label => 'Would you like to subscribe for bins or sacks?',
    required => 1,
    widget => 'RadioGroup',
    options => [
        { value => 'bin', label => 'Bins', hint => '240L capacity, which is about the same size as a standard wheelie bin' },
        { value => 'sack', label => 'Sacks', hint => 'Buy a roll of 10 sacks and use them anytime within your subscription year' },
    ],
);

has_page sacks_details => (
    title_ggw => 'Subscribe to the %s',
    template => 'waste/garden/sacks/subscribe_details.html',
    fields => ['payment_method', 'name', 'email', 'phone', 'continue_review'],
    field_ignore_list => sub {
        my $page = shift;
        return ['payment_method'] if $page->form->c->stash->{staff_payments_allowed};
    },
    update_field_list => sub {
        my $form = shift;
        my $cost_pa = $form->{c}->cobrand->garden_waste_sacks_cost_pa();
        $form->{c}->stash->{cost_pa} = $cost_pa / 100;
        return {};
    },
    next => 'sacks_summary',
);


has_page sacks_summary => (
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

1;
