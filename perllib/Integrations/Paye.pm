=head1 NAME

Integrations::Paye - integration with the Capita paye.net interface

=head1 DESCRIPTION

=cut

package Integrations::Paye;

use Moo;
with 'FixMyStreet::Roles::SOAPIntegration';

use Data::Dumper;
use Sys::Syslog;
use DateTime;
use MIME::Base64;
use Digest::HMAC;
use Crypt::Digest::SHA256;
use SOAP::Lite +trace => [qw(debug)];

has config => ( is => 'ro' );

has url => ( is => 'ro' );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        SOAP::Lite->soapversion(1.1);
        my $soap = SOAP::Lite->on_action( sub { "$_[0]IPortalService/$_[1]"; } )->proxy($self->config->{paye_url});
        $soap->autotype(0);
        return $soap;
    }
);

has log_open => (
    is => 'ro',
    lazy => 1,
    builder => '_syslog_open',
);

sub _syslog_open {
    my $self = shift;
    my $ident = $self->config->{log_ident} or return 0;
    my $opts = 'pid,ndelay';
    my $facility = 'local6';
    my $log;
    eval {
        Sys::Syslog::setlogsock('unix');
        openlog($ident, $opts, $facility);
        $log = $ident;
    };
    $log;
}

sub DEMOLISH {
    my $self = shift;
    closelog() if $self->log_open;
}

sub log {
    my ($self, $str) = @_;
    $self->log_open or return;
    $str = Dumper($str) if ref $str;
    syslog('debug', '%s', $str);
}

sub call {
    my ($self, $method, @params) = @_;

    require SOAP::Lite;
    $self->log($method);
    $self->log(\@params);
    my $res = $self->endpoint->call(
        SOAP::Data->name($method)->attr({
            #'xmlns:scpbase' => 'http://www.capita-software-services.com/scp/base',
            xmlns => 'http://www.capita-software.co.uk/software/pages/payments.aspx?apnPortal',
            'xmlns:common' => 'https://support.capita-software.co.uk/selfservice/?commonFoundation',
            'xmlns:temp' => 'http://tempuri.org/'
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

    my $ref = $args->{ref} . ':' . time;
    my $hmac = Digest::HMAC->new(MIME::Base64::decode($self->config->{paye_hmac}), "Crypt::Digest::SHA256");
    $hmac->add(join('!', 'CapitaPortal', $self->config->{paye_siteID}, $ref, $ts, 'Original', $self->config->{paye_hmac_id}));

    return ixhash(
        'common:subject' => ixhash(
            'common:subjectType' => 'CapitaPortal',
            'common:identifier' => $self->config->{paye_siteID},
            'common:systemCode' => 'APN',
        ),
        'common:requestIdentification' => ixhash(
            'common:uniqueReference' => $ref,
            'common:timeStamp' => $ts,
        ),
        'common:signature' => ixhash(
            'common:algorithm' => 'Original',
            'common:hmacKeyID' => $self->config->{paye_hmac_id},
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
            #'scpbase:itemSummary' => ixhash(
            #   'scpbase:description' => $_->{description},
            #),
            'itemDetails' => ixhash(
                'fundCode' => $self->config->{paye_fund_code},
                'reference' => $_->{reference},
                'amountInMinorUnits' => $_->{amount},
                'additionalInfo' => ixhash(
                    'narrative' => $args->{uprn},
                    'additionalReference' => $_->{lineId},
                ),
                'accountDetails' => {
                    'name' => {
                        'surname' => $args->{name},
                    },
                    'address' => ixhash(
                        'address1' => $args->{address1},
                        'address2' => $args->{address2},
                        #'country' => $args->{country},
                        'postcode' => $args->{postcode},
                    ),
                    $args->{email} ? (
                        'contact' => {
                            'email' => $args->{email},
                        }
                    ) : (),
                },
            ),
            $self->config->{scp_vat_code} ? (
                'vat' =>ixhash(
                    'vatCode' => $self->config->{scp_vat_code},
                    'vatRate' => $self->config->{scp_vat_rate} || 0,
                    'vatAmountInMinorUnits' => $_->{vat} || 0,
                ),
            ) : (),
            'lineId' => $_->{lineId},
        );
        $total += $_->{amount};
    }

    my $obj = [ 'temp:request' => ixhash(
        'credentials' => $credentials,
        'login' => ixhash(
            'loginName' => $self->config->{paye_username},
            'password' => $self->config->{paye_password},
            'consortiumCode' => $self->config->{paye_consortiumCode},
            'siteId' => $self->config->{paye_siteID},
        ),
        'requestType' => 'PayOnly',
        'requestId' => $args->{request_id},
        'routing' => ixhash(
            'returnUrl' => $args->{returnUrl},
        ),
        'sale' => ixhash(
            #'scpbase:saleSummary' => ixhash(
            #    'scpbase:description' => $args->{description},
            #    'scpbase:amountInMinorUnits' => $total,
            #    'scpbase:reference' => $args->{ref},
            #),
            items => {
                item => \@items,
            },
        ),
    ) ];

    my $res = $self->call('temp:Invoke', @$obj);

    if ( $res && $res->{InvokeResponse} ) {
        $res = $res->{InvokeResponse}{InvokeResult};
    }

    return $res;
}

#sub query {
#    my ($self, $args) = @_;
#    my $credentials = $self->credentials($args);

#    my $obj = [
#        'common:credentials' => $credentials,
#        'scpbase:siteId' => $self->config->{siteID},
#        'scpbase:scpReference' => $args->{scpReference},
#    ];

#    my $res = $self->call('scpSimpleQueryRequest', @$obj);

#    # GET back includes
#    # transactionState - IN_PROGESS/COMPLETE/INVALID_REFERENCE
#    #
#    # paymentResult/status - SUCCESS/ERROR/CARD_DETAILS_REJECTED/CANCELLED/LOGGED_OUT/NOT_ATTEMPTED
#    # paymentResult/paymentDetails - on SUCCESS, more details, including card desc etc. not clear we need this
#    # paymentResult/errorDetails - what is says
#    if ( $res && $res->{scpSimpleQueryResponse} ) {
#        $res = $res->{scpSimpleQueryResponse};
#    }

#    return $res;
#}

1;
