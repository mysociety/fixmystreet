use FixMyStreet::TestMech;
use FixMyStreet::App;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Reports;
use FixMyStreet::Cobrand::HighwaysEngland;
use HighwaysEngland;
use DateTime;
use File::Temp 'tempdir';
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

$mech->create_contact_ok(email => 'testareaemail@nh', body_id => $highways->id, category => 'Pothole (NH)');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'highwaysengland', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    CONTACT_EMAIL => 'fixmystreet@example.org',
    COBRAND_FEATURES => {
        contact_email => { highwaysengland => 'highwaysengland@example.org' },
        borough_email_addresses => {
            highwaysengland => {
                'testareaemail@nh' => [ {
                    'areas' => [ 'Area 1' ],
                    'email' => 'area1email@example.org',
                } ],
            },
        },
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
                    category      => 'Pothole (NH)',
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
        is $email->header('To'), '"National Highways" <area1email@example.org>';
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Heard from: Facebook/, 'where hear included in email';
        like $body, qr/Road: M1/, 'road data included in email';
        like $body, qr/Area: Area 1/, 'area data included in email';
        unlike $body, qr/FixMyStreet is an independent service/, 'FMS not mentioned in email';
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
                    category => 'Pothole (NH)',
                }
            },
            "submit details"
        );
        $mech->content_contains('Thank you');

        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
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
        $report->send_state('unprocessed');
        $report->cobrand("fixmystreet");
        $report->update;

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        $mech->email_count_is(1);
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/FixMyStreet is an independent service/, 'FMS template used for email';
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

    subtest "check All Reports pages display councils correctly" => sub {
        $mech->host('fixmystreet.com');
        $mech->get_ok('/reports/National+Highways');
        $mech->content_contains('Hackney'); # Mock has this returned
        $mech->host('highwaysengland.example.org');
        $mech->get_ok('/reports/National+Highways');
        $mech->content_contains('Hackney');
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    $mech->delete_problems_for_body($highways->id);
    my ($problem1, $problem2) = $mech->create_problems_for_body(2, $highways->id, 'Title');
    $problem1->update({
        extra => {
            where_hear => "Social media",
            _fields => [
                { name => "area_name", value => "South West", },
                { name => 'road_name', value => 'M5', },
            ],
        },
        service => 'desktop',
        cobrand => 'highwaysengland'
    });
    $problem2->update({
        extra => {
            where_hear => "Search engine",
            _fields => [
                { name => "area_name", value => "Area 7", },
                { name => 'sect_label', value => 'M1/111', },
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

    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'highwaysengland',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('URL","Device Type","Site Used","Reported As","User Email","User Phone","Area name","Road name","Section label","How you found us","Update 1","Update 1 date","Update 1 name","Update 2","Update 2 date","Update 2 name"');
    my @row1 = (
        'http://highwaysengland.example.org/report/' . $problem1->id,
        'desktop', 'highwaysengland', '', $problem1->user->email, '', '"South West"', 'M5', '', '"Social media"',
        '"This is an update"', $comment1->confirmed->datetime, '"Council User"',
        '"Second update"', $comment2->confirmed->datetime, 'public',
    );
    $mech->content_contains(join ',', @row1);
    $mech->content_contains('http://highwaysengland.example.org/report/' . $problem2->id .',mobile,fixmystreet,,' . $problem2->user->email . ',,"Area 7",,M1/111,"Search engine"');

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'highwaysengland',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('URL","Device Type","Site Used","Reported As","User Email","User Phone","Area name","Road name","Section label","How you found us","Update 1","Update 1 date","Update 1 name","Update 2","Update 2 date","Update 2 name"');
    @row1 = (
        'http://highwaysengland.example.org/report/' . $problem1->id,
        'desktop', 'highwaysengland', '', $problem1->user->email, '', '"South West"', 'M5', '', '"Social media"',
        '"This is an update"', $comment1->confirmed->datetime, '"Council User"',
        '"Second update"', $comment2->confirmed->datetime, 'public',
    );
    $mech->content_contains(join ',', @row1);
    $mech->content_contains('http://highwaysengland.example.org/report/' . $problem2->id .',mobile,fixmystreet,,' . $problem2->user->email . ',,"Area 7",,M1/111,"Search engine"');

};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'highwaysengland' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Categories must end with (NH)' => sub {
        my $superuser = $mech->create_user_ok('super@example.com', name => 'Admin',
            from_body => $highways, password => 'password', is_superuser => 1);
        $mech->log_in_ok( $superuser->email );

        my $expected_error = 'Category must end with (NH).';

        $mech->get_ok('/admin/body/' . $highways->id . '/_add');
        $mech->submit_form_ok( { with_fields => {
            category   => 'no suffix category',
            title_hint => 'test',
            email      => 'test@example.com',
            note       => 'test note',
            non_public => undef,
            state => 'unconfirmed',
        } } );
        $mech->content_contains($expected_error);

        $mech->submit_form_ok( { with_fields => {
            category   => 'suffix category (NH)',
            title_hint => 'test',
            email      => 'test@example.com',
            note       => 'test note',
            non_public => undef,
            state => 'unconfirmed',
        } } );
        $mech->content_lacks($expected_error);
        my $contact = $highways->contacts->find({ category => "suffix category (NH)" });
        is defined($contact), 1, "Contact with valid category suffix was created.";

        $mech->get_ok('/admin/body/' . $highways->id .'/suffix%20category%20%28NH%29');
        $mech->submit_form_ok( { with_fields => {
            category   => 'suffix removed category',
        } } );
        $mech->content_contains($expected_error);

        $mech->submit_form_ok( { with_fields => {
            category   => 'suffix category edited (NH)',
        } } );
        $mech->content_lacks($expected_error);
        my $edited_contact = $highways->contacts->find({ category => "suffix category edited (NH)" });
        is defined($contact), 1, "Contact category was edited to one with a valid suffix.";
    };
};

done_testing();
