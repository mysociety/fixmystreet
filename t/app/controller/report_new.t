package FixMyStreet::Cobrand::HounslowNoName;
use base 'FixMyStreet::Cobrand::UK';

sub council_area_id { 2483 };

package main;

use Test::MockModule;
use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;
$mech->get_ok('/report/new');

my $sample_file = file(__FILE__)->parent->file("sample.jpg")->stringify;
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
my @bodies;
for my $body (
    { area_id => 2651, name => 'City of Edinburgh Council' },
    { area_id => 2226, name => 'Gloucestershire County Council' },
    { area_id => 2326, name => 'Cheltenham Borough Council' },
    { area_id => 2504, name => 'Westminster City Council' },
    { area_id => 2482, name => 'Bromley Council' },
    { area_id => 2227, name => 'Hampshire County Council' },
    { area_id => 2333, name => 'Hart Council' },
    { area_id => 2535, name => 'Sandwell Borough Council' },
    { area_id => 1000, name => 'Highways England' },
    { area_id => 2217, name => 'Buckinghamshire County Council' },
    { area_id => 2232, name => 'Lincolnshire County Council' },
    { area_id => 2237, name => 'Oxfordshire County Council' },
    { area_id => 2600, name => 'Rutland County Council' },
    { area_id => 2234, name => 'Northamptonshire County Council' },
    { area_id => 2483, name => 'Hounslow Borough Council' },
    { area_id => 2566, name => 'Peterborough City Council' },
) {
    my $body_obj = $mech->create_body_ok($body->{area_id}, $body->{name});
    push @bodies, $body_obj;
    $body_ids{$body->{area_id}} = $body_obj->id;
}

# Let's make some contacts to send things to!
my $contact1 = $mech->create_contact_ok(
    body_id => $body_ids{2651}, # Edinburgh
    category => 'Street lighting',
    email => 'highways@example.com',
);
my $contact2 = $mech->create_contact_ok(
    body_id => $body_ids{2226}, # Gloucestershire
    category => 'Potholes',
    email => 'potholes@example.com',
);
my $contact3 = $mech->create_contact_ok(
    body_id => $body_ids{2326}, # Cheltenham
    category => 'Trees',
    email => 'trees@example.com',
);
my $contact4 = $mech->create_contact_ok(
    body_id => $body_ids{2482}, # Bromley
    category => 'Trees',
    email => 'trees@example.com',
);
my $contact5 = $mech->create_contact_ok(
    body_id => $body_ids{2651}, # Edinburgh
    category => 'Trees',
    email => 'trees@example.com',
);
my $contact6 = $mech->create_contact_ok(
    body_id => $body_ids{2333}, # Hart
    category => 'Trees',
    email => 'trees@example.com',
);
my $contact7 = $mech->create_contact_ok(
    body_id => $body_ids{2227}, # Hampshire
    category => 'Street  lighting',
    email => 'highways@example.com',
);
my $contact8 = $mech->create_contact_ok(
    body_id => $body_ids{2504},
    category => 'Street lighting',
    email => 'highways@example.com'
);
my $contact9 = $mech->create_contact_ok(
    body_id => $body_ids{2226}, # Gloucestershire
    category => 'Street lighting',
    email => 'streetlights-2226@example.com',
);
my $contact10 = $mech->create_contact_ok(
    body_id => $body_ids{2326}, # Cheltenham
    category => 'Street lighting',
    email => 'streetlights-2326@example.com',
);
my $contact11 = $mech->create_contact_ok(
    body_id => $body_ids{1000}, # Highways
    category => 'Pothole',
    email => 'pothole-1000@example.com',
);
my $contact12 = $mech->create_contact_ok(
    body_id => $body_ids{2217}, # Buckinghamshire
    category => 'Street lighting',
    email => 'streetlights-2217@example.com',
);
my $contact13 = $mech->create_contact_ok(
    body_id => $body_ids{2232}, # Lincolnshire
    category => 'Trees',
    email => 'trees-2232@example.com',
);
my $contact14 = $mech->create_contact_ok(
    body_id => $body_ids{2237}, # Oxfordshire
    category => 'Trees',
    email => 'trees-2247@example.com',
);
my $contact15 = $mech->create_contact_ok(
    body_id => $body_ids{2600}, # Rutland
    category => 'Trees',
    email => 'trees-2600@example.com',
);
my $contact16 = $mech->create_contact_ok(
    body_id => $body_ids{2234}, # Northamptonshire
    category => 'Trees',
    email => 'trees-2234@example.com',
);
my $contact17 = $mech->create_contact_ok(
    body_id => $body_ids{2483}, # Hounslow
    category => 'Trees',
    email => 'trees-2483@example.com',
);
my $contact18 = $mech->create_contact_ok(
    body_id => $body_ids{2483}, # Hounslow
    category => 'General Enquiry',
    email => 'general-enquiry-2483@example.com',
    non_public => 1,
);
my $contact19 = $mech->create_contact_ok(
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

my $first_user;
foreach my $test (
    {
        desc => 'does not have an account, does not set a password',
        user => 0, password => 0,
    },
    {
        desc => 'does not have an account, sets a password',
        user => 0, password => 1,
    },
    {
        desc => 'does have an account and is not signed in; does not sign in, does not set a password',
        user => 1, password => 0,
    },
    {
        desc => 'does have an account and is not signed in; does not sign in, sets a password',
        user => 1, password => 1,
    },
) {
  subtest "test report creation for a user who " . $test->{desc} => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-1@example.com';
    if ($test->{user}) {
        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        ok $user, "test user does exist";
        $user->problems->delete;
        $user->name( 'Old Name' );
        $user->password( 'old_password' );
        $user->update;
    } elsif (!$first_user) {
        ok !FixMyStreet::DB->resultset('User')->find( { email => $test_email } ),
          "test user does not exist";
        $first_user = 1;
    } else {
        # Not first pass, so will exist, but want no user to start, so delete it.
        $mech->delete_user($test_email);
    }

    # submit initial pc form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    may_show_name => '1',
                    username      => 'test-1@example.com',
                    phone         => '07903 123 456',
                    category      => 'Street lighting',
                    password_register => $test->{password} ? 'secret' : '',
                }
            },
            "submit good details"
        );
    };

    # check that we got the errors expected
    is_deeply $mech->page_errors, [], "check there were no errors";

    # check that the user has been created/ not changed
    my $user =
      FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
    ok $user, "user found";
    if ($test->{user}) {
        is $user->name, 'Old Name', 'name unchanged';
        ok $user->check_password('old_password'), 'password unchanged';
    } else {
        is $user->name, undef, 'name not yet set';
        is $user->password, '', 'password not yet set for new user';
    }

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    # check that the report is not available yet.
    is $report->state, 'unconfirmed', "report not confirmed";
    is $mech->get( '/report/' . $report->id )->code, 404, "report not found";

    # Check the report has been assigned appropriately
    is $report->bodies_str, $body_ids{2651};

    # receive token
    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/confirm that you want to send your\s+report/i, "confirm the problem";

    my $url = $mech->get_link_from_email($email);

    # confirm token
    $mech->get_ok($url);
    $report->discard_changes;
    is $report->state, 'confirmed', "Report is now confirmed";

    $mech->get_ok( '/report/' . $report->id );

    is $report->name, 'Joe Bloggs', 'name updated correctly';
    if ($test->{password}) {
        ok $report->user->check_password('secret'), 'password updated correctly';
    } elsif ($test->{user}) {
        ok $report->user->check_password('old_password'), 'password unchanged, as no new one given';
    } else {
        is $report->user->password, '', 'password still not set, as none given';
    }

    # check that the reporter has an alert
    my $alert = FixMyStreet::DB->resultset('Alert')->find( {
        user       => $report->user,
        alert_type => 'new_updates',
        parameter  => $report->id,
    } );
    ok $alert, "created new alert";

    # user is created and logged in
    $mech->logged_in_ok;

    # cleanup
    $mech->delete_user($user)
        if $test->{user} && $test->{password};
  };
}

