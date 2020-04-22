use FixMyStreet::TestMech;
use Path::Tiny;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

my $sample_file = path(__FILE__)->parent->child("sample.jpg");
ok -e $sample_file, "sample file $sample_file exists";

subtest "test that bare requests to /report/new get redirected" => sub {
    $mech->get_ok('/report/new');
    is $mech->uri->path, '/', "went to /";
    is_deeply { $mech->uri->query_form }, {}, "query empty";

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/report/new?pc=SW1A%201AA');
        is $mech->uri->path, '/around', "went to /around";
        is_deeply { $mech->uri->query_form }, { pc => 'SW1A 1AA' },
          "pc correctly transferred";

        $mech->get_ok('/report/new?pc_override=SW1A%201AA&latitude=51&longitude=-2');
        is $mech->uri->path, '/around', "went to /around";
        is_deeply { $mech->uri->query_form }, { pc => 'SW1A 1AA' },
          "pc correctly transferred, lat/lon gone";
    };
};

my %body_ids;
for my $body (
    { area_id => 2226, name => 'Gloucestershire County Council' },
    { area_id => 2504, name => 'Westminster City Council' },
    { area_id => 2482, name => 'Bromley Council' },
    { area_id => 2217, name => 'Buckinghamshire Council' },
    { area_id => 2232, name => 'Lincolnshire County Council' },
    { area_id => 2237, name => 'Oxfordshire County Council' },
    { area_id => 2600, name => 'Rutland County Council' },
    { area_id => 2234, name => 'Northamptonshire County Council' },
    { area_id => 2566, name => 'Peterborough City Council' },
) {
    my $body_obj = $mech->create_body_ok($body->{area_id}, $body->{name});
    $body_ids{$body->{area_id}} = $body_obj->id;
}

# Let's make some contacts to send things to!
$mech->create_contact_ok(
    body_id => $body_ids{2226}, # Gloucestershire
    category => 'Potholes',
    email => 'potholes@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2482}, # Bromley
    category => 'Trees',
    email => 'trees@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2504},
    category => 'Street lighting',
    email => 'highways@example.com'
);
$mech->create_contact_ok(
    body_id => $body_ids{2226}, # Gloucestershire
    category => 'Street lighting',
    email => 'streetlights-2226@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2217}, # Buckinghamshire
    category => 'Street lighting',
    email => 'streetlights-2217@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2232}, # Lincolnshire
    category => 'Trees',
    email => 'trees-2232@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2237}, # Oxfordshire
    category => 'Trees',
    email => 'trees-2247@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2600}, # Rutland
    category => 'Trees',
    email => 'trees-2600@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2234}, # Northamptonshire
    category => 'Trees',
    email => 'trees-2234@example.com',
);
$mech->create_contact_ok(
    body_id => $body_ids{2566}, # Peterborough
    category => 'Trees',
    email => 'trees-2566@example.com',
);

