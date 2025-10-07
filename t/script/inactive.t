use FixMyStreet::TestMech;
use Test::Output;

use_ok 'FixMyStreet::Script::Inactive';

my $in = FixMyStreet::Script::Inactive->new( anonymize => 6, email => 3 );
my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com');
my $t = DateTime->new(year => 2016, month => 1, day => 1, hour => 12);
$user->last_active($t);
$user->update;

my $anon_email = join('@', 'anonymous', 'brent.gov.uk');
my $anon_user = $mech->create_user_ok($anon_email);
$anon_user->last_active($t);
$anon_user->email($anon_email); # Don't want uniquified one
$anon_user->update;

my $user_inactive = $mech->create_user_ok('inactive@example.com');
$t = DateTime->now->subtract(months => 4);
$user_inactive->last_active($t);
$user_inactive->update;

my $comment_user = $mech->create_user_ok('commentuser@example.com');
$comment_user->last_active($t);
$comment_user->update;
my $body = $mech->create_body_ok(2237, 'Oxfordshire Council', { comment_user_id => $comment_user->id });
$user->update({ from_body => $body });

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
$user->add_to_planned_reports($problems[1]);

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
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['brent', 'fixmystreet'],
        COBRAND_FEATURES => {
            anonymous_account => {
                brent => 'anonymous',
            }
        },
    }, sub {
        my $in = FixMyStreet::Script::Inactive->new( anonymize => 6, email => 3, verbose => 1 );
        stdout_is { $in->users } "Anonymizing user #" . $user->id . "\nEmailing user #" . $user_inactive->id . "\n", 'users dealt with first time';

        my $email = $mech->get_email;
        my $user_email = $user_inactive->email;
        like $email->as_string, qr/Your $user_email/, 'Inactive email sent';
        $mech->clear_emails_ok;

        $user->discard_changes;
        is $user->email, 'removed-' . $user->id . '@example.org', 'User has been anonymized';
        is $user->from_body, undef;
        isnt $user->user_planned_reports->first->removed, undef;

        stdout_is { $in->users } '', 'No output second time';

        $mech->email_count_is(0); # No further email sent

        $user->discard_changes;
        is $user->email, 'removed-' . $user->id . '@example.org', 'User has been anonymized';
    };
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

subtest 'Test state/category/days deletion' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'peterborough'
    }, sub {
        for (my $d = 1; $d <= 10; $d+=1) {
            my $t = DateTime->now->subtract(days => $d);
            my ($problem) = $mech->create_problems_for_body(1, 2566, 'Title', {
                dt => $t,
                lastupdate => "$t",
                category => $d % 3 ? 'Collection' : 'Pothole',
                state => $d % 2 ? 'confirmed' : 'unconfirmed',
                cobrand => 'peterborough',
            });
        }

        my $in = FixMyStreet::Script::Inactive->new( cobrand => 'peterborough', delete => '3d', state => 'unconfirmed', category => 'Collection' );
        $in->reports;
        my $count = FixMyStreet::DB->resultset("Problem")->search({ cobrand => 'peterborough' })->count;
        is $count, 7, 'Three match that are old enough, unconfirmed, and Collection (4, 8, 10)'
    }
};

subtest 'Test closing updates per category with closure_timespan' => sub {
    my $contact1 = $mech->create_contact_ok(
        body_id => $body->id,
        category => 'Pothole',
        email => 'pothole@testbody1.gov.uk',
        extra => {
            closure_timespan => '2m'
        }
    );
    my $contact2 = $mech->create_contact_ok(
        body_id => $body->id,
        category => 'Streetlight',
        email => 'streetlight@testbody1.gov.uk',
        extra => {
            closure_timespan => '3m'
        }
    );
    my $contact3 = $mech->create_contact_ok(
        body_id => $body->id,
        category => 'Graffiti',
        email => 'graffiti@testbody2.gov.uk',
        extra => {
            closure_timespan => '1m'
        }
    );
    my $contact4 = $mech->create_contact_ok(
        body_id => $body->id,
        category => 'Litter',
        email => 'litter@testbody1.gov.uk'
    );

    my $now = DateTime->now;

    # Problems that should be closed (older than their category's closure_timespan)
    my ($old_pothole) = $mech->create_problems_for_body(1, $body->id, 'Old Pothole', {
        dt => $now->clone->subtract(months => 3),
        lastupdate => $now->clone->subtract(months => 3),
        state => 'fixed - user',
        category => 'Pothole',
        bodies_str => $body->id,
    });
    my ($old_streetlight) = $mech->create_problems_for_body(1, $body->id, 'Old Streetlight', {
        dt => $now->clone->subtract(months => 4),
        lastupdate => $now->clone->subtract(months => 4),
        state => 'fixed - council',
        category => 'Streetlight',
        bodies_str => $body->id,
    });
    my ($old_graffiti) = $mech->create_problems_for_body(1, $body->id, 'Old Graffiti', {
        dt => $now->clone->subtract(months => 2),
        lastupdate => $now->clone->subtract(months => 2),
        state => 'fixed - user',
        category => 'Graffiti',
        bodies_str => $body->id,
    });

    # Problems that should NOT be closed (newer than their category's closure_timespan)
    my ($new_pothole) = $mech->create_problems_for_body(1, $body->id, 'New Pothole', {
        dt => $now->clone->subtract(days => 10),
        lastupdate => $now->clone->subtract(days => 10),
        state => 'fixed - user',
        category => 'Pothole',
        bodies_str => $body->id,
    });
    my ($new_streetlight) = $mech->create_problems_for_body(1, $body->id, 'New Streetlight', {
        dt => $now->clone->subtract(months => 2),
        lastupdate => $now->clone->subtract(months => 2),
        state => 'fixed - council',
        category => 'Streetlight',
        bodies_str => $body->id,
    });

    # Problem with category that has no closure_timespan (should be ignored)
    my ($litter_problem) = $mech->create_problems_for_body(1, $body->id, 'Old Litter', {
        dt => $now->clone->subtract(months => 6),
        lastupdate => $now->clone->subtract(months => 6),
        state => 'fixed - user',
        category => 'Litter',
        bodies_str => $body->id,
    });

    my $in = FixMyStreet::Script::Inactive->new(close_per_category => 1);
    $in->reports;

    $old_pothole->discard_changes;
    is $old_pothole->get_extra_metadata('closed_updates'), 1, 'Old pothole closed to updates (older than 2m)';
    $old_streetlight->discard_changes;
    is $old_streetlight->get_extra_metadata('closed_updates'), 1, 'Old streetlight closed to updates (older than 3m)';
    $old_graffiti->discard_changes;
    is $old_graffiti->get_extra_metadata('closed_updates'), 1, 'Old graffiti closed to updates (older than 1m)';
    $new_pothole->discard_changes;
    is $new_pothole->get_extra_metadata('closed_updates'), undef, 'New pothole not closed to updates (newer than 2m)';
    $new_streetlight->discard_changes;
    is $new_streetlight->get_extra_metadata('closed_updates'), undef, 'New streetlight not closed to updates (newer than 3m)';
    $litter_problem->discard_changes;
    is $litter_problem->get_extra_metadata('closed_updates'), undef, 'Litter problem not closed (no closure_timespan set)';
};

done_testing;
