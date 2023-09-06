package FixMyStreet::Roles::SCP;

use Moo::Role;
use strict;
use warnings;
use URI::Escape;
use Integrations::SCP;

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
    $p->set_extra_metadata('redirect_id', $redirect_id);
    $p->update;

    my $backUrl;
    my $reference;
    if ($back eq 'bulky') {
        # Need to pass through property ID as not sure how to work it out once we're back
        my $id = URI::Escape::uri_escape_utf8($c->stash->{property}{id});
        $backUrl = $c->uri_for_action('/waste/pay_cancel', [ $p->id, $redirect_id ] ) . '?property_id=' . $id;
        $reference = $payment->config->{customer_ref_bulky};
    } else {
        $backUrl = $c->uri_for_action("/waste/$back", [ $c->stash->{property}{id} ]) . '';
    }
    $reference ||= $payment->config->{customer_ref};

    my $address = $c->stash->{property}{address};
    my @parts = split ',', $address;

    my @items = ({
        amount => $amount,
        reference => $reference,
        description => $p->title,
        lineId => $self->waste_cc_payment_line_item_ref($p),
    });
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

             $p->set_extra_metadata('scpReference', $result->{scpReference});
             $p->update;

             # need to save scpReference against request here
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

sub garden_cc_check_payment_status {
    my ($self, $c, $p) = @_;

    # need to get some ID Things which I guess we stored in pay
    my $scpReference = $p->get_extra_metadata('scpReference');
    $c->detach( '/page_error_404_not_found' ) unless $scpReference;

    my $payment = Integrations::SCP->new(
        config => $self->feature('payment_gateway')
    );

    my $resp = $payment->query({
        scpReference => $scpReference,
    });

    if ($resp->{transactionState} eq 'COMPLETE') {
        if ($resp->{paymentResult}->{status} eq 'SUCCESS') {
            my $auth_details
                = $resp->{paymentResult}{paymentDetails}{authDetails};
            $p->set_extra_metadata( 'authCode', $auth_details->{authCode} );
            $p->set_extra_metadata( 'continuousAuditNumber',
                $auth_details->{continuousAuditNumber} );
            $p->update;

            # create sub in echo
            my $ref = $resp->{paymentResult}->{paymentDetails}->{paymentHeader}->{uniqueTranId};
            return $ref
        # It is not clear to me that it's possible to get to this with a redirect
        } else {
            $c->stash->{error} = $resp->{paymentResult}->{status};
            return undef;
        }
    } else {
        # again, I am not sure it's possible for this to ever happen
        $c->stash->{error} = $resp->{transactionState};
        return undef;
    }
}

1;
