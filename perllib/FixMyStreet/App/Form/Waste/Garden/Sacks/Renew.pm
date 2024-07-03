=head1 NAME

FixMyStreet::App::Form::Waste::Garden::Sacks::Renew - renewal form subclass to ask about sacks/bins

=cut

package FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew';

sub with_bins_wanted {
    my $cobrand = $_[0]->c->cobrand->moniker;
    return $cobrand eq 'merton';
}

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

with 'FixMyStreet::App::Form::Waste::Garden::Sacks::Choice';

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
        my $end_date = $c->stash->{garden_form_data}->{end_date};
        my $cost_pa = $c->cobrand->garden_waste_renewal_sacks_cost_pa($end_date) * $bin_count;
        if ($data->{apply_discount}) {
            ($cost_pa) = $c->cobrand->apply_garden_waste_discount($cost_pa);
        }
        $form->{c}->stash->{cost_pa} = $cost_pa / 100;
        $form->{c}->stash->{cost_now} = $cost_pa / 100;

        my $bins_wanted_opts = { default => 1 };
        if ($form->with_bins_wanted) {
            my $max_bins = $c->stash->{garden_form_data}->{max_bins};
            $bins_wanted_opts->{range_end} = $max_bins;
        }
        return {
            bins_wanted => $bins_wanted_opts,
        };
    },
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        unless ($form->with_bins_wanted) {
            $data->{bins_wanted} = 1;
        }
    },
    next => 'summary',
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

1;
