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

    my @options = (
        { value => 'direct_debit', label => 'Direct Debit', hint => 'Set up your payment details once, and we’ll automatically renew your subscription each year, until you tell us to stop. You can cancel or amend at any time.', data_hide => '#form-cheque_reference-row,#form-payment_explanation-row' },
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
