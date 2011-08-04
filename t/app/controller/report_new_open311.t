use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;

my $mech = FixMyStreet::TestMech->new;

my $open311Conf = FixMyStreet::App->model('DB::Open311Conf')->find_or_create( {
        area_id => 2651,
        endpoint => 'http://example.com/open311',
        jurisdiction => 'mySociety',
        api_key => 'apikey',
} );

my %contact_params = (
    confirmed => 1,
    deleted => 0,
    editor => 'Test',
    whenedited => \'current_timestamp',
    note => 'Created for test',
);
# Let's make some contacts to send things to!
my $contact1 = FixMyStreet::App->model('DB::Contact')->find_or_create( {
    %contact_params,
    area_id => 2651, # Edinburgh
    category => 'Street lighting',
    email => '100',
    extra => [ { description => 'Lamppost number', code => 'number', required => 'True' },
               { description => 'Lamppost type', code => 'type', required => 'False', values =>
                   { value => { Yellow => { key => 'modern' }, 'Gas' => { key => 'old' } } }
               } 
             ],
} );
my $contact2 = FixMyStreet::App->model('DB::Contact')->find_or_create( {
    %contact_params,
    area_id => 2651, # Edinburgh
    category => 'Graffiti Removal',
    email => '101',
} );
ok $contact1, "created test contact 1";
ok $contact2, "created test contact 2";

# test that the various bit of form get filled in and errors correctly
# generated.
foreach my $test (
    {
        msg    => 'all fields empty',
        pc     => 'EH99 1SP',
        fields => {
            title         => '',
            detail        => '',
            photo         => '',
            name          => '',
            may_show_name => '1',
            email         => '',
            phone         => '',
            category      => 'Street lighting',
            password_sign_in => '',
            password_register => '',
            remember_me => undef,
        },
        changes => {
            number => '',
            type   => 'old',
        },
        errors  => [
            'Please enter a subject',
            'Please enter some details',
            'This information is required',
            'Please enter your email',
            'Please enter your name',
        ],
        submit_with => {
            title => 'test',
            detail => 'test detail',
            name => 'Test User',
            email => 'testopen311@example.com',
            category => 'Street lighting',
            number => 27,
        },
        extra => [
            {
                name => 'number',
                value => 27,
                description => 'Lamppost number',
            },
            {
                name => 'type',
                value => 'old',
                description => 'Lamppost type',
            }
        ]
    },
  )
{
    subtest "check form errors where $test->{msg}" => sub {
        $mech->log_out_ok;
        $mech->clear_emails_ok;

        # check that the user does not exist
        my $test_email = $test->{submit_with}->{email};
        my $user = FixMyStreet::App->model('DB::User')->find( { email => $test_email } );
        if ( $user ) {
            $user->problems->delete;
            $user->comments->delete;
            $user->delete;
        }

        $mech->get_ok('/around');

        # submit initial pc form
        $mech->submit_form_ok( { with_fields => { pc => $test->{pc} } },
            "submit location" );
        is_deeply $mech->form_errors, [], "no errors for pc '$test->{pc}'";

        # click through to the report page
        $mech->follow_link_ok( { text => 'skip this step', },
            "follow 'skip this step' link" );

        # submit the main form
        $mech->submit_form_ok( { with_fields => $test->{fields} },
            "submit form" );

        # check that we got the errors expected
        is_deeply $mech->form_errors, $test->{errors}, "check errors";

        # check that fields have changed as expected
        my $new_values = {
            %{ $test->{fields} },     # values added to form
            %{ $test->{changes} },    # changes we expect
        };
        is_deeply $mech->visible_form_values, $new_values,
          "values correctly changed";

        if ( $test->{fields}->{category} eq 'Street lighting' ) {
            my $result = scraper {
                process 'div#category_meta div select#form_type option', 'option[]' => '@value';
            }
            ->scrape( $mech->response );

            is_deeply $result->{option}, [ qw/old modern/], 'displayed streetlight type select';
        }

        $new_values = {
            %{ $test->{fields} },
            %{ $test->{submit_with} },
        };
        $mech->submit_form_ok( { with_fields => $new_values } );

        $user = FixMyStreet::App->model('DB::User')->find( { email => $test_email } );
        ok $user, 'created user';
        my $prob = $user->problems->first;
        ok $prob, 'problem created';

        is_deeply $prob->extra, $test->{extra}, 'extra open311 data added to problem';

        $user->problems->delete;
        $user->delete;
    };
}

$contact1->delete;
$contact2->delete;

done_testing();