# test that the various bit of form get filled in and errors correctly
# generated.
foreach my $test (
    {
        msg    => 'all fields empty',
        pc     => 'OX1 3DH',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => '',
            may_show_name => '1',
            username      => '',
            phone         => '',
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            # No category error, as no categories for Oxon at all, so is skipped
            'Please enter your email',
            'Please enter your name',
        ],
    },
    {
        msg    => 'all fields empty, bad category',
        pc     => 'GL50 2PR',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => '',
            may_show_name => '1',
            username      => '',
            phone         => '',
            category      => 'Something bad',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            category => '-- Pick a category --',
        },
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please choose a category',
            'Please enter your email',
            'Please enter your name',
        ],
    },
    {
        msg    => 'all fields empty except category',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => '',
            may_show_name => '1',
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
            'Please enter your name',
        ],
    },
    {
        msg    => 'may_show_name is remembered',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => '',
            may_show_name => undef,
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
            'Please enter your name',
        ],
    },
    {
        msg    => 'may_show_name unchanged if name is present (stays false)',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Bob Jones',
            may_show_name => undef,
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
        ],
    },
    {
        msg    => 'may_show_name unchanged if name is present (stays true)',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Bob Jones',
            may_show_name => '1',
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'Please enter your email',
        ],
    },
    {
        msg    => 'title and details tidied up',
        pc     => 'SW1A 1AA',
        fields => {
            title         => "DOG SHIT\r\nON WALLS",
            detail        => "on this portakabin -\r\n\r\nmore of a portaloo HEH!!",
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Bob Jones',
            may_show_name => '1',
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            title => 'Dog poo on walls',
            detail =>
              "On this [portable cabin] -\n\nMore of a [portable loo] HEH!!",
        },
        errors => [ 'Please enter your email', ],
    },
    {
        msg    => 'name too short',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'DUDE',
            may_show_name => '1',
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        errors  => [
            'Please enter your email',
'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below',
        ],
    },
    {
        msg    => 'name is anonymous',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'anonymous',
            may_show_name => '1',
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {},
        errors  => [
            'Please enter your email',
'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below',
        ],
    },
    {
        msg    => 'email invalid',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Test title',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Joe Smith',
            may_show_name => '1',
            username      => 'not an email',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => { username => 'notanemail' },
        errors  => [ 'Please enter a valid email', ],
    },
    {
        msg    => 'cleanup title and detail',
        pc     => 'SW1A 1AA',
        fields => {
            title         => "   Test   title   ",
            detail        => "   first line   \n\n second\nline\n\n   ",
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => '',
            may_show_name => '1',
            username      => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            title  => 'Test title',
            detail => "First line\n\nSecond line",
        },
        errors => [
            'Please enter your email',
            'Please enter your name',
        ],
    },
    {
        msg    => 'clean up name and email',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => '  Bob    Jones   ',
            may_show_name => '1',
            username      => '   BOB @ExAmplE.COM   ',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            name  => 'Bob Jones',
            username => 'bob@example.com',
        },
        errors => [ 'Please enter a subject', 'Please enter some details', ],
    },
    {
        msg    => 'non-photo upload gives error',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Title',
            detail        => 'Detail',
            photo1        => [ [ undef, 'bad.txt', Content => 'This is not a JPEG', Content_Type => 'text/plain' ], 1 ],
            photo2        => '',
            photo3        => '',
            name          => 'Bob Jones',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            photo1 => '',
        },
        errors => [ "Please upload an image only" ],
    },
    {
        msg    => 'bad photo upload gives error',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'Title',
            detail        => 'Detail',
            photo1        => [ [ undef, 'fake.jpeg', Content => 'This is not a JPEG', Content_Type => 'image/jpeg' ], 1 ],
            photo2        => '',
            photo3        => '',
            name          => 'Bob Jones',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            photo1 => '',
        },
        errors => [ "That image doesn't appear to have uploaded correctly (Please upload an image only ), please try again." ],
    },
    {
        msg    => 'photo with octet-stream gets through okay',
        pc     => 'SW1A 1AA',
        fields => {
            title         => '',
            detail        => 'Detail',
            photo1        => [ [ $sample_file, undef, Content_Type => 'application/octet-stream' ], 1 ],
            photo2        => '',
            photo3        => '',
            name          => 'Bob Jones',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            photo1 => '',
        },
        errors => [ "Please enter a subject" ],
    },
    {
        msg    => 'email in title',
        pc     => 'SW1A 1AA',
        fields => {
            title         => 'user@example.com',
            detail        => 'Test detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Joe Smith',
            may_show_name => '1',
            username      => 'user@example.com',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => {
            username => 'user@example.com',
            title => 'User@example.com'
        },
        errors  => [ 'Please make sure you are not including an email address', ],
    },
    {
        msg    => 'Bromley long detail',
        pc     => 'BR1 3UH',
        fields => {
            fms_extra_title => 'MR',
            title         => '',
            detail        => 'X' . 'x' x 1751,
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Bob Example',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '',
            category      => 'Trees',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Please enter a subject', 'Reports are limited to 1750 characters in length. Please shorten your report' ],
    },
    {
        msg    => 'Oxfordshire long detail',
        pc     => 'OX20 1SZ',
        fields => {
            title         => '',
            detail        => 'X' . 'x' x 1701,
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Bob Example',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '',
            category      => 'Trees',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Please enter a subject', 'Reports are limited to 1700 characters in length. Please shorten your report' ],
    },
    {
        msg    => 'Lincolnshire long phone',
        pc     => 'PE9 2GX',
        fields => {
            title         => '',
            detail        => 'Detail',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'Bob Example',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '123456789 12345678910',
            category      => 'Trees',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Please enter a subject', 'Phone numbers are limited to 20 characters in length.' ],
    },
    {
        msg    => 'Buckinghamshire long name',
        pc     => 'RG9 6TL',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'This is a very long name that should fail validation',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Please enter a subject', 'Please enter some details', 'Names are limited to 50 characters in length.' ],
    },
    {
        msg    => 'Rutland long name',
        pc     => 'LE15 0GJ',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'This is a very long name that should fail validation',
            may_show_name => '1',
            username      => 'bob@example.com',
            phone         => '',
            category      => 'Trees',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Please enter a subject', 'Please enter some details', 'Names are limited to 40 characters in length.' ],
    },
    {
        msg    => 'Oxfordshire validation',
        pc     => 'OX20 1SZ',
        fields => {
            title         => '',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'This is a really extraordinarily long name that definitely should fail validation',
            may_show_name => '1',
            username      => 'bob.has.a.very.long.email@thisisalonghostname.example.com',
            phone         => '01234 5678910 09876 54321 ext 203',
            category      => 'Trees',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Please enter a subject', 'Please enter some details', 'Emails are limited to 50 characters in length.', 'Phone numbers are limited to 20 characters in length.', 'Names are limited to 50 characters in length.'],
    },
    {
        msg    => 'Northamptonshire validation',
        pc     => 'NN1 1NS',
        fields => {
            title         => 'This is a very long title that should fail the validation as it is really much too long to pass the validation of 120 characters',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'A User',
            may_show_name => '1',
            username      => 'user@example.org',
            phone         => '',
            category      => 'Trees',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Summaries are limited to 120 characters in length. Please shorten your summary', 'Please enter some details'],
    },
    {
        msg    => 'Peterborough validation',
        pc     => 'PE1 1HF',
        fields => {
            title         => 'This is a very long title that should fail the validation',
            detail        => '',
            photo1        => '',
            photo2        => '',
            photo3        => '',
            name          => 'A User',
            may_show_name => '1',
            username      => 'user@example.org',
            phone         => '',
            category      => 'Trees',
            password_sign_in => '',
            password_register => '',
        },
        changes => { },
        errors => [ 'Summaries are limited to 50 characters in length. Please shorten your summary', 'Please enter some details'],
    },
  )
{
    subtest "check form errors where $test->{msg}" => sub {
        $mech->get_ok('/around');

        # submit initial pc form
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' }, 'bromley', 'oxfordshire', 'rutland', 'lincolnshire', 'buckinghamshire', 'northamptonshire', 'peterborough' ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
                "submit location" );
            is_deeply $mech->page_errors, [], "no errors for pc '$test->{pc}'";

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            # submit the main form
            $mech->submit_form_ok( { with_fields => $test->{fields} },
                "submit form" );
        };

        # check that we got the errors expected
        is_deeply [ sort @{$mech->page_errors} ], [ sort @{$test->{errors}} ], "check errors";

        # check that fields have changed as expected
        my $new_values = {
            %{ $test->{fields} },     # values added to form
            %{ $test->{changes} },    # changes we expect
        };
        is_deeply $mech->visible_form_values, $new_values,
          "values correctly changed";
    };
}

# this test to make sure that we don't see spurious error messages about
# the name being blank when there is a sign in error
subtest "test password errors for a user who is signing in as they report" => sub {
    my $user = $mech->create_user_ok('test-2@example.com',
        name => 'Joe Bloggs',
        phone => '01234 567 890',
        password => 'secret2',
        phone_verified => 1,
    );

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/around?pc=GL50+2PR');
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_sign_in',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    username      => 'test-2@example.com',
                    password_sign_in => 'secret1',
                    category      => 'Street lighting',
                }
            },
            "submit with wrong password"
        );
    };

    # check that we got the errors expected
    is_deeply $mech->page_errors, [
        "There was a problem with your login information. If you cannot remember your password, or do not have one, please fill in the \x{2018}No\x{2019} section of the form.",
    ], "check there were errors";

    $mech->content_lacks('1234 567', 'phone number not shown');
};

subtest "check that a lat/lon off coast leads to /around" => sub {
    my $off_coast_latitude  = 50.78301;
    my $off_coast_longitude = -0.646929;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok(
            "/report/new"
              . "?latitude=$off_coast_latitude"
              . "&longitude=$off_coast_longitude"
        );
    };

    is $mech->uri->path, '/around', "redirected to '/around'";

    is_deeply
      $mech->page_errors,
      [ 'That location does not appear to be covered by a council; perhaps it is offshore or outside the country. Please try again.' ],
      "Found location error";

};

done_testing;
