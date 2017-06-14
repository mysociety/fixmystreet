use FixMyStreet::Test;

use Sub::Override;

use FixMyStreet;

use_ok 'FixMyStreet::Cobrand';

# check that the allowed cobrands is correctly loaded from config
sub check_allowed_cobrands {
    my $should = shift;
    $should = [ map { { moniker => $_, host => $_ } } @$should ];
    my $allowed = FixMyStreet::Cobrand->get_allowed_cobrands;
    ok $allowed, "got the allowed_cobrands";
    isa_ok $allowed, "ARRAY";
    is_deeply $allowed, $should, "allowed_cobrands matched";
}

FixMyStreet::override_config { ALLOWED_COBRANDS => 'fixmyhouse' },
    sub { check_allowed_cobrands([ 'fixmyhouse' ]); };
FixMyStreet::override_config { ALLOWED_COBRANDS => [ 'fixmyhouse' ] },
    sub { check_allowed_cobrands([ 'fixmyhouse' ]); };
FixMyStreet::override_config { ALLOWED_COBRANDS => [ 'fixmyhouse', 'fixmyshed' ] },
    sub { check_allowed_cobrands([ 'fixmyhouse', 'fixmyshed' ]); };

sub run_host_tests {
    my %host_tests = @_;
    for my $host ( sort keys %host_tests ) {
        # get the cobrand class by host
        my $cobrand = FixMyStreet::Cobrand->get_class_for_host($host);
        my $test_class = $host_tests{$host};
        my $test_moniker = lc $test_class;
        is $cobrand, "FixMyStreet::Cobrand::$test_class", "does $host -> F::C::$test_class";
        my $c = $cobrand->new();
        is $c->moniker, $test_moniker;
    }
}

# Only one cobrand, always use it
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
}, sub {
    run_host_tests(
        'www.fixmystreet.com'    => 'FixMyStreet',
        'fiksgatami.example.org' => 'FixMyStreet',
        'oxfordshire.fixmystreet.com' => 'FixMyStreet',
        'some.odd.site.com'      => 'FixMyStreet',
    );
};

# Only one cobrand, no .pm file, should still work
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'nopmfile' ],
}, sub {
    run_host_tests(
        'www.fixmystreet.com' => 'nopmfile',
        'some.odd.site.com'   => 'nopmfile',
    );
};

# Couple of cobrands, hostname checking and default fallback
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fiksgatami', 'fixmystreet' ],
}, sub {
    run_host_tests(
        'www.fixmystreet.com'    => 'FixMyStreet',
        'fiksgatami.example.org' => 'FiksGataMi',
        'oxfordshire.fixmystreet.com' => 'FixMyStreet',    # not in the allowed_cobrands list
        'some.odd.site.com'      => 'Default',
    );
};

# now enable oxfordshire too and check that it works
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fiksgatami', 'oxfordshire', 'fixmystreet' ],
}, sub {
    run_host_tests(
        'www.fixmystreet.com'  => 'FixMyStreet',
        'fiksgatami.example.org' => 'FiksGataMi',
        'oxfordshire.fixmystreet.com' => 'Oxfordshire',  # found now it is in allowed_cobrands
        'some.odd.site.com'      => 'Default',
    );
};

# And a check with some regex matching
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'fixmystreet' => 'example' }, 'oxfordshire', { 'testing' => 'fixmystreet' } ],
}, sub {
    run_host_tests(
        'www.fixmystreet.com'  => 'testing',
        'fiksgatami.example.org' => 'FixMyStreet',
        'oxfordshire.fixmystreet.com' => 'Oxfordshire',
        'some.odd.site.com'      => 'Default',
    );
};

# check that the moniker works as expected both on class and object.
is FixMyStreet::Cobrand::FiksGataMi->moniker, 'fiksgatami',
  'class->moniker works';
is FixMyStreet::Cobrand::FiksGataMi->new->moniker, 'fiksgatami',
  'object->moniker works';

# check is_default works
ok FixMyStreet::Cobrand::Default->is_default,     '::Default is default';
ok !FixMyStreet::Cobrand::FiksGataMi->is_default, '::FiksGataMi is not default';

# all done
done_testing();
