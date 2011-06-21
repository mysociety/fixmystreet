use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use FixMyStreet::App::Controller::Questionnaire;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

# create a test user and report
$mech->delete_user('test@example.com');

my $user =
  FixMyStreet::App->model('DB::User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $report_time = '2011-03-01 12:00:00';

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'EH1 1BB',
        council            => '2651',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        title              => 'Testing',
        detail             => 'Testing Detail',
        used_map           => 1,
        name               => $user->name,
        anonymous          => 0,
        state              => 'confirmed',
        confirmed          => $report_time,
        lastupdate         => $report_time,
        whensent           => '2011-03-01 12:05:00',
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 1,
        latitude           => '55.951963',
        longitude          => '-3.189944',
        user_id            => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

# Call the questionaire sending function...
FixMyStreet::App->model('DB::Questionnaire')->send_questionnaires( {
    site => 'fixmystreet'
} );
my $email = $mech->get_email;
ok $email, "got an email";
like $email->body, qr/fill in our short questionnaire/i, "got questionnaire email";
my ($token) = $email->body =~ m{http://.*?/Q/(\S+)};
ok $token, "extracted questionnaire token '$token'";
$mech->clear_emails_ok;

$report->discard_changes;
is $report->send_questionnaire, 0;

$token = FixMyStreet::App->model("DB::Token")->find( {
    scope => 'questionnaire', token => $token
} );
ok $token, 'found token for questionnaire';

my $questionnaire = FixMyStreet::App->model('DB::Questionnaire')->find( {
    id => $token->data
} );
ok $questionnaire, 'found questionnaire';

foreach my $test (
    {
        desc => 'User goes to questionnaire URL with a bad token',
        token_extra => 'BAD',
        content => "we couldn't validate that token",
    },
    {
        desc => 'User goes to questionnaire URL for a now-hidden problem',
        state => 'hidden',
        content => "we couldn't locate your problem",
    },
    {
        desc => 'User goes to questionnaire URL for an already answered questionnaire',
        answered => \'ms_current_timestamp()',
        content => 'already answered this questionnaire',
    },
) {
    subtest $test->{desc} => sub {
        $report->state( $test->{state} || 'confirmed' );
        $report->update;
        $questionnaire->whenanswered( $test->{answered} );
        $questionnaire->update;
        (my $token = $token->token);
        $token .= $test->{token_extra} if $test->{token_extra};
        $mech->get_ok("/Q/$token");
        $mech->content_contains( $test->{content} );
        # Reset, no matter what test did
        $report->state( 'confirmed' );
        $report->update;
        $questionnaire->whenanswered( undef );
        $questionnaire->update;
    };
}

$mech->get_ok("/Q/" . $token->token);
$mech->title_like( qr/Questionnaire/ );
$mech->submit_form_ok( );
my @errors = @{ $mech->page_errors };
ok scalar @errors, 'displayed error messages';
is $errors[0], "Please state whether or not the problem has been fixed", 'error message';

foreach my $test (
    {
        desc => 'Open report, has been fixed, first time reporter, no update left',
        problem_state => 'confirmed',
        fields => {
            been_fixed => 'Yes',
            reported => 'No',
        },
        comment => 'Questionnaire filled in by problem reporter',
    },
    {
        desc => 'Open report, has been fixed, reported before, leaves an update',
        problem_state => 'confirmed',
        fields => {
            been_fixed => 'Yes',
            reported => 'Yes',
            update => 'The council fixed this really quickly, thanks!',
        },
    },
    {
        desc => 'Open report, has not been fixed, not reported before, no update, asks for another questionnaire',
        problem_state => 'confirmed',
        fields => {
            been_fixed => 'No',
            reported => 'No',
            another => 'Yes',
        },
    },
    {
        desc => 'Open report, unknown fixed, reported before, update, no further questionnaire',
        problem_state => 'confirmed',
        fields => {
            been_fixed => 'Unknown',
            reported => 'Yes',
            update => 'This is still going on.',
            # another => 'No', Error for not setting this tested below
        },
    },
    {
        desc => 'Fixed report, confirmed fixed, not reported before, no update',
        problem_state => 'fixed',
        fields => {
            been_fixed => 'Yes',
            reported => 'No',
        },
        lastupdate_static => 1,
    },
    {
        desc => 'Fixed report, unknown fixed, not reported before, no update, asks for another',
        problem_state => 'fixed',
        fields => {
            been_fixed => 'Unknown',
            reported => 'No',
            another => 'Yes',
        },
    },
    {
        desc => 'Fixed report, reopened, reported before, no update, no further questionnaire',
        problem_state => 'fixed',
        fields => {
            been_fixed => 'No',
            reported => 'Yes',
            another => 'No',
            # update => 'Dummy', Error for not setting this tested below
        },
    },
) {
    subtest $test->{desc} => sub {
        $report->state ( $test->{problem_state} );
        $report->update;

        $mech->get_ok("/Q/" . $token->token);
        $mech->title_like( qr/Questionnaire/ );
        $mech->submit_form_ok( { with_fields => $test->{fields} } );

        # If reopening, we've just submitted without an update. Should cause an error.
        if ($test->{problem_state} eq 'fixed' && $test->{fields}{been_fixed} eq 'No') {
            my @errors = @{ $mech->page_errors };
            ok scalar @errors, 'displayed error messages';
            is $errors[0], "Please provide some explanation as to why you're reopening this report", 'error message';
            $test->{fields}{update} = 'This has not been fixed.';
            $mech->submit_form_ok( { with_fields => $test->{fields} } );
        }

        # We forgot to say we wanted another questionnaire or not with this test
        if ($test->{problem_state} eq 'confirmed' && $test->{fields}{been_fixed} eq 'Unknown') {
            my @errors = @{ $mech->page_errors };
            ok scalar @errors, 'displayed error messages';
            is $errors[0], "Please indicate whether you'd like to receive another questionnaire", 'error message';
            $test->{fields}{another} = 'No';
            $mech->submit_form_ok( { with_fields => $test->{fields} } );
        }

        my $result;
        $result = 'fixed'     if $test->{fields}{been_fixed} eq 'Yes';
        $result = 'confirmed' if $test->{fields}{been_fixed} eq 'No';
        $result = 'unknown'   if $test->{fields}{been_fixed} eq 'Unknown';

        my $another = 0;
        $another = 1 if $test->{fields}{another} && $test->{fields}{another} eq 'Yes';

        # Check the right HTML page has been returned
        $mech->content_like( qr/<title>[^<]*Questionnaire/m );
        $mech->content_contains( 'glad to hear it&rsquo;s been fixed' )
            if $result eq 'fixed';
        $mech->content_contains( 'get some more information about the status of your problem' )
            if $result eq 'unknown';
        $mech->content_contains( "sorry to hear that" )
            if $result eq 'confirmed';

        # Check the database has the right information
        $report->discard_changes;
        $questionnaire->discard_changes;
        is $report->state, $result eq 'unknown' ? $test->{problem_state} : $result;
        is $report->send_questionnaire, $another;
        ok DateTime::Format::Pg->format_datetime( $report->lastupdate) gt $report_time, 'lastupdate changed'
            unless $test->{fields}{been_fixed} eq 'Unknown' || $test->{lastupdate_static};
        is $questionnaire->old_state, $test->{problem_state};
        is $questionnaire->new_state, $result;
        is $questionnaire->ever_reported, $test->{fields}{reported} eq 'Yes' ? 1 : 0;
        if ($test->{fields}{update} || $test->{comment}) {
            my $c = FixMyStreet::App->model("DB::Comment")->find(
                { problem_id => $report->id }
            );
            is $c->text, $test->{fields}{update} || $test->{comment};
        }

        # Reset questionnaire for next test
        $questionnaire->old_state( undef );
        $questionnaire->new_state( undef );
        $questionnaire->ever_reported( undef );
        $questionnaire->whenanswered( undef );
        $questionnaire->update;
        $report->send_questionnaire( 0 );
        $report->lastupdate( $report_time );
        $report->comments->delete;
        $report->update;
    };
}

# EHA extra checking
ok $mech->host("reportemptyhomes.com"), 'change host to reportemptyhomes';

# Reset, and all the questionaire sending function - FIXME should it detect site itself somehow?
$report->send_questionnaire( 1 );
$report->update;
$questionnaire->delete;
FixMyStreet::App->model('DB::Questionnaire')->send_questionnaires( {
    site => 'emptyhomes'
} );
$email = $mech->get_email;
ok $email, "got an email";
like $email->body, qr/fill in this short questionnaire/i, "got questionnaire email";
($token) = $email->body =~ m{http://.*?/Q/(\S+)};
ok $token, "extracted questionnaire token '$token'";

$mech->get_ok("/Q/" . $token);
$mech->content_contains( 'should have reported what they have done' );

# Test already answered the ever reported question, so not shown again
my $questionnaire2 = FixMyStreet::App->model('DB::Questionnaire')->find_or_create(
    {
        problem_id => $report->id,
        whensent => '2011-03-28 12:00:00',
        ever_reported => 1,
    }
);
ok $questionnaire, 'added another questionnaire';
ok $mech->host("fixmystreet.com"), 'change host to fixmystreet';
$mech->get_ok("/Q/" . $token);
$mech->title_like( qr/Questionnaire/ );
$mech->content_contains( 'Has this problem been fixed?' );
$mech->content_lacks( 'ever reported' );

# EHA extra checking
ok $mech->host("reportemptyhomes.com"), 'change host to reportemptyhomes';
$mech->get_ok("/Q/" . $token);
$mech->content_contains( 'made a lot of progress' );

$mech->delete_user('test@example.com');
done_testing();