# this test to make sure that we don't see spurious error messages about
# the name being blank when there is a sign in error
subtest "test password errors for a user who is signing in as they report" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-2@example.com';

    my $user = $mech->create_user_ok($test_email);

    # setup the user.
    ok $user->update( {
        name     => 'Joe Bloggs',
        phone    => '01234 567 890',
        password => 'secret2',
        phone_verified => 1,
    } ), "set user details";

    # submit initial pc form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
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

foreach my $test (
  { two_factor => '', desc => '', },
  { two_factor => 'yes', desc => ' with two-factor', },
  { two_factor => 'new', desc => ' with mandated two-factor, not yet set up', },
) {
  subtest "test report creation for a user who is signing in as they report$test->{desc}" => sub {
    $mech->log_out_ok;
    $mech->cookie_jar({});
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-2@example.com';

    my $user = $mech->create_user_ok($test_email);

    # setup the user.
    ok $user->update( {
        name     => 'Joe Bloggs',
        phone    => '01234 567 890',
        password => 'secret2',
        $test->{two_factor} ? (is_superuser => 1) : (),
    } ), "set user details";

    my $auth;
    my $mock;
    if ($test->{two_factor} eq 'yes') {
        use Auth::GoogleAuth;
        $auth = Auth::GoogleAuth->new;
        $user->set_extra_metadata('2fa_secret', $auth->generate_secret32);
        $user->update;
    } elsif ($test->{two_factor} eq 'new') {
        $mock = Test::MockModule->new('FixMyStreet::Cobrand::FixMyStreet');
        $mock->mock(must_have_2fa => sub { 1 });
    }

    # submit initial pc form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_sign_in',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    username      => $user->email,
                    password_sign_in => 'secret2',
                    category      => 'Street lighting',
                }
            },
            "submit good details"
        );

        if ($test->{two_factor} eq 'yes') {
            my $code = $auth->code;
            my $wrong_code = $auth->code(undef, time() - 120);
            $mech->content_contains('Please generate a two-factor code');
            $mech->submit_form_ok({ with_fields => { '2fa_code' => $wrong_code } }, "provide wrong 2FA code" );
            $mech->content_contains('Try again');
            $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
        } elsif ($test->{two_factor} eq 'new') {
            $mech->content_contains('requires two-factor');
            $mech->submit_form_ok({ with_fields => { '2fa_action' => 'activate' } }, "submit 2FA activation");
            my ($token) = $mech->content =~ /name="secret32" value="([^"]*)">/;

            use Auth::GoogleAuth;
            my $auth = Auth::GoogleAuth->new({ secret32 => $token });
            my $code = $auth->code;
            $mech->submit_form_ok({ with_fields => { '2fa_code' => $code } }, "provide correct 2FA code" );
        }

        # check that we got the message expected
        $mech->content_contains( 'You have successfully signed in; please check and confirm your details are accurate:' );

        # Now submit with a name
        $mech->submit_form_ok(
            {
                with_fields => {
                    name => 'Joe Bloggs',
                }
            },
            "submit good details"
        );
    };

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    if ($test->{two_factor} eq '') {
        # The superuser account will be immediately redirected
        $mech->content_contains('Thank you for reporting this issue');
    }

    # Check the report has been assigned appropriately
    is $report->bodies_str, $body_ids{2651};

    # check that no emails have been sent
    $mech->email_count_is(0);

    # check report is confirmed and available
    is $report->state, 'confirmed', "report is now confirmed";
    $mech->get_ok( '/report/' . $report->id );

    # check that the reporter has an alert
    my $alert = FixMyStreet::DB->resultset('Alert')->find( {
        user       => $report->user,
        alert_type => 'new_updates',
        parameter  => $report->id,
    } );
    ok $alert, "created new alert";

    # user is created and logged in
    $mech->logged_in_ok;

    # cleanup
    $mech->delete_user($user)
  };
}

