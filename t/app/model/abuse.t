use FixMyStreet::Test;

my $abuse_rs = FixMyStreet::DB->resultset('Abuse');

$abuse_rs->create({ safe => 0, email => 'unsafe@example.com' });
$abuse_rs->create({ safe => 1, email => 'example.org' });

subtest 'unsafe' => sub {
    is $abuse_rs->count, 2, 'two entries in db';
    is $abuse_rs->unsafe->count, 1, 'one is unsafe';
};

subtest 'check' => sub {
    ok !$abuse_rs->check('safe@example.net'), 'not present is okay';
    ok !$abuse_rs->check('safe@example.org'), 'safe domain is okay';
    ok $abuse_rs->check('unsafe@example.com'), 'unsafe email is not okay';
};

done_testing();
