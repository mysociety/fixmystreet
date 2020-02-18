use Test::More;
use Test::Output;

use_ok 'FixMyStreet::Script::CreateSuperuser';

stderr_like { FixMyStreet::Script::CreateSuperuser::createsuperuser(); }
    qr/Specify a single email address/, 'Email error shown';
stderr_is { FixMyStreet::Script::CreateSuperuser::createsuperuser('test@example.org'); }
    "Specify a password for this new user.\n", 'Password error shown';
stdout_is { FixMyStreet::Script::CreateSuperuser::createsuperuser('test@example.org', 'password'); }
    "test\@example.org is now a superuser.\n", 'Correct message shown';

my $user = FixMyStreet::DB->resultset("User")->find({ email => 'test@example.org' });
ok $user, 'user created';
is $user->is_superuser, 1, 'is a superuser';

$user->update({ is_superuser => 0 });
stdout_is { FixMyStreet::Script::CreateSuperuser::createsuperuser('test@example.org'); }
    "test\@example.org is now a superuser.\n", 'Correct message shown';
$user->discard_changes;
is $user->is_superuser, 1, 'is a superuser again';

done_testing;
