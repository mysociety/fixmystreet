package FixMyStreet::SendReport::Angus;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport'; }

use Try::Tiny;
use Encode;
use XML::Simple;

sub get_auth_token {
    my ($self, $authxml) = @_;

    my $xml = new XML::Simple;
    my $obj;

    eval {
        $obj = $xml->parse_string( $authxml );
    };

    my $success = $obj->{success};
    $success =~ s/^\s+|\s+$//g if defined $success;
    my $token = $obj->{AuthenticateResult};
    $token =~ s/^\s+|\s+$//g if defined $token;

    if (defined $success && $success eq 'True' && defined $token) {
        return $token;
    } else {
        $self->error("Couldn't authenticate against Angus endpoint.");
    }
}

sub get_external_id {
    my ($self, $resultxml) = @_;

    my $xml = new XML::Simple;
    my $obj;

    eval {
        $obj = $xml->parse_string( $resultxml );
    };

    my $success = $obj->{success};
    $success =~ s/^\s+|\s+$//g if defined $success;
    my $external_id = $obj->{CreateRequestResult}->{RequestId};

    if (defined $success && $success eq 'True' && defined $external_id) {
        return $external_id;
    } else {
        $self->error("Couldn't find external id in response from Angus endpoint.");
        return undef;
    }
}

sub crm_request_type {
    my ($self, $row, $h) = @_;
    return 'StLight'; # TODO: Set this according to report category
}

sub jadu_form_fields {
    my ($self, $row, $h) = @_;
    my $xml = XML::Simple->new(
        NoAttr=> 1,
        KeepRoot => 1,
        SuppressEmpty => 0,
    );
    my $metas = $row->get_extra_fields();
    my %extras;
    foreach my $field (@$metas) {
        $extras{$field->{name}} = $field->{value};
    }
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->cobrand)->new();
    my $output = $xml->XMLout({
        formfields => {
            formfield => [
                {
                    name => 'RequestTitle',
                    value => $h->{title}
                },
                {
                    name => 'RequestDetails',
                    value => $h->{detail}
                },
                {
                    name => 'ReporterName',
                    value => $h->{name}
                },
                {
                    name => 'ReporterEmail',
                    value => $h->{email}
                },
                {
                    name => 'ReporterAnonymity',
                    value => $row->anonymous ? 'True' : 'False'
                },
                {
                    name => 'ReportedDateTime',
                    value => $h->{confirmed}
                },
                {
                    name => 'ColumnId',
                    value => $extras{'column_id'} || ''
                },
                {
                    name => 'ReportId',
                    value => $h->{id}
                },
                {
                    name => 'ReportedNorthing',
                    value => $h->{northing}
                },
                {
                    name => 'ReportedEasting',
                    value => $h->{easting}
                },
                {
                    name => 'Imageurl1',
                    value => $row->photos->[0] ? ($cobrand->base_url . $row->photos->[0]->{url_full}) : ''
                },
                {
                    name => 'Imageurl2',
                    value => $row->photos->[1] ? ($cobrand->base_url . $row->photos->[1]->{url_full}) : ''
                },
                {
                    name => 'Imageurl3',
                    value => $row->photos->[2] ? ($cobrand->base_url . $row->photos->[2]->{url_full}) : ''
                }
            ]
        }
    });
    # The endpoint crashes if the JADUFormFields string has whitespace between XML elements, so strip it out...
    $output =~ s/>[\s\n]+</></g;
    return $output;
}

sub send {
    my ( $self, $row, $h ) = @_;

    # FIXME: should not recreate this each time
    my $angus_service;

    require Integrations::AngusSOAP;

    my $return = 1;
    $angus_service ||= Integrations::AngusSOAP->on_fault(sub { my($soap, $res) = @_; die ref $res ? $res->faultstring : $soap->transport->status, "\n"; });
    try {
        my $authresult = $angus_service->AuthenticateJADU();
        my $authtoken = $self->get_auth_token( $authresult );
        # authenticationtoken, CallerId, CallerAddressId, DeliveryId, DeliveryAddressId, CRMRequestType, JADUXFormRef, PaymentRef, JADUFormFields
        my $result = $angus_service->CreateServiceRequest(
            $authtoken, '1', '1', '1', '1', $self->crm_request_type($row, $h),
            'FMS', '', $self->jadu_form_fields($row, $h)
        );
        my $external_id = $self->get_external_id( $result );
        if ( $external_id ) {
            $row->external_id( $external_id );
            $return = 0;
        }
    } catch {
        my $e = $_;
        $self->error( "Error sending to Angus: $e" );
    };
    $self->success( !$return );
    return $return;
}

1;
