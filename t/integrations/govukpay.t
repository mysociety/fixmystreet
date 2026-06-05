use strict;
use warnings;

use Test::More;
use Test::MockModule;
use JSON::MaybeXS;

use Integrations::GOVUKPay;

my $json = JSON::MaybeXS->new(utf8 => 1);

# --- Mock LWP::UserAgent ---

my %last_request;
my $mock_response_code = 200;
my $mock_response_body = '{}';

my $ua_mock = Test::MockModule->new('LWP::UserAgent');
$ua_mock->mock('request' => sub {
    my ($self, $req) = @_;
    %last_request = (
        method  => $req->method,
        url     => $req->uri . '',
        headers => { map { $_ => $req->header($_) } $req->header_field_names },
        content => $req->content,
    );

    my $resp = HTTP::Response->new($mock_response_code);
    $resp->content($mock_response_body);
    $resp->content_type('application/json');
    $resp->header('Content-Length' => length $mock_response_body);
    return $resp;
});

# Suppress syslog calls in tests
my $syslog_mock = Test::MockModule->new('FixMyStreet::Roles::Syslog');
$syslog_mock->mock('log' => sub {});

# --- Set up integration ---

my $config = {
    api_key   => 'test_api_key_abc123',
    api_url   => 'https://publicapi.payments.service.gov.uk',
    log_ident => 'test_govukpay',
};

my $pay = Integrations::GOVUKPay->new({ config => $config });

# --- Tests ---

subtest 'create_payment sends correct request' => sub {
    $mock_response_code = 201;
    $mock_response_body = $json->encode({
        payment_id => 'hu20sqlact5260q2nanm0q8u93',
        state      => { status => 'created', finished => \0 },
        _links     => {
            next_url => { href => 'https://www.payments.service.gov.uk/secure/abc123' },
        },
    });

    my $result = $pay->create_payment({
        amount      => 2500,
        reference   => 'ORDER-001',
        description => 'Garden waste subscription',
        return_url  => 'https://example.com/pay_complete/1/token123',
        email       => 'test@example.com',
        metadata    => { report_id => '42' },
    });

    # Check the HTTP request
    is $last_request{method}, 'POST', 'uses POST method';
    like $last_request{url}, qr{/v1/payments$}, 'correct URL';
    is $last_request{headers}{'Authorization'}, 'Bearer test_api_key_abc123', 'auth header set';

    my $sent = $json->decode($last_request{content});
    is $sent->{amount}, 2500, 'amount sent correctly';
    is $sent->{reference}, 'ORDER-001', 'reference sent';
    is $sent->{description}, 'Garden waste subscription', 'description sent';
    is $sent->{return_url}, 'https://example.com/pay_complete/1/token123', 'return_url sent';
    is $sent->{email}, 'test@example.com', 'email sent';
    is $sent->{metadata}{report_id}, '42', 'metadata sent';

    # Check the result
    is $result->{payment_id}, 'hu20sqlact5260q2nanm0q8u93', 'payment_id returned';
    is $result->{next_url}, 'https://www.payments.service.gov.uk/secure/abc123', 'next_url returned';
};

subtest 'create_payment dies on API error' => sub {
    $mock_response_code = 400;
    $mock_response_body = $json->encode({
        code        => 'P0101',
        description => 'Missing mandatory attribute: amount',
    });

    eval { $pay->create_payment({ amount => 0, reference => 'X', description => 'X', return_url => 'X' }) };
    like $@, qr/GOV\.UK Pay.*failed.*400/, 'dies with status on error';
};

subtest 'create_payment dies on missing payment_id' => sub {
    $mock_response_code = 200;
    $mock_response_body = $json->encode({
        _links => { next_url => { href => 'https://example.com' } },
    });

    eval { $pay->create_payment({ amount => 100, reference => 'X', description => 'X', return_url => 'X' }) };
    like $@, qr/no payment_id/, 'dies when no payment_id in response';
};

subtest 'get_payment_details returns full data' => sub {
    $mock_response_code = 200;
    $mock_response_body = $json->encode({
        payment_id => 'abc123',
        state      => { status => 'success', finished => \1 },
        amount     => 2500,
        reference  => 'ORDER-001',
    });

    my $details = $pay->get_payment_details('abc123');

    like $last_request{url}, qr{/v1/payments/abc123$}, 'correct URL with payment_id';
    is $last_request{method}, 'GET', 'uses GET method';
    is $details->{state}{status}, 'success', 'status returned';
    is $details->{amount}, 2500, 'amount returned';
};

subtest 'get_payment_status returns status string' => sub {
    $mock_response_code = 200;
    $mock_response_body = $json->encode({
        payment_id => 'abc123',
        state      => { status => 'submitted', finished => \0 },
    });

    my $status = $pay->get_payment_status('abc123');
    is $status, 'submitted', 'returns status string';
};

subtest 'get_payment_details dies on 404' => sub {
    $mock_response_code = 404;
    $mock_response_body = $json->encode({ code => 'P0200', description => 'Not found' });

    eval { $pay->get_payment_details('nonexistent') };
    like $@, qr/GOV\.UK Pay.*failed.*404/, 'dies on 404';
};

subtest 'search_payments sends query params' => sub {
    $mock_response_code = 200;
    $mock_response_body = $json->encode({
        total   => 1,
        count   => 1,
        results => [{
            payment_id => 'abc123',
            state      => { status => 'success' },
        }],
    });

    my $result = $pay->search_payments({ reference => 'ORDER-001', state => 'success' });

    like $last_request{url}, qr{reference=ORDER-001}, 'reference param in URL';
    like $last_request{url}, qr{state=success}, 'state param in URL';
    is $result->{total}, 1, 'total returned';
    is $result->{results}[0]{payment_id}, 'abc123', 'result payment_id returned';
};

subtest 'config defaults' => sub {
    my $minimal = Integrations::GOVUKPay->new({ config => { api_key => 'k' } });
    is $minimal->_api_url, 'https://publicapi.payments.service.gov.uk', 'default api_url';
    is $minimal->log_ident, 'govukpay', 'default log_ident';
};

done_testing;
