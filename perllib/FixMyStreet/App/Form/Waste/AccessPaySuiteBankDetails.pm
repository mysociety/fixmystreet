package FixMyStreet::App::Form::Waste::AccessPaySuiteBankDetails;

use utf8;
use HTML::FormHandler::Moose::Role;
use mySociety::PostcodeUtil;
use Try::Tiny;

has_field name_title => (
    type => 'Text',
    required => 1,
    label => 'Title (e.g. Mr, Mrs, Ms, Dr, etc.)',
);

has_field first_name => (
    type => 'Text',
    required => 0,
    label => 'First name',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('First name must be 255 characters or less') if length($self->value) > 255;
    },
);

has_field surname => (
    type => 'Text',
    required => 1,
    label => 'Surname',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Surname must be 255 characters or less') if length($self->value) > 255;
    },
);

has_field address1 => (
    type => 'Text',
    required => 1,
    label => 'Address line 1',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 1 must be 50 characters or less')
            if length($self->value) > 50;
    },
);

has_field address2 => (
    type => 'Text',
    required => 1,
    label => 'Address line 2',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 2 must be 30 characters or less')
            if length($self->value) > 30;
    },
);

has_field address3 => (
    type => 'Text',
    required => 0,
    label => 'Address line 3',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 3 must be 30 characters or less')
            if length($self->value) > 30;
    },
);

has_field address4 => (
    type => 'Text',
    required => 0,
    label => 'Address line 4',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Address line 4 must be 30 characters or less')
            if length($self->value) > 30;
    },
);

has_field post_code => (
    type => 'Text',
    required => 1,
    label => 'Postcode',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        $self->add_error('Please enter a valid postcode')
            unless mySociety::PostcodeUtil::is_valid_postcode($self->value);
    },
);

has_field account_holder => (
    type => 'Text',
    required => 1,
    label => 'Name of account holder',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        my $value = $self->value;
        # Remove any special characters, keeping only alphanumeric and spaces
        $value =~ s/[^a-zA-Z0-9 ]//g;
        $self->add_error('Account holder name must be 18 characters or less')
            if length($value) > 18;
        # Update the value to the cleaned version
        $self->value($value);
    },
);

has_field account_number => (
    type => 'Text',
    required => 1,
    label => 'Account number',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        # NB the given value is also validated, along with the sort code,
        # against the Access PaySuite bankchecker API.
        # Remove any non-numerical characters
        my $value = $self->value;
        $value =~ s/[^0-9]//g;
        # Update the value to just the numbers
        $self->value($value);
        # Validate it's exactly 8 digits with leading zeros intact
        $self->add_error('Please enter a valid 8 digit account number')
            unless $value =~ /^[0-9]{8}$/;
    },
);

has_field sort_code => (
    type => 'Text',
    required => 1,
    label => 'Sort code',
    validate_method => sub {
        my $self = shift;
        return unless $self->value;
        # NB the given value is also validated, along with the account number,
        # against the Access PaySuite bankchecker API.
        my $sort_code = $self->value;
        $sort_code =~ s/[^0-9]//g;
        $self->value($sort_code);
        $self->add_error('Please enter a valid 6 digit sort code')
            unless $sort_code =~ /^\d{6}$/;
    },
);

has_field submit_bank_details => (
    type => 'Submit',
    value => 'Review subscription',
    element_attr => { class => 'govuk-button' },
);

=head2 * _validate_bank_details

Takes sort code/account number fields and validates values against the Access
PaySuite bankchecker API which performs 'modulus checks' on them.

Returns 0 if valid, 1 if invalid. If invalid, sets form errors accordingly.

=cut


sub _validate_bank_details {
    my ($self, $sort_code, $account_number ) = @_;

    # don't bother calling the API if we don't have both values
    return 1 unless $sort_code->value && $account_number->value;

    my $cfg = $self->{c}->cobrand->feature('payment_gateway');

    # fail validation if not configured - we don't want to set up invalid DDs.
    unless ( $cfg && $cfg->{validator_url} ) {
        $self->add_form_error("There was a problem verifying your bank details; please try again");
        return 1;
    }

    my $url = $cfg->{validator_url};

    my $ua = LWP::UserAgent->new(
        timeout => 20,
        agent => 'WasteWorks by SocietyWorks (swtech@societyworks.org)',
    );

    my $uri = URI->new('');
    $uri->query_form({
        client => $cfg->{validator_client},
        apikey => $cfg->{validator_apikey},
        sortCode => $sort_code->value,
        accountNumber => $account_number->value,
    });
    $url .= "?" . $uri->query;

    $self->{c}->log->debug("PaySuite bankcheck API call: $url");
    my $result;
    try {
        my $j = JSON->new->utf8->allow_nonref;
        my $response = $ua->get($url);
        $result = $j->decode($response->content);
    } catch {
        my $e = $_ || '';
        $self->{c}->log->error("PaySuite bankcheck API error: $e");
    };

    # didn't get valid JSON back, or request failed.
    unless ( $result ) {
        $self->{c}->log->error("PaySuite bankcheck API call failed.");
        $self->add_form_error("There was a problem verifying your bank details; please try again");
        return 1;
    }

    # API call succeeded but a problem with the params
    if ( $result->{error} ) {
        $self->{c}->log->error("PaySuite bankcheck API call returned error: " . $result->{error});
        $self->add_form_error("There was a problem verifying your bank details; please try again");
        return 1;
    } elsif ( $result->{success} ) {
        # API call succeeded, parameters were OK, now check the content to
        # verify the sort code/account no were actually valid.

        my $ret = 0;
        # We only fail account number validation if 'status' value is false
        if ( !$result->{success}->{account}->{status} ) {
            $account_number->add_error("Account number is invalid.");
            $ret = 1;
        }
        if ( $result->{success}->{sortcode} eq 'invalid') {
            $sort_code->add_error("Sort code is invalid.");
            $ret = 1;
        }
        return $ret;
    }

    # Unknown response from API; fail validation just to be safe.
    $self->{c}->log->error("PaySuite bankcheck validation failure:");
    $self->{c}->log->error(Dumper($result));
    $self->add_form_error("There was a problem verifying your bank details; please try again");
    return 1;
}

1;
