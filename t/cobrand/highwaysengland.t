use FixMyStreet::TestMech;
use FixMyStreet::App;
use FixMyStreet::Script::Reports;
use FixMyStreet::Cobrand::HighwaysEngland;
use HighwaysEngland;
use DateTime;
use Test::MockModule;

my $he_mock = Test::MockModule->new('HighwaysEngland');
$he_mock->mock('database_file', sub { FixMyStreet->path_to('t/geocode/roads.sqlite'); });

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }


my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
$ukc->mock('_fetch_features', sub {
    my ($self, $cfg, $x, $y) = @_;
    is $y, 259573, 'Correct latitude';
    return [
        {
            properties => { area_name => 'Area 1', ROA_NUMBER => 'M1', sect_label => 'M1/111' },
            geometry => {
                type => 'LineString',
                coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
            }
        },
    ];
});

my $he_mock_cobrand = Test::MockModule->new('FixMyStreet::Cobrand::HighwaysEngland');
$he_mock_cobrand->mock('anonymous_account', sub { { email => 'anoncategory@example.org', name => 'Anonymous Category' } });

my $he = FixMyStreet::Cobrand::HighwaysEngland->new();

my $r = $he->geocode_postcode('M1');
ok $r->{error}, "searching for road only generates error";

$r = $he->geocode_postcode('m1');
ok $r->{error}, "searching for lowecase road only generates error";

my $mech = FixMyStreet::TestMech->new;
my $highways = $mech->create_body_ok(164186, 'National Highways', { send_method => 'Email::Highways' }, { cobrand => 'highwaysengland' });

$mech->create_contact_ok(email => 'highways@example.com', body_id => $highways->id, category => 'Pothole', group => 'National Highways');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'highwaysengland', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    CONTACT_EMAIL => 'fixmystreet@example.org',
    COBRAND_FEATURES => {
        contact_email => { highwaysengland => 'highwaysengland@example.org' },
        updates_allowed => {
            highwaysengland => 'open',
        },
    },
}, sub {
    ok $mech->host('highwaysengland.example.org');

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
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Heard from: Facebook/, 'where hear included in email';
        like $body, qr/Road: M1/, 'road data included in email';
        like $body, qr/Area: Area 1/, 'area data included in email';
        unlike $body, qr/Never retype another FixMyStreet report/, 'FMS not mentioned in email';
    };

    subtest "check things redacted appropriately" => sub {
        $mech->get_ok('/report/new?latitude=52.23025&longitude=-1.015826');
        my $title = "Test Redact report from 07000 000000";
        my $detail = 'Please could you email me on test@example.org or ring me on (01234) 567 890 or 07000 000000.';
        $mech->submit_form_ok(
            {
                button => 'report_anonymously',
                with_fields => {
                    title => $title,
                    detail => $detail,
                    category => 'Pothole',
                }
            },
            "submit details"
        );
        $mech->content_contains('Thank you');

        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->title, 'Test Redact report from [phone removed]';
        is $report->detail, 'Please could you email me on [email removed] or ring me on [phone removed] or [phone removed].';

        my ($history) = $report->moderation_history;
        is $history->title, $title;
        is $history->detail, $detail;

        $report->delete;
    };

    subtest "Reports from FMS cobrand use correct branding in email" => sub {
        my $report = FixMyStreet::DB->resultset("Problem")->first;
        ok $report, "Found the report";
        $report->whensent(undef);
        $report->cobrand("fixmystreet");
        $report->update;

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        $mech->email_count_is(1);
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Never retype another FixMyStreet report/, 'FMS template used for email';
    };

    my ($problem) = $mech->create_problems_for_body(1, $highways->id, 'Title', { created => '2021-11-30T12:34:56' });
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

    subtest 'check not in a group' => sub {
        my $j = $mech->get_ok_json('/report/new/ajax?latitude=52.236251&longitude=-0.892052&w=1');
        is $j->{subcategories}, undef;
    };

    subtest 'Reports do not have update form' => sub {
        $problem->state('fixed - council');
        $problem->update;

        $mech->get_ok('/report/' . $problem->id);
        $mech->content_lacks('Provide an update');
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

    my $now = DateTime->now;
    my $comment1 = $mech->create_comment_for_problem($problem1, $staffuser, 'Name Name', 'This is an update', 't', 'confirmed', 'confirmed', { confirmed => $now });
    $comment1->set_extra_metadata(is_body_user => $highways->id);
    $comment1->update;
    my $comment2 = $mech->create_comment_for_problem($problem1, $problem1->user, 'Jo Public', 'Second update', 't', 'confirmed', 'confirmed', { confirmed => $now });

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'highwaysengland',
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('URL","Device Type","Site Used","Reported As","Area name","How you found us","Update 1","Update 1 date","Update 1 name","Update 2","Update 2 date","Update 2 name"');
    my @row1 = (
        'http://highwaysengland.example.org/report/' . $problem1->id,
        'desktop', 'highwaysengland', '', '"South West"', '"Social media"',
        '"This is an update"', $comment1->confirmed->datetime, '"Council User"',
        '"Second update"', $comment2->confirmed->datetime, 'public',
    );
    $mech->content_contains(join ',', @row1);
    $mech->content_contains('http://highwaysengland.example.org/report/' . $problem2->id .',mobile,fixmystreet,,"Area 7","Search engine"');
};

done_testing();
