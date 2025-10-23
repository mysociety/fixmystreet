=head1 NAME

FixMyStreet::App::Form::Waste::Billing - billing information for garden subs and renewals

=head1 DESCRIPTION

=cut

package FixMyStreet::App::Form::Waste::Billing;

use utf8;
use HTML::FormHandler::Moose::Role;

has_field payment_method => (
    type => 'Select',
    label => 'How do you want to pay?',
    required => 1,
    widget => 'RadioGroup',
    default => 'credit_card',
);

sub options_payment_method {
    my $form = shift;
    my $c = $form->{c};
    my $cobrand = $c->cobrand->moniker;
    my $garden_form = $form =~ /Garden/;

    my $dd_hint = 'Set up your payment details once, and we’ll renew your subscription automatically each year. You can update or cancel anytime.';
    if ($cobrand eq 'bexley') {
        # Can definitely set first_bin_discount, as we want the DD cost
        my $costs = WasteWorks::Costs->new({ cobrand => $c->cobrand, first_bin_discount => 1 });
        my $cost = sprintf('%.2f', $costs->bins(1) / 100);
        my $extra = sprintf('%.2f', $costs->per_bin / 100);
        my $max = $c->cobrand->waste_garden_maximum;
        $dd_hint = "Sign up to Direct Debit and we’ll drop the cost of your first bin to £$cost. Extra bins cost £$extra each (up to $max in total). $dd_hint";
    }
    my @options = (
        { value => 'direct_debit', label => 'Direct Debit', hint => $dd_hint, data_hide => '#form-cheque_reference-row,#form-payment_explanation-row' },
        { value => 'credit_card', label => 'Debit or Credit Card', data_hide => '#form-cheque_reference-row,#form-payment_explanation-row' },
    );
    if (!$garden_form || $c->stash->{waste_features}->{dd_disabled}) {
        # Get rid of DD option
        shift @options;
    }

    # Merton only have cheque on garden, not bulky
    my $cheque_cobrand = !($cobrand eq 'merton' && !$garden_form);
    if ($c->cobrand->waste_cheque_payments && $cheque_cobrand) {
        push @options, { label => 'Cheque payment', value => 'cheque', data_show => '#form-cheque_reference-row', data_hide => '#form-payment_explanation-row' };
    }
    if ($cobrand eq 'merton') {
        push @options, { label => 'Cash payment', value => 'cash', data_show => '#form-payment_explanation-row', data_hide => '#form-cheque_reference-row' };
        push @options, { label => 'No payment to be taken', value => 'waived', data_show => '#form-payment_explanation-row', data_hide => '#form-cheque_reference-row' };
    }

    return @options;
}

has_field cheque_reference => (
    type => 'Text',
    label => 'Payment reference',
    required_when => { payment_method => 'cheque' },
);

has_field payment_explanation => (
    label => 'Explanation',
    type => 'Text',
    required_when => { payment_method => ['waived', 'cash'] },
);

1;
