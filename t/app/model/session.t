use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

$mech->log_in_ok('test@example.com');

my $session = FixMyStreet::DB->resultset("Session")->first;

my $id = $session->id;
$id =~ s/\s+$//;
is $id, "session:" . $session->id_code;
is $session->user->email, 'test@example.com';

done_testing;