#### test report creation for user with account and logged in
my ($saved_lat, $saved_lon);
foreach my $test (
    { category => 'Trees', council => 2326 },
    { category => 'Potholes', council => 2226 },
) {
    subtest "test report creation for a user who is logged in" => sub {

        # check that the user does not exist
        my $test_email = 'test-2@example.com';

        $mech->clear_emails_ok;
        my $user = $mech->log_in_ok($test_email);

        # setup the user.
        ok $user->update(
            {
                name  => 'Test User',
                phone => '01234 567 890',
            }
          ),
          "set users details";

        # submit initial pc form
        $mech->get_ok('/around');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR', } },
                "submit location" );

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            # check that the fields are correctly prefilled
            is_deeply(
                $mech->visible_form_values,
                {
                    title         => '',
                    detail        => '',
                    may_show_name => '1',
                    name          => 'Test User',
                    phone         => '01234 567 890',
                    photo1        => '',
                    photo2        => '',
                    photo3        => '',
                    category      => '-- Pick a category --',
                },
                "user's details prefilled"
            );

            $mech->submit_form_ok(
                {
                    with_fields => {
                        title         => "Test Report at café",
                        detail        => 'Test report details.',
                        photo1        => '',
                        name          => 'Joe Bloggs',
                        may_show_name => '1',
                        phone         => '07903 123 456',
                        category      => $test->{category},
                    }
                },
                "submit good details"
            );
        };

        # find the report
        my $report = $user->problems->first;
        ok $report, "Found the report";

        # Check the report has been assigned appropriately
        is $report->bodies_str, $body_ids{$test->{council}};

        $mech->content_contains('Thank you for reporting this issue');

        # check that no emails have been sent
        $mech->email_count_is(0);

        # check report is confirmed and available
        is $report->state, 'confirmed', "report is now confirmed";
        $mech->get_ok( '/report/' . $report->id );

        # check that the reporter has an alert
        my $alert = FixMyStreet::DB->resultset('Alert')->find( {
            user       => $report->user,
            alert_type => 'new_updates',
            parameter  => $report->id,
        } );
        ok $alert, "created new alert";

        # user is still logged in
        $mech->logged_in_ok;

        # Test that AJAX pages return the right data
        $mech->get_ok(
            '/around?ajax=1&bbox=' . ($report->longitude - 0.01) . ',' .  ($report->latitude - 0.01)
            . ',' . ($report->longitude + 0.01) . ',' .  ($report->latitude + 0.01)
        );
        $mech->content_contains( "Test Report at caf\xc3\xa9" );
        $saved_lat = $report->latitude;
        $saved_lon = $report->longitude;

        # cleanup
        $mech->delete_user($user);
    };

}

