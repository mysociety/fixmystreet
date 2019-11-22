use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;
use LWP::Protocol::PSGI;
use t::Mock::MapItZurich;

LWP::Protocol::PSGI->register(t::Mock::MapItZurich->to_psgi_app, host => 'mapit.zurich');

my $mech = FixMyStreet::TestMech->new;
$mech->get_ok('/import');

my $sample_file = file(__FILE__)->parent->file("sample.jpg")->stringify;
ok -e $sample_file, "sample file $sample_file exists";

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2608, 'Borsetshire Council');
$mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street lighting',
    email => 'streetlighting@example.com',
);
$mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'highways@example.com',
);

# submit an empty report to import - check we get all errors
subtest "Test creating bad partial entries" => sub {

    foreach my $test (
        {
            fields => { email => 'bob', },
            errors => [
                'You must supply a service',
                'Please enter a subject',
                'Please enter your name',
                'Please enter a valid email',
                'Either a location or a photo must be provided.',
            ],
        },
        {
            fields => { email => 'bob@example.com' },
            errors => [
                'You must supply a service',
                'Please enter a subject',
                'Please enter your name',
                'Either a location or a photo must be provided.',
            ],
        },
        {
            fields => { lat => 1, lon => 1, },
            errors => [
                'You must supply a service',
                'Please enter a subject',
                'Please enter your name',
                'Please enter your email',
'We had a problem with the supplied co-ordinates - outside the UK?',
            ],
        },
        {
            fields => { photo => $sample_file, },
            errors => [
                'You must supply a service',
                'Please enter a subject',
                'Please enter your name',
                'Please enter your email',
            ],
        },
      )
    {
        $mech->get_ok('/import');

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
        }, sub {
            $mech->submit_form_ok(    #
                { with_fields => $test->{fields} },
                "fill in form"
            );
        };

        is_deeply( $mech->import_errors, $test->{errors}, "expected errors" );
    }

};

for my $test (
    {
        desc => 'Submit a correct entry',
    },
    {
        desc => 'Submit a correct web entry',
        web  => 1,
    }
) {
subtest "Submit a correct entry" => sub {
    $mech->get_ok('/import');

    $mech->submit_form_ok(    #
        {
            with_fields => {
                service => 'test-script',
                name    => 'Test User',
                email   => 'Test@example.com',
                subject => 'Test report',
                detail  => 'This is a test report',
                photo   => $sample_file,
                web     => $test->{web},
            }
        },
        "fill in form"
    );

    is_deeply( $mech->import_errors, [], "got no errors" );
    if ( $test->{web} ) {
        $mech->content_contains('Nearly done! Now check', "Got email confirmation page");
    } else {
        is $mech->content, 'SUCCESS', "Got success response";
    }

    # check that we have received the email
    my $token_url = $mech->get_link_from_email;
    $mech->clear_emails_ok;
    ok $token_url, "Found a token url $token_url";

    # go to the token url
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok($token_url);
    };

    # check that we are on '/around'
    is $mech->uri->path, '/around', "sent to /around";

    # check that we are not shown anything as we don't have a location yet
    is_deeply $mech->visible_form_values, { pc => '' },
      "check only pc field is shown";

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok(
            { with_fields => { pc => 'SN15 5NG' } },
            "fill in postcode"
        );
    };

    is $mech->uri->path, '/report/new', "sent to report page";

    # check that fields are prefilled for us
    is_deeply $mech->visible_form_values,
      {
        name          => 'Test User',
        title         => 'Test report',
        detail        => 'This is a test report',
        photo1        => '',
        photo2        => '',
        photo3        => '',
        phone         => '',
        may_show_name => '1',
        category      => '-- Pick a category --',
      },
      "check imported fields are shown";

    # Check photo present, and still there after map submission (testing bug #18)
    $mech->content_contains( '<img align="right" src="/photo/' );
    $mech->content_contains('latitude" value="51.5"', 'Check latitude');
    $mech->content_contains('longitude" value="-2.1"', 'Check longitude');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok(
            {
                button => 'tile_16192.10896',
                x => 10,
                y => 10,
            },
            "New map location"
        );
    };
    $mech->content_contains( '<img align="right" src="/photo/' );
    $mech->content_contains('latitude" value="51.508475"', 'Check latitude');
    $mech->content_contains('longitude" value="-2.108946"', 'Check longitude');

    # check that fields haven't changed at all
    is_deeply $mech->visible_form_values,
      {
        name          => 'Test User',
        title         => 'Test report',
        detail        => 'This is a test report',
        photo1        => '',
        photo2        => '',
        photo3        => '',
        phone         => '',
        may_show_name => '1',
        category      => '-- Pick a category --',
      },
      "check imported fields are shown";

    # change the details
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok(
            {
                with_fields => {
                    name          => 'New Test User',
                    title         => 'New Test report',
                    detail        => 'This is a test report',
                    phone         => '01234 567 890',
                    may_show_name => '1',
                    category      => 'Street lighting',
                }
            },
            "Update details and save"
        );
    };

    # check that report has been created
    my $user =
      FixMyStreet::DB->resultset('User')
      ->find( { email => 'test@example.com' } );
    ok $user, "Found a user";

    my $report = $user->problems->first;
    is $report->state, 'confirmed',       'is confirmed';
    is $report->title, 'New Test report', 'title is correct';

    $mech->delete_user($user);
};
}

