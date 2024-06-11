package Integrations::Adelante;

use Moo;
with 'FixMyStreet::Roles::Syslog';

use Crypt::Digest::SHA256;
use DateTime;
use HTTP::Request::Common;
use JSON::MaybeXS;
use LWP::UserAgent;

has config => (
    is => 'ro',
    coerce => sub { return {} unless $_[0] },
);

has url => ( is => 'ro' );

has log_ident => (
    is => 'lazy',
    default => sub { $_[0]->config->{log_ident}; },
);

sub pay {
    my ($self, $args) = @_;

    my $method = $args->{staff} ? 'PAY' : 'PAY3DS';

    my @items;
    foreach (@{$args->{items}}) {
        push @items, {
            Ref1 => $_->{cost_code},
            Ref2 => $_->{reference},
            #Narrative => $args->{uprn},
            FundCode => $args->{fund_code},
            Amount => $_->{amount},
        };
    }

    my $obj = {
        Function => $method,
        Channel => $self->config->{channel},
        $args->{staff} ? (MID => $self->config->{mid}) : (),
        PaymentReference => $args->{reference},
        Name => $args->{name},
        Address => $args->{address},
        $args->{email} ? (EmailAddress => $args->{email}) : (),
        $args->{phone} ? (Telephone => $args->{phone}) : (),
        ReturnURL => $args->{returnUrl},
        Lines => \@items,
    };

    my $resp = $self->call('Payment.ashx', $obj);
    return $resp;
}

sub query {
    my ($self, $args) = @_;

    my $res = $self->call('Payment.ashx', {
        Function => 'GET',
        UID => $args->{reference},
    });

    # GET back includes PaymentID, UID, PaymentReference,
    # Status: Authorised, Awaiting, Cancelled, Declined, Error, Expired, Pending
    return $res;
}

sub echo {
    my $self = shift;
    my $resp = $self->call('Echo.ashx', {
        Function => 'ECHO',
        Input => 'Hello World',
    });
}

sub call {
    my ($self, $method, $data) = @_;
    $self->log($method);
    $self->log($data);

    $data->{User} = $self->config->{username};
    $data->{Password} = $self->config->{password};
    $data = JSON::MaybeXS->new->utf8->encode($data);

    my $sig = $self->sign($data . $self->config->{pre_shared_key});
    my $url = $self->config->{url} . $method;
    $url .= "?Format=JSON&Signature=" . $sig;

    my $req = HTTP::Request::Common::POST(
        $url,
        Content_Type => "application/json",
        Content => $data
    );

    $ENV{PERL_LWP_SSL_CA_PATH} = '/etc/ssl/certs' unless $ENV{DEV_USE_SYSTEM_CA_PATH};
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);
    $response = $response->decoded_content;
    $self->log($response || 'No response');

    $response = JSON::MaybeXS->new->utf8->decode($response);
    if ($response->{Result} ne 'OK') {
        die $response->{Result};
    }
    return $response;
}

sub sign {
    my ($self, $data) = @_;

    my $hash = Crypt::Digest::SHA256->new;
    $hash->add($data);
    return $hash->b64digest;
}

1;