# XXX add test for category with multiple bodies
foreach my $test (
    {
        desc => "test report creation for multiple bodies",
        category => 'Street lighting',
        councils => [ 2226, 2326 ],
        extra_fields => {},
        email_count => 2,
    },
    {
        desc => "test single_body_only means only one report body",
        category => 'Street lighting',
        councils => [ 2326 ],
        extra_fields => { single_body_only => 'Cheltenham Borough Council' },
        email_count => 1,
    },
    {
        desc => "test invalid single_body_only means no report bodies",
        category => 'Street lighting',
        councils => [],
        extra_fields => { single_body_only => 'Invalid council' },
        email_count => 1,
    },
    {
        desc => "test do_not_send means body is ignored",
        category => 'Street lighting',
        councils => [ 2326 ],
        extra_fields => { do_not_send => 'Gloucestershire County Council' },
        email_count => 1,
    },
    {
        desc => "test single_body_only with Highways England",
        category => 'Street lighting',
        councils => [ 1000 ],
        extra_fields => { single_body_only => 'Highways England' },
        email_count => 1,
    },
) {
    subtest $test->{desc} => sub {

        # check that the user does not exist
        my $test_email = 'test-2@example.com';

        $mech->clear_emails_ok;
        my $user = $mech->log_in_ok($test_email);

        # setup the user.
        ok $user->update(
            {
                name  => 'Test User',
                phone => '01234 567 890',
            }
          ),
          "set users details";

        # submit initial pc form
        $mech->get_ok('/around');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR', } },
                "submit location" );

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            # check that the fields are correctly prefilled
            is_deeply(
                $mech->visible_form_values,
                {
                    title         => '',
                    detail        => '',
                    may_show_name => '1',
                    name          => 'Test User',
                    phone         => '01234 567 890',
                    photo1        => '',
                    photo2        => '',
                    photo3        => '',
                    category      => '-- Pick a category --',
                },
                "user's details prefilled"
            );

            $mech->submit_form_ok(
                {
                    with_fields => {
                        title         => "Test Report at café",
                        detail        => 'Test report details.',
                        photo1        => '',
                        name          => 'Joe Bloggs',
                        may_show_name => '1',
                        phone         => '07903 123 456',
                        category      => $test->{category},
                        %{$test->{extra_fields}}
                    }
                },
                "submit good details"
            );
        };

        # find the report
        my $report = $user->problems->first;
        ok $report, "Found the report";

        # Check the report has been assigned appropriately
        is $report->bodies_str, join(',', @body_ids{@{$test->{councils}}}) || undef;

        $mech->content_contains('Thank you for reporting this issue');

        # check that no emails have been sent
        $mech->email_count_is(0);

        # check report is confirmed and available
        is $report->state, 'confirmed', "report is now confirmed";
        $mech->get_ok( '/report/' . $report->id );

        # Test that AJAX pages return the right data
        $mech->get_ok(
            '/around?ajax=1&bbox=' . ($report->longitude - 0.01) . ',' .  ($report->latitude - 0.01)
            . ',' . ($report->longitude + 0.01) . ',' .  ($report->latitude + 0.01)
        );
        $mech->content_contains( "Test Report at caf\xc3\xa9" );
        $saved_lat = $report->latitude;
        $saved_lon = $report->longitude;

        # cleanup
        $mech->delete_user($user);
    };

}

subtest "Test inactive categories" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        BASE_URL => 'https://www.fixmystreet.com',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        # Around and New report have both categories
        $mech->get_ok('/around?pc=GL50+2PR');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $contact2->update( { state => 'inactive' } ); # Potholes
        # But when Potholes is inactive, it's not on New report
        $mech->get_ok('/around?pc=GL50+2PR');
        $mech->content_contains('Potholes');
        $mech->content_contains('Trees');
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");
        $mech->content_lacks('Potholes');
        $mech->content_contains('Trees');
        # Change back
        $contact2->update( { state => 'confirmed' } );
    };
};

subtest "category groups" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            category_groups => { fixmystreet => 1 }
        }
    }, sub {
        $contact2->update( { extra => { group => ['Roads','Pavements'] } } );
        $contact9->update( { extra => { group => 'Roads' } } );
        $contact10->update( { extra => { group => 'Roads' } } );
        $mech->get_ok("/report/new?lat=$saved_lat&lon=$saved_lon");
        $mech->content_like(qr{<optgroup label="Pavements">\s*<option value='Potholes'>Potholes</option></optgroup>});
        $mech->content_like(qr{<optgroup label="Roads">\s*<option value='Potholes'>Potholes</option>\s*<option value='Street lighting'>Street lighting</option></optgroup>});
    };
};

subtest "test report creation for a category that is non public" => sub {
    $mech->log_out_ok;
    $mech->clear_emails_ok;

    # check that the user does not exist
    my $test_email = 'test-2@example.com';

    my $user = $mech->create_user_ok($test_email);

    $contact1->update( { non_public => 1 } );

    # submit initial pc form
    $mech->get_ok('/around');
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                button      => 'submit_register',
                with_fields => {
                    title         => 'Test Report',
                    detail        => 'Test report details.',
                    photo1        => '',
                    username      => $user->email,
                    name          => 'Joe Bloggs',
                    category      => 'Street lighting',
                }
            },
            "submit good details"
        );
    };

    # find the report
    my $report = $user->problems->first;
    ok $report, "Found the report";

    # Check the report is not public
    ok $report->non_public, 'report is not public';

    my $email = $mech->get_email;
    ok $email, "got an email";
    like $mech->get_text_body_from_email($email), qr/confirm that you want to send your\s+report/i, "confirm the problem";

    my $url = $mech->get_link_from_email($email);

    # confirm token
    $mech->get_ok($url);
    $report->discard_changes;

    is $report->state, 'confirmed', "Report is now confirmed";

    $mech->logged_in_ok;
    $mech->get_ok( '/report/' . $report->id, 'user can see own report' );

    $mech->log_out_ok;
    ok $mech->get("/report/" . $report->id), "fetched report";
    is $mech->res->code, 403, "access denied to report";

    # cleanup
    $mech->delete_user($user);
    $contact1->update( { non_public => 0 } );
};

$contact2->category( "Pothol\x{00E9}s" );
$contact2->update;

