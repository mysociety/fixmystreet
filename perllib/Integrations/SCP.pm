package Integrations::SCP;

use Moo;
with 'Integrations::Roles::SOAP';
with 'FixMyStreet::Roles::Syslog';

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

has log_ident => (
    is => 'lazy',
    default => sub { $_[0]->config->{log_ident}; },
);

sub call {
    my ($self, $method, @params) = @_;

    require SOAP::Lite;
    $self->log($method);
    $self->log(\@params);
    my $res = $self->endpoint->call(
        SOAP::Data->name($method)->attr({
            'xmlns:scpbase' => 'http://www.capita-software-services.com/scp/base',
            'xmlns:common' => 'https://support.capita-software.co.uk/selfservice/?commonFoundation',
            xmlns => 'http://www.capita-software-services.com/scp/simple'
        }),
        make_soap_structure_with_attr(@params),
    );

    my $body;
    if ( $res ) {
        $body = $res->body;
        $self->log($body);
    } else {
        $self->log('No response');
    }

    return $body;
}

sub credentials {
    my ($self, $args) = @_;

    # this is UTC
    my $ts = DateTime->now->format_cldr('yyyyMMddHHmmss');

    # ref is set for payment, scpReference for query
    my $ref = ($args->{ref} || $args->{scpReference}) . ':' . time;
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
    my $entry_method = $args->{staff} ? 'CNP' : 'ECOM';

    for my $field( qw/name address1 address2/ ) {
        $args->{$field} = substr($args->{$field}, 0, 50) if $args->{$field};
    }

    my @items;
    my $total = 0;
    foreach (@{$args->{items}}) {
        push @items, ixhash(
            'scpbase:itemSummary' => ixhash(
                'scpbase:description' => $_->{description},
                'scpbase:amountInMinorUnits' => $_->{amount},
                'scpbase:reference' => $_->{reference},
            ),
            $self->config->{scp_vat_code} ? (
                'scpbase:tax' => {
                    'scpbase:vat' =>ixhash(
                        'scpbase:vatCode' => $self->config->{scp_vat_code},
                        'scpbase:vatRate' => $self->config->{scp_vat_rate} || 0,
                        'scpbase:vatAmountInMinorUnits' => $_->{vat} || 0,
                    ),
                },
            ) : (),
            'scpbase:lgItemDetails' => ixhash(
                'scpbase:fundCode' => $args->{fund_code},
                'scpbase:additionalReference' => $_->{lineId},
                'scpbase:narrative' => $args->{uprn}, # Needs to differ for Bexley
                'scpbase:accountName' => {
                    'scpbase:surname' => $args->{name},
                },
            ),
            'scpbase:lineId' => $_->{lineId},
        );
        $total += $_->{amount};
    }

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
        'scpbase:panEntryMethod' => $entry_method,
        'scpbase:additionalInstructions' => {
            'scpbase:systemCode' => 'SCP'
        },
        'scpbase:billing' => {
            'scpbase:cardHolderDetails' => ixhash(
                'scpbase:cardHolderName' => $args->{name},
                'scpbase:address' => ixhash(
                    'scpbase:address1' => $args->{address1},
                    $args->{town} && $args->{address2}
                        ? ( 'scpbase:address2' => $args->{address2} )
                        : (),
                    # Town/city may end up in the address2 field
                    $args->{town}
                        ? ( 'scpbase:city' => $args->{town} )
                        : ( 'scpbase:city' => $args->{address2} ),
                    'scpbase:country' => $args->{country},
                    'scpbase:postcode' => $args->{postcode},
                ),
                $args->{email} ? (
                    'scpbase:contact' => {
                        'scpbase:email' => $args->{email},
                    }
                ) : (),
            ),
        },
        'sale' => ixhash(
            'scpbase:saleSummary' => ixhash(
                'scpbase:description' => $args->{description},
                'scpbase:amountInMinorUnits' => $total,
                'scpbase:reference' => $args->{ref},
            ),
            items => {
                item => \@items,
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
