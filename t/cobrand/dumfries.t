use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

use DateTime;
use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use Test::More;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::Dumfries';

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'dumfries' ],
    COBRAND_FEATURES => {
        contact_us_phone => {
            dumfries => '1234567',
        },
    }
}, sub {

        subtest 'Front page has correct wording' => sub {
            $mech->get_ok("/");
            $mech->content_contains("<h1>Report, view local roads and lighting problems</h1>");
            $mech->content_contains("(like potholes, blocked drains, broken paving, or street lighting)");
        };

        subtest 'faq contains contact_us_phone substitutions' => sub {
            $mech->get_ok("/faq");
            ok $mech->text =~ "For these types of issue, please call us on: 1234567", 'contact_us_phone sentence reads correctly';
        };

        subtest 'Privacy contains contact_us_phone substitutions' => sub {
            $mech->get_ok("/about/privacy");
            ok $mech->text =~ "Please call us on: 1234567 if you would like your details to be removed from our admin database sooner than that", 'contact_us_phone sentence reads correctly';
            ok $mech->text =~ "To exercise your right to object, you can call us on: 123456", 'contact_us_phone sentence reads correctly';
        };

    };


my $body = $mech->create_body_ok(2656, 'Dumfries and Galloway', {
    cobrand => 'dumfries'
});

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'potholes@dumgal.gov.uk'
);

my $reporter = $mech->create_user_ok('reporter@example.com', name => 'Reporter');
my $staff_user = $mech->create_user_ok('staff@dumgal.gov.uk', name => 'Staff User', from_body => $body);
my $other_user = $mech->create_user_ok('other@example.com', name => 'Other User');

# Create problem once and reuse it
my $problem = FixMyStreet::DB->resultset('Problem')->create({
    postcode           => 'DG1 1AA',
    bodies_str         => $body->id,
    areas              => ',2656,',
    category           => 'Potholes',
    title              => 'Test problem',
    detail             => 'Test detail',
    used_map           => 1,
    name               => 'Reporter',
    anonymous          => 0,
    state              => 'confirmed',
    confirmed          => DateTime->now,
    lastupdate         => DateTime->now->subtract(days => 20),
    latitude           => 55.0706,
    longitude          => -3.9568,
    user_id            => $reporter->id,
    cobrand            => 'dumfries',
});

# Create context and cobrand once
my ($res, $c) = ctx_request('/');
my $cobrand = FixMyStreet::Cobrand::Dumfries->new({ c => $c });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['dumfries'],
}, sub {
    subtest 'updates_disallowed - state not planned or investigating' => sub {
        $problem->update({
            state => 'confirmed',
            lastupdate => \"'2020-01-01 00:00:00'",
        });
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when state is not planned or investigating';
    };

    subtest 'updates_disallowed - state is planned but less than 14 days' => sub {
        my $recent = DateTime->now->subtract(days => 7)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'planned',
            lastupdate => \"'$recent'",
        });
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when less than 14 days have passed';
    };

    subtest 'updates_disallowed - state is investigating but less than 14 days' => sub {
        my $recent = DateTime->now->subtract(days => 10)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'investigating',
            lastupdate => \"'$recent'",
        });
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when less than 14 days have passed (investigating state)';
    };

    subtest 'updates allowed - reporter on planned report after 14 days' => sub {
        my $old = DateTime->now->subtract(days => 14)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'planned',
            lastupdate => \"'$old'",
        });
        $problem->discard_changes;
        $c->user($reporter);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, '',
            'Updates allowed when reporter updates their own report (planned, 14+ days)';
    };

    subtest 'updates allowed - staff on investigating report after 14 days' => sub {
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'investigating',
            lastupdate => \"'$old'",
        });
        $problem->discard_changes;
        $c->user($staff_user);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, '',
            'Updates allowed when staff updates report (investigating, 14+ days)';
    };

    subtest 'updates disallowed - other user on planned report after 14 days' => sub {
        my $old = DateTime->now->subtract(days => 20)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'planned',
            lastupdate => \"'$old'",
        });
        $problem->discard_changes;
        $c->user($other_user);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when other user (not staff/reporter) tries to update';
    };

    subtest 'updates disallowed - not logged in user' => sub {
        my $old = DateTime->now->subtract(days => 14)->strftime('%Y-%m-%d %H:%M:%S');
        $problem->update({
            state => 'planned',
            lastupdate => \"'$old'",
        });
        $problem->discard_changes;
        $c->user(undef);

        my $result = $cobrand->updates_disallowed($problem);
        is $result, 1,
            'Updates disallowed when not logged in';
    };
};

$problem->delete;

done_testing();
