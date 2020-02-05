use Test::MockModule;

use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');

subtest 'check /around?ajax defaults to open reports only' => sub {
    my $categories = [ 'Bridges', 'Fences', 'Manhole' ];
    my $params = {
        postcode  => 'OX28 4DS',
        cobrand => 'oxfordshire',
        latitude  =>  51.784721,
        longitude => -1.494453,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    # Create one open and one fixed report in each category
    foreach my $category ( @$categories ) {
        foreach my $state ( 'confirmed', 'fixed' ) {
            my %report_params = (
                %$params,
                category => $category,
                state => $state,
            );
            $mech->create_problems_for_body( 1, $oxon->id, 'Around page', \%report_params );
        }
    }

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'oxfordshire' => '.' } ],
    }, sub {
        my $json = $mech->get_ok_json( '/around?ajax=1&status=all&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 6, 'correct number of reports created';

        $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 3, 'correct number of reports returned with no filters';

        $json = $mech->get_ok_json( '/around?ajax=1&filter_category=Fences&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 1, 'only one Fences report by default';
    }
};

my @problems = FixMyStreet::DB->resultset('Problem')->search({}, { rows => 3 })->all;

subtest 'can use customer reference to search for reports' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $problem = $problems[0];
        $problem->set_extra_metadata( customer_reference => 'ENQ12456' );
        $problem->update;

        $mech->get_ok('/around?pc=ENQ12456');
        is $mech->uri->path, '/report/' . $problem->id, 'redirects to report';
    };
};

my $user = $mech->create_user_ok( 'user@example.com', name => 'Test User' );
my $user2 = $mech->create_user_ok( 'user2@example.com', name => 'Test User2' );

subtest 'check unable to fix label' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $problem = $problems[0];
        $problem->state( 'unable to fix' );
        $problem->update;

        my $alert = FixMyStreet::DB->resultset('Alert')->create( {
            parameter  => $problem->id,
            alert_type => 'new_updates',
            cobrand    => 'oxfordshire',
            user       => $user,
        } )->confirm;

        FixMyStreet::DB->resultset('Comment')->create( {
            problem_state => 'unable to fix',
            problem_id => $problem->id,
            user_id    => $user2->id,
            name       => 'User',
            mark_fixed => 'f',
            text       => "this is an update",
            state      => 'confirmed',
            confirmed  => 'now()',
            anonymous  => 'f',
        } );


        $mech->get_ok('/report/' . $problem->id);
        $mech->content_contains('Investigation complete');

        FixMyStreet::Script::Alerts::send();
        $mech->email_count_is(1);
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Investigation complete/, 'state correct in email';
    };
};

$oxon->update({
    send_method => 'Open311',
    endpoint => 'endpoint',
    api_key => 'key',
    jurisdiction => 'home',
});
my $contact = $mech->create_contact_ok( body_id => $oxon->id, category => 'Gullies and Catchpits', email => 'GC' );
$contact->set_extra_fields( (
    { code => 'feature_id', datatype => 'hidden', variable => 'true' },
    { code => 'usrn', datatype => 'hidden', variable => 'true' },
) );
$contact->update;

for my $test (
    {
        field => 'usrn',
        value => '12345',
        text => 'USRN',
    },
    {
        field => 'feature_id',
        value => '12345',
        text => 'Asset Id',
    },
) {
    subtest 'Check special Open311 request handling of ' . $test->{text}, sub {
        my ($p) = $mech->create_problems_for_body( 1, $oxon->id, 'Test', {
            cobrand => 'oxfordshire',
            category => 'Gullies and Catchpits',
            user => $user,
            latitude => 51.754926,
            longitude => -1.256179,
        });
        $p->set_extra_fields({ name => $test->{field}, value => $test->{value}});
        $p->update;

        my $test_data;
        FixMyStreet::override_config {
            STAGING_FLAGS => { send_reports => 1 },
            ALLOWED_COBRANDS => ['oxfordshire' ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $test_data = FixMyStreet::Script::Reports::send();
        };

        $p->discard_changes;
        ok $p->whensent, 'Report marked as sent';
        is $p->send_method_used, 'Open311', 'Report sent via Open311';
        is $p->external_id, 248, 'Report has right external ID';
        unlike $p->detail, qr/$test->{text}:/, $test->{text} . ' not saved to report detail';

        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        like $c->param('description'), qr/$test->{text}: $test->{value}/, $test->{text} . ' included in body';
    };
}

END {
    done_testing();
}
