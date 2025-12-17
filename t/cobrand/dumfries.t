use FixMyStreet::TestMech;

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

done_testing();
