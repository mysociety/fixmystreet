use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::Dumfries';

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'dumfries' ],
}, sub {

        subtest 'Front page has correct wording' => sub {
            $mech->get_ok("/");
            $mech->content_contains("<h1>Report, view local roads and lighting problems</h1>");
            $mech->content_contains("(like potholes, blocked drains, broken paving, or street lighting)");
        };

    };

done_testing();
