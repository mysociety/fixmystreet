package TestSyslog;

use Moo;
with 'FixMyStreet::Roles::Syslog';

has log_ident => ( is => 'ro', default => 'test' );

package main;

use FixMyStreet::Test;
use Test::MockModule;

my $syslog = Test::MockModule->new('Sys::Syslog');
my $logged;
$syslog->mock(
    openlog => sub {},
    syslog => sub { $logged = $_[2]; },
);

my $log = TestSyslog->new;
is $log->can('_redact'), undef;

foreach my $test (
    { in => "scalar", out => "scalar" },
    { in => { name => 'Foo', 'bankSortCode' => '123456', 'accountNumber' => '12345678' },
        out => { name => 'Foo', 'bankSortCode' => '[REDACTED]', 'accountNumber' => '[REDACTED]' } },
    { in => [ { name => 'Foo', 'bankSortCode' => '123456', 'accountNumber' => '12345678' }, { name => 'Foo', 'bankSortCode' => '123456', 'accountNumber' => '12345678' } ],
        out => [ { name => 'Foo', 'bankSortCode' => '[REDACTED]', 'accountNumber' => '[REDACTED]' }, { name => 'Foo', 'bankSortCode' => '[REDACTED]', 'accountNumber' => '[REDACTED]' } ] },
    { in => { response => { paymentResult => { paymentDetails => { authDetails => { maskedCardNumber => '1234********1234', cardDescription => 'PLASTIC' } } } } },
        out => { response => { paymentResult => { paymentDetails => { authDetails => { maskedCardNumber => '[REDACTED]', cardDescription => '[REDACTED]' } } } } } },
) {
    my $out = FixMyStreet::Roles::Syslog::_redact($test->{in});
    is_deeply $out, $test->{out};
    $log->log($test->{in});
    ok $logged;
    unlike $logged, qr/1234/;
}

done_testing;
