use DateTime;

use FixMyStreet::TestMech;
use FixMyStreet::App::Controller::Questionnaire;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');

my $dt = DateTime->now()->subtract( weeks => 5 );
my $report_time = $dt->ymd . ' ' . $dt->hms;
my $sent = $dt->add( minutes => 5 );
my $sent_time = $sent->ymd . ' ' . $sent->hms;

my $report = FixMyStreet::App->model('DB::Problem')->find_or_create(
    {
        postcode           => 'EH1 1BB',
        bodies_str         => '2651',
        areas              => ',11808,135007,14419,134935,2651,20728,',
        category           => 'Street lighting',
        title              => 'Testing',
        detail             => "Testing \x{2013} Detail",
        used_map           => 1,
        name               => $user->name,
        anonymous          => 0,
        state              => 'confirmed',
        confirmed          => $report_time,
        lastupdate         => $report_time,
        whensent           => $sent_time,
        lang               => 'en-gb',
        service            => '',
        cobrand            => '',
        cobrand_data       => '',
        send_questionnaire => 1,
        latitude           => '55.951963',
        longitude          => '-3.189944',
        user_id            => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

# Make sure questionnaires aren't sent if the report is closed.
foreach my $state (
    'closed', 'duplicate', 'not responsible', 'unable to fix', 'internal referral'
) {
    subtest "questionnaire not sent for $state state" => sub {
        $report->update( { send_questionnaire => 1, state => $state } );
        $report->questionnaires->delete;
        FixMyStreet::App->model('DB::Questionnaire')->send_questionnaires( {
            site => 'fixmystreet'
        } );

        $mech->email_count_is(0);

        $report->discard_changes;
        is $report->send_questionnaire, 0;
    }
}
$report->update( { send_questionnaire => 1, state => 'confirmed' } );
$report->questionnaires->delete;

# Call the questionaire sending function...
FixMyStreet::App->model('DB::Questionnaire')->send_questionnaires( {
    site => 'fixmystreet'
} );
my $email = $mech->get_email;
ok $email, "got an email";
my $plain = $mech->get_text_body_from_email($email, 1);
like $plain->body, qr/fill in our short questionnaire/i, "got questionnaire email";

like $plain->body_str, qr/Testing \x{2013} Detail/, 'email contains encoded character';
is $plain->header('Content-Type'), 'text/plain; charset="utf-8"', 'in the right character set';

my $url = $mech->get_link_from_email($email, 0, 1);
my ($token) = $url =~ m{/Q/(\S+)};
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
        content => "Sorry, that wasn&rsquo;t a valid link",
        code => 400,
    },
    {
        desc => 'User goes to questionnaire URL for a now-hidden problem',
        state => 'hidden',
        content => "we couldn't locate your problem",
        code => 400,
    },
    {
        desc => 'User goes to questionnaire URL for an already answered questionnaire',
        answered => \"current_timestamp - '10 minutes'::interval",
        content => 'already answered this questionnaire',
        code => 400,
    },
    {
        desc => 'User goes to questionnaire URL for a very recently answered questionnaire',
        answered => \"current_timestamp - '10 seconds'::interval",
        content_lacks => 'already answered this questionnaire',
        code => 200,
    },
) {
    subtest $test->{desc} => sub {
        $report->state( $test->{state} || 'confirmed' );
        $report->update;
        $questionnaire->whenanswered( $test->{answered} );
        $questionnaire->update;
        (my $token = $token->token);
        $token .= $test->{token_extra} if $test->{token_extra};
        $mech->get("/Q/$token");
        is $mech->res->code, $test->{code}, "Right status received";
        $mech->content_contains( $test->{content} ) if $test->{content};
        $mech->content_lacks( $test->{content_lacks} ) if $test->{content_lacks};
        # Reset, no matter what test did
        $report->state( 'confirmed' );
        $report->update;
        $questionnaire->whenanswered( undef );
        $questionnaire->update;
    };
}

