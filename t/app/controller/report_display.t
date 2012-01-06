use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;
use DateTime;

my $mech = FixMyStreet::TestMech->new;

# create a test user and report
$mech->delete_user('test@example.com');
my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        council            => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Test 2',
        detail             => 'Test 2 Detail',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        state              => 'confirmed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

subtest "check that no id redirects to homepage" => sub {
    $mech->get_ok('/report');
    is $mech->uri->path, '/', "at home page";
};

subtest "test id=NNN redirects to /NNN" => sub {
    $mech->get_ok("/report?id=$report_id");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
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

subtest "test a good report" => sub {
    $mech->get_ok("/report/$report_id");
    is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
    is $mech->extract_problem_title, 'Test 2', 'problem title';
    is $mech->extract_problem_meta,
      'Reported by Test User at 15:47, Sat 16 April 2011',
      'correct problem meta information';
    $mech->content_contains('Test 2 Detail');

    my $update_form = $mech->form_name('updateForm');

    my %fields = (
        name      => '',
        rznvy     => '',
        update    => '',
        add_alert => 1, # defaults to true
        fixed     => undef
    );
    is $update_form->value($_), $fields{$_}, "$_ value" for keys %fields;
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
'Reported by Transport service by Test User at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 'f',
        category  => 'Roads',
        service   => 'Transport service',
        meta =>
'Reported by Transport service in the Roads category by Test User at 15:47, Sat 16 April 2011'
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
'Reported by Transport service anonymously at 15:47, Sat 16 April 2011'
    },
    {
        anonymous => 't',
        category  => 'Roads',
        service   => 'Transport service',
        meta =>
'Reported by Transport service in the Roads category anonymously at 15:47, Sat 16 April 2011'
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
        banner_text => 'This problem is old and of unknown status.',
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
        banner_text => 'This problem has been fixed.',
        fixed => 1
    },
    {
        description => 'fixed report',
        date => DateTime->now,
        state => 'fixed',
        banner_id => 'fixed',
        banner_text => 'This problem has been fixed.',
        fixed => 1
    },
    {
        description => 'user fixed report',
        date => DateTime->now,
        state => 'fixed - user',
        banner_id => 'fixed',
        banner_text => 'This problem has been fixed.',
        fixed => 1
    },
    {
        description => 'council fixed report',
        date => DateTime->now,
        state => 'fixed - council',
        banner_id => 'fixed',
        banner_text => 'This problem has been fixed.',
        fixed => 1
    },
    {
        description => 'closed report',
        date => DateTime->now,
        state => 'closed',
        banner_id => 'closed',
        banner_text => 'This problem has been closed.',
        fixed => 0
    },
    {
        description => 'investigating report',
        date => DateTime->now,
        state => 'investigating',
        banner_id => 'progress',
        banner_text => 'This problem is in progress.',
        fixed => 0
    },
    {
        description => 'planned report',
        date => DateTime->now,
        state => 'planned',
        banner_id => 'progress',
        banner_text => 'This problem is in progress.',
        fixed => 0
    },
    {
        description => 'in progressreport',
        date => DateTime->now,
        state => 'in progress',
        banner_id => 'progress',
        banner_text => 'This problem is in progress.',
        fixed => 0
    },
) {
    subtest "banner for $test->{description}" => sub {
        $report->confirmed( $test->{date}->ymd . ' ' . $test->{date}->hms );
        $report->lastupdate( $test->{date}->ymd . ' ' . $test->{date}->hms );
        $report->state( $test->{state} );
        $report->update;

        $mech->get_ok("/report/$report_id");
        is $mech->uri->path, "/report/$report_id", "at /report/$report_id";
        my $banner = $mech->extract_problem_banner;
        if ( $banner->{text} ) {
            $banner->{text} =~ s/^ //g;
            $banner->{text} =~ s/ $//g;
        }

        is $banner->{id}, $test->{banner_id}, 'banner id';
        is $banner->{text}, $test->{banner_text}, 'banner text';

        my $update_form = $mech->form_name( 'updateForm' );
        if ( $test->{fixed} ) {
            is $update_form->find_input( 'fixed' ), undef, 'problem is fixed';
        } else {
            ok $update_form->find_input( 'fixed' ), 'problem is not fixed';
        }
    };
}

for my $test ( 
    {
        desc => 'no state dropdown if user not from authority',
        from_council => 0,
        no_state => 1,
        report_council => '2504',
    },
    {
        desc => 'state dropdown if user from authority',
        from_council => 2504,
        no_state => 0,
        report_council => '2504',
    },
    {
        desc => 'no state dropdown if user not from same council as problem',
        from_council => 2505,
        no_state => 1,
        report_council => '2504',
    },
    {
        desc => 'state dropdown if user from authority and problem sent to multiple councils',
        from_council => 2504,
        no_state => 0,
        report_council => '2504,2506',
    },
) {
    subtest $test->{desc} => sub {
        $mech->log_in_ok( $user->email );
        $user->from_council( $test->{from_council} );
        $user->update;

        $report->discard_changes;
        $report->council( $test->{report_council} );
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

$report->discard_changes;
$report->council( 2504 );
$report->update;

# tidy up
$mech->delete_user('test@example.com');
done_testing();
