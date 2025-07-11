package FixMyStreet::Roles::Cobrand::SCP;

use Moo::Role;
use URI::Escape;
use Integrations::SCP;

requires 'waste_cc_payment_sale_ref';
requires 'waste_cc_payment_line_item_ref';
# requires 'waste_cc_payment_admin_fee_line_item_ref'; Only if admin fee used

sub waste_cc_has_redirect { 1 }

sub waste_cc_get_redirect_url {
    my ($self, $c, $back) = @_;

    my $payment = Integrations::SCP->new({
        config => $self->feature('payment_gateway')
    });

    my $p = $c->stash->{report};
    my $uprn = $p->get_extra_field_value('uprn');

    my $amount = $p->get_extra_field_value( 'pro_rata' );
    unless ($amount) {
        $amount = $p->get_extra_field_value( 'payment' );
    }
    my $admin_fee = $p->get_extra_field_value('admin_fee');

    my $redirect_id = mySociety::AuthToken::random_token();
    $p->update_extra_metadata(redirect_id => $redirect_id);

    my $fund_code = $payment->config->{scp_fund_code};
    my $customer_ref = $payment->config->{customer_ref};

    my $backUrl;
    if ($p->category eq 'Bulky collection') {
        # Need to pass through property ID as not sure how to work it out once we're back
        my $id = URI::Escape::uri_escape_utf8($c->stash->{property}{id});
        $backUrl = $c->uri_for_action('/waste/pay_cancel', [ $p->id, $redirect_id ] ) . '?property_id=' . $id;
    }
    $backUrl = $c->uri_for_action("/waste/$back", [ $c->stash->{property}{id} ]) . ''
        unless $backUrl;

    if ($p->category eq 'Bulky collection') {
        if (my $bulky_fund_code = $payment->config->{bulky_scp_fund_code}) {
            $fund_code = $bulky_fund_code;
        }
        if (my $bulky_customer_ref = $payment->config->{bulky_customer_ref}) {
            $customer_ref = $bulky_customer_ref;
        }
    } elsif ($p->category eq 'Request new container') {
        if (my $request_customer_ref = $payment->config->{request_customer_ref}) {
            $customer_ref = $request_customer_ref;
        }
    }

    my $address = $c->stash->{property}{address};
    my @parts = split ',', $address;

    my @items = ({
        amount => $amount,
        reference => $customer_ref,
        description => $p->title,
        lineId => $self->waste_cc_payment_line_item_ref($p),
    }) if $amount;
    if (my $grouped_ids = $p->get_extra_metadata('grouped_ids')) {
        foreach my $id (@$grouped_ids) {
            my $problem = $c->model('DB::Problem')->find({ id => $id });
            my $amount = $problem->get_extra_field_value('payment');
            push @items, {
                amount => $amount,
                reference => $customer_ref,
                description => $problem->title,
                lineId => $self->waste_cc_payment_line_item_ref($problem),
            } if $amount;
        }
    }

    if ($admin_fee) {
        push @items, {
            amount => $admin_fee,
            reference => $payment->config->{customer_ref_admin_fee},
            description => 'Admin fee',
            lineId => $self->waste_cc_payment_admin_fee_line_item_ref($p),
        };
    }
    my $result = $payment->pay({
        returnUrl => $c->uri_for_action('/waste/pay_complete', [ $p->id, $redirect_id ] ) . '',
        backUrl => $backUrl,
        ref => $self->waste_cc_payment_sale_ref($p),
        request_id => $p->id,
        description => $p->title,
        name => $p->name,
        email => $p->user->email,
        uprn => $uprn,
        address1 => shift @parts,
        address2 => shift @parts,
        country => 'UK',
        postcode => pop @parts,
        items => \@items,
        staff => $c->stash->{staff_payments_allowed} eq 'cnp',
        fund_code => $fund_code,
    });

    if ( $result ) {
        $c->stash->{xml} = $result;

        # GET back
        # requestId - should match above
        # scpReference - transaction Ref, used later for query
        # transactionState - in progress/complete
        # invokeResult/status - SUCCESS/INVALID_REQUEST/ERROR
        # invokeResult/redirectURL - what is says
        # invokeResult/errorDetails - what it says
        #
        if ( $result->{transactionState} eq 'IN_PROGRESS' &&
             $result->{invokeResult}->{status} eq 'SUCCESS' ) {

             $p->update_extra_metadata(scpReference => $result->{scpReference});

             my $redirect = $result->{invokeResult}->{redirectUrl};
             return $redirect;
         } else {
             # XXX - should this do more?
            (my $error = $result->{invokeResult}->{status}) =~ s/_/ /g;
            $c->stash->{error} = $error;
            return undef;
         }
     } else {
        return undef;
    }
}

sub cc_check_payment_status {
    my ($self, $scp_reference) = @_;

    my $payment = Integrations::SCP->new(
        config => $self->feature('payment_gateway')
    );

    my $resp = $payment->query({
        scpReference => $scp_reference,
    });

    my $error;
    my $auth_code;
    my $can;
    my $tx_id;

    if ($resp->{transactionState} eq 'COMPLETE') {
        if ($resp->{paymentResult}->{status} eq 'SUCCESS') {
            my $auth_details
                = $resp->{paymentResult}{paymentDetails}{authDetails};
            $auth_code = $auth_details->{authCode};
            $can = $auth_details->{continuousAuditNumber};
            $tx_id = $resp->{paymentResult}->{paymentDetails}->{paymentHeader}->{uniqueTranId};
        # It is not clear to me that it's possible to get to this with a redirect
        } else {
            $error = $resp->{paymentResult}->{status};
        }
    } else {
        # again, I am not sure it's possible for this to ever happen
        $error = $resp->{transactionState};
    }

    return ($error, $auth_code, $can, $tx_id);
}

sub cc_check_payment_and_update {
    my ($self, $reference, $p) = @_;

    my ($error, $auth_code, $can, $tx_id) = $self->cc_check_payment_status($reference);
    if (!$error) {
        $p->update_extra_metadata(
            authCode => $auth_code,
            continuousAuditNumber => $can,
        );
        return (undef, $tx_id);
    }
    return ($error, undef);
}

sub waste_cc_check_payment_status {
    my ($self, $c, $p) = @_;

    # need to get some ID Things which I guess we stored in pay
    my $scpReference = $p->get_extra_metadata('scpReference');
    $c->detach( '/page_error_404_not_found' ) unless $scpReference;

    my ($error, $id) = $self->cc_check_payment_and_update($scpReference, $p);
    if ($error) {
        $c->stash->{error} = $error;
        return undef;
    }

    # create sub
    return $id;
}

1;
