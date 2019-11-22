use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my');
is $mech->uri->path, '/auth', "got sent to the sign in page";

$mech->get_ok('/my/anonymize');
is $mech->uri->path, '/auth', "got sent to the sign in page";

my @problems = $mech->create_problems_for_body(3, 1234, 'Test Title');
$problems[1]->update({anonymous => 1});

my $other_user = FixMyStreet::DB->resultset('User')->find_or_create({ email => 'another@example.com' });
my @other = $mech->create_problems_for_body(1, 1234, 'Another Title', { user => $other_user });

my $user = $mech->log_in_ok( 'test@example.com' );
$mech->get_ok('/my');
is $mech->uri->path, '/my', "stayed on '/my' page";

$mech->content_contains('Test Title');
$mech->content_lacks('Another Title');

my @update;
my $i = 0;
foreach ($user, $user, $other_user) {
    $update[$i] = FixMyStreet::DB->resultset('Comment')->create({
        text => 'this is an update',
        user => $_,
        state => 'confirmed',
        problem => $problems[0],
        mark_fixed => 0,
        confirmed => \'current_timestamp',
        anonymous => $i % 2,
    });
    $i++;
}

foreach (
    { type => 'problem', id => 0, result => 404, desc => 'nothing' },
    { type => 'problem', obj => $problems[0], result => 200, desc => 'own report' },
    { type => 'problem', obj => $problems[1], result => 400, desc => 'already anon report' },
    { type => 'problem', obj => $other[0], result => 400, desc => 'other user report' },
    { type => 'update', id => -1, result => 400, desc => 'non-existent update' },
    { type => 'update', obj => $update[0], result => 200, desc => 'own update' },
    { type => 'update', obj => $update[1], result => 400, desc => 'already anon update' },
    { type => 'update', obj => $update[2], result => 400, desc => 'other user update' },
) {
    my $id = $_->{id} // $_->{obj}->id;
    $mech->get("/my/anonymize?$_->{type}=$id");
    is $mech->res->code, $_->{result}, "Got $_->{result} fetching $_->{desc}";
    if ($_->{result} == 200) {
        $mech->submit_form_ok( { button => 'hide' }, 'Submit button to hide name' );
        $_->{obj}->discard_changes;
        is $_->{obj}->anonymous, 1, 'Object now made anonymous';
        $_->{obj}->update({anonymous => 0});
    }
}

$mech->get("/my/anonymize?problem=" . $problems[0]->id);
$mech->submit_form_ok( { button => 'hide_everywhere' }, 'Submit button to hide name everywhere' );
is $problems[0]->discard_changes->anonymous, 1, 'Problem from form made anonymous';
is $problems[2]->discard_changes->anonymous, 1, 'Other user problem made anonymous';
is $update[0]->discard_changes->anonymous, 1, 'User update made anonymous';

done_testing();
