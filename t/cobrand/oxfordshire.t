use Test::MockModule;

use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $oxon);

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
        ALLOWED_COBRANDS => 'oxfordshire',
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

my @problems = FixMyStreet::DB->resultset('Problem')->search({}, { rows => 3, order_by => 'id' })->all;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'oxfordshire',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

    subtest 'can use customer reference to search for reports' => sub {
        my $problem = $problems[0];
        $problem->set_extra_metadata( customer_reference => 'ENQ12456' );
        $problem->update;

        $mech->get_ok('/around?pc=ENQ12456');
        is $mech->uri->path, '/report/' . $problem->id, 'redirects to report';
    };

    subtest 'check unable to fix label' => sub {
        my $user = $mech->create_user_ok( 'user@example.com', name => 'Test User' );
        my $user2 = $mech->create_user_ok( 'user2@example.com', name => 'Test User2' );

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

    subtest 'extra CSV columns are present' => sub {

        $problems[1]->update({ external_id => $problems[1]->id });
        $problems[2]->update({ external_id => "123098123" });

        $mech->log_in_ok( $counciluser->email );

        $mech->get_ok('/dashboard?export=1');

        my @rows = $mech->content_as_csv;
        is scalar @rows, 7, '1 (header) + 6 (reports) = 7 lines';
        is scalar @{$rows[0]}, 21, '21 columns present';

        is_deeply $rows[0],
            [
                'Report ID', 'Title', 'Detail', 'User Name', 'Category',
                'Created', 'Confirmed', 'Acknowledged', 'Fixed', 'Closed',
                'Status', 'Latitude', 'Longitude', 'Query', 'Ward',
                'Easting', 'Northing', 'Report URL', 'Site Used',
                'Reported As', 'HIAMS/Exor Ref',
            ],
            'Column headers look correct';

        is $rows[1]->[20], 'ENQ12456', 'HIAMS reference included in row';
        is $rows[2]->[20], '', 'Report without HIAMS ref has empty ref field';
        is $rows[3]->[20], '123098123', 'Older Exor report has correct ref';
    };
};

done_testing();
