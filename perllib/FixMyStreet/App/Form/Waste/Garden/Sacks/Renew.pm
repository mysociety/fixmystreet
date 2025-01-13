=head1 NAME

FixMyStreet::App::Form::Waste::Garden::Sacks::Renew - renewal form subclass to ask about sacks/bins

=cut

package FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew';
use WasteWorks::Costs;

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
    title => 'Renew your garden waste subscription',
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
        my $bins_wanted_disabled = $c->cobrand->call_hook('waste_renewal_bins_wanted_disabled');
        my $data = $form->saved_data;
        my $bin_count = $c->get_param('bins_wanted') || $data->{bins_wanted} || 1;
        my $costs = WasteWorks::Costs->new({ cobrand => $c->cobrand, discount => $data->{apply_discount} });
        my $cost_pa = $costs->sacks_renewal($bin_count);
        $form->{c}->stash->{cost_pa} = $cost_pa / 100;
        $form->{c}->stash->{cost_now} = $cost_pa / 100;

        my $bins_wanted_opts = { default => 1 };
        if ($form->with_bins_wanted) {
            my $max_bins = $c->stash->{garden_form_data}->{max_bins};
            $bins_wanted_opts->{range_end} = $max_bins;
        }
        if ($bins_wanted_disabled) {
            $bins_wanted_opts->{disabled} = 1;
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
        # Normally set by first page of this form (to then get sent to this
        # page), but Merton is currently skipping that
        $data->{container_choice} = 'sack';
    },
    next => 'summary',
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
);

1;
