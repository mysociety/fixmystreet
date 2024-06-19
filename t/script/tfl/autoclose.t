use FixMyStreet::TestMech;
use DateTime;
use Test::Output;

use_ok 'FixMyStreet::Script::TfL::AutoClose';

my $close = FixMyStreet::Script::TfL::AutoClose->new( commit => 1 );
my $no_commit = FixMyStreet::Script::TfL::AutoClose->new();
my $mech = FixMyStreet::TestMech->new;


my $area_id = 2651;
my $body = $mech->create_body_ok($area_id, 'TfL');
my $body_user = $mech->create_user_ok('tfl@example.com', name => 'TfL', from_body => $body);
$body->update( { comment_user_id => $body_user->id } );
my $c1 = $mech->create_contact_ok(category => 'Potholes', body_id => $body->id, email => 'p');
my $c2 = $mech->create_contact_ok(category => 'Graffiti', body_id => $body->id, email => 'g');
my $c3 = $mech->create_contact_ok(category => 'Flytipping', body_id => $body->id, email => 'f');
my $t1 = FixMyStreet::DB->resultset('ResponseTemplate')->create({
    body_id => $body->id, title => "Not auto closed", text => "Text 1 ⛄", state => "fixed - council" }
);
my $t2 = FixMyStreet::DB->resultset('ResponseTemplate')->create({
    body_id => $body->id, title => "Auto closed", text => "Text 2", state => "fixed - council", auto_response => 1
});
my $t3 = FixMyStreet::DB->resultset('ResponseTemplate')->create({
    body_id => $body->id, title => "Investigating", text => "Text 3", state => "investigating", auto_response => 1
});
$t1->add_to_contacts($c1);
$t2->add_to_contacts($c2);
$t3->add_to_contacts($c3);

is_deeply keys %{ $close->categories }, ("Graffiti"), "fetches correct category list";

my $now = DateTime->now;

my %problems;
for my $p (
    {
        category => 'Grafitti',
        state => 'in progress',
        test => 'category_not_state',
        date => $now->clone->add( days => -30 ),
    },
    {
        category => 'Grafitti',
        state => 'action scheduled',
        test => 'category_state',
        date => $now->clone->add( days => -30 ),
    },
    {
        category => 'Potholes',
        state => 'action scheduled',
        test => 'not_category_state',
        date => $now->clone->add( days => -30 ),
    },
    {
        category => 'Grafitti',
        state => 'action scheduled',
        test => 'category_state_not_old',
        date => $now->clone->add( days => -20 ),
    }
) {
    my $k = delete $p->{test};
    my $d = delete $p->{date};
    $p->{confirmed} = $d;
    $p->{lastupdate} = $d;
    ($problems{$k}) = $mech->create_problems_for_body( 1, $body->id, 'Title', $p);
    my $c = FixMyStreet::DB->resultset('Comment')->create({
        problem => $problems{$k},
        text => 'comment',
        state => 'confirmed',
        problem_state => $p->{state},
        user => $body_user,
        confirmed => $p->{lastupdate}
    });
    is $problems{$k}->comments->count, 1, "comment added";
}

subtest "check that nothing saved without commit arg" => sub {
    ok $no_commit->close_reports({ 'Grafitti' => $t2 }), "close reports ran";
    $_->discard_changes for values %problems;

    is $problems{category_not_state}->state, 'in progress', 'ignores incorrect state';
    is $problems{category_state}->state, 'action scheduled', 'not updated to fixed';
    is $problems{not_category_state}->state, 'action scheduled', 'ignores incorrect category';
    is $problems{category_state_not_old}->state, 'action scheduled', 'ignores newer reports';

    is $problems{category_state}->comments->count, 1, "no comment added";
};

subtest "check that reports are updated" => sub {
    ok $close->close_reports({ 'Grafitti' => $t2 }), "close reports ran";

    $_->discard_changes for values %problems;

    is $problems{category_not_state}->state, 'in progress', 'ignores incorrect state';
    is $problems{category_state}->state, 'fixed - council', 'updates to fixed';
    is $problems{not_category_state}->state, 'action scheduled', 'ignores incorrect category';
    is $problems{category_state_not_old}->state, 'action scheduled', 'ignores newer reports';

    my $comment = ( $problems{category_state}->comments->order_by('id')->all )[-1];
    is $comment->text, "Text 2", "correct template used when closing";
};

