package FixMyStreet::App::Form::Waste::Garden::Kingston::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew';

has_page sacks_choice => (
    title_ggw => 'Subscribe to the %s',
    fields => ['container_choice', 'continue'],
    next => sub {
        return 'sacks_details' if $_[0]->{container_choice} eq 'sack';
        return 'intro';
    }
);

has_field container_choice => (
    type => 'Select',
    label => 'Would you like to subscribe for bins or sacks?',
    required => 1,
    widget => 'RadioGroup',
);

sub options_container_choice {
    my $num = $_[0]->{c}->cobrand->moniker eq 'sutton' ? 20 : 10;
    [
        { value => 'bin', label => 'Bins', hint => '240L capacity, which is about the same size as a standard wheelie bin' },
        { value => 'sack', label => 'Sacks', hint => "Buy a roll of $num sacks and use them anytime within your subscription year" },
    ];
}

has_page sacks_details => (
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/sacks/renew.html',
    fields => ['payment_method', 'cheque_reference', 'name', 'phone', 'email', 'continue_review'],
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};

        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa();
        $form->{c}->stash->{cost_pa} = $cost_pa / 100;
        $form->{c}->stash->{cost_now} = $cost_pa / 100;
        return {};
    },
    next => 'sacks_summary',
);

has_page sacks_summary => (
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

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

1;
