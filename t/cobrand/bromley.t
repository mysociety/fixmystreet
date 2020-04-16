use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
my $mech = FixMyStreet::TestMech->new;

# Create test data
my $user = $mech->create_user_ok( 'bromley@example.com', name => 'Bromley' );
my $body = $mech->create_body_ok( 2482, 'Bromley Council');
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'LIGHT',
);
$contact->set_extra_metadata(id_field => 'service_request_id_ext');
$contact->set_extra_fields(
    { code => 'easting', datatype => 'number', },
    { code => 'northing', datatype => 'number', },
    { code => 'service_request_id_ext', datatype => 'number', },
    { code => 'service_sub_code', values => [ { key => 'RED', name => 'Red' }, { key => 'BLUE', name => 'Blue' } ], },
);
$contact->update;
my $tfl = $mech->create_body_ok( 2482, 'TfL');
$mech->create_contact_ok(
    body_id => $tfl->id,
    category => 'Traffic Lights',
    email => 'tfl@example.org',
);

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    latitude => 51.402096,
    longitude => 0.015784,
    cobrand => 'bromley',
    user => $user,
});
my $report = $reports[0];

for my $update ('in progress', 'unable to fix') {
    FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => $update,
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "This update marks it as $update",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
}

# Test Bromley special casing of 'unable to fix'
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains( 'marks it as in progress' );
$mech->content_contains( 'State changed to: In progress' );
$mech->content_contains( 'marks it as unable to fix' );
$mech->content_contains( 'State changed to: No further action' );

