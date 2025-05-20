use FixMyStreet::Test;
use Test::MockModule;

my $abuse_rs = FixMyStreet::DB->resultset('Abuse');

$abuse_rs->create({ safe => 0, email => 'unsafe@example.com' });
$abuse_rs->create({ safe => 1, email => 'example.org' });

# .org fails to lookup; .net is okay; .com is not
my $lwp = Test::MockModule->new('LWP::UserAgent');
$lwp->mock('get', sub {
    my $body;
    $body = '{ "status": "429" }' if $_[1] =~ /example\.org/;
    $body = '{ "status": "200", "disposable": false }' if $_[1] =~ /example\.net/;
    $body = '{ "status": "200", "disposable": true }' if $_[1] =~ /example\.com/;
    return HTTP::Response->new(0, undef, undef, $body);
});

subtest 'unsafe' => sub {
    is $abuse_rs->count, 2, 'two entries in db';
    is $abuse_rs->unsafe->count, 1, 'one is unsafe';
};

subtest 'check' => sub {
    ok !$abuse_rs->check('safe@example.net'), 'not present is okay';
    ok !$abuse_rs->check('safe@example.org'), 'safe domain is okay';
    ok $abuse_rs->check('unsafe@example.com'), 'unsafe email is not okay';
};

subtest usercheck => sub {
    my $fn = \&FixMyStreet::DB::ResultSet::Abuse::usercheck;
    is $fn->('example.org'), 'off', 'no api key, all okay';

    FixMyStreet::override_config {
        CHECK_USERCHECK => 'api_key',
    }, sub {
        is $fn->('example.org'), 'fail', 'error in lookup fails';
        is $fn->('example.com'), 'bad', 'listed domain returns bad';
        is $fn->('example.net'), 'good', 'unlisted domain returns good';
    };
};

subtest 'check with usercheck' => sub {
    FixMyStreet::override_config {
        CHECK_USERCHECK => 'api_key',
    }, sub {
        is $abuse_rs->count, 2, 'still two entries in db';
        ok !$abuse_rs->check('safe@example.net'), 'not present is okay';
        is $abuse_rs->find('example.net')->safe, 1, 'new safe entry created';
        ok !$abuse_rs->check('safe@example.org'), 'safe domain is okay';
        is $abuse_rs->count, 3, 'No new entry';
        ok $abuse_rs->check('unsafe@example.com'), 'unsafe email is not okay';
        is $abuse_rs->count, 3, 'No new entry';
        ok $abuse_rs->check('newunsafe@example.com'), 'new unsafe email is not okay';
        is $abuse_rs->count, 4, 'New entry';
        is $abuse_rs->find('example.com')->safe, 0, 'new unsafe entry created';
    };
};

done_testing();
