=head1 NAME

FixMyStreet::App::Form::Waste::Garden::Sacks::Renew - renewal form subclass to ask about sacks/bins

=cut

package FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew';

sub with_bins_wanted { 0 }

has_page sacks_choice => (
    title_ggw => 'Subscribe to the %s',
    fields => ['container_choice', 'apply_discount', 'continue'],
    next => sub {
        return 'sacks_details' if $_[0]->{container_choice} eq 'sack';
        return 'intro';
    },
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        if (!($c->stash->{waste_features}->{ggw_discount_as_percent}) || !($c->stash->{is_staff})) {
            return ['apply_discount']
        }
    },
);

has_field container_choice => (
    type => 'Select',
    label => 'Would you like to subscribe for bins or sacks?',
    required => 1,
    widget => 'RadioGroup',
);

sub options_container_choice {
    my $cobrand = $_[0]->{c}->cobrand->moniker;
    my $num = $cobrand eq 'sutton' ? 20 :
        $cobrand eq 'kingston' ? 10 : '';
    [
        { value => 'bin', label => 'Bins', hint => '240L capacity, which is about the same size as a standard wheelie bin' },
        { value => 'sack', label => 'Sacks', hint => "Buy a roll of $num sacks and use them anytime within your subscription year" },
    ];
}

has_page sacks_details => (
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/sacks/renew.html',
    fields => ['bins_wanted', 'payment_method', 'cheque_reference', 'name', 'phone', 'email', 'apply_discount', 'continue_review'],
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        my @fields;
        push @fields, 'payment_method', 'cheque_reference' if $c->stash->{staff_payments_allowed} && !$c->cobrand->waste_staff_choose_payment_method;
        push @fields, 'bins_wanted' unless $page->form->with_bins_wanted;
        push @fields, 'apply_discount' if (!($c->stash->{waste_features}->{ggw_discount_as_percent}) || !($c->stash->{is_staff}));
        return \@fields;
    },
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;
        my $bin_count = $c->get_param('bins_wanted') || $data->{bins_wanted} || 1;
        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa() * $bin_count;
        if ($data->{apply_discount}) {
            ($cost_pa) = $c->cobrand->apply_garden_waste_discount($cost_pa);
        }
        $form->{c}->stash->{cost_pa} = $cost_pa / 100;
        $form->{c}->stash->{cost_now} = $cost_pa / 100;
        return {
            bins_wanted => { default => 1 },
        };
    },
    next => 'summary',
);

has_field bins_wanted => (
    type => 'Integer',
    build_label_method => sub {
        my $self = shift;
        my $choice = $self->form->saved_data->{container_choice} || '';
        if ($choice eq 'sack') {
            return "Number of sack subscriptions",
        } else {
            return $self->SUPER::bins_wanted_label_method;
        }
    },
    tags => { number => 1 },
    required => 1,
    range_start => 1,
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

1;