subtest "Submit a correct entry (with location)" => sub {

    $mech->get_ok('/import');

    $mech->submit_form_ok(    #
        {
            with_fields => {
                service => 'test-script',
                lat     => '51.5',
                lon     => '-2.1',
                name    => 'Test User ll',
                email   => 'test-ll@example.com',
                subject => 'Test report ll',
                detail  => 'This is a test report ll',
                photo   => $sample_file,
            }
        },
        "fill in form"
    );

    is_deeply( $mech->import_errors, [], "got no errors" );
    is $mech->content, 'SUCCESS', "Got success response";

    # check that we have received the email
    my $token_url = $mech->get_link_from_email;
    $mech->clear_emails_ok;
    ok $token_url, "Found a token url $token_url";

    # go to the token url
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok($token_url);
    };

    # check that we are on '/report/new'
    is $mech->uri->path, '/report/new', "sent to /report/new";

    # check that fields are prefilled for us
    is_deeply $mech->visible_form_values,
      {
        name          => 'Test User ll',
        title         => 'Test report ll',
        detail        => 'This is a test report ll',
        photo1        => '',
        photo2        => '',
        photo3        => '',
        phone         => '',
        may_show_name => '1',
        category      => '-- Pick a category --',
      },
      "check imported fields are shown";

    # change the details
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok(    #
            {
                with_fields => {
                    name          => 'New Test User ll',
                    title         => 'New Test report ll',
                    detail        => 'This is a test report ll',
                    phone         => '01234 567 890',
                    may_show_name => '1',
                    category      => 'Street lighting',
                }
            },
            "Update details and save"
        );
    };

    # check that report has been created
    my $user =
      FixMyStreet::DB->resultset('User')
      ->find( { email => 'test-ll@example.com' } );
    ok $user, "Found a user";

    my $report = $user->problems->first;
    is $report->state, 'confirmed',          'is confirmed';
    is $report->title, 'New Test report ll', 'title is correct';

    $mech->delete_user($user);
};

subtest "Submit a correct entry (with location) to cobrand" => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'zurich' ],
    MAPIT_URL => 'http://mapit.zurich/',
    MAPIT_TYPES => [ 'O08' ],
    MAPIT_ID_WHITELIST => [],
    MAP_TYPE => 'Zurich,OSM',
  }, sub {
    ok $mech->host("zurich.example.org"), 'change host to zurich';

    $mech->get_ok('/import');

    $mech->submit_form_ok(    #
        {
            with_fields => {
                service => 'test-script',
                lat     => '47.4',
                lon     => '8.5',
                name    => 'Test User ll',
                email   => 'test-ll@example.com',
                subject => 'Test report ll',
                detail  => 'This is a test report ll',
                photo   => $sample_file,
            }
        },
        "fill in form"
    );

    is_deeply( $mech->import_errors, [], "got no errors" );
    is $mech->content, 'SUCCESS', "Got success response";

    # check that we have received the email
    my $token_url = $mech->get_link_from_email;
    $mech->clear_emails_ok;
    ok $token_url, "Found a token url $token_url";

    # go to the token url
    $mech->get_ok($token_url);

    # check that we are on '/report/new'
    is $mech->uri->path, '/report/new', "sent to /report/new";

    # check that fields are prefilled for us
    is_deeply $mech->visible_form_values,
      {
        name          => 'Test User ll',
        detail        => 'This is a test report ll',
        photo1         => '',
        photo2         => '',
        photo3         => '',
        phone         => '',
        username => 'test-ll@example.com',
      },
      "check imported fields are shown"
          or diag Dumper( $mech->visible_form_values ); use Data::Dumper;

    my $user = FixMyStreet::DB->resultset('User')->find( { email => 'test-ll@example.com' } );
    ok $user, "Found a user";

    my $report = $user->problems->first;
    is $report->state, 'partial',        'is still partial';
    is $report->title, 'Test report ll', 'title is correct';
    is $report->lang, 'de-ch',           'language is correct';

    $mech->delete_user($user);
  };
};

done_testing();