subtest "check map click ajax response" => sub {
    my $extra_details;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=' . $saved_lat . '&longitude=' . $saved_lon );
    };
    # this order seems to be random so check individually/sort
    like $extra_details->{councils_text}, qr/Cheltenham Borough Council/, 'correct council text for two tier';
    like $extra_details->{councils_text}, qr/Gloucestershire County Council/, 'correct council text for two tier';
    like $extra_details->{category}, qr/Pothol\x{00E9}s.*Street lighting/, 'category looks correct for two tier council';
    my @sorted_bodies = sort @{ $extra_details->{bodies} };
    is_deeply \@sorted_bodies, [ "Cheltenham Borough Council", "Gloucestershire County Council" ], 'correct bodies for two tier';
    ok !$extra_details->{titles_list}, 'Non Bromley does not send back list of titles';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.4021&longitude=0.01578');
    };
    ok $extra_details->{titles_list}, 'Bromley sends back list of titles';
    like $extra_details->{councils_text}, qr/Bromley Council/, 'correct council text';
    like $extra_details->{councils_text_private}, qr/^These details will be sent to the council, but will never be shown online/, 'correct private council text';
    like $extra_details->{category}, qr/Trees/, 'category looks correct';
    is_deeply $extra_details->{bodies}, [ "Bromley Council" ], 'correct bodies';
    ok !$extra_details->{contribute_as}, 'no contribute as section';
    ok !$extra_details->{top_message}, 'no top message';
    ok $extra_details->{extra_name_info}, 'extra name info';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=52.563074&longitude=-1.991032' );
    };
    like $extra_details->{councils_text}, qr/^These will be published online for others to see/, 'correct council text for council with no contacts';
    is $extra_details->{category}, '', 'category is empty for council with no contacts';
    is_deeply $extra_details->{bodies}, [ "Sandwell Borough Council" ], 'correct bodies for council with no contacts';
    ok !$extra_details->{extra_name_info}, 'no extra name info';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.482286&longitude=-0.328163' );
    };
    is_deeply $extra_details->{display_names}, { 'Hounslow Borough Council' => 'Hounslow Highways' }, 'council display name mapping correct';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslownoname',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.482286&longitude=-0.328163' );
    };
    isnt defined $extra_details->{display_names}, 'no council display names if none defined';

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $extra_details = $mech->get_ok_json( '/report/new/ajax?latitude=51.482286&longitude=-0.328163' );
    };
    ok $extra_details->{by_category}->{'General Enquiry'}->{non_public}, 'non_public set correctly for private category';
    isnt defined $extra_details->{by_category}->{Tree}->{non_public}, 'non_public omitted for public category';
};

#### test uploading an image

#### test completing a partial report (eq flickr upload)

#### possibly manual testing
# create report without using map
# create report by clicking on map with javascript off
# create report with images off

subtest "check that a lat/lon off coast leads to /around" => sub {
    my $off_coast_latitude  = 50.78301;
    my $off_coast_longitude = -0.646929;

    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok(    #
            "/report/new"
              . "?latitude=$off_coast_latitude"
              . "&longitude=$off_coast_longitude"
        );
    };

    is $mech->uri->path, '/around', "redirected to '/around'";

    is_deeply         #
      $mech->page_errors,
      [ 'That location does not appear to be covered by a council; perhaps it is offshore or outside the country. Please try again.' ],
      "Found location error";

};

subtest "check we load a partial report correctly" => sub {
    my $user = FixMyStreet::DB->resultset('User')->find_or_create(
        {
            email => 'test-partial@example.com'
        }
    );

    my $report = FixMyStreet::DB->resultset('Problem')->create( {
        name               => '',
        postcode           => '',
        category           => 'Street lighting',
        title              => 'Testing',
        detail             => "Testing Detail",
        anonymous          => 0,
        state              => 'partial',
        lang               => 'en-gb',
        service            => '',
        areas              => '',
        used_map           => 1,
        latitude           => '51.754926',
        longitude          => '-1.256179',
        user_id            => $user->id,
    } );

    my $report_id = $report->id;

    my $token = FixMyStreet::DB->resultset("Token")
        ->create( { scope => 'partial', data => $report->id } );

    my $token_code = $token->token;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    },
    sub {
        $mech->get("/L/$token_code");
        is $mech->res->previous->code, 302, 'partial token page redirects';
        is $mech->uri->path, "/report/new", "partial redirects to report page";
        $mech->content_contains('Testing Detail');
    };

    $mech->delete_user($user);
};

