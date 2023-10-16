use FixMyStreet::TestMech;
use Test::Deep;

my $mech    = FixMyStreet::TestMech->new;
my $cobrand = FixMyStreet::Cobrand::Gloucestershire->new;
my $body    = $mech->create_body_ok(
    2226,
    'Gloucestershire County Council',
    {   send_method  => 'Open311',
        api_key      => 'key',
        endpoint     => 'endpoint',
        jurisdiction => 'jurisdiction',
    },
    { cobrand => 'gloucestershire', },
);

my $graffiti = $mech->create_contact_ok(
    body_id  => $body->id,
    category => 'Graffiti',
    email    => 'GLOS_GRAFFITI',
);

my $standard_user_1
    = $mech->create_user_ok( 'user1@email.com', name => 'User 1' );
my $standard_user_2
    = $mech->create_user_ok( 'user2@email.com', name => 'User 2' );
my $staff_user = $mech->create_user_ok(
    'staff@email.com',
    name      => 'Staff User',
    from_body => $body,
);
my $superuser = $mech->create_user_ok(
    'super@email.com',
    name         => 'Super User',
    is_superuser => 1,
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet', 'gloucestershire' ],
    MAPIT_URL        => 'http://mapit.uk/',
    STAGING_FLAGS    => { skip_must_have_2fa => 1 },
    COBRAND_FEATURES => {
        anonymous_account => { gloucestershire => 'anonymous.fixmystreet' },
        updates_allowed   => {
            gloucestershire => 'reporter-not-open/staff-open',
            fixmystreet     => {
                Gloucestershire => 'reporter-not-open/staff-open',
            }
        },
    },
}, sub {
    ok $mech->host('gloucestershire'), 'change host to gloucestershire';
    $mech->get_ok('/');
    $mech->content_like(qr/Enter a Gloucestershire postcode/);

    subtest 'variations of example search location are disambiguated' => sub {
        for my $string (
            'Gloucester Road, Tewkesbury',
            '  gloucester  rd,tewkesbury  ',
        ) {
            is $cobrand->disambiguate_location($string)->{town},
                'Gloucestershire, GL20 5XA', $string;
        }
    };

    subtest 'open311_extra_data_include' => sub {
        my ($report) = $mech->create_problems_for_body(
            1,
            $body->id,
            'My report',
            {   cobrand => 'gloucestershire',
                user    => $standard_user_1,
                category => 'Graffiti',
            },
        );

        cmp_deeply $cobrand->open311_extra_data_include($report), [
            { name => 'report_url', value => undef },
            { name => 'title',      value => re('My report Test') },
            {   name  => 'description',
                value => re('My report Test.*Detail'),
            },
            {   name  => 'description',
                value => re('Graffiti | My report Test'),
            },
            {   name  => 'location',
                value => re('My report Test.*Detail'),
            },
        ], 'Correct data set for standard report';

        my $pothole = $mech->create_contact_ok(
            body_id  => $body->id,
            category => 'Potholes',
            email    => 'POTHOLE_WRAPPED',
        );
        $pothole->set_extra_fields(
            {   code        => '_wrapped_service_code',
                description => "Pothole wrapped group",
                values      => [
                    {   key  => 'GLOS_POTHOLE_PAVEMENT',
                        name => 'Pothole in pavement',
                    },
                ],
                datatype => 'singlevaluelist',
                required => 'true',
                variable => 'true',
            },
        );
        $pothole->update;

        my ($report_2) = $mech->create_problems_for_body(
            1,
            $body->id,
            'My report',
            {   cobrand => 'gloucestershire',
                user    => $standard_user_1,
                category => 'Potholes',
            },
        );
        $report_2->set_extra_fields(
            {
                name => '_wrapped_service_code',
                value => 'GLOS_POTHOLE_PAVEMENT',
                description => 'Pothole in pavement',
            },
        );

        cmp_deeply $cobrand->open311_extra_data_include($report_2), [
            { name => 'report_url', value => undef },
            { name => 'title',      value => re('My report Test') },
            {   name  => 'description',
                value => re('My report Test.*Detail'),
            },
            {   name  => 'description',
                value => re('Pothole in pavement | My report Test'),
            },
            {   name  => 'location',
                value => re('My report Test.*Detail'),
            },
        ], 'Correct data set for report with a wrapped category';
    };

    subtest 'test report creation anonymously by button' => sub {
        $mech->log_in_ok( $standard_user_1->email );
        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR' } },
            'submit location' );
        $mech->follow_link_ok(
            { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link"
        );

        $mech->submit_form_ok(
            {   button      => 'report_anonymously',
                with_fields => {
                    title    => 'Anon report',
                    detail   => 'ABC',
                    category => 'Graffiti',
                }
            },
            'submit report anonymously',
        );
        cmp_deeply $mech->page_errors, [], 'check there were no errors';

        my $report = FixMyStreet::DB->resultset('Problem')
            ->find( { title => 'Anon report' } );
        ok $report, 'report found in DB';
        is $report->state, 'confirmed', 'report confirmed';
        is $report->name, 'Anonymous user';
        is $report->user->email,
            'anonymous.fixmystreet@gloucestershire.gov.uk';
        is $report->anonymous,                            1;
        is $report->get_extra_metadata('contributed_as'), 'anonymous_user';

        my $alert = FixMyStreet::App->model('DB::Alert')->find(
            {   user       => $report->user,
                alert_type => 'new_updates',
                parameter  => $report->id,
            }
        );
        is $alert, undef, "no alert created";
    };

    for my $host ( 'fixmystreet', 'gloucestershire' ) {
        ok $mech->host($host), "change host to $host";

        subtest 'for an open report' => sub {
            for my $state ( 'confirmed', 'in progress' ) {
                my ($report) = $mech->create_problems_for_body(
                    1,
                    $body->id,
                    'Open report',
                    {   cobrand => 'gloucestershire',
                        user    => $standard_user_1,
                        state   => $state,
                    },
                );

                note 'Logged-out user';
                $mech->log_out_ok;
                $mech->get( '/report/' . $report->id );
                $mech->content_lacks(
                    'div id="update_form"',
                    'Update form not shown at all',
                );
                $mech->content_lacks(
                    'form name="report_inspect_form" id="report_inspect_form"',
                    'No admin sidebar',
                );
                if ( $host eq 'gloucestershire' ) {
                    $mech->content_contains(
                        'This report is closed to updates.',
                        'Correct message shown',
                    );
                    $mech->content_lacks(
                        'make a new report in the same location',
                        'Lacks option to make a new report in same location',
                    );
                } else {
                    $mech->content_contains(
                        'This report is now closed to updates.',
                        'Correct message shown',
                    );
                    $mech->content_lacks(
                        'Only the original reporter may leave updates',
                        'Doesn’t mention original reporter being able to leave updates',
                    );
                }

                note 'Original reporter';
                $mech->log_in_ok( $standard_user_1->email );
                $mech->get( '/report/' . $report->id );
                $mech->content_lacks(
                    'div id="update_form"',
                    'Update form not shown at all',
                );
                $mech->content_lacks(
                    'form name="report_inspect_form" id="report_inspect_form"',
                    'No admin sidebar',
                );
                if ( $host eq 'gloucestershire' ) {
                    $mech->content_contains(
                        'This report is closed to updates.',
                        'Correct message shown',
                    );
                    $mech->content_lacks(
                        'make a new report in the same location',
                        'Lacks option to make a new report in same location',
                    );
                }

                note 'Another standard user';
                $mech->log_in_ok( $standard_user_2->email );
                $mech->get( '/report/' . $report->id );
                $mech->content_lacks(
                    'div id="update_form"',
                    'Update form not shown at all',
                );
                $mech->content_lacks(
                    'form name="report_inspect_form" id="report_inspect_form"',
                    'No admin sidebar',
                );
                if ( $host eq 'gloucestershire' ) {
                    $mech->content_contains(
                        'This report is closed to updates.',
                        'Correct message shown',
                    );
                    $mech->content_lacks(
                        'make a new report in the same location',
                        'Lacks option to make a new report in same location',
                    );
                }

                # Admin are shown a dropdown for states, rather than just a
                # checkbox

                note 'Staff';
                $mech->log_in_ok( $staff_user->email );
                $mech->get( '/report/' . $report->id );
                $mech->content_contains(
                    'name="update" class="form-control" id="form_update"',
                    'Update textbox shown',
                );
                $mech->content_lacks(
                    'input type="checkbox" name="fixed" id="form_fixed"',
                    'State checkbox not shown',
                );
                $mech->content_contains(
                    'select class="form-control" name="state"  id="state"',
                    'State dropdown shown',
                );
                $mech->content_lacks(
                    'form name="report_inspect_form" id="report_inspect_form"',
                    'No admin sidebar',
                );
                if ( $host eq 'gloucestershire' ) {
                    $mech->content_lacks(
                        'This report is closed to updates.',
                        '"Closed to updates" message not shown',
                    );
                }

                note 'Superuser';
                $mech->log_in_ok( $superuser->email );
                $mech->get( '/report/' . $report->id );
                $mech->content_contains(
                    'name="update" class="form-control" id="form_update"',
                    'Update textbox shown',
                );
                $mech->content_lacks(
                    'input type="checkbox" name="fixed" id="form_fixed"',
                    'State checkbox not shown',
                );
                $mech->content_contains(
                    'select class="form-control" name="state"  id="state"',
                    'State dropdown shown',
                );
                $mech->content_contains(
                    'form name="report_inspect_form" id="report_inspect_form"',
                    'Shown admin sidebar',
                );
                if ( $host eq 'gloucestershire' ) {
                    $mech->content_lacks(
                        'This report is closed to updates.',
                        '"Closed to updates" message not shown',
                    );
                }
            }
        };

        subtest 'for a closed report' => sub {
            # 'closed' == any state that does not fall under open
            my ($report) = $mech->create_problems_for_body(
                1,
                $body->id,
                'Closed report',
                {   cobrand => 'gloucestershire',
                    user    => $standard_user_1,
                    state   => 'fixed - council',
                },
            );

            note 'Logged-out user';
            $mech->log_out_ok;
            $mech->get( '/report/' . $report->id );
            $mech->content_lacks(
                'div id="update_form"',
                'Update form not shown at all',
            );
            $mech->content_lacks(
                'form name="report_inspect_form" id="report_inspect_form"',
                'No admin sidebar',
            );
            if ( $host eq 'gloucestershire' ) {
                $mech->content_contains(
                    'This report is closed to updates.',
                    'Correct message shown',
                );
                $mech->content_contains(
                    'make a new report in the same location',
                    'Option to make a new report in same location',
                );
            }

            note 'Original reporter';
            $mech->log_in_ok( $standard_user_1->email );
            $mech->get( '/report/' . $report->id );
            $mech->content_contains(
                'name="update" class="form-control" id="form_update"',
                'Update textbox shown',
            );
            $mech->content_contains(
                'type="checkbox" name="reopen" id="form_reopen"',
                'State checkbox shown',
            );
            $mech->content_lacks(
                'select class="form-control" name="state"  id="state"',
                'State dropdown not shown',
            );
            $mech->content_lacks(
                'form name="report_inspect_form" id="report_inspect_form"',
                'No admin sidebar',
            );
            if ( $host eq 'gloucestershire' ) {
                $mech->content_lacks(
                    'This report is closed to updates.',
                    '"Closed to updates" message not shown',
                );
            }

            note 'Another standard user';
            $mech->log_in_ok( $standard_user_2->email );
            $mech->get( '/report/' . $report->id );
            $mech->content_lacks(
                'div id="update_form"',
                'Update form not shown at all',
            );
            $mech->content_lacks(
                'form name="report_inspect_form" id="report_inspect_form"',
                'No admin sidebar',
            );
            if ( $host eq 'gloucestershire' ) {
                $mech->content_contains(
                    'This report is closed to updates.',
                    'Correct message shown',
                );
                $mech->content_contains(
                    'make a new report in the same location',
                    'Option to make a new report in same location',
                );
            }

            # Admin are shown a dropdown for states, rather than just a
            # checkbox

            note 'Staff';
            $mech->log_in_ok( $staff_user->email );
            $mech->get( '/report/' . $report->id );
            $mech->content_lacks(
                'div id="update_form"',
                'Update form not shown at all',
            );
            $mech->content_lacks(
                'form name="report_inspect_form" id="report_inspect_form"',
                'No admin sidebar',
            );
            if ( $host eq 'gloucestershire' ) {
                $mech->content_contains(
                    'This report is closed to updates.',
                    'Correct message shown',
                );
                $mech->content_contains(
                    'make a new report in the same location',
                    'Option to make a new report in same location',
                );
            }

            note 'Superuser';
            $mech->log_in_ok( $superuser->email );
            $mech->get( '/report/' . $report->id );
            $mech->content_lacks(
                'div id="update_form"',
                'Update form not shown at all',
            );
            $mech->content_contains(
                'form name="report_inspect_form" id="report_inspect_form"',
                'Shown admin sidebar',
            );
            if ( $host eq 'gloucestershire' ) {
                $mech->content_contains(
                    'This report is closed to updates.',
                    'Correct message shown',
                );
                $mech->content_contains(
                    'make a new report in the same location',
                    'Option to make a new report in same location',
                );
            }
        };
    }
};

done_testing();
