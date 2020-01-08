use FixMyStreet::TestMech;
use Test::Output;

use_ok 'FixMyStreet::Script::Inactive';

my $in = FixMyStreet::Script::Inactive->new( anonymize => 6, email => 3 );
my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com');
my $t = DateTime->new(year => 2016, month => 1, day => 1, hour => 12);
$user->last_active($t);
$user->update;

my $user_inactive = $mech->create_user_ok('inactive@example.com');
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
        cobrand => $m % 3 ? 'default' : 'bromley',
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

subtest 'Test operating on one cobrand only' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley'
    }, sub {
        my $in = FixMyStreet::Script::Inactive->new( cobrand => 'bromley', close => 1 );
        $in->reports;
        # Reports not a multiple of 2 are fixed, reports a multiple of 3 are bromley
        $problems[2]->discard_changes;
        is $problems[2]->get_extra_metadata('closed_updates'), 1, 'Closed to updates';
        $problems[4]->discard_changes;
        is $problems[4]->get_extra_metadata('closed_updates'), undef, 'Not closed to updates';
        $problems[6]->discard_changes;
        is $problems[6]->get_extra_metadata('closed_updates'), undef, 'Not closed to updates';
        $problems[8]->discard_changes;
        is $problems[8]->get_extra_metadata('closed_updates'), 1, 'Closed to updates';
    };
};

subtest 'Closing updates on inactive fixed/closed reports' => sub {
    my $in = FixMyStreet::Script::Inactive->new( close => 1 );
    $in->reports;
    $problems[4]->discard_changes;
    is $problems[4]->get_extra_metadata('closed_updates'), 1, 'Closed to updates';
    $mech->get_ok("/report/" . $problems[4]->id);
    $mech->content_contains('now closed to updates');
};

subtest 'Deleting reports' => sub {
    my $in = FixMyStreet::Script::Inactive->new( delete => 6 );
    $in->reports;

    my $count = FixMyStreet::DB->resultset("Problem")->count;
    is $count, 6, 'Six left';

    $mech->get("/report/" . $problems[2]->id);
    is $mech->res->code, 404;
};

subtest 'Anonymization of inactive users' => sub {
    my $in = FixMyStreet::Script::Inactive->new( anonymize => 6, email => 3, verbose => 1 );
    stdout_is { $in->users } "Anonymizing user #" . $user->id . "\nEmailing user #" . $user_inactive->id . "\n", 'users dealt with first time';

    my $email = $mech->get_email;
    like $email->as_string, qr/inactive\@example.com/, 'Inactive email sent';
    $mech->clear_emails_ok;

    $user->discard_changes;
    is $user->email, 'removed-' . $user->id . '@example.org', 'User has been anonymized';

    stdout_is { $in->users } '', 'No output second time';

    $mech->email_count_is(0); # No further email sent

    $user->discard_changes;
    is $user->email, 'removed-' . $user->id . '@example.org', 'User has been anonymized';
};

subtest 'Test TfL deletion of safety critical reports' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'tfl'
    }, sub {
        for (my $y = 2; $y <= 10; $y+=2) {
            # 2 years, not safety; 4 years safety, 6 years not safety, 8 years safety, 10 years not safety
            my $t = DateTime->now->subtract(years => $y);
            my ($problem) = $mech->create_problems_for_body(1, 2237, 'Title', {
                dt => $t,
                lastupdate => "$t",
                state => 'fixed - user',
                cobrand => 'tfl',
            });
            $problem->update_extra_field({ name => 'safety_critical', value => $y % 4 ? 'no' : 'yes' });
            $problem->update;
        }

        my $in = FixMyStreet::Script::Inactive->new( cobrand => 'tfl', delete => 36 );
        $in->reports;
        my $count = FixMyStreet::DB->resultset("Problem")->search({ cobrand => 'tfl' })->count;
        is $count, 3, 'Three reports left, one too recent, two safety critical';

        $in = FixMyStreet::Script::Inactive->new( cobrand => 'tfl', delete => 84 );
        $in->reports;
        $count = FixMyStreet::DB->resultset("Problem")->search({ cobrand => 'tfl' })->count;
        is $count, 2, 'Two reports left, two too recent';
    }
};

done_testing;