for my $test (
    {
        desc  => 'user title not set if not bromley problem',
        host  => 'www.fixmystreet.com',
        postcode => 'EH1 1BB',
        fms_extra_title => '',
        extra => [],
        user_title => undef,
    },
    {
        desc  => 'title shown for bromley problem on main site',
        host  => 'www.fixmystreet.com',
        postcode => 'BR1 3UH',
        fms_extra_title => 'MR',
        extra => [
            {
                name        => 'fms_extra_title',
                value       => 'MR',
                description => 'FMS_EXTRA_TITLE',
            },
        ],
        user_title => 'MR',
    },
    {
        desc =>
          'title, first and last name shown for bromley problem on cobrand',
        host       => 'bromley.fixmystreet.com',
        postcode => 'BR1 3UH',
        first_name => 'Test',
        last_name  => 'User',
        fms_extra_title => 'MR',
        extra      => [
            {
                name        => 'fms_extra_title',
                value       => 'MR',
                description => 'FMS_EXTRA_TITLE',
            },
            {
                name        => 'first_name',
                value       => 'Test',
                description => 'FIRST_NAME',
            },
            {
                name        => 'last_name',
                value       => 'User',
                description => 'LAST_NAME',
            },
        ],
        user_title => 'MR',
    },
  )
{
    subtest $test->{desc} => sub {
        my $override = {
            ALLOWED_COBRANDS => [ $test->{host} =~ /bromley/ ? 'bromley' : 'fixmystreet' ],
            MAPIT_URL => 'http://mapit.uk/',
        };

        $mech->host( $test->{host} );

        $mech->log_out_ok;
        $mech->clear_emails_ok;

        $mech->get_ok('/');
        FixMyStreet::override_config $override, sub {
            $mech->submit_form_ok( { with_fields => { pc => $test->{postcode}, } },
                "submit location" );
            $mech->follow_link_ok(
                { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link"
            );
        };

        my $fields = $mech->visible_form_values('mapSkippedForm');
        if ( $test->{fms_extra_title} ) {
            ok exists( $fields->{fms_extra_title} ), 'user title field displayed';
        } else {
            ok !exists( $fields->{fms_extra_title} ), 'user title field not displayed';
        }
        if ( $test->{first_name} ) {
            ok exists( $fields->{first_name} ), 'first name field displayed';
            ok exists( $fields->{last_name} ),  'last name field displayed';
            ok !exists( $fields->{name} ), 'no name field displayed';
        }
        else {
            ok !exists( $fields->{first_name} ),
              'first name field not displayed';
            ok !exists( $fields->{last_name} ), 'last name field not displayed';
            ok exists( $fields->{name} ), 'name field displayed';
        }

        my $submission_fields = {
            title             => "Test Report",
            detail            => 'Test report details.',
            photo1            => '',
            username          => 'firstlast@example.com',
            may_show_name     => '1',
            phone             => '07903 123 456',
            category          => 'Trees',
            password_register => '',
        };

        $submission_fields->{fms_extra_title} = $test->{fms_extra_title}
            if $test->{fms_extra_title};

        if ( $test->{first_name} ) {
            $submission_fields->{first_name} = $test->{first_name};
            $submission_fields->{last_name}  = $test->{last_name};
        }
        else {
            $submission_fields->{name} = 'Test User';
        }

        FixMyStreet::override_config $override, sub {
            $mech->submit_form_ok( { with_fields => $submission_fields },
                "submit good details" );
        };

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $mech->get_text_body_from_email($email), qr/confirm that you want to send your\s+report/i, "confirm the problem";

        my $url = $mech->get_link_from_email($email);

        # confirm token in order to update the user details
        $mech->get_ok($url);

        my $user = FixMyStreet::DB->resultset('User')->find( { email => 'firstlast@example.com' } );

        my $report = $user->problems->first;
        ok $report, "Found the report";
        my $extras = $report->get_extra_fields;
        is $user->title, $test->{'user_title'}, 'user title correct';
        is_deeply $extras, $test->{extra}, 'extra contains correct values';

        $mech->delete_user($user);
    };
}

subtest 'user title not reset if no user title in submission' => sub {
        $mech->log_out_ok;
        $mech->host( 'www.fixmystreet.com' );

        my $user = $mech->log_in_ok( 'userwithtitle@example.com' );

        ok $user->update(
            {
                name => 'Has Title',
                phone => '0789 654321',
                title => 'MR',
            }
        ),
        "set users details";


        my $submission_fields = {
            title             => "Test Report",
            detail            => 'Test report details.',
            photo1            => '',
            name              => 'Has Title',
            may_show_name     => '1',
            phone             => '07903 123 456',
            category          => 'Trees',
        };

        $mech->get_ok('/');
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } },
                "submit location" );
            $mech->follow_link_ok(
                { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link"
            );

            my $fields = $mech->visible_form_values('mapSkippedForm');
            ok !exists( $fields->{fms_extra_title} ), 'user title field not displayed';

            $mech->submit_form_ok( { with_fields => $submission_fields },
                "submit good details" );
        };

        $user->discard_changes;
        my $report = $user->problems->first;
        ok $report, "Found report";
        is $report->title, "Test Report", "Report title correct";
        is $user->title, 'MR', 'User title unchanged';
};

