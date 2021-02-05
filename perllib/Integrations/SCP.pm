package Integrations::SCP;

use strict;
use warnings;
use DateTime;
use Moo;
use XML::Simple;
use MIME::Base64;
use Digest::HMAC;
use Crypt::Digest::SHA256;
use DateTime;
use SOAP::Lite +trace => [qw(method debug)];
use FixMyStreet;

has config => (
    is => 'ro'
);

has url => ( is => 'ro' );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        SOAP::Lite->soapversion(1.2);
        my $soap = SOAP::Lite->on_action( sub { $_[1]; } )->proxy($self->config->{cc_url});
        $soap->autotype(0);
        return $soap;
    }
);


sub call {
    my ($self, $method, @params) = @_;

    my $res = $self->endpoint->call(
        SOAP::Data->name($method)->attr({ xmlns => 'http://www.capita-software-services.com/scp/simple' }),
        make_soap_structure(@params),
    );

    if ( $res ) {
        return $res->body;
    }

    return undef;
}

sub credentials {
    my ($self, $args) = @_;

    my $ts = DateTime->now->format_cldr('yyyyMMddHHmmss');

    my $hmac = Digest::HMAC->new(MIME::Base64::decode($self->config->{hmac}), "Crypt::Digest::SHA256");
    $hmac->add(join('!', 'CapitaPortal', $self->config->{scpID}, $args->{ref}, $ts, 'Original', $self->config->{hmac_id}));

    return {
        'subject' => {
            'subjectType' => 'CapitaPortal',
            'identifier' => $self->config->{scpID},
            'systemCode' => 'SCP',
        },
        'requestIdentification' => {
            'uniqueReference' => $args->{ref},
            'timeStamp' => $ts,
        },
        'signature' => {
            'algorithm' => 'Original',
            'hmacKeyID' => $self->config->{hmac_id},
            'digest' => $hmac->b64digest,
        }
    }
}

sub pay {
    my ($self, $args) = @_;

    my $credentials = $self->credentials($args);
    my $obj = [
        'credentials' => { attr => { xmlns => 'https://support.capita-software.co.uk/selfservice/?commonFoundation' }, %$credentials },
        'requestType' => { attr => { xmlns => 'http://www.capita-software-services.com/scp/base' }, value => 'payOnly' },
        'requestId' => { attr => { xmlns => 'http://www.capita-software-services.com/scp/base' }, value => $args->{request_id} },
        'routing' => {
            attr => { xmlns => 'http://www.capita-software-services.com/scp/base' },
            'returnUrl' => $args->{returnUrl},
            'backUrl' => $args->{backUrl},
            'siteID' => $self->config->{siteID},
            'scpId' => $self->config->{scpID},
        },
        'panEntryMethod' => { attr => { xmlns => 'http://www.capita-software-services.com/scp/base' }, value => 'ECOM' },
        'sale' => {
            attr => { xmlns => 'http://www.capita-software-services.com/scp/simple' },
            'saleSummary' => {
                attr => { xmlns => 'http://www.capita-software-services.com/scp/base' },
                'description' => $args->{description},
                'amountInMinorUnits' => $args->{amount},
            }
        },
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
        'credentials' => { attr => { xmlns => 'https://support.capita-software.co.uk/selfservice/?commonFoundation' }, %$credentials },
        siteID => { attr => { xmlns => 'http://www.capita-software-services.com/scp/base' }, value => $self->config->{siteID}},
        scpReference => { atrr => { xmlns => 'http://www.capita-software-services.com/scp/base' }, value => $args->{scpReference} },
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

sub make_soap_structure {
    my @out;
    for (my $i=0; $i<@_; $i+=2) {
        my $name = $_[$i] =~ /:/ ? $_[$i] : $_[$i];
        my $v = $_[$i+1];
        if (ref $v eq 'HASH') {
            my $attr = delete $v->{attr};
            my $value = delete $v->{value};

            my $d = SOAP::Data->name($name => $value ? $value : \SOAP::Data->value(make_soap_structure(%$v)));

            $d->attr( $attr ) if $attr;
            push @out, $d;
        } elsif (ref $v eq 'ARRAY') {
            push @out, map { SOAP::Data->name($name => \SOAP::Data->value(make_soap_structure(%$_))) } @$v;
        } else {
            push @out, SOAP::Data->name($name => $v);
        }
    }
    return @out;
}


1;
