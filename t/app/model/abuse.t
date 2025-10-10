use FixMyStreet::Test;
use Test::MockModule;

# unsafe@example.com - already banned
# example.co.uk - bad request
# example.org - too many requests (present locally as safe)
# example.net - passes usercheck
# example.com - fails usercheck (not present locally)

my $abuse_rs = FixMyStreet::DB->resultset('Abuse');

$abuse_rs->create({ safe => 0, email => 'unsafe@example.com' });
$abuse_rs->create({ safe => 1, email => 'example.org' });
$abuse_rs->create({ safe => 1, email => 'safe.example.org' });
$abuse_rs->create({ safe => 0, email => 'baduser@safe.example.org' });
my $count = $abuse_rs->count;

# .org fails to lookup; .net is okay; .com is not; .co.uk is badly formatted
my $lwp = Test::MockModule->new('LWP::UserAgent');
$lwp->mock('get', sub {
    my $body;
    $body = '{ "status": "400" }' if $_[1] =~ /example\.co\.uk$/;
    $body = '{ "status": "429" }' if $_[1] =~ /example\.org$/;
    $body = '{ "status": "200", "disposable": false }' if $_[1] =~ /example\.net$/;
    $body = '{ "status": "200", "disposable": true }' if $_[1] =~ /example\.com$/;
    return HTTP::Response->new(0, undef, undef, $body);
});

subtest 'unsafe' => sub {
    is $abuse_rs->count, $count, 'correct number in db';
    is $abuse_rs->unsafe->count, 2, 'two is unsafe';
};

subtest 'check' => sub {
    ok !$abuse_rs->check('safe@example.net'), 'not present is okay';
    ok !$abuse_rs->check('safe@example.org'), 'safe domain is okay';
    ok $abuse_rs->check('unsafe@example.com'), 'unsafe email is not okay';
    ok $abuse_rs->check('baduser@safe.example.org'), 'unsafe email is not okay';
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
        is $abuse_rs->count, $count, 'still correct entries in db';
        ok !$abuse_rs->check('safe@example.net'), 'not present is okay';
        is $abuse_rs->find('example.net')->safe, 1, 'new safe entry created';
        ok !$abuse_rs->check('safe@example.org'), 'safe domain is okay';
        is $abuse_rs->count, $count+1, 'New entry';
        ok $abuse_rs->check('unsafe@Example.com'), 'unsafe email is not okay';
        is $abuse_rs->count, $count+1, 'No new entry';
        ok $abuse_rs->check('newunsafe@example.com'), 'new unsafe email is not okay';
        is $abuse_rs->count, $count+2, 'New entry';
        is $abuse_rs->find('example.com')->safe, 0, 'new unsafe entry created';
        ok !$abuse_rs->check('07700 900000'), 'Mobile phone number';
        is $abuse_rs->count, $count+2, 'No new entry';
    };
};

subtest 'check with comma-separated email addresses' => sub {
    FixMyStreet::override_config {
        CHECK_USERCHECK => 'api_key',
    }, sub {
        $abuse_rs->delete_all;
        ok !$abuse_rs->check('test@example.net,test@example.co.uk'), 'two email addresses are okay';
        is $abuse_rs->count, 1, 'one entry in db';
        is $abuse_rs->find('example.net')->safe, 1, 'new safe entry created';
        is $abuse_rs->find('example.net,test@example.co.uk'), undef, 'badly formatted domain entry not created';
        is $abuse_rs->find('bar.com'), undef, 'second domain entry not created';
    }

};

done_testing();