subtest "test Hart" => sub {
    for my $test (
        {
            desc      => 'confirm link for cobrand council in two tier cobrand links to cobrand site',
            category  => 'Trees',
            council   => 2333,
            national  => 0,
            button    => 'submit_register',
        },
          {
            desc      => 'confirm link for non cobrand council in two tier cobrand links to national site',
            category  => 'Street Lighting',
            council   => 2227,
            national  => 1,
            button    => 'submit_register',
          },
          {
            desc      => 'confirmation page for cobrand council in two tier cobrand links to cobrand site',
            category  => 'Trees',
            council   => 2333,
            national  => 0,
            confirm  => 1,
          },
          {
            desc      => 'confirmation page for non cobrand council in two tier cobrand links to national site',
            category  => 'Street Lighting',
            council   => 2227,
            national  => 1,
            confirm  => 1,
          },
    ) {
        subtest $test->{ desc } => sub {
            my $test_email = 'test-22@example.com';
            $mech->host( 'hart.fixmystreet.com' );
            $mech->clear_emails_ok;
            $mech->log_out_ok;

            my $user = $mech->log_in_ok($test_email) if $test->{confirm};

            FixMyStreet::override_config {
                ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                BASE_URL => 'http://www.fixmystreet.com',
                MAPIT_URL => 'http://mapit.uk/',
            }, sub {
                $mech->get_ok('/around');
                $mech->content_contains( "Hart Council" );
                $mech->submit_form_ok( { with_fields => { pc => 'GU51 4AE' } }, "submit location" );
                $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
                my %optional_fields = $test->{confirm} ?  () :
                    ( username => $test_email, phone => '07903 123 456' );

                # we do this as otherwise test::www::mechanize::catalyst
                # goes to the value set in ->host above irregardless and
                # that is a 404. It works but it is not pleasant.
                $mech->clear_host if $test->{confirm} && $test->{national};
                $mech->submit_form_ok(
                    {
                        button      => $test->{button},
                        with_fields => {
                            title         => 'Test Report',
                            detail        => 'Test report details.',
                            photo1        => '',
                            name          => 'Joe Bloggs',
                            may_show_name => '1',
                            category      => $test->{category},
                            %optional_fields
                        }
                    },
                    "submit good details"
                );
            };
            is_deeply $mech->page_errors, [], "check there were no errors";

            # check that the user has been created/ not changed
            $user =
              FixMyStreet::DB->resultset('User')->find( { email => $user ? $user->email : $test_email } );
            ok $user, "user found";

            # find the report
            my $report = $user->problems->first;
            ok $report, "Found the report";

            # Check the report has been assigned appropriately
            is $report->bodies_str, $body_ids{$test->{council}};

            if ( $test->{confirm} ) {
                is $mech->uri->path, "/report/new";
                my $base = 'www.fixmystreet.com';
                $base = '"' unless $test->{national};
                $mech->content_contains("$base/report/" . $report->id, "links to correct site");
            } else {
                # receive token
                my $email = $mech->get_email;
                ok $email, "got an email";
                my $body = $mech->get_text_body_from_email($email);
                like $body, qr/to confirm that you want to send your/i, "confirm the problem";

                # does it reference the fact that this report hasn't been sent to Hart?
                if ( $test->{national} ) {
                    like $body, qr/Hart Council is not responsible for this type/i, "mentions report hasn't gone to Hart";
                } else {
                    unlike $body, qr/Hart Council is not responsible for this type/i, "doesn't mention report hasn't gone to Hart";
                }

                my $url = $mech->get_link_from_email($email);

                # confirm token
                FixMyStreet::override_config {
                    ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                    BASE_URL => 'http://www.fixmystreet.com',
                }, sub {
                    $mech->get_ok($url);
                };

                my $base = 'www.fixmystreet.com';
                $base = '"' unless $test->{national};
                $mech->content_contains( $base . '/report/' .
                    $report->id, 'confirm page links to correct site' );

                if ( $test->{national} ) {
                    # Shouldn't be found, as it was a county problem
                    FixMyStreet::override_config {
                        ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                    }, sub {
                        is $mech->get( '/report/' . $report->id )->code, 404, "report not found";
                    };

                    # But should be on the main site
                    $mech->host( 'www.fixmystreet.com' );
                }
                FixMyStreet::override_config {
                    ALLOWED_COBRANDS => [ 'hart', 'fixmystreet' ],
                }, sub {
                    $mech->get_ok( '/report/' . $report->id );
                };
            }

            $report->discard_changes;
            is $report->state, 'confirmed', "Report is now confirmed";

            is $report->name, 'Joe Bloggs', 'name updated correctly';

            $mech->delete_user($user);
        };
    }
};

subtest "categories from deleted bodies shouldn't be visible for new reports" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/report/new/ajax?latitude=51.896268&longitude=-2.093063'); # Cheltenham
        ok $mech->content_contains( $contact3->category );

        # Delete the body which the contact belongs to.
        $contact3->body->update( { deleted => 1 } );

        $mech->get_ok('/report/new/ajax?latitude=51.896268&longitude=-2.093063'); # Cheltenham
        ok $mech->content_lacks( $contact3->category );

        $contact3->body->update( { deleted => 0 } );
    };
};

