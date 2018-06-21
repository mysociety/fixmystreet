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

my @problems;
for (my $m = 1; $m <= 12; $m++) {
    my $t = DateTime->new(year => 2017, month => $m, day => 1, hour => 12);
    push @problems, $mech->create_problems_for_body(1, 2237, 'Title', {
        dt => $t,
        lastupdate => "$t",
        state => $m % 2 ? 'fixed - user' : 'confirmed',
    });
}

$mech->create_comment_for_problem($problems[0], $user, 'Name', 'Update', 0, 'confirmed', $problems[0]->state);
FixMyStreet::DB->resultset("Alert")->create({ alert_type => 'new_updates', parameter => $problems[2]->id, user => $user });

subtest 'Anonymization of inactive fixed/closed reports' => sub {
    $in->reports;

    my $count = FixMyStreet::DB->resultset("Problem")->search({ user_id => $user->id })->count;
    is $count, 6, 'Six non-anonymised';

    my $comment = FixMyStreet::DB->resultset("Comment")->first;
    my $alert = FixMyStreet::DB->resultset("Alert")->first;
    is $comment->anonymous, 1, 'Comment anonymized';
    is $comment->user->email, 'removed-automatically@example.org', 'Comment user anonymized';
    is $alert->user->email, 'removed-automatically@example.org', 'Alert anonymized';
    isnt $alert->whendisabled, undef, 'Alert disabled';

    $mech->create_comment_for_problem($problems[0], $user, 'Name 2', 'Update', 0, 'confirmed', $problems[0]->state);
    $comment = FixMyStreet::DB->resultset("Comment")->search({ name => 'Name 2' })->first;

    $in->reports;
    $comment->discard_changes;
    is $comment->anonymous, 1, 'Comment anonymized';
    is $comment->user->email, 'removed-automatically@example.org', 'Comment user anonymized';
};

subtest 'Closing updates on inactive fixed/closed reports' => sub {
    my $in = FixMyStreet::Script::Inactive->new( close => 1 );
    $in->reports;
    $problems[2]->discard_changes;
    is $problems[2]->get_extra_metadata('closed_updates'), 1, 'Closed to updates';
    $mech->get_ok("/report/" . $problems[2]->id);
    $mech->content_contains('now closed to updates');
};

subtest 'Anonymization of inactive users' => sub {
    $in->users;

    my $email = $mech->get_email;
    like $email->as_string, qr/inactive\@example.com/, 'Inactive email sent';

    $user->discard_changes;
    is $user->email, 'removed-' . $user->id . '@example.org', 'User has been anonymized';
};

done_testing;
