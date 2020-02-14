use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;
use Test::LongString;
use DateTime;

my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $user2 = $mech->create_user_ok('test2@example.com', name => 'Other User');

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $westminster = $mech->create_body_ok(2504, 'Westminster City Council');
my ($report, $report2) = $mech->create_problems_for_body(2, $westminster->id, "Example", {
    user => $user,
    confirmed => $dt->ymd . ' ' . $dt->hms,
});
$report->update({
    title => 'Test 2',
    detail => 'Test 2 Detail'
});
my $report_id = $report->id;

subtest "check that no id redirects to homepage" => sub {
    $mech->get_ok('/report');
    is $mech->uri->path, '/', "at home page";
};

subtest "test bad council email clients web links" => sub {
    $mech->get_ok("/report/3D$report_id");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
};

subtest "test tailing non-ints get stripped" => sub {
    $mech->get_ok("/report/${report_id}xx ");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
};

subtest "test bad ids get dealt with (404)" => sub {
    foreach my $id ( 'XXX', 99999999 ) {
        ok $mech->get("/report/$id"), "get '/report/$id'";
        is $mech->res->code, 404,           "page not found";
        is $mech->uri->path, "/report/$id", "at /report/$id";
        $mech->content_contains('Unknown problem ID');
    }
};

subtest "change report to unconfirmed and check for 404 status" => sub {
    ok $report->update( { state => 'unconfirmed' } ), 'unconfirm report';
    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->res->code, 404, "page not found";
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
    $mech->content_contains('Unknown problem ID');
    ok $report->update( { state => 'confirmed' } ), 'confirm report again';
};


subtest "change report to hidden and check for 410 status" => sub {
    ok $report->update( { state => 'hidden' } ), 'hide report';
    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->res->code, 410, "page gone";
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
    $mech->content_contains('That report has been removed from FixMyStreet.');
    ok $report->update( { state => 'confirmed' } ), 'confirm report again';
};

subtest "duplicate reports are signposted correctly" => sub {
    $report2->set_extra_metadata(duplicate_of => $report->id);
    $report2->state('duplicate');
    $report2->update;

    my $report2_id = $report2->id;
    ok $mech->get("/report/$report2_id"), "get '/report/$report2_id'";
    $mech->content_contains('This report is a duplicate');
    $mech->content_contains($report->title);
    $mech->log_out_ok;

    $report2->unset_extra_metadata('duplicate_of');
    $report2->state('confirmed');
    $report2->update;
};

subtest "test /report/ajax" => sub {
    my $json = $mech->get_ok_json( "/report/ajax/$report_id" );
    is $json->{report}->{title}, "Test 2", "correct title";
    is $json->{report}->{state}, "confirmed", "correct state";
};

subtest "test a good report" => sub {
    $mech->get_ok("/report/$report_id");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
    is $mech->extract_problem_title, 'Test 2', 'problem title';
    is $mech->extract_problem_meta,
      'Reported by Test User at 15:47, Sat 16 April 2011',
      'correct problem meta information';
    $mech->content_contains('Test 2 Detail');
    $mech->content_lacks('Sent to');

    my $update_form = $mech->form_name('updateForm');

    my %fields = (
        name      => '',
        username => '',
        update    => '',
        add_alert => 1, # defaults to true
        fixed     => undef
    );
    is $update_form->value($_), $fields{$_}, "$_ value" for keys %fields;
};

subtest "test duration string" => sub {
    $report->update({ whensent => \'current_timestamp' });
    $mech->get_ok("/report/$report_id");
    $mech->content_contains('Sent to Westminster');
    FixMyStreet::override_config {
        AREA_LINKS_FROM_PROBLEMS => 1,
    }, sub {
        $mech->get_ok("/report/$report_id");
        $mech->content_contains('Sent to <a href="/reports/Westminster+City+Council">Westminster');
    };
};

foreach my $meta (
    {
        anonymous => 'f',
        category  => 'Other',
        service   => '',
        meta      => 'Reported by Test User at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 'f',
        category  => 'Roads',
        service   => '',
        meta =>
'Reported in the Roads category by Test User at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 'f',
        category  => '',
        service   => 'Transport service',
        meta =>
'Reported via Transport service by Test User at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 'f',
        category  => 'Roads',
        service   => 'Transport service',
        meta =>
'Reported via Transport service in the Roads category by Test User at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 't',
        category  => 'Other',
        service   => '',
        meta      => 'Reported anonymously at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 't',
        category  => 'Roads',
        service   => '',
        meta =>
'Reported in the Roads category anonymously at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 't',
        category  => '',
        service   => 'Transport service',
        meta =>
'Reported via Transport service anonymously at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 't',
        category  => 'Roads',
        service   => 'Transport service',
        meta =>
'Reported via Transport service in the Roads category anonymously at 15:47, Sat 16 April 2011'
    },
  )
{
    $report->service( $meta->{service} );
    $report->category( $meta->{category} );
    $report->anonymous( $meta->{anonymous} );
    $report->update;
    subtest "test correct problem meta information" => sub {
        $mech->get_ok("/report/$report_id");

    is $mech->extract_problem_meta, $meta->{meta};

    };
}

