use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;
use Path::Class;

my $mech = FixMyStreet::TestMech->new;
$mech->get_ok('/import');

my $sample_file = file(__FILE__)->parent->file("sample.jpg")->stringify;
ok -e $sample_file, "sample file $sample_file exists";

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

        $mech->submit_form_ok(    #
            { with_fields => $test->{fields} },
            "fill in form"
        );

        is_deeply( $mech->import_errors, $test->{errors}, "expected errors" );
    }

};

# submit an empty report to import - check we get all errors
subtest "Submit a correct entry" => sub {

    $mech->get_ok('/import');

    $mech->submit_form_ok(    #
        {
            with_fields => {
                service => 'test-script',
                name    => 'Test User',
                email   => 'test@example.com',
                subject => 'Test report',
                detail  => 'This is a test report',
                photo   => $sample_file,
            }
        },
        "fill in form"
    );

    is_deeply( $mech->import_errors, [], "got no errors" );
    is $mech->content, 'SUCCESS', "Got success response";

    # check that we have received the email
    $mech->email_count_is(1);
    my $email = $mech->get_email;
    $mech->clear_emails_ok;

    my ($token_url) = $email->body =~ m{(http://\S+)};
    ok $token_url, "Found a token url $token_url";

    # go to the token url
    $mech->get_ok($token_url);

    # check that we are not shown anything as we don't have a location yet
    is_deeply $mech->visible_form_values, { pc => '' },
      "check only pc field is shown";

    is $mech->uri->path, '/around', "sent to report page";

    $mech->submit_form_ok(    #
        { with_fields => { pc => 'SW1A 1AA' } },
        "fill in postcode"
    );

    is $mech->uri->path, '/report/new', "sent to report page";

    # check that fields are prefilled for us
    is_deeply $mech->visible_form_values,
      {
        name          => 'Test User',
        email         => 'test@example.com',
        title         => 'Test report',
        detail        => 'This is a test report',
        photo         => '',
        phone         => '',
        may_show_name => '1',
      },
      "check imported fields are shown";

  TODO: {
        local $TODO = "'/report/123' urls not served by catalyst yet";

        # change the details
        $mech->submit_form_ok(    #
            {
                with_fields => {
                    name          => 'New Test User',
                    email         => 'test@example.com',
                    title         => 'New Test report',
                    detail        => 'This is a test report',
                    phone         => '01234 567 890',
                    may_show_name => '1',
                }
            },
            "Update details and save"
        );
    }

    # check that report has been created
    my $user =
      FixMyStreet::App->model('DB::User')
      ->find( { email => 'test@example.com' } );
    ok $user, "Found a user";

    my $report = $user->problems->first;
    is $report->state, 'confirmed',       'is confirmed';
    is $report->title, 'New Test report', 'title is correct';

    $mech->delete_user($user);
};

done_testing();
