use strict;
use warnings;
use JSON::MaybeXS;
use Test::More;
use Test::MockModule;

use_ok 'Integrations::Adelante';

my $lwp = Test::MockModule->new('LWP::UserAgent');
$lwp->mock(request => sub {
    my ($self, $req) = @_;

    my $content = decode_json($req->content);
    my $function = $content->{Function};
    my $return = '"Result":"OK",';
    if ($function eq 'PAY3DS') {
        if ($content->{PaymentReference} eq "zero-cost") {
            is_deeply $content->{Lines}, [{
                Ref1 => 'CC',
                Ref2 => 'some-cost',
                Amount => 1800,
                FundCode => 32,
            }];
        } elsif ($content->{PaymentReference} eq "empty-amount") {
            is_deeply $content->{Lines}, [], 'zero-cost item, no lines';
        } else {
            is_deeply $content->{Lines}, [{
                Ref1 => 'CC',
                Ref2 => 'reference',
                Amount => 1000,
                FundCode => 32,
            }];
        }
        is $content->{ReturnURL}, "http://example.org/return";
        $return .= '"UID":"UID", "Link":"https://example.org/"';
    } elsif ($function eq 'GET') {
        if ($content->{UID} eq 'a-reference') {
            is $content->{UID} , 'a-reference';
            $return .= '"Status":"Authorised"';
        } else {
            is $content->{UID}, "a-staff-reference";
            $return .= '"Status":"Authorised","MPOSID":"20013971","AuthCode":"999777"';
        }
    } elsif ($function eq 'ECHO') {
        is $content->{User}, "username";
        is $content->{Input}, "Hello World";
        $return .= '"UID":"UID", "Link":"https://example.org/"';
    } else {
        is $function, 'ERROR';
    }
    return HTTP::Response->new(200, 'OK', [], "{$return}");
});

my $integration = Integrations::Adelante->new(
    config => {
        url => 'http://example.org/cc',
        username => 'username',
        password => 'password',
        pre_shared_key => 'psk',
        channel => 'CHANNEL',
    }
);

subtest "check get redirect" => sub {
    my $res = $integration->pay({
        returnUrl => 'http://example.org/return',
        fund_code => '32',
        reference => 'reference',
        name => 'name',
        address => 'address',
        email => 'email',
        items => [ { cost_code => 'CC', reference => 'reference', amount => 1000 } ],
    });

    ok $res, 'got response';
    is $res->{UID}, "UID";
    is $res->{Link}, "https://example.org/";
};

subtest "check query" => sub {
    my $res = $integration->query({
        reference => 'a-reference',
    });

    ok $res, 'got response';
    is $res->{Status}, "Authorised", 'transaction complete';
};

subtest "check staff query" => sub {
    my $res = $integration->query({
        reference => 'a-staff-reference',
    });

    ok $res, 'got response';
    is $res->{Status}, "Authorised", 'transaction complete';
    is $res->{MPOSID}, "20013971";
    is $res->{AuthCode}, "999777";
};

subtest 'check echo' => sub {
    my $res = $integration->echo();
    is $res->{Result}, 'OK';
};

subtest "check zero-cost line items" => sub {
    my $res = $integration->pay({
        returnUrl => 'http://example.org/return',
        fund_code => '32',
        reference => 'zero-cost',
        name => 'name',
        address => 'address',
        email => 'email',
        items => [
            { cost_code => 'CC', reference => 'zero-cost', amount => 0 },
            { cost_code => 'CC', reference => 'some-cost', amount => 1800 }
        ],
    });

    ok $res, 'got response for zero-cost item';
    is $res->{UID}, "UID";
    is $res->{Link}, "https://example.org/";
};

subtest "check empty amount line items" => sub {
    my $res = $integration->pay({
        returnUrl => 'http://example.org/return',
        fund_code => '32',
        reference => 'empty-amount',
        name => 'name',
        address => 'address',
        email => 'email',
        items => [ { cost_code => 'CC', reference => 'empty-amount', amount => '' } ],
    });

    ok $res, 'got response for empty amount item';
    is $res->{UID}, "UID";
    is $res->{Link}, "https://example.org/";
};

done_testing;
