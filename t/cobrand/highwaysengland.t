use FixMyStreet::TestMech;
use FixMyStreet::App;
use FixMyStreet::Script::Reports;
use FixMyStreet::Cobrand::HighwaysEngland;
use HighwaysEngland;
use Test::MockModule;

my $he_mock = Test::MockModule->new('HighwaysEngland');
$he_mock->mock('database_file', sub { FixMyStreet->path_to('t/geocode/roads.sqlite'); });

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }


my $he_mock_cobrand = Test::MockModule->new('FixMyStreet::Cobrand::HighwaysEngland');
$he_mock_cobrand->mock('anonymous_account', sub { { email => 'anoncategory@example.org', name => 'Anonymous Category' } });

my $he = FixMyStreet::Cobrand::HighwaysEngland->new();

my $r = $he->geocode_postcode('M1');
ok $r->{error}, "searching for road only generates error";

$r = $he->geocode_postcode('m1');
ok $r->{error}, "searching for lowecase road only generates error";

my $mech = FixMyStreet::TestMech->new;
my $highways = $mech->create_body_ok(2234, 'Highways England');

$mech->create_contact_ok(email => 'highways@example.com', body_id => $highways->id, category => 'Pothole');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'highwaysengland',
    MAPIT_URL => 'http://mapit.uk/',
    CONTACT_EMAIL => 'fixmystreet@example.org',
    COBRAND_FEATURES => {
        contact_email => { highwaysengland => 'highwaysengland@example.org' },
    },
}, sub {
    subtest "check where heard from saved" => sub {
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'M1, J16', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                button => 'report_anonymously',
                with_fields => {
                    title         => "Test Report for HE",
                    detail        => 'Test report details.',
                    category      => 'Pothole',
                    where_hear    => 'Facebook',
                }
            },
            "submit good details"
        );
        $mech->content_contains('Thank you');

        my $report = FixMyStreet::DB->resultset("Problem")->first;
        ok $report, "Found the report";
        is $report->get_extra_metadata('where_hear'), 'Facebook', 'saved where hear';

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        $mech->email_count_is(1);
        my $email = $mech->get_email;
        like $mech->get_text_body_from_email($email), qr/Heard from: Facebook/, 'where hear included in email'

    };

    my ($problem) = $mech->create_problems_for_body(1, $highways->id, 'Title');
    subtest "check anonymous display" => sub {
        $mech->get_ok('/report/' . $problem->id);
        $mech->content_lacks('Reported by Test User at');
    };

    subtest "contact form is disabled without report ID" => sub {
        $mech->get('/contact');
        ok !$mech->res->is_success(), "want a bad response";
        is $mech->res->code, 404, "got 404";
    };

    subtest "contact form is enabled for abuse reports" => sub {
        $mech->get_ok('/contact?id=' . $problem->id);
        $mech->content_lacks('fixmystreet@example.org', "Doesn't mention global CONTACT_EMAIL");
        $mech->content_lacks('fixmystreet&#64;example.org', "Doesn't mention (escaped) global CONTACT_EMAIL");
        $mech->content_contains('highwaysengland&#64;example.org', "Does mention cobrand contact_email") or diag $mech->content;
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    $mech->delete_problems_for_body($highways->id);
    my ($problem1, $problem2) = $mech->create_problems_for_body(2, $highways->id, 'Title');
    $problem1->update({
        extra => {
            where_hear => "Social media",
            _fields => [
                {
                    name => "area_name",
                    value => "South West",
                },
            ],
        },
        service => 'desktop',
        cobrand => 'highwaysengland'
    });
    $problem2->update({
        extra => {
            where_hear => "Search engine",
            _fields => [
                {
                    name => "area_name",
                    value => "Area 7",
                },
            ],
        },
        service => 'mobile',
        cobrand => 'fixmystreet',
    });

    my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User',
        from_body => $highways, password => 'password');
    $mech->log_in_ok( $staffuser->email );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'highwaysengland',
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('URL","Device Type","Reported As","Area name","How you found us","Site Used"');
    $mech->content_contains('http://highwaysengland.example.org/report/' . $problem1->id .',desktop,,"South West","Social media",highwaysengland');
    $mech->content_contains('http://highwaysengland.example.org/report/' . $problem2->id .',mobile,,"Area 7","Search engine",fixmystreet');
};

done_testing();
