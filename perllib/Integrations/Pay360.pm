package Integrations::Pay360;

use Moo;
with 'Integrations::Roles::SOAP';

has config => (
    is => 'ro'
);

has url => ( is => 'ro' );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        SOAP::Lite->soapversion(1.2);
        my $soap = SOAP::Lite->on_action( sub { $_[1]; } )->proxy($self->config->{dd_api_url});
        $soap->autotype(0);
        return $soap;
    }
);

has auth_header => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        SOAP::Header->name("UserAuthenticateHeader")->attr({
            'xmlns' => 'https://www.emandates.co.uk/v3/'
        })->value(
            \SOAP::Header->value(
                SOAP::Header->name('UserName', $self->config->{dd_username}),
                SOAP::Header->name('Password', $self->config->{dd_password}),
            )
        );
    },
);


sub call {
    my ($self, $method, @params) = @_;

    require SOAP::Lite;
    my $res = $self->endpoint->call(
        SOAP::Data->name($method)->attr({ xmlns => 'https://www.emandates.co.uk/v3/' }),
        $self->auth_header,
        make_soap_structure_with_attr(@params),
    );

    if ( $res ) {
        return $res->body;
    }

    return undef;
}

sub one_off_payment {
    my ($self, $args) = @_;

    my $obj = [
        reference => $args->{payer_reference},
        amountString => $args->{amount},
        dueDateString => $args->{date}->strftime('%d-%m-%Y'),
        clientSUN => $self->config->{dd_sun},
        yourRef => $args->{reference},
        comments => $args->{comment}
    ];

    my $res = $self->call('CreatePayment', @$obj);

    if ($res) {
        $res = $res->{CreatePaymentResponse}->{CreatePaymentResult};

        if ($res->{StatusCode} eq 'SA') {
            return $res;
        } else {
            return {
                error => $res->{StatusMessage}
            }
        }
    }

    return { error => 'Unknown error' };
}

sub amend_plan {
    my ($self, $args) = @_;

    my $get_plan = [
        clientSUN => $self->config->{dd_sun},
        reference => $args->{payer_reference},
    ];

    my $plan = $self->call('GetPayerPaymentPlanDetails', @$get_plan);

    if ($plan ) {
        $plan = $plan->{GetPayerPaymentPlanDetailsResponse}->{GetPayerPaymentPlanDetailsResult};

        if ($plan->{StatusCode} eq "SA") {
            my $obj = [
                clientSUN => $self->config->{dd_sun},
                payerPlan => {
                    %{ $plan->{PayerPaymentPlan} },
                    RegularAmount => $args->{amount},
                }
            ];

            my $res = $self->call('UpdatePayerPaymentPlan', @$obj);

            return $res;
        }
    }
}

sub get_payer {
    my ($self, $args) = @_;

    my $obj = [
        clientSUN => $self->config->{dd_sun},
        reference => $args->{payer_reference},
    ];

    my $res = $self->call('GetPayer', @$obj);
    if ( $res ) {
        $res = $res->{GetPayerResponse}->{GetPayerResult};
        return $res->{PayerWithAnswers}{Payer}{Status};
    }
}

sub get_payers {
    my ($self, $args) = @_;

    my $obj = [
        clientSUN => $self->config->{dd_sun},
        clientID => $self->config->{dd_client_id},
    ];

    my $res = $self->call('GetPayers', @$obj);

    if ( $res ) {
        $res = $res->{GetPayersResponse}->{GetPayersResult};

        if ($res->{StatusCode} eq 'SA') {
            if ($res->{Payers}) {
                return force_arrayref( $res, 'Payers' );
            } else {
                return [];
            }
        } else {
            return {
                error => $res->{StatusMessage}
            }
        }
    }

    return { error => "unknown error" };
}

sub get_all_history {
    my ($self, $args) = @_;

    my $obj = [
        clientSUN => $self->config->{dd_sun},
        clientID => $self->config->{dd_client_id},
    ];

    my $res = $self->call('GetPaymentHistoryAllPayers', @$obj);

    if ( $res ) {
        return $res;
        $res = $res->{GetPaymentHistoryAllPayersResponse}->{GetPaymentHistoryAllPayersResult};

        if ($res->{StatusCode} eq 'SA') {
            if ($res->{Payments}) {
                return force_arrayref( $res, 'Payments' );
            } else {
                return [];
            }
        } else {
            return {
                error => $res->{StatusMessage}
            }
        }
    }

    return { error => "unknown error" };
}

sub get_recent_payments {
    my ($self, $args) = @_;

    my $obj = [
        clientSUN => $self->config->{dd_sun},
        clientID => $self->config->{dd_client_id},
        fromDate => $args->{start}->strftime('%d/%m/%Y'),
        toDate => $args->{end}->strftime('%d/%m/%Y'),
    ];

    my $res = $self->call('GetPaymentHistoryAllPayersWithDates', @$obj);

    if ( $res ) {
        $res = $res->{GetPaymentHistoryAllPayersWithDatesResponse}->{GetPaymentHistoryAllPayersWithDatesResult};

        if ($res->{StatusCode} eq 'SA') {
            if ($res->{Payments}) {
                return force_arrayref( $res->{Payments}, 'PaymentAPI' );
            } else {
                return [];
            }
        } else {
            return {
                error => $res->{StatusMessage}
            }
        }
    }

    return { error => "unknown error" };
}

sub get_cancelled_payers {
    my ($self, $args) = @_;

    my $obj = [
        clientSUN => $self->config->{dd_sun},
        clientID => $self->config->{dd_client_id},
        fromDate => $args->{start}->strftime('%d/%m/%Y'),
        toDate => $args->{end}->strftime('%d/%m/%Y'),
    ];

    my $res = $self->call('GetCancelledPayerReport', @$obj);

    if ( $res ) {
        $res = $res->{GetCancelledPayerReportResponse}->{GetCancelledPayerReportResult};

        if ($res->{StatusCode} eq 'SA') {
            if ($res->{CancelledPayerRecords}) {
                return force_arrayref( $res->{CancelledPayerRecords}, 'CancelledPayerRecordAPI' );
            } else {
                return [];
            }
        } else {
            return {
                error => $res->{StatusMessage}
            };
        }
    }

    return { error => "unknown error" };
}

sub cancel_plan {
    my ($self, $args) = @_;

    my $obj = [
        reference => $args->{payer_reference},
        send0CString => 'TRUE',
        clientSUN => $self->config->{dd_sun},
    ];

    my $res = $self->call('CancelPayer', @$obj);
    if ( $res ) {
        $res = $res->{CancelPayerResponse}->{CancelPayerResult};

        if ( $res->{OverallStatus} eq 'True' ) {
            return 1;
        } else {
            return { error => $res->{StatusMessage} }
        }
    }

    return { error => "unknown error" };
}

1;
