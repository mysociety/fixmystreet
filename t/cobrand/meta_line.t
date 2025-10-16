use FixMyStreet::TestMech;

# Test cobrand that shows "Other" category in meta_line
package FixMyStreet::Cobrand::ShowOther;
use parent 'FixMyStreet::Cobrand::Default';

sub show_other_category_in_summary { return 1; }

package main;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2237, 'Test Council');
my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

# Create cobrand instances
my $default_cobrand = FixMyStreet::Cobrand::Default->new();
my $show_other_cobrand = FixMyStreet::Cobrand::ShowOther->new();

subtest 'Default cobrand hides "Other" category in meta_line' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'default',
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test', {
            cobrand => 'default',
            category => 'Other',
            user => $user,
            anonymous => 0,
        });

        # Set the cobrand on the schema because we're not testing in a web context.
        $problem->result_source->schema->cobrand($default_cobrand);

        my $meta = $problem->meta_line;

        unlike $meta, qr/Other/i, 'Meta line does not mention Other category';
        like $meta, qr/Reported by Test User at/, 'Meta line shows reporter and time';
    };
};

subtest 'Cobrand with flag set shows "Other" category in meta_line' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'showother',
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test', {
            cobrand => 'showother',
            category => 'Other',
            user => $user,
            anonymous => 0,
        });

        # Set the cobrand on the schema because we're not testing in a web context.
        $problem->result_source->schema->cobrand($show_other_cobrand);

        my $meta = $problem->meta_line;

        like $meta, qr/Other/i, 'Meta line mentions Other category';
        like $meta, qr/Reported in the Other category by Test User at/, 'Meta line shows category, reporter and time';
    };
};

subtest 'Anonymous reports with "Other" category' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'default',
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test', {
            cobrand => 'default',
            category => 'Other',
            user => $user,
            anonymous => 1,
        });

        # Set the cobrand on the schema because we're not testing in a web context.
        $problem->result_source->schema->cobrand($default_cobrand);

        my $meta = $problem->meta_line;

        unlike $meta, qr/Other/i, 'Anonymous meta line does not mention Other category';
        like $meta, qr/Reported anonymously at/, 'Anonymous meta line shows anonymous';
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'showother',
    }, sub {
        # Create an anonymous problem with category "Other"
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test', {
            cobrand => 'showother',
            category => 'Other',
            user => $user,
            anonymous => 1,
        });

        # Set the cobrand on the schema because we're not testing in a web context.
        $problem->result_source->schema->cobrand($show_other_cobrand);

        my $meta = $problem->meta_line;

        like $meta, qr/Other/i, 'Anonymous meta line with flag set mentions Other category';
        like $meta, qr/Reported in the Other category anonymously at/, 'Anonymous meta line shows category';
    };
};

subtest 'Reports with service_display and "Other" category' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'default',
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test', {
            cobrand => 'default',
            category => 'Other',
            user => $user,
            service => 'iOS',
            anonymous => 0,
        });

        # Set the cobrand on the schema
        $problem->result_source->schema->cobrand($default_cobrand);

        my $meta = $problem->meta_line;

        unlike $meta, qr/Other/i, 'Meta line with service does not mention Other category';
        like $meta, qr/Reported via iOS by Test User at/, 'Meta line shows service but not category';
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'showother',
    }, sub {
        # Create a problem with category "Other" and service_display
        my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test', {
            cobrand => 'showother',
            category => 'Other',
            user => $user,
            service => 'iOS',
            anonymous => 0,
        });

        # Set the cobrand on the schema
        $problem->result_source->schema->cobrand($show_other_cobrand);

        my $meta = $problem->meta_line;

        like $meta, qr/Other/i, 'Meta line with service and flag set mentions Other category';
        like $meta, qr/Reported via iOS in the Other category by Test User at/, 'Meta line shows service and category';
    };
};

done_testing();