for my $test (
    {
        desc => 'testing special Open311 behaviour',
        updates => {},
        expected => {
          'attribute[easting]' => 540315,
          'attribute[northing]' => 168935,
          'attribute[service_request_id_ext]' => $report->id,
          'attribute[report_title]' => 'Test Test 1 for ' . $body->id,
          'jurisdiction_id' => 'FMS',
          address_id => undef,
        },
    },
    {
        desc => 'testing Open311 behaviour with no map click or postcode',
        updates => {
            used_map => 0,
            postcode => ''
        },
        expected => {
          'attribute[easting]' => 540315,
          'attribute[northing]' => 168935,
          'attribute[service_request_id_ext]' => $report->id,
          'jurisdiction_id' => 'FMS',
          'address_id' => '#NOTPINPOINTED#',
        },
    },
    {
        desc => 'asset ID',
        feature_id => '1234',
        expected => {
          'attribute[service_request_id_ext]' => $report->id,
          'attribute[report_title]' => 'Test Test 1 for ' . $body->id . ' | ID: 1234',
        },
    },
) {
    subtest $test->{desc}, sub {
        $report->$_($test->{updates}->{$_}) for keys %{$test->{updates}};
        $report->$_(undef) for qw/ whensent send_method_used external_id /;
        $report->set_extra_fields({ name => 'feature_id', value => $test->{feature_id} })
            if $test->{feature_id};
        $report->update;
        $body->update( { send_method => 'Open311', endpoint => 'http://bromley.endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1 } );
        my $test_data;
        FixMyStreet::override_config {
            STAGING_FLAGS => { send_reports => 1 },
            ALLOWED_COBRANDS => [ 'fixmystreet', 'bromley' ],
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $test_data = FixMyStreet::Script::Reports::send();
        };
        $report->discard_changes;
        ok $report->whensent, 'Report marked as sent';
        is $report->send_method_used, 'Open311', 'Report sent via Open311';
        is $report->external_id, 248, 'Report has right external ID';

        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param($_), $test->{expected}->{$_}, "Request had correct $_"
            for keys %{$test->{expected}};
    };
}

for my $test (
    {
        cobrand => 'bromley',
        fields => {
            submit_update   => 1,
            username => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            first_name            => 'Unreg',
            last_name            => 'User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
    {
        cobrand => 'fixmystreet',
        fields => {
            submit_update   => 1,
            username => 'unregistered@example.com',
            update          => 'Update from an unregistered user',
            add_alert       => undef,
            name            => 'Unreg User',
            fms_extra_title => 'DR',
            may_show_name   => undef,
        }
    },
)
{
    subtest 'check Bromley update emails via ' . $test->{cobrand} . ' cobrand are correct' => sub {
        $mech->log_out_ok();
        $mech->clear_emails_ok();

        my $report_id = $report->id;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => [ $test->{cobrand} ],
        }, sub {
            $mech->get_ok("/report/$report_id");
            $mech->submit_form_ok(
                {
                    with_fields => $test->{fields}
                },
                'submit update'
            );
        };
        $mech->content_contains('Nearly done! Now check your email');

        my $body = $mech->get_text_body_from_email;
        like $body, qr/This update will be sent to Bromley Council/i, "Email indicates problem will be sent to Bromley";
        unlike $body, qr/Note that we do not send updates to/i, "Email does not say updates aren't sent to Bromley";

        my $unreg_user = FixMyStreet::DB->resultset('User')->find( { email => 'unregistered@example.com' } );

        ok $unreg_user, 'found user';

        $mech->delete_user( $unreg_user );
    };
}

subtest 'check display of TfL reports' => sub {
    $mech->create_problems_for_body( 1, $tfl->id, 'TfL Test', {
        latitude => 51.402096,
        longitude => 0.015784,
        cobrand => 'bromley',
        user => $user,
    });
    $mech->get_ok( '/report/' . $report->id );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->follow_link_ok({ text_regex => qr/Back to all reports/i });
    };
    $mech->content_like(qr{<a title="TfL Test[^>]*www.example.org[^>]*><img[^>]*grey});
    $mech->content_like(qr{<a title="Test Test[^>]*href="/[^>]*><img[^>]*yellow});
};

subtest 'check geolocation overrides' => sub {
    my $cobrand = FixMyStreet::Cobrand::Bromley->new;
    foreach my $test (
        { query => 'Main Rd, BR1', town => 'Bromley', string => 'Main Rd' },
        { query => 'Main Rd, BR3', town => 'Beckenham', string => 'Main Rd' },
        { query => 'Main Rd, BR4', town => 'West Wickham', string => 'Main Rd' },
        { query => 'Main Rd, BR5', town => 'Orpington', string => 'Main Rd' },
        { query => 'Main Rd, BR7', town => 'Chislehurst', string => 'Main Rd' },
        { query => 'Main Rd, BR8', town => 'Swanley', string => 'Main Rd' },
        { query => 'Old Priory Avenue', town => 'BR6 0PL', string => 'Old Priory Avenue' },
    ) {
        my $res = $cobrand->disambiguate_location($test->{query});
        is $res->{town}, $test->{town}, "Town matches $test->{town}";
        is $res->{string}, $test->{string}, "String matches $test->{string}";
    }
};

subtest 'check special subcategories in admin' => sub {
    $mech->create_user_ok('superuser@example.com', is_superuser => 1);
    $mech->log_in_ok('superuser@example.com');
    $user->update({ from_body => $body->id });
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/admin/users/' . $user->id);
        $mech->submit_form_ok({ with_fields => { 'contacts['.$contact->id.']' => 1, 'contacts[BLUE]' => 1 } });
    };
    $user->discard_changes;
    is_deeply $user->get_extra_metadata('categories'), [ $contact->id ];
    is_deeply $user->get_extra_metadata('subcategories'), [ 'BLUE' ];
};

subtest 'check heatmap page' => sub {
    $user->update({ area_ids => [ 60705 ] });
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => { category_groups => { bromley => 1 }, heatmap => { bromley => 1 } },
    }, sub {
        $mech->log_in_ok($user->email);
        $mech->get_ok('/dashboard/heatmap?end_date=2018-12-31');
        $mech->get_ok('/dashboard/heatmap?filter_category=RED&ajax=1');
    };
};

done_testing();