for my $test (
    {
        description => 'new report',
        date => DateTime->now,
        state => 'confirmed',
        banner_id => undef,
        banner_text => undef,
        fixed => 0
    },
    {
        description => 'old report',
        date => DateTime->new(
            year => 2009,
            month => 6,
            day => 12,
            hour => 9,
            minute => 43,
            second => 12
        ),
        state => 'confirmed',
        banner_id => 'unknown',
        banner_text => 'unknown',
        fixed => 0
    },
    {
        cobrand => 'fixmystreet',
        description => 'old open311 report',
        date => DateTime->new(
            year => 2009,
            month => 6,
            day => 12,
            hour => 9,
            minute => 43,
            second => 12
        ),
        state => 'confirmed',
        send_method => 'Open311',
        banner_id => undef,
        banner_text => undef,
        fixed => 0
    },
    {
        cobrand => 'westminster',
        description => 'old westminster report',
        date => DateTime->new(
            year => 2009,
            month => 6,
            day => 12,
            hour => 9,
            minute => 43,
            second => 12
        ),
        state => 'confirmed',
        banner_id => undef,
        banner_text => undef,
        fixed => 0
    },
    {
        description => 'old fixed report',
        date => DateTime->new(
            year => 2009,
            month => 6,
            day => 12,
            hour => 9,
            minute => 43,
            second => 12
        ),
        state => 'fixed',
        banner_id => 'fixed',
        banner_text => 'fixed',
        fixed => 1
    },
    {
        description => 'fixed report',
        date => DateTime->now,
        state => 'fixed',
        banner_id => 'fixed',
        banner_text => 'fixed',
        fixed => 1
    },
    {
        description => 'user fixed report',
        date => DateTime->now,
        state => 'fixed - user',
        banner_id => 'fixed',
        banner_text => 'fixed',
        fixed => 1
    },
    {
        description => 'council fixed report',
        date => DateTime->now,
        state => 'fixed - council',
        banner_id => 'fixed',
        banner_text => 'fixed',
        fixed => 1
    },
    {
        description => 'duplicate report',
        date => DateTime->now,
        state => 'duplicate',
        banner_id => 'closed',
        banner_text => 'closed',
        fixed => 0
    },
    {
        description => 'not responsible report',
        date => DateTime->now,
        state => 'not responsible',
        banner_id => 'closed',
        banner_text => 'closed',
        fixed => 0
    },
    {
        description => 'unable to fix report',
        date => DateTime->now,
        state => 'unable to fix',
        banner_id => 'closed',
        banner_text => 'closed',
        fixed => 0
    },
    {
        description => 'internal referral report',
        date => DateTime->now,
        state => 'internal referral',
        banner_id => 'closed',
        banner_text => 'closed',
        fixed => 0
    },
    {
        description => 'closed report',
        date => DateTime->now,
        state => 'closed',
        banner_id => 'closed',
        banner_text => 'closed',
        fixed => 0
    },
    {
        description => 'investigating report',
        date => DateTime->now,
        state => 'investigating',
        banner_id => 'progress',
        banner_text => 'investigating',
        fixed => 0
    },
    {
        description => 'action scheduled report',
        date => DateTime->now,
        state => 'action scheduled',
        banner_id => 'progress',
        banner_text => 'action scheduled',
        fixed => 0
    },
    {
        description => 'planned report',
        date => DateTime->now,
        state => 'planned',
        banner_id => 'progress',
        banner_text => 'planned',
        fixed => 0
    },
    {
        description => 'in progress report',
        date => DateTime->now,
        state => 'in progress',
        banner_id => 'progress',
        banner_text => 'progress',
        fixed => 0
    },
) {
    subtest "banner for $test->{description}" => sub {
        $report->confirmed( $test->{date}->ymd . ' ' . $test->{date}->hms );
        $report->lastupdate( $test->{date}->ymd . ' ' . $test->{date}->hms );
        $report->state( $test->{state} );
        $report->send_method_used( $test->{send_method} || undef );
        $report->update;

        my $cobrands = $test->{cobrand} ? [ $test->{cobrand} ] : [];
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => $cobrands,
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok("/report/$report_id");
        };
        is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
        my $banner = $mech->extract_problem_banner;
        if ( $banner->{text} ) {
            $banner->{text} =~ s/^ //g;
            $banner->{text} =~ s/ $//g;
        }

        if ( $test->{banner_id} ) {
            ok $banner->{class} =~ /banner--$test->{banner_id}/i, 'banner class';
        } else {
            is $banner->{class}, $test->{banner_id}, 'banner class';
        }

        if ($test->{banner_text}) {
            ok $banner->{text} =~ /$test->{banner_text}/i, 'banner text';
        } else {
            is $banner->{text}, $test->{banner_text}, 'banner text';
        }

        my $update_form = $mech->form_name( 'updateForm' );
        if ( $test->{fixed} ) {
            is $update_form->find_input( 'fixed' ), undef, 'problem is fixed';
        } else {
            ok $update_form->find_input( 'fixed' ), 'problem is not fixed';
        }
    };
}

