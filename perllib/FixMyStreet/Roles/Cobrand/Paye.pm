=head1 NAME

FixMyStreet::Roles::Cobrand::Paye - cobrand specific code for staff Paye use

=head1 SYNOPSIS

In some cobrands, staff are taken to a different payment mechanism than the public

=cut

package FixMyStreet::Roles::Cobrand::Paye;

use Moo::Role;
use Integrations::Paye;

=head2 Staff payments

If a staff member is making a payment, then instead of using SCP, we redirect
to Paye. We also need to check the completed payment against the same source.

=cut

around waste_cc_get_redirect_url => sub {
    my ($orig, $self, $c, $back) = @_;

    if ($c->stash->{is_staff}) {
        my $payment = Integrations::Paye->new({
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

        my $backUrl = $c->uri_for_action("/waste/$back", [ $c->stash->{property}{id} ]) . '';
        my $address = $c->stash->{property}{address};
        my @parts = split ',', $address;

        my @items = ({
            amount => $amount,
            reference => $payment->config->{customer_ref},
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
            returnUrl => $c->uri_for('pay_complete', $p->id, $redirect_id ) . '',
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
            # apnReference - transaction Ref, used later for query
            # transactionState - InProgress
            # invokeResult/status - Success/...
            # invokeResult/redirectUrl - what is says
            # invokeResult/errorDetails - what it says
            if ( $result->{transactionState} eq 'InProgress' &&
                 $result->{invokeResult}->{status} eq 'Success' ) {

                 $p->set_extra_metadata('apnReference', $result->{apnReference});
                 $p->update;

                 my $redirect = $result->{invokeResult}->{redirectUrl};
                 $redirect .= "?apnReference=$result->{apnReference}";
                 return $redirect;
             } else {
                 # XXX - should this do more?
                my $error = $result->{invokeResult}->{status};
                $c->stash->{error} = $error;
                return undef;
             }
         } else {
            return undef;
        }
        return;
    }

    return $self->$orig($c, $back);
};

around garden_cc_check_payment_status => sub {
    my ($orig, $self, $c, $p) = @_;

    if (my $apn = $p->get_extra_metadata('apnReference')) {
        my $payment = Integrations::Paye->new({
            config => $self->feature('payment_gateway')
        });

        my $resp = $payment->query({
            request_id => $p->id,
            apnReference => $apn,
        });

        if ($resp->{transactionState} eq 'Complete') {
            if ($resp->{paymentResult}->{status} eq 'Success') {
                my $auth_details
                    = $resp->{paymentResult}{paymentDetails}{authDetails};
                $p->update_extra_metadata(
                    authCode => $auth_details->{authCode},
                    continuousAuditNumber => $resp->{paymentResult}{paymentDetails}{payments}{paymentSummary}{continuousAuditNumber},
                );
                $p->update_extra_field({ name => 'payment_method', value => 'csc' });
                $p->update;

                my $ref = $auth_details->{uniqueAuthId};
                return $ref;
            } else {
                $c->stash->{error} = $resp->{paymentResult}->{status};
                return undef;
            }
        } else {
            $c->stash->{error} = $resp->{transactionState};
            return undef;
        }
    }

    return $self->$orig($c, $p);
};

=head2 waste_check_staff_payment_permissions

Staff can make payments via a PAYE endpoint.

=cut

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};
    return unless $c->stash->{is_staff};
    $c->stash->{staff_payments_allowed} = 'paye-api';
}

=item * Staff cannot choose the payment method (if there were multiple)

=cut

sub waste_staff_choose_payment_method { 0 }

1;
