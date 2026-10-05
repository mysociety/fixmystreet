=head1 NAME

FixMyStreet::Roles::Cobrand::GOVUKPay - GOV.UK Pay payment gateway role

=head1 SYNOPSIS

In your cobrand:

    package FixMyStreet::Cobrand::YourCobrand;
    use Moo;
    with 'FixMyStreet::Roles::Cobrand::GOVUKPay';

    sub waste_cc_payment_reference {
        my ($self, $p) = @_;
        return 'REF-' . $p->id;
    }

=head1 DESCRIPTION

A Moo::Role providing GOV.UK Pay integration for FixMyStreet waste/garden
subscriptions and similar payment flows.  Follows the same interface as
L<FixMyStreet::Roles::Cobrand::SCP> and L<FixMyStreet::Roles::Cobrand::Adelante>.

Configuration is read from C<< $cobrand->feature('payment_gateway') >>
and should include:

    COBRAND_FEATURES:
      payment_gateway:
        yourcobrand:
          govukpay_api_key: 'your-api-key'
          govukpay_api_url: 'https://publicapi.payments.service.gov.uk'
          govukpay_description_prefix: 'FixMyStreet'  # optional

=cut

package FixMyStreet::Roles::Cobrand::GOVUKPay;

use Moo::Role;
use Try::Tiny;
use Integrations::GOVUKPay;

# Cobrands consuming this role must provide a method that returns a
# payment reference string for a given Problem.
requires 'waste_cc_payment_reference';

=head2 waste_cc_has_redirect

Returns 1 — GOV.UK Pay always redirects the payer to their hosted page.

=cut

sub waste_cc_has_redirect { 1 }

=head2 _govukpay_config

Returns the GOV.UK Pay subset of the payment_gateway config.

=cut

sub _govukpay_config {
    my $self = shift;
    my $cfg = $self->feature('payment_gateway') || {};
    return {
        api_key   => $cfg->{govukpay_api_key},
        api_url   => $cfg->{govukpay_api_url} || 'https://publicapi.payments.service.gov.uk',
        log_ident => $cfg->{log_ident} || 'govukpay',
    };
}

=head2 _govukpay_client

Returns a configured L<Integrations::GOVUKPay> instance.

=cut

sub _govukpay_client {
    my $self = shift;
    return Integrations::GOVUKPay->new({
        config => $self->_govukpay_config,
    });
}

=head2 waste_cc_get_redirect_url($c, $back)

Creates a payment via GOV.UK Pay and returns the hosted payment page URL.
Stores C<scpReference> in the report's extra metadata for later lookup.

=cut

sub waste_cc_get_redirect_url {
    my ($self, $c, $back) = @_;

    my $p = $c->stash->{report};

    # Work out the amount — pro_rata takes precedence over payment
    my $amount = $p->get_extra_field_value('pro_rata');
    $amount = $p->get_extra_field_value('payment') unless $amount;
    my $admin_fee = $p->get_extra_field_value('admin_fee') || 0;
    my $total = ($amount || 0) + $admin_fee;

    unless ($total && $total > 0) {
        $c->stash->{error} = 'No payment amount found';
        return undef;
    }

    # Generate redirect token for verification on return
    my $redirect_id = mySociety::AuthToken::random_token();
    $p->update_extra_metadata(redirect_id => $redirect_id);

    my $reference = $self->waste_cc_payment_reference($p);
    my $cfg       = $self->feature('payment_gateway') || {};
    my $prefix    = $cfg->{govukpay_description_prefix} || 'FixMyStreet';
    my $description = "$prefix: " . $p->title;

    # Build return / back URLs
    my $return_url = $c->uri_for_action('/waste/pay_complete', [ $p->id, $redirect_id ]) . '';


    my $result = try {
        my $payment = $self->_govukpay_client;
        $payment->create_payment({
            amount      => $total,
            reference   => $reference,
            description => $description,
            return_url  => $return_url,
            email       => $p->user->email,
            metadata    => {
                report_id => $p->id . '',
                category  => $p->category,
            },
        });
    } catch {
        $c->stash->{error} = $_;
        return undef;
    };
    return undef unless $result;

    # Store GOV.UK Pay payment_id for later status queries.
    $p->update_extra_metadata(scpReference => $result->{payment_id});

    return $result->{next_url};
}

=head2 cc_check_payment_status($govukpay_id)

Queries GOV.UK Pay for the status of the given payment ID.

Returns C<($error, $payment_id)> where C<$payment_id> is the GOV.UK Pay
payment_id (used as the transaction reference) on success, or C<$error>
is a descriptive string on failure.

=cut

sub cc_check_payment_status {
    my ($self, $govukpay_id) = @_;

    my ($data, $error);

    my $details = try {
        $self->_govukpay_client->get_payment_details($govukpay_id);
    } catch {
        $error = $_;
    };
    return ($error, undef) if $error;

    my $state = $details->{state} || {};
    if ($state->{status} eq 'success') {
        $data = $details;
    } elsif ($state->{finished}) {
        # Finished but not success → cancelled, failed, error
        $error = $state->{status} || 'payment_failed';
    } else {
        # Still in progress
        $error = 'in_progress';
    }

    return ($error, $data);
}

=head2 cc_check_payment_and_update($reference, $p)

Checks payment status via GOV.UK Pay.
C<$reference> is the GOV.UK Pay payment ID (stored as scpReference
on the report).

Returns C<($error, $payment_reference)>.

=cut

sub cc_check_payment_and_update {
    my ($self, $reference, $p) = @_;

    my ($error, $data) = $self->cc_check_payment_status($reference);
    return (undef, $data->{payment_id}) if $data;
    return ($error, undef);
}

=head2 waste_cc_check_payment_status($c, $p)

Called by the Waste controller on C<pay_complete>.  Fetches the payment
status from GOV.UK Pay, updates the report, and returns the payment
reference on success or C<undef> on failure (with C<$c->stash->{error}>
set).

=cut

sub waste_cc_check_payment_status {
    my ($self, $c, $p) = @_;

    my $govukpay_id = $p->get_extra_metadata('scpReference');
    $c->detach('/page_error_404_not_found') unless $govukpay_id;

    my ($error, $id) = $self->cc_check_payment_and_update($govukpay_id, $p);
    if ($error) {
        if ($error eq 'in_progress') {
            # Payment hasn't completed yet — show a retry page
            $c->stash->{retry_confirmation} = 1;
        }
        $c->stash->{error} = $error;
        return undef;
    }

    return $id;
}

1;
