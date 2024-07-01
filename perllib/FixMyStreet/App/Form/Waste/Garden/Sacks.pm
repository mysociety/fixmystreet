=head1 NAME

FixMyStreet::App::Form::Waste::Garden::Sacks - subscription form subclass to ask about sacks/bins

=cut

package FixMyStreet::App::Form::Waste::Garden::Sacks;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden';

sub with_sacks_choice { 1 }
sub with_bins_wanted {
    my $cobrand = $_[0]->c->cobrand->moniker;
    return $cobrand eq 'merton';
}

has_page choice => (
    title_ggw => 'Subscribe to the %s',
    fields => ['container_choice', 'continue'],
    next => sub {
        return 'sacks_details' if $_[0]->{container_choice} eq 'sack';
        return 'existing';
    }
);

with 'FixMyStreet::App::Form::Waste::Garden::Sacks::Choice';

has_page sacks_details => (
    title_ggw => 'Subscribe to the %s',
    template => 'waste/garden/sacks/subscribe_details.html',
    fields => ['bins_wanted', 'payment_method', 'cheque_reference', 'name', 'email', 'phone', 'password', 'continue_review'],
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        my @fields;
        if ($c->stash->{staff_payments_allowed} && !$c->cobrand->waste_staff_choose_payment_method) {
            push @fields, 'payment_method', 'cheque_reference', 'password';
        } elsif ($c->stash->{staff_payments_allowed}) {
            push @fields, 'password';
        } elsif ($c->cobrand->call_hook('waste_password_hidden')) {
            push @fields, 'password';
        }
        push @fields, 'bins_wanted' unless $page->form->with_bins_wanted;
        return \@fields;
    },
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->{c};
        my $count = $c->get_param('bins_wanted') || $data->{bins_wanted} || 1;
        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa() * $count;
        if ($data->{apply_discount}) {
            ($cost_pa, $c->stash->{per_sack_cost}) =
                $c->cobrand->apply_garden_waste_discount($cost_pa, $c->stash->{per_sack_cost});
        }
        $c->stash->{cost_pa} = $cost_pa / 100;
        return {
            bins_wanted => { default => $count },
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
    required => 1,
    range_start => 1,
);

1;