subtest "Correct OpenGraph image is used when report has no photo" => sub {
        $report->update({ photo => undef });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains("/cobrands/fixmystreet/images/fms-og_image.jpg", "site image is used");
        $mech->content_lacks("/photo/$report_id.0.og", "report image is not present");
};

subtest "Correct OpenGraph image is used when report has a photo" => sub {
        $report->update({ photo => '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg' });
        $mech->get_ok("/report/$report_id");
        $mech->content_contains("/photo/$report_id.0.og.jpeg", "report opengraph image is present");
        $mech->content_lacks("/cobrands/fixmystreet/images/fms-og_image.jpg", "site image is not used");
};

my $body_westminster = $mech->create_body_ok(2504, 'Westminster City Council');
my $body_camden = $mech->create_body_ok(2505, 'Camden Borough Council');

for my $test (
    {
        desc => 'no state dropdown if user not from authority',
        from_body => undef,
        no_state => 1,
        report_body => $body_westminster->id,
    },
    {
        desc => 'state dropdown if user from authority',
        from_body => $body_westminster->id,
        no_state => 0,
        report_body => $body_westminster->id,
    },
    {
        desc => 'no state dropdown if user not from same body as problem',
        from_body => $body_camden->id,
        no_state => 1,
        report_body => $body_westminster->id,
    },
    {
        desc => 'state dropdown if user from authority and problem sent to multiple bodies',
        from_body => $body_westminster->id,
        no_state => 0,
        report_body => $body_westminster->id . ',2506',
    },
) {
    subtest $test->{desc} => sub {
        $mech->log_in_ok( $user->email );
        $user->from_body( $test->{from_body} );
        $user->update;

        $report->discard_changes;
        $report->bodies_str( $test->{report_body} );
        $report->update;

        $mech->get_ok("/report/$report_id");
        my $fields = $mech->visible_form_values( 'updateForm' );
        if ( $test->{no_state} ) {
            ok !$fields->{state};
        } else {
            ok $fields->{state};
        }
    };
}

my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $oxfordshireuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxfordshire);

subtest "check user details show when a user has correct permissions" => sub {
    $report->update( {
      name => 'Oxfordshire County Council',
      user_id => $oxfordshireuser->id,
      service => '',
      anonymous => 'f',
      bodies_str => $oxfordshire->id,
      confirmed => '2012-01-10 15:17:00'
    });

    ok $oxfordshireuser->user_body_permissions->create({
        body => $oxfordshire,
        permission_type => 'view_body_contribute_details',
    });

    $mech->log_in_ok( $oxfordshireuser->email );
    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->extract_problem_meta,
      'Reported in the Roads category by Oxfordshire County Council (Council User) at 15:17, Tue 10 January 2012 (Hide your name?)',
      'correct problem meta information';

    ok $oxfordshireuser->user_body_permissions->delete_all, "Remove view_body_contribute_details permissions";

    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->extract_problem_meta,
      'Reported in the Roads category by Oxfordshire County Council at 15:17, Tue 10 January 2012 (Hide your name?)',
      'correct problem meta information for user without relevant permissions';

    $mech->log_out_ok;

    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->extract_problem_meta,
      'Reported in the Roads category by Oxfordshire County Council at 15:17, Tue 10 January 2012',
      'correct problem meta information for logged out user';

};

subtest "check brackets don't appear when username and report name are the same" => sub {
    $report->update( {
      name => 'Council User'
    });

    $mech->log_in_ok( $oxfordshireuser->email );
    ok $mech->get("/report/$report_id"), "get '/report/$report_id'";
    is $mech->extract_problem_meta,
      'Reported in the Roads category by Council User at 15:17, Tue 10 January 2012 (Hide your name?)',
      'correct problem meta information';
};

END {
    done_testing();
}
