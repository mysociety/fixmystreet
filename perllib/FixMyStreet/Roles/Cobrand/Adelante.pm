package FixMyStreet::Roles::Cobrand::Adelante;

use Moo::Role;
use Hash::Util qw(lock_hash);
use Try::Tiny;
use URI::Escape;
use Integrations::Adelante;

requires 'waste_cc_payment_reference';

my %CONTAINERS = (
    garden_240 => 39,
    garden_140 => 37,
);
lock_hash(%CONTAINERS);

sub waste_cc_has_redirect { 1 }

sub waste_cc_get_redirect_url {
    my ($self, $c, $back) = @_;

    my $payment = Integrations::Adelante->new({
        config => $self->feature('payment_gateway')->{adelante}
    });

    my $p = $c->stash->{report};
    #my $uprn = $p->get_extra_field_value('uprn');

    my $amount = $p->get_extra_field_value( 'pro_rata' );
    unless ($amount) {
        $amount = $p->get_extra_field_value( 'payment' );
    }
    my $admin_fee = $p->get_extra_field_value('admin_fee');

    my $redirect_id = mySociety::AuthToken::random_token();
    $p->update_extra_metadata(redirect_id => $redirect_id);

    my $fund_code = $payment->config->{fund_code};
    my $cost_code = $payment->config->{cost_code};

    if ($p->category eq 'Bulky collection') {
        $fund_code = $payment->config->{bulky_fund_code} || $fund_code;
        $cost_code = $payment->config->{bulky_cost_code} || $cost_code;
    } elsif ($p->category eq 'Request new container') {
        $cost_code = $payment->config->{request_cost_code} || $cost_code;
    }

    my $address = $c->stash->{property}{address};
    my $ref = $self->waste_cc_payment_reference($p);

    my @items;
    push @items, {
        amount => $amount,
        cost_code => per_item_cost_code($p, $payment, $cost_code),
        reference => $ref,
    } if $amount;
    if (my $grouped_ids = $p->get_extra_metadata('grouped_ids')) {
        foreach my $id (@$grouped_ids) {
            my $problem = $c->model('DB::Problem')->find({ id => $id });
            my $amount = $problem->get_extra_field_value('payment');
            my $ref = $self->waste_cc_payment_reference($problem);
            push @items, {
                amount => $amount,
                cost_code => per_item_cost_code($problem, $payment, $cost_code),
                reference => $ref,
            } if $amount;
        }
    }
    if ($admin_fee) {
        push @items, {
            amount => $admin_fee,
            cost_code => $payment->config->{cost_code_admin_fee},
            reference => '?',
        };
    }
    my $result = try {
        $payment->pay({
            returnUrl => $c->uri_for_action('/waste/pay_complete', [ $p->id, $redirect_id ] ) . '',
            reference => $ref . '-' . time(), # Has to be unique
            name => $p->name,
            email => $p->user->email,
            phone => $p->user->phone,
            #uprn => $uprn,
            address => $address,
            items => \@items,
            staff => $c->stash->{staff_payments_allowed} eq 'cnp',
            fund_code => $fund_code,
        });
    } catch {
        $c->stash->{error} = $_;
        return undef;
    };
    return unless $result;

    $p->update_extra_metadata(scpReference => $result->{UID});
    return $result->{Link};
}

sub cc_check_payment_status {
    my ($self, $reference) = @_;

    my $payment = Integrations::Adelante->new(
        config => $self->feature('payment_gateway')->{adelante}
    );

    my ($data, $error);

    my $resp = try {
        $payment->query({
            reference => $reference,
        });
    } catch {
        $error = $_;
    };
    return ($error, undef) if $error;

    if ($resp->{Status} eq 'Authorised') {
        $data = $resp;
    } else {
        $error = $resp->{Status};
    }

    return ($error, $data);
}

sub cc_check_payment_and_update {
    my ($self, $reference, $p) = @_;

    my ($error, $data) = $self->cc_check_payment_status($reference);
    if ($data) {
        for (qw(MPOSID AuthCode)) {
            $p->update_extra_field({ name => $_, value => $data->{$_} }) if $data->{$_};
        }
        $p->update;
        return (undef, $data->{PaymentID});
    }
    return ($error, undef);
}

sub waste_cc_check_payment_status {
    my ($self, $c, $p) = @_;

    # need to get some ID Things which I guess we stored in pay
    my $reference = $p->get_extra_metadata('scpReference');
    $c->detach( '/page_error_404_not_found' ) unless $reference;

    my ($error, $id) = $self->cc_check_payment_and_update($reference, $p);
    if ($error) {
        if ($error =~ /Execution Timeout Expired/) {
            $c->stash->{retry_confirmation} = 1;
        }
        $c->stash->{error} = $error;
        return undef;
    }

    # create sub in echo
    return $id;
}

sub per_item_cost_code {
    my ($p, $payment, $cost_code) = @_;
    if ($p->cobrand eq 'merton') {
        my $container = $p->get_extra_field_value('Container_Type') || '';
        if ($container eq $CONTAINERS{garden_240} || $container eq $CONTAINERS{garden_140}) { # Garden (eq because could be e.g. '35::2')
            $cost_code = $payment->config->{cost_code_admin_fee};
        }
    }
    return $cost_code;
}

1;
