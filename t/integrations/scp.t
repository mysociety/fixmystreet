use strict; use warnings;

use Test::More;
use Test::MockModule;
use Test::MockTime ':all';
use Path::Tiny;
use SOAP::Lite;
use SOAP::Transport::HTTP;
use HTTP::Request::Common;

use Integrations::SCP;

sub scpSimpleInvokeRequest {
    my %args = @_;

    my $requestId = 1;
    my $scpReference = 654321;
    my $state = 'COMPLETE';
    my $status = 'SUCCESS';
    my $url = 'http://example.org/redirect';
    return <<"EOD"
<scpSimpleInvokeResponse>
    <requestId>$requestId</requestId>
    <scpReference>$scpReference</scpReference>
    <transactionState>$state</transactionState>
    <invokeResult>
        <status>$status</status>
        <redirectUrl>$url</redirectUrl>
    </invokeResult>
</scpSimpleInvokeResponse>
EOD
}

sub gen_full_response {
    my ($append) = @_;

    my $xml = <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema">
<soap:Body>$append</soap:Body>
</soap:Envelope>
EOF

    return $xml;
}

my %sent;

my $t = SOAP::Transport::HTTP::Client->new();
my $transport = Test::MockModule->new('SOAP::Transport::HTTP::Client', no_auto => 1);
$transport->mock(send_receive => sub {
        my $self = shift;
        my %args = @_;

         my ($method) = ( $args{envelope} =~ /Body><(\w*)/ );

        my $action = \&{ $method };
        my $resp = $action->(%args);
        return gen_full_response( $resp );
    }
);

my $integration = Integrations::SCP->new(
    config => {
        cc_url => 'http://example.org/cc',
        hmac_id => '99',
        siteID => '33',
        scpID => '10',
        hmac => 'la2927uiuy-adskflhalsdf==',
    }
);


subtest "check get redirect" => sub {
    my $res = $integration->pay({
        returnUrl => 'http://example.org/return',
        backUrl => 'http://example.org/back',
        ref => time(),
        request_id => time(),
        description => 'This is a test',
        amount => '1000',
    });

    ok $res, 'got response';

    is $res->{transactionState}, "COMPLETE", 'transaction complete';
    is $res->{invokeResult}->{redirectUrl}, 'http://example.org/redirect', 'got redirect';
};


done_testing;