subtest "unresponsive body handling works" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        # Test body-level send method
        my $old_send = $contact1->body->send_method;
        $contact1->body->update( { send_method => 'Refused' } );
        my $body_id = $contact1->body->id;
        my $extra_details = $mech->get_ok_json('/report/new/ajax?latitude=55.952055&longitude=-3.189579');
        like $extra_details->{top_message}, qr{Edinburgh.*accept reports.*/unresponsive\?body=$body_id};
        is_deeply $extra_details->{unresponsive}, { $body_id => 1 }, "unresponsive json set";
        $extra_details = $mech->get_ok_json('/report/new/category_extras?category=Street%20lighting&latitude=55.952055&longitude=-3.189579');
        is_deeply $extra_details->{unresponsive}, { $body_id => 1 }, "unresponsive json set";

        my $test_email = 'test-2@example.com';
        $mech->log_out_ok;
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'EH1 1BB', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                with_fields => {
                    title         => "Test Report at café",
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    username      => $test_email,
                    may_show_name => '1',
                    phone         => '07903 123 456',
                    category      => 'Trees',
                }
            },
            "submit good details"
        );

        my $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        ok $user, "test user does exist";

        my $report = $user->problems->first;
        ok $report, "Found the report";
        is $report->bodies_str, undef, "Report not going anywhere";

        like $mech->get_text_body_from_email, qr/despite not being sent/i, "correct email sent";

        $user->problems->delete;
        $mech->clear_emails_ok;

        # Make sure the same behaviour occurs for reports from the mobile app
        $mech->log_out_ok;
        $mech->post_ok( '/report/new/mobile', {
            title               => "Test Report at café",
            detail              => 'Test report details.',
            photo1              => '',
            name                => 'Joe Bloggs',
            email               => $test_email,
            may_show_name       => '1',
            phone               => '07903 123 456',
            category            => 'Trees',
            service             => 'iOS',
            lat                 => 55.952055,
            lon                 => -3.189579,
            pc                  => '',
            used_map            => '1',
            submit_register     => '1',
            password_register   => '',
        });
        my $res = $mech->response;
        ok $res->header('Content-Type') =~ m{^application/json\b}, 'response should be json';

        $user = FixMyStreet::DB->resultset('User')->find( { email => $test_email } );
        ok $user, "test user does exist";

        $report = $user->problems->first;
        ok $report, "Found the report";
        is $report->bodies_str, undef, "Report not going anywhere";

        like $mech->get_text_body_from_email, qr/despite not being sent/i, "correct email sent";

        $user->problems->delete;
        $mech->clear_emails_ok;

        $contact1->body->update( { send_method => $old_send } );

        # And test per-category refusing
        my $old_email = $contact3->email;
        $contact3->update( { email => 'REFUSED' } );
        $extra_details = $mech->get_ok_json('/report/new/ajax?latitude=51.896268&longitude=-2.093063');
        like $extra_details->{by_category}{$contact3->category}{category_extra}, qr/Cheltenham.*Trees.*unresponsive.*category=Trees/s;
        $extra_details = $mech->get_ok_json('/report/new/category_extras?category=Trees&latitude=51.896268&longitude=-2.093063');
        is_deeply $extra_details->{unresponsive}, { $contact3->body->id => 1 }, "unresponsive json set";

        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR', } }, "submit location" );
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, }, "follow 'skip this step' link" );
        $mech->submit_form_ok(
            {
                with_fields => {
                    title         => "Test Report at café",
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    username      => $test_email,
                    may_show_name => '1',
                    phone         => '07903 123 456',
                    category      => 'Trees',
                }
            },
            "submit good details"
        );

        $report = $user->problems->first;
        ok $report, "Found the report";
        is $report->bodies_str, undef, "Report not going anywhere";

        $contact3->update( { email => $old_email } );
        $mech->delete_user($user);
    };
};

subtest "unresponsive body page works" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    }, sub {
        my $old_send = $contact1->body->send_method;
        my $body_id = $contact1->body->id;
        my $url = "/unresponsive?body=$body_id";
        is $mech->get($url)->code, 404, "page not found";
        $contact1->body->update( { send_method => 'Refused' } );
        $mech->get_ok($url);
        $mech->content_contains('Edinburgh');
        $contact1->body->update( { send_method => $old_send } );

        my $old_email = $contact3->email;
        $body_id = $contact3->body->id;
        $url = "/unresponsive?body=$body_id;category=Trees";
        is $mech->get($url)->code, 404, "page not found";
        $contact3->update( { email => 'REFUSED' } );
        $mech->get_ok($url);
        $mech->content_contains('Cheltenham');
        $mech->content_contains('Trees');
        $contact3->update( { email => $old_email } );
    };
};

subtest "extra google analytics code displayed on logged in problem creation" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        BASE_URL => 'https://www.fixmystreet.com',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        # check that the user does not exist
        my $test_email = 'test-2@example.com';

        $mech->clear_emails_ok;
        my $user = $mech->log_in_ok($test_email);

        # setup the user.
        ok $user->update(
            {
                name  => 'Test User',
                phone => '01234 567 890',
            }
          ),
          "set users details";

        # submit initial pc form
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR', } },
            "submit location" );

        # click through to the report page
        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->submit_form_ok(
            {
                with_fields => {
                    title         => "Test Report at café",
                    detail        => 'Test report details.',
                    photo1        => '',
                    name          => 'Joe Bloggs',
                    may_show_name => '1',
                    phone         => '07903 123 456',
                    category      => 'Trees',
                }
            },
            "submit good details"
        );

        # find the report
        my $report = $user->problems->first;
        ok $report, "Found the report";

        $mech->content_contains( "'id': 'report/" . $report->id . "'", 'extra google code present' );

        # cleanup
        $mech->delete_user($user);
    };
};

subtest "extra google analytics code displayed on email confirmation problem creation" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
        BASE_URL => 'https://www.fixmystreet.com',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->log_out_ok;
        $mech->clear_emails_ok;

        $mech->get_ok('/');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR' } },
            "submit location" );
        $mech->follow_link_ok(
            { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link"
        );

        my $fields = $mech->visible_form_values('mapSkippedForm');
        my $submission_fields = {
            title             => "Test Report",
            detail            => 'Test report details.',
            photo1            => '',
            username          => 'firstlast@example.com',
            name              => 'Test User',
            may_show_name     => '1',
            phone             => '07903 123 456',
            category          => 'Trees',
            password_register => '',
        };

        $mech->submit_form_ok( { with_fields => $submission_fields },
            "submit good details" );

        my $email = $mech->get_email;
        ok $email, "got an email";
        like $mech->get_text_body_from_email($email), qr/confirm that you want to/i, "confirm the problem";

        my $url = $mech->get_link_from_email($email);

        # confirm token in order to update the user details
        $mech->get_ok($url);

        # find the report
        my $user = FixMyStreet::DB->resultset('User')->find( { email => 'firstlast@example.com' } );

        my $report = $user->problems->first;
        ok $report, "Found the report";

        $mech->content_contains( "'id': 'report/" . $report->id . "'", 'extra google code present' );

        $mech->delete_user($user);
    };
};

done_testing();
