=head1 NAME

FixMyStreet::App::Form::Waste::Billing - billing information for garden subs and renewals

=head1 DESCRIPTION

=cut

package FixMyStreet::App::Form::Waste::Billing;

use utf8;
use HTML::FormHandler::Moose::Role;
use FixMyStreet::SMS;

has_field payment_method => (
    type => 'Select',
    label => 'How do you want to pay?',
    required => 1,
    widget => 'RadioGroup',
);

sub options_payment_method {
    my $form = shift;
    my @options = (
        { value => 'direct_debit', label => 'Direct Debit', hint => 'Set up your payment details once, and we’ll automatically renew your subscription each year, until you tell us to stop. You can cancel or amend at any time.', data_hide => '#form-cheque_reference-row' },
        { value => 'credit_card', label => 'Debit or Credit Card', data_hide => '#form-cheque_reference-row' },
    );
    if ($form->{c}->stash->{waste_features}->{dd_disabled}) {
        shift @options;
    }
    if ($form->{c}->cobrand->waste_cheque_payments) {
        push @options, { label => 'Telephone or Cheque Payment', value => 'cheque', data_show => '#form-cheque_reference-row' };
    }
    return @options;
}

has_field cheque_reference => (
    type => 'Text',
    label => 'Payment reference',
    required_when => { payment_method => 'cheque' },
);

has_field name => (
    type => 'Text',
    label => 'Full name',
    required => 1,
    validate_method => sub {
        my $self = shift;
        $self->add_error('Please enter your full name.')
            if length($self->value) < 5
                || $self->value !~ m/\s/
                || $self->value =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    },
);

has_field phone => (
    type => 'Text',
    label => 'Telephone number',
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field email => (
    type => 'Email',
);

1;
