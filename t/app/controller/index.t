use FixMyStreet::TestMech;
use DateTime;
use Web::Scraper;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

use t::Mock::Nominatim;

# check that the homepage loads
$mech->get_ok('/');

subtest "check that the form goes to /around" => sub {
    $mech->get_ok('/');
    is $mech->uri->path, '/', "still on '/'";

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/'
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'SW1A 1AA', } } );
    };

    # check that we are at /around
    is $mech->uri->path, '/around', "Got to /around";
    is_deeply { $mech->uri->query_form }, { pc => 'SW1A 1AA' },
      "query passed along";
};

subtest "does pc, (x,y), (e,n) or (lat,lon) go to /around" => sub {

    foreach my $test (    #
        {
            in  => { pc => 'SW1A 1AA' },
            out => { pc => 'SW1A 1AA' },
        },
        {
            in  => { lat => 51.50100, lon => -0.14158 },
            out => { lat => 51.50100, lon => -0.14158 },
        },
        {
            in  => { x   => 3281,      y   => 1113, },
            out => { lat => 51.499825, lon => -0.140137 },
        },
        {
            in  => { e   => 1234,      n   => 4567 },
            out => { lat => 49.808509, lon => -7.544784 },
        },
      )
    {

        my $uri = URI->new('http://localhost/');
        $uri->query_form( $test->{in} );

        # get the uri and check for 302
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok($uri);
        };

        # check that we are at /around
        is $mech->uri->path, '/around', "Got to /around";
        is_deeply { $mech->uri->query_form }, $test->{out}, "query correct";
    }
};

my $problem_rs = FixMyStreet::DB->resultset('Problem');
my $num = $problem_rs->count;

my @edinburgh_problems = $mech->create_problems_for_body(5, 2651, 'Front page');
is scalar @edinburgh_problems, 5, 'correct number of edinburgh problems created';

$mech->get_ok('/report/' . $edinburgh_problems[2]->id);
$mech->content_contains('Front page Test 3 for 2651', 'problem to be marked non public visible');
is $problem_rs->count, $num+5;

my $private = $edinburgh_problems[2];
ok $private->update( { non_public => 1 } ), 'problem marked non public';

ok $mech->get('/report/' . $edinburgh_problems[2]->id);
is $mech->res->code, 403, 'page forbidden';
is $problem_rs->count, $num+5;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');
subtest "prefilters /around if user has categories" => sub {
    my $user = $mech->log_in_ok('test@example.com');
    my $categories = [
        $mech->create_contact_ok( body_id => $oxon->id, category => 'Cows', email => 'cows@example.net' )->id,
        $mech->create_contact_ok( body_id => $oxon->id, category => 'Potholes', email => 'potholes@example.net' )->id,
    ];
    $user->from_body($oxon);
    $user->set_extra_metadata('categories', $categories);
    $user->update;

    $mech->get_ok('/');
    # NB can't use visible_form_values because categories field is hidden
    $mech->content_contains("Cows,Potholes");
};

subtest "prefilters /around if filter_category given in URL" => sub {
    $mech->get_ok('/?filter_category=MyUniqueTestCategory&filter_group=MyUniqueTestGroup');
    # NB can't use visible_form_values because fields are hidden
    $mech->content_contains("MyUniqueTestCategory");
    $mech->content_contains("MyUniqueTestGroup");
};

subtest "recent reports are correctly shown on front page" => sub {
    FixMyStreet::DB->resultset('Problem')->delete_all;

    my ($r1, $r2, $r3)= $mech->create_problems_for_body(3, 2651, 'Recent problem');

    # Make the oldest problem have the newest confirmed timestamp so it appears top of recent list
    $r1->update( { confirmed => $r1->confirmed + DateTime::Duration->new( minutes => 5 ) } );

    $mech->get_ok('/');

    my $result = scraper {
        process '#front-recently ul li h3', 'title[]', 'TEXT';
    }->scrape( $mech->response );

    is_deeply $result->{title}, [
        'Recent problem Test 3 for 2651',
        'Recent problem Test 1 for 2651',
        'Recent problem Test 2 for 2651'
    ], "correct ordering of recent problems";
};

END {
    done_testing();
}