subtest "If been_fixed is provided in the URL" => sub {
    $mech->get_ok("/Q/" . $token->token . "?been_fixed=Yes");
    $mech->content_contains('id="been_fixed_yes" value="Yes" checked');
    $report->discard_changes;
    is $report->state, 'fixed - user';
    $questionnaire->discard_changes;
    is $questionnaire->old_state, 'confirmed';
    is $questionnaire->new_state, 'fixed - user';
    $mech->submit_form_ok({ with_fields => { been_fixed => 'Unknown', reported => 'Yes', another => 'No' } });
    $report->discard_changes;
    is $report->state, 'confirmed';
    $questionnaire->discard_changes;
    is $questionnaire->old_state, 'confirmed';
    is $questionnaire->new_state, 'unknown';
    $questionnaire->update({ whenanswered => undef, ever_reported => undef, old_state => undef, new_state => undef });
};

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
    {
        desc => 'Fixed report, reopened, reported before, blank update, no further questionnaire',
        problem_state => 'fixed',
        fields => {
            been_fixed => 'No',
            reported => 'Yes',
            another => 'No',
            update => '   ',
        },
    },
    {
        desc => 'Closed report, said fixed, reported before, no update, no further questionnaire',
        problem_state => 'closed',
        fields => {
            been_fixed => 'Yes',
            reported => 'Yes',
            another => 'No',
        },
    },
    {
        desc => 'Closed report, said not fixed, reported before, no update, no further questionnaire',
        problem_state => 'closed',
        fields => {
            been_fixed => 'No',
            reported => 'Yes',
            another => 'No',
        },
        lastupdate_static => 1,
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
        $result = 'fixed - user'
          if $test->{fields}{been_fixed} eq 'Yes'
              && $test->{problem_state} ne 'fixed';
        $result = 'fixed'
          if $test->{fields}{been_fixed} eq 'Yes'
              && $test->{problem_state} eq 'fixed';
        $result = 'confirmed' if $test->{fields}{been_fixed} eq 'No' && $test->{problem_state} ne 'closed';
        $result = 'closed' if $test->{fields}{been_fixed} eq 'No' && $test->{problem_state} eq 'closed';
        $result = 'unknown'   if $test->{fields}{been_fixed} eq 'Unknown';

        my $another = 0;
        $another = 1 if $test->{fields}{another} && $test->{fields}{another} eq 'Yes';

        # Check the right HTML page has been returned
        $mech->content_like( qr/<title>[^<]*Questionnaire/m );
        $mech->content_contains( 'Glad to hear' )
            if $result =~ /fixed/;
        $mech->content_lacks( 'Glad to hear' )
            if $result !~ /fixed/;
        $mech->content_contains( 'get some more information about the status of your problem' )
            if $result eq 'unknown';
        $mech->content_contains( "sorry to hear" )
            if $result eq 'confirmed' || $result eq 'closed';

        # Check the database has the right information
        $report->discard_changes;
        $questionnaire->discard_changes;
        is $report->state, $result eq 'unknown' ? $test->{problem_state} : $result;
        is $report->send_questionnaire, $another;
        ok (DateTime::Format::Pg->format_datetime( $report->lastupdate) gt $report_time, 'lastupdate changed')
            unless $test->{fields}{been_fixed} eq 'Unknown' || $test->{lastupdate_static};
        is $questionnaire->old_state, $test->{problem_state};
        is $questionnaire->new_state, $result;
        is $questionnaire->ever_reported, $test->{fields}{reported} eq 'Yes' ? 1 : 0;
        if ($test->{fields}{update} || $test->{comment}) {
            my $c = FixMyStreet::App->model("DB::Comment")->find(
                { problem_id => $report->id }
            );
            is $c->text, $test->{fields}{update} || $test->{comment};
            if ( $result =~ /fixed/ ) {
                ok $c->mark_fixed, 'comment marked as fixed';
                ok !$c->mark_open, 'comment not marked as open';
            } elsif ( $result eq 'confirmed' ) {
                ok $c->mark_open, 'comment marked as open';
                ok !$c->mark_fixed, 'comment not marked as fixed';
            } elsif ( $result eq 'unknown' ) {
                ok !$c->mark_open, 'comment not marked as open';
                ok !$c->mark_fixed, 'comment not marked as fixed';
            }
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

my $comment = FixMyStreet::App->model('DB::Comment')->find_or_create(
    {
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'A User',
        mark_fixed => 'false',
        text       => 'This is some update text',
        state      => 'confirmed',
        confirmed  => $sent_time,
        anonymous  => 'f',
    }
);
subtest 'Check updates are shown correctly on questionnaire page' => sub {
    $mech->get_ok("/Q/" . $token->token);
    $mech->content_contains( 'Show all updates' );
    $mech->content_contains( 'This is some update text' );
};

for my $test (
    {
        state => 'confirmed',
        fixed => 0
    },
    {
        state => 'planned',
        fixed => 0
    },
    {
        state => 'action scheduled',
        fixed => 0
    },
    {
        state => 'in progress',
        fixed => 0
    },
    {
        state => 'investigating',
        fixed => 0
    },
    {
        state => 'duplicate',
        fixed => 0
    },
    {
        state => 'not responsible',
        fixed => 0
    },
    {
        state => 'unable to fix',
        fixed => 0
    },
    {
        state => 'closed',
        fixed => 0
    },
    {
        state => 'fixed',
        fixed => 1
    },
    {
        state => 'fixed - council',
        fixed => 1
    },
    {
        state => 'fixed - user',
        fixed => 1
    },
) {
    subtest "correct fixed text for state $test->{state}" => sub {
        $report->state ( $test->{state} );
        $report->update;

        $mech->get_ok("/Q/" . $token->token);
        $mech->title_like( qr/Questionnaire/ );
        if ( $test->{fixed} ) {
            $mech->content_contains('An update marked this problem as fixed');
        } else {
            $mech->content_lacks('An update marked this problem as fixed');
        }
    };
}

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet' ],
}, sub {
    $report->discard_changes;
    $report->send_questionnaire( 1 );
    $report->update;
    $questionnaire->delete;

    FixMyStreet::App->model('DB::Questionnaire')->send_questionnaires();

    my $email = $mech->get_email;
    my $body = $mech->get_text_body_from_email($email);
    $mech->clear_emails_ok;
    $body =~ s/\s+/ /g;
    like $body, qr/fill in our short questionnaire/i, "got questionnaire email";
    my $url = $mech->get_link_from_email($email, 0, 1);
    ($token) = $url =~ m{/Q/(\S+)};
    ok $token, "extracted questionnaire token '$token'";

    # Test already answered the ever reported question, so not shown again
    $dt = $dt->add( weeks => 4 );
    my $questionnaire2 = FixMyStreet::App->model('DB::Questionnaire')->find_or_create(
        {
            problem_id => $report->id,
            whensent => $dt->ymd . ' ' . $dt->hms,
            ever_reported => 1,
        }
    );
    ok $questionnaire2, 'added another questionnaire';
    $mech->get_ok("/Q/" . $token);
    $mech->title_like( qr/Questionnaire/ );
    $mech->content_contains( 'Has this problem been fixed?' );
    $mech->content_lacks( 'ever reported' );

    $token = FixMyStreet::App->model("DB::Token")->find( { scope => 'questionnaire', token => $token } );
    ok $token, 'found token for questionnaire';
    $questionnaire = FixMyStreet::App->model('DB::Questionnaire')->find( { id => $token->data } );
    ok $questionnaire, 'found questionnaire';

    $questionnaire2->delete;
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fiksgatami' ],
}, sub {
    # I18N Unicode extra testing using FiksGataMi
    $report->discard_changes;
    $report->send_questionnaire( 1 );
    $report->cobrand( 'fiksgatami' );
    $report->update;
    $questionnaire->delete;
    FixMyStreet::App->model('DB::Questionnaire')->send_questionnaires();
    $email = $mech->get_email;
    ok $email, "got an email";
    $mech->clear_emails_ok;

    my $plain = $mech->get_text_body_from_email($email, 1);
    like $plain->body_str, qr/Testing \x{2013} Detail/, 'email contains encoded character from user';
    like $plain->body_str, qr/sak p\xe5 FiksGataMi/, 'email contains encoded character from template';
    is $plain->header('Content-Type'), 'text/plain; charset="utf-8"', 'email is in right encoding';
};

done_testing();
