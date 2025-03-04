package FixMyStreet::App::Form::Waste::Garden::Bexley;

use utf8;
use LWP::UserAgent;
use JSON::MaybeXS;
use URI;
use Try::Tiny;
use Data::Dumper;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden';

with 'FixMyStreet::App::Form::Waste::AccessPaySuiteBankDetails';

# Create a dedicated page for entering bank details.
has_page bank_details => (
    title => 'Enter Your Bank Details',
    template => 'waste/bank_details.html',
    fields => ['name_title', 'first_name', 'surname', 'address1', 'address2', 'address3', 'address4', 'post_code', 'account_holder', 'account_number', 'sort_code', 'submit_bank_details'],
    next => 'summary',
);

sub validate {
    my $self = shift;

    if ( $self->page_name eq 'bank_details' ) {
        my $sort_code = $self->field('sort_code');
        my $account_number = $self->field('account_number');
        return 1 unless $sort_code && $account_number;
        return 1 if $self->_validate_bank_details($sort_code, $account_number);
    }

    $self->next::method();
}

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
