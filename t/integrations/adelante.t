use strict;
use warnings;
use Test::More;
use Test::MockModule;

use_ok 'Integrations::Adelante';

my $lwp = Test::MockModule->new('LWP::UserAgent');
$lwp->mock(request => sub {
    my ($self, $req) = @_;

    my ($function) = $req->content =~ /"Function":"(.*?)"/;
    my $return = '"Result":"OK",';
    if ($function eq 'PAY3DS') {
        like $req->content, qr/"Ref1":"CC"/;
        if ($req->content =~ /"zero-cost"/) {
            like $req->content, qr/"Ref2":"zero-cost"/;
            like $req->content, qr/"Amount":"0"/, 'zero-cost items have Amount as "0"';
        } elsif ($req->content =~ /"empty-amount"/) {
            like $req->content, qr/"Ref2":"empty-amount"/;
            like $req->content, qr/"Amount":"0"/, 'empty amounts default to "0"';
        } else {
            like $req->content, qr/"Ref2":"reference"/;
            like $req->content, qr/"Amount":1000/;
        }
        like $req->content, qr/"ReturnURL":"http:\/\/example\.org/;
        $return .= '"UID":"UID", "Link":"https://example.org/"';
    } elsif ($function eq 'GET') {
        if ($req->content =~ /a-reference/) {
            like $req->content, qr/"UID":"a-reference"/;
            $return .= '"Status":"Authorised"';
        } else {
            like $req->content, qr/"UID":"a-staff-reference"/;
            $return .= '"Status":"Authorised","MPOSID":"20013971","AuthCode":"999777"';
        }
    } elsif ($function eq 'ECHO') {
        like $req->content, qr/"User":"username"/;
        like $req->content, qr/"Input":"Hello World"/;
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
        items => [ { cost_code => 'CC', reference => 'zero-cost', amount => 0 } ],
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
