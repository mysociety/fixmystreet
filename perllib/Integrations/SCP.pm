package Integrations::SCP;

use Moo;
with 'FixMyStreet::Roles::SOAPIntegration';

use DateTime;
use MIME::Base64;
use Digest::HMAC;
use Crypt::Digest::SHA256;

has config => (
    is => 'ro'
);

has url => ( is => 'ro' );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        SOAP::Lite->soapversion(1.1);
        my $soap = SOAP::Lite->on_action( sub { ''; } )->proxy($self->config->{cc_url});
        $soap->autotype(0);
        return $soap;
    }
);


sub call {
    my ($self, $method, @params) = @_;

    require SOAP::Lite;
    my $res = $self->endpoint->call(
        SOAP::Data->name($method)->attr({
            'xmlns:scpbase' => 'http://www.capita-software-services.com/scp/base',
            'xmlns:common' => 'https://support.capita-software.co.uk/selfservice/?commonFoundation',
            xmlns => 'http://www.capita-software-services.com/scp/simple'
        }),
        make_soap_structure_with_attr(@params),
    );

    if ( $res ) {
        return $res->body;
    }

    return undef;
}

sub credentials {
    my ($self, $args) = @_;

    # this is UTC
    my $ts = DateTime->now->format_cldr('yyyyMMddHHmmss');

    my $ref = $args->{ref} . ':' . time;
    my $hmac = Digest::HMAC->new(MIME::Base64::decode($self->config->{hmac}), "Crypt::Digest::SHA256");
    $hmac->add(join('!', 'CapitaPortal', $self->config->{scpID}, $ref, $ts, 'Original', $self->config->{hmac_id}));

    return ixhash(
        'common:subject' => ixhash(
            'common:subjectType' => 'CapitaPortal',
            'common:identifier' => $self->config->{scpID},
            'common:systemCode' => 'SCP',
        ),
        'common:requestIdentification' => ixhash(
            'common:uniqueReference' => $ref,
            'common:timeStamp' => $ts,
        ),
        'common:signature' => ixhash(
            'common:algorithm' => 'Original',
            'common:hmacKeyID' => $self->config->{hmac_id},
            'common:digest' => $hmac->b64digest,
        )
    );
}

sub pay {
    my ($self, $args) = @_;

    my $credentials = $self->credentials($args);
    my $obj = [
        'common:credentials' => $credentials,
        'scpbase:requestType' => 'payOnly' ,
        'scpbase:requestId' => $args->{request_id},
        'scpbase:routing' => ixhash(
            'scpbase:returnUrl' => $args->{returnUrl},
            'scpbase:backUrl' => $args->{backUrl},
            'scpbase:siteId' => $self->config->{siteID},
            'scpbase:scpId' => $self->config->{scpID},
        ),
        'scpbase:panEntryMethod' => 'ECOM',
        'scpbase:additionalInstructions' => {
            'scpbase:systemCode' => 'SCP'
        },
        'scpbase:billing' => {
            'scpbase:cardHolderDetails' => ixhash(
                'scpbase:address' => ixhash(
                    'scpbase:address1' => $args->{address1},
                    'scpbase:address2' => $args->{address2},
                    'scpbase:country' => $args->{country},
                    'scpbase:postcode' => $args->{postcode},
                ),
                'scpbase:contact' => {
                    'scpbase:email' => $args->{email},
                }
            ),
        },
        'sale' => ixhash(
            'scpbase:saleSummary' => ixhash(
                'scpbase:description' => $args->{description},
                'scpbase:amountInMinorUnits' => $args->{amount},
                'scpbase:reference' => $args->{ref},
            ),
            items => {
                item => [
                    ixhash(
                        'scpbase:itemSummary' => ixhash(
                            'scpbase:description' => $args->{description},
                            'scpbase:amountInMinorUnits' => $args->{amount},
                            'scpbase:reference' => $self->config->{customer_ref},
                        ),
                        'scpbase:tax' => {
                            'scpbase:vat' =>ixhash(
                                'scpbase:vatCode' => $self->config->{scp_vat_code},
                                'scpbase:vatRate' => $self->config->{scp_vat_rate} || 0,
                                'scpbase:vatAmountInMinorUnits' => $args->{vat} || 0,
                            ),
                        },
                        'scpbase:lgItemDetails' => ixhash(
                            'scpbase:fundCode' => $self->config->{scp_fund_code},
                            'scpbase:additionalReference' => $args->{ref},
                            'scpbase:narrative' => $args->{uprn},
                        ),
                        'scpbase:lineId' => $args->{ref},
                    ),
                ],
            },
        ),
    ];

    my $res = $self->call('scpSimpleInvokeRequest', @$obj);

    if ( $res && $res->{scpSimpleInvokeResponse} ) {
        $res = $res->{scpSimpleInvokeResponse};
    }

    return $res;
}

sub query {
    my ($self, $args) = @_;
    my $credentials = $self->credentials($args);

    my $obj = [
        'common:credentials' => $credentials,
        'scpbase:siteId' => $self->config->{siteID},
        'scpbase:scpReference' => $args->{scpReference},
    ];

    my $res = $self->call('scpSimpleQueryRequest', @$obj);

    # GET back includes
    # transactionState - IN_PROGESS/COMPLETE/INVALID_REFERENCE
    #
    # paymentResult/status - SUCCESS/ERROR/CARD_DETAILS_REJECTED/CANCELLED/LOGGED_OUT/NOT_ATTEMPTED
    # paymentResult/paymentDetails - on SUCCESS, more details, including card desc etc. not clear we need this
    # paymentResult/errorDetails - what is says
    if ( $res && $res->{scpSimpleQueryResponse} ) {
        $res = $res->{scpSimpleQueryResponse};
    }

    return $res;
}

sub version {
    my ($self, $args) = @_;
    my $credentials = $self->credentials($args);
    my $obj = [
        'credentials' => { attr => { xmlns => 'https://support.capita-software.co.uk/selfservice/?commonFoundation' }, %$credentials },
    ];
    my $res = $self->call('scpVersionRequest', @$obj);

    return $res;
}

1;
