use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $bexley = $mech->create_body_ok(2494, 'Bexley Council', { cobrand => 'bexley' });
$mech->create_contact_ok(body_id => $bexley->id, category => 'Damaged road', email => "ROAD");
my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council', { cobrand => 'oxfordshire' });
my $user = $mech->create_user_ok('user@example.com', name => 'Test User', from_body => $body);

$mech->log_in_ok( $user->email );

my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$ukc->mock('_get_bank_holiday_json', sub {
    {
        "england-and-wales" => {
            "events" => [
                { "date" => "2019-12-25", "title" => "Christmas Day" }
            ]
        }
    }
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
}, sub {
    subtest 'setting site message' => sub {
        $user->user_body_permissions->create({
            body => $body,
            permission_type => 'emergency_message_edit',
        });

        $mech->get_ok('/admin/sitemessage');
        $mech->content_lacks('Waste message');
        $mech->submit_form_ok({ with_fields => { site_message => 'Testing site message' } });
        $mech->content_contains('Testing site message');
        $mech->get_ok('/');
        $mech->content_contains('Testing site message');

        # Check removing message
        $mech->get_ok('/admin/sitemessage');
        $mech->submit_form_ok({ with_fields => { site_message => '' } });
        $mech->content_lacks('Testing site message');
        $mech->get_ok('/');
        $mech->content_lacks('Testing site message');
    };

    subtest "user without permissions can't set site message" => sub {
        $user->user_body_permissions->delete;
        $user->user_body_permissions->create({
            body => $body,
            permission_type => 'report_edit',
        });

        $mech->get('/admin/sitemessage');
        ok !$mech->res->is_success, "want a bad response";
        is $mech->res->code, 404, "got 404";
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
    COBRAND_FEATURES => { waste => { oxfordshire => 1 } },
}, sub {
    subtest 'setting site waste message' => sub {
        $user->user_body_permissions->create({
            body => $body,
            permission_type => 'emergency_message_edit',
        });

        $mech->get_ok('/admin/sitemessage');
        $mech->content_contains('Waste message');
        $mech->submit_form_ok({ with_fields => { site_message_waste => 'Testing site waste message' } });
        $mech->content_contains('Testing site waste message');
        $mech->get_ok('/');
        $mech->content_lacks('Testing site waste message');
        $mech->get_ok('/waste');
        $mech->content_contains('Testing site waste message');

        # Check removing message
        $mech->get_ok('/admin/sitemessage');
        $mech->submit_form_ok({ with_fields => { site_message_waste => '' } });
        $mech->content_lacks('Testing site waste message');
        $mech->get_ok('/waste');
        $mech->content_lacks('Testing site waste message');
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'oxfordshire' ],
}, sub {
    subtest 'setting reporting message' => sub {
        $mech->get_ok('/admin/sitemessage');
        $mech->content_contains('hard-coded');
    }
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'bexley', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk',
}, sub {
    subtest 'setting reporting message' => sub {
        $user->update({ from_body => $bexley });
        $user->user_body_permissions->create({
            body => $bexley,
            permission_type => 'emergency_message_edit',
        });

        $mech->host('bexley.example.org');
        $mech->get_ok('/admin/sitemessage');
        $mech->submit_form_ok({ with_fields => { site_message_reporting => 'Testing reporting message' } });
        $mech->content_contains('Testing reporting message');
        $mech->get_ok('/report/new?latitude=51.45556&longitude=0.15356');
        $mech->content_contains('Testing reporting message');

        $mech->host('fixmystreet.example.org');
        $mech->get_ok('/report/new?latitude=51.45556&longitude=0.15356');
        $mech->content_contains('Testing reporting message');

        # Check removing message
        $mech->host('bexley.example.org');
        $mech->get_ok('/admin/sitemessage');
        $mech->submit_form_ok({ with_fields => { site_message_reporting => '' } });
        $mech->content_lacks('Testing reporting message');
        $mech->get_ok('/report/new?latitude=51.45556&longitude=0.15356');
        $mech->content_lacks('Testing reporting message');
    };

    subtest 'setting OOH messages' => sub {
        my ($csrf) = $mech->content =~ /name="token" value="([^"]*)"/;
        $mech->post_ok('/admin/sitemessage', {
            site_message => 'Testing message',
            site_message_ooh => 'This is an OOH message',
            # Tuesdays, midnight-noon
            'ooh[0].day' => 3,
            'ooh[0].start' => 0,
            'ooh[0].end' => 12*60,
            # Bank Holidays all day
            'ooh[1].day' => 8,
            'ooh[1].start' => 0,
            'ooh[1].end' => 24*60,
            token => $csrf,
        });
        $mech->content_contains('This is an OOH message');
        set_fixed_time('2022-07-19T04:00:00Z');
        $mech->get_ok('/');
        $mech->content_contains('This is an OOH message');
        set_fixed_time('2022-07-19T14:00:00Z');
        $mech->get_ok('/');
        $mech->content_contains('Testing message');
        set_fixed_time('2019-12-25T14:00:00Z');
        $mech->get_ok('/');
        $mech->content_contains('This is an OOH message');
    };
};

done_testing;