subtest "check that days argument works" => sub {
    my $close_newer = FixMyStreet::Script::TfL::AutoClose->new( days => 19, commit => 1 );
    ok $close_newer->close_reports({ 'Grafitti' => $t2 }), "close reports ran";

    $problems{category_state_not_old}->discard_changes;
    is $problems{category_state_not_old}->state, 'fixed - council', 'updates to fixed';
};

subtest 'check that uses oldest comment for time' => sub {
    my $latest = $now->clone->add( days => -20 );
    my $oldest = $now->clone->add( days => -30 );
    my ($p) = $mech->create_problems_for_body( 1, $body->id, 'Title', {
        category => 'Grafitti',
        state => 'action scheduled',
        user => $body_user,
        lastupdate => $latest,
        confirmed => $latest,
    });

    my $first = FixMyStreet::DB->resultset('Comment')->create({
        problem => $p,
        problem_state => 'investigating',
        text => 'comment',
        state => 'confirmed',
        user => $body_user,
        confirmed => $oldest
    });

    FixMyStreet::DB->resultset('Comment')->create({
        problem => $p,
        text => 'comment',
        state => 'confirmed',
        problem_state => 'action scheduled',
        user => $body_user,
        confirmed => $latest
    });

    ok $close->close_reports({ 'Grafitti' => $t2 }), "close reports ran";

    $p->discard_changes;
    is $p->state, 'action scheduled', 'ignores comments with wrong state';


    $first->update( { problem_state => 'action scheduled' });
    ok $close->close_reports({ 'Grafitti' => $t2 }), "close reports ran";

    $p->discard_changes;
    is $p->state, 'fixed - council', 'updates to fixed';
};

subtest 'check that changing state accounted for' => sub {
    my $latest = $now->clone->add( days => -20 );
    my $oldest = $now->clone->add( days => -30 );
    my ($p) = $mech->create_problems_for_body( 1, $body->id, 'Title', {
        category => 'Grafitti',
        state => 'action scheduled',
        user => $body_user,
        lastupdate => $latest,
        confirmed => $latest,
    });

    my $investigating = FixMyStreet::DB->resultset('Comment')->create({
        problem => $p,
        problem_state => 'investigating',
        text => 'comment',
        state => 'confirmed',
        user => $body_user,
        confirmed => $latest
    });

    FixMyStreet::DB->resultset('Comment')->create({
        problem => $p,
        text => 'comment',
        state => 'confirmed',
        problem_state => 'action scheduled',
        user => $body_user,
        confirmed => $oldest
    });

    FixMyStreet::DB->resultset('Comment')->create({
        problem => $p,
        text => 'comment',
        state => 'confirmed',
        problem_state => 'action scheduled',
        user => $body_user,
        confirmed => $now->clone->add( hours => -2 ),
    });

    # regression test for problem_state not always being set
    FixMyStreet::DB->resultset('Comment')->create({
        problem => $p,
        text => 'comment',
        state => 'confirmed',
        problem_state => undef,
        user => $body_user,
        confirmed => $now->clone->add( hours => -1 ),
    });
    FixMyStreet::DB->resultset('Comment')->create({
        problem => $p,
        text => 'comment',
        state => 'confirmed',
        problem_state => 'action scheduled',
        user => $body_user,
        confirmed => $now,
    });

    ok $close->close_reports({ 'Grafitti' => $t2 }), "close reports ran";

    $p->discard_changes;
    is $p->state, 'action scheduled', 'change of state resets time';


    $investigating->update( { problem_state => 'action scheduled' });
    ok $close->close_reports({ 'Grafitti' => $t2 }), "close reports ran";

    $p->discard_changes;
    is $p->state, 'fixed - council', 'updates to fixed';
};
subtest 'check verbose works' => sub {
    my $verbose = FixMyStreet::Script::TfL::AutoClose->new( commit => 1, verbose => 1 );
    stdout_is { $close->close_reports({ 'Grafitti' => $t2 }) } "", "No message displayed with verbose";
    stdout_is { $verbose->close_reports({ 'Grafitti' => $t2 }) } "0 reports closed\n", "Message displayed with verbose";
};

subtest 'check dry run warning displayed' => sub {
    stderr_is { $no_commit->close() } "DRY RUN: use --commit to close reports\n", "Dry run warning message displayed without commit";
    stderr_is { $close->close() } "", "No warning displayed with commit";
};

done_testing;
