use FixMyStreet::TestMech;

use_ok 'FixMyStreet::Script::Inactive';

my $in = FixMyStreet::Script::Inactive->new( anonymize => 6, email => 3 );
my $mech = FixMyStreet::TestMech->new;

my $user = FixMyStreet::DB->resultset("User")->find_or_create({ email => 'test@example.com' });
my $t = DateTime->new(year => 2016, month => 1, day => 1, hour => 12);
$user->last_active($t);
$user->update;

my $user_inactive = FixMyStreet::DB->resultset("User")->find_or_create({ email => 'inactive@example.com' });
$t = DateTime->now->subtract(months => 4);
$user_inactive->last_active($t);
$user_inactive->update;

subtest 'Anonymization of inactive users' => sub {
    $in->users;

    my $email = $mech->get_email;
    like $email->as_string, qr/inactive\@example.com/, 'Inactive email sent';

    $user->discard_changes;
    is $user->email, 'removed-' . $user->id . '@example.org', 'User has been anonymized';
};

done_testing;
