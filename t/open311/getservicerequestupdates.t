#!/usr/bin/env perl

use FixMyStreet::Test;
use Test::Output;
use CGI::Simple;
use LWP::Protocol::PSGI;
use Test::Warn;
use t::Mock::Static;

use_ok( 'Open311' );

use_ok( 'Open311::GetServiceRequestUpdates' );
use DateTime;
use DateTime::Format::W3CDTF;
use FixMyStreet::DB;

my $user = FixMyStreet::DB->resultset('User')->find_or_create(
    {
        email => 'system_user@example.com'
    }
);

my %bodies = (
    2237 => FixMyStreet::DB->resultset("Body")->create({ name => 'Oxfordshire' }),
    2482 => FixMyStreet::DB->resultset("Body")->create({
        name => 'Bromley',
        send_method => 'Open311',
        send_comments => 1,
        endpoint => 'endpoint',
        comment_user_id => $user->id,
        blank_updates_permitted => 1,
    }),
    2651 => FixMyStreet::DB->resultset("Body")->create({ name => 'Edinburgh' }),
);
$bodies{2237}->body_areas->create({ area_id => 2237 });

my $response_template = $bodies{2482}->response_templates->create({
    title => "investigating template",
    text => "We are investigating this report.",
    auto_response => 1,
    state => "investigating"
});
my $response_template_fixed = $bodies{2482}->response_templates->create({
    title => "fixed template",
    text => "We have fixed this report.",
    auto_response => 1,
    state => "fixed - council"
});

my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
<service_requests_updates>
<request_update>
<update_id>638344</update_id>
<service_request_id>1</service_request_id>
<status>open</status>
<description>This is a note</description>
UPDATED_DATETIME
</request_update>
</service_requests_updates>
};


my $dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new)->add( minutes => -5 );

# basic xml -> perl object tests
for my $test (
    {
        desc => 'basic parsing - element missing',
        updated_datetime => '',
        res => { update_id => 638344, service_request_id => 1,
                status => 'open', description => 'This is a note' },
    },
    {
        desc => 'basic parsing - empty element',
        updated_datetime => '<updated_datetime />',
        res =>  { update_id => 638344, service_request_id => 1,
                status => 'open', description => 'This is a note', updated_datetime => undef } ,
    },
    {
        desc => 'basic parsing - element with no content',
        updated_datetime => '<updated_datetime></updated_datetime>',
        res =>  { update_id => 638344, service_request_id => 1,
                status => 'open', description => 'This is a note', updated_datetime => undef } ,
    },
    {
        desc => 'basic parsing - element with content',
        updated_datetime => sprintf( '<updated_datetime>%s</updated_datetime>', $dt ),
        res =>  { update_id => 638344, service_request_id => 1,
                status => 'open', description => 'This is a note', updated_datetime => $dt } ,
    },
) {
    subtest $test->{desc} => sub {
        my $local_requests_xml = $requests_xml;
        $local_requests_xml =~ s/UPDATED_DATETIME/$test->{updated_datetime}/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

        my $res = $o->get_service_request_updates;
        is_deeply $res->[0], $test->{ res }, 'result looks correct';

    };
}

subtest 'check extended request parsed correctly' => sub {
    my $extended_requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id_ext>120384</service_request_id_ext>
    <service_request_id>1</service_request_id>
    <status>open</status>
    <description>This is a note</description>
    UPDATED_DATETIME
    </request_update>
    </service_requests_updates>
    };

    my $updated_datetime = sprintf( '<updated_datetime>%s</updated_datetime>', $dt );
    my $expected_res =  { update_id => 638344, service_request_id => 1, service_request_id_ext => 120384,
            status => 'open', description => 'This is a note', updated_datetime => $dt };

    $extended_requests_xml =~ s/UPDATED_DATETIME/$updated_datetime/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $extended_requests_xml } );

    my $res = $o->get_service_request_updates;
    is_deeply $res->[0], $expected_res, 'result looks correct';

};

my $problem_rs = FixMyStreet::DB->resultset('Problem');
my $problem = $problem_rs->new(
    {
        postcode     => 'EH99 1SP',
        latitude     => 1,
        longitude    => 1,
        areas        => 1,
        title        => '',
        detail       => '',
        used_map     => 1,
        user_id      => 1,
        name         => '',
        state        => 'confirmed',
        service      => '',
        cobrand      => 'default',
        cobrand_data => '',
        user         => $user,
        created      => DateTime->now()->subtract( days => 1 ),
        lastupdate   => DateTime->now()->subtract( days => 1 ),
        anonymous    => 1,
        external_id  => int(rand(time())),
        bodies_str   => $bodies{2482}->id,
    }
);

$problem->insert;

for my $test (
    {
        desc => 'OPEN status for confirmed problem does not change state',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'OPEN',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'confirmed',
        end_state => 'confirmed',
    },
    {
        desc => 'bad state does not update states but does create update',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'INVALID_STATE',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => undef,
        end_state => 'confirmed',
    },

    # NB because we have an auto-response ResponseTemplate set up for
    # the 'investigating' state, this test is also testing that the
    # response template isn't used if the update XML has a non-empty
    # <description>.
    {
        desc => 'investigating status changes problem status',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'INVESTIGATING',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'investigating',
        end_state => 'investigating',
    },
    {
        desc => 'in progress status changes problem status',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'IN_PROGRESS',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'in progress',
        end_state => 'in progress',
    },
    {
        desc => 'action scheduled status changes problem status',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'ACTION_SCHEDULED',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'action scheduled',
        end_state => 'action scheduled',
    },
    {
        desc => 'not responsible status changes problem status',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'NOT_COUNCILS_RESPONSIBILITY',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'not responsible',
        end_state => 'not responsible',
    },
    {
        desc => 'internal referral status changes problem status',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'INTERNAL_REFERRAL',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'internal referral',
        end_state => 'internal referral',
    },
    {
        desc => 'duplicate status changes problem status',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'DUPLICATE',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'duplicate',
        end_state => 'duplicate',
    },
    {
        desc => 'fixed status marks report as fixed - council',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'FIXED',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'fixed - council',
        end_state => 'fixed - council',
    },
    {
        desc => 'status of CLOSED marks report as fixed - council',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'CLOSED',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'fixed - council',
        end_state => 'fixed - council',
    },
    {
        desc => 'status of CLOSED marks report as closed when using extended statuses',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'CLOSED',
        mark_fixed=> 0,
        mark_open => 0,
        problem_state => 'closed',
        end_state => 'closed',
        extended_statuses => 1,
    },
    {
        desc => 'status of OPEN re-opens fixed report',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'fixed - user',
        comment_status => 'OPEN',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'confirmed',
        end_state => 'confirmed',
    },
    {
        desc => 'action sheduled re-opens fixed report as action scheduled',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'fixed - user',
        comment_status => 'ACTION_SCHEDULED',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'action scheduled',
        end_state => 'action scheduled',
    },
    {
        desc => 'open status re-opens closed report',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'not responsible',
        comment_status => 'OPEN',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'confirmed',
        end_state => 'confirmed',
    },
    {
        desc => 'open status removes action scheduled status',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'action scheduled',
        comment_status => 'OPEN',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'confirmed',
        end_state => 'confirmed',
    },
    {
        desc => 'fixed status leaves fixed - user report as fixed - user',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'fixed - user',
        comment_status => 'FIXED',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => undef,
        end_state => 'fixed - user',
    },
    {
        desc => 'closed status updates fixed report',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'fixed - user',
        comment_status => 'NO_FURTHER_ACTION',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'unable to fix',
        end_state => 'unable to fix',
    },
    {
        desc => 'no futher action status closes report',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'confirmed',
        comment_status => 'NO_FURTHER_ACTION',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'unable to fix',
        end_state => 'unable to fix',
    },
    {
        desc => 'fixed status sets closed report as fixed',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'unable to fix',
        comment_status => 'FIXED',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'fixed - council',
        end_state => 'fixed - council',
    },
    {
        desc => 'empty description triggers auto-response template',
        description => 'We are investigating this report.',
        xml_description => '',
        external_id => 638344,
        start_state => 'fixed - council',
        comment_status => 'INVESTIGATING',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'investigating',
        end_state => 'investigating',
    },
    {
        desc => 'change in fixed state does not trigger auto-response template',
        description => '',
        xml_description => '',
        external_id => 638344,
        start_state => 'fixed - user',
        comment_status => 'FIXED',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => undef,
        end_state => 'fixed - user',
        comment_state => 'hidden',
    },
    {
        desc => 'unchanging state does not trigger auto-response template',
        description => '',
        xml_description => '',
        external_id => 638344,
        start_state => 'investigating',
        comment_status => 'INVESTIGATING',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'investigating',
        end_state => 'investigating',
        comment_state => 'hidden',
    },
    {
        desc => 'open status does not re-open hidden report',
        description => 'This is a note',
        external_id => 638344,
        start_state => 'hidden',
        comment_status => 'OPEN',
        mark_fixed => 0,
        mark_open => 0,
        problem_state => 'confirmed',
        end_state => 'hidden',
    },
) {
    subtest $test->{desc} => sub {
        my $local_requests_xml = setup_xml($problem->external_id, $problem->id, $test->{comment_status}, $test->{xml_description});
        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', extended_statuses => $test->{extended_statuses}, test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

        $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
        $problem->state( $test->{start_state} );
        $problem->update;

        my $update = Open311::GetServiceRequestUpdates->new;
        $update->fetch($o);

        is $problem->comments->count, 1, 'comment count';
        $problem->discard_changes;

        my $c = FixMyStreet::DB->resultset('Comment')->search( { external_id => $test->{external_id} } )->first;
        ok $c, 'comment exists';
        is $c->text, $test->{description}, 'text correct';
        is $c->mark_fixed, $test->{mark_fixed}, 'mark_closed correct';
        is $c->problem_state, $test->{problem_state}, 'problem_state correct';
        is $c->mark_open, $test->{mark_open}, 'mark_open correct';
        is $c->state, $test->{comment_state} || 'confirmed', 'comment state correct';
        is $problem->state, $test->{end_state}, 'correct problem state';
        $problem->comments->delete;
    };
}

my $problemOx = $problem_rs->create({
    postcode     => 'EH99 1SP',
    latitude     => 1,
    longitude    => 1,
    areas        => 1,
    title        => '',
    detail       => '',
    used_map     => 1,
    user_id      => 1,
    name         => '',
    state        => 'confirmed',
    service      => '',
    cobrand      => 'default',
    cobrand_data => '',
    user         => $user,
    created      => DateTime->now()->subtract( days => 1 ),
    lastupdate   => DateTime->now()->subtract( days => 1 ),
    anonymous    => 1,
    external_id  => int(rand(time())),
    bodies_str   => $bodies{2237}->id,
});

for my $test (
    {
        desc => 'OPEN status for confirmed problem does not change state (Oxfordshire)',
        start_state => 'confirmed',
        comment_status => 'OPEN',
        problem_state => undef,
        end_state => 'confirmed',
    },
    {
        desc => 'OPEN status for action scheduled problem does not change state (Oxfordshire)',
        start_state => 'action scheduled',
        comment_status => 'OPEN',
        problem_state => undef,
        end_state => 'action scheduled',
    },
) {
    subtest $test->{desc} => sub {
        my $local_requests_xml = setup_xml($problemOx->external_id, $problemOx->id, $test->{comment_status});
        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

        $problemOx->lastupdate( DateTime->now()->subtract( days => 1 ) );
        $problemOx->state( $test->{start_state} );
        $problemOx->update;

        my $update = Open311::GetServiceRequestUpdates->new( system_user => $user );
        $update->update_comments( $o, $bodies{2237} );

        is $problemOx->comments->count, 1, 'comment count';
        $problemOx->discard_changes;

        my $c = FixMyStreet::DB->resultset('Comment')->search( { external_id => 638344 } )->first;
        ok $c, 'comment exists';
        is $c->problem_state, $test->{problem_state}, 'problem_state correct';
        is $problemOx->state, $test->{end_state}, 'correct problem state';
        $problemOx->comments->delete;
    };
}

subtest 'Update with media_url includes image in update' => sub {
    my $guard = LWP::Protocol::PSGI->register(t::Mock::Static->to_psgi_app, host => 'example.com');

    my $local_requests_xml = setup_xml($problem->external_id, 1, "");
    $local_requests_xml =~ s#</service_request_id>#</service_request_id>
        <media_url>http://example.com/image.jpeg</media_url>#;
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

    $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
    $problem->state('confirmed');
    $problem->update;

    my $update = Open311::GetServiceRequestUpdates->new( system_user => $user );
    $update->update_comments( $o, $bodies{2482} );

    is $problem->comments->count, 1, 'comment count';
    my $c = $problem->comments->first;
    is $c->external_id, 638344;
    is $c->photo, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg', 'photo exists';
    $problem->comments->delete;
};

subtest 'Update with customer_reference adds reference to problem' => sub {
    my $guard = LWP::Protocol::PSGI->register(t::Mock::Static->to_psgi_app, host => 'example.com');

    my $local_requests_xml = setup_xml($problem->external_id, 1, "");
    $local_requests_xml =~ s#</service_request_id>#</service_request_id>
        <customer_reference>REFERENCE</customer_reference>#;
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

    $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
    $problem->state('confirmed');
    $problem->update;

    my $update = Open311::GetServiceRequestUpdates->new( system_user => $user );
    $update->update_comments( $o, $bodies{2482} );

    $problem->discard_changes;
    is $problem->comments->count, 1, 'comment count';
    my $c = $problem->comments->first;
    is $c->external_id, 638344;
    is $problem->get_extra_metadata('customer_reference'), 'REFERENCE';
    $problem->comments->delete;
};

subtest 'date for comment correct' => sub {
    my $local_requests_xml = setup_xml($problem->external_id, $problem->id, "");
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

    my $update = Open311::GetServiceRequestUpdates->new( system_user => $user );
    FixMyStreet::override_config {
        TIME_ZONE => 'Australia/Sydney',
    }, sub {
        $update->update_comments( $o, $bodies{2482} );
    };

    my $comment = $problem->comments->first;
    is $comment->created, $dt, 'created date set to date from XML';
    is $comment->confirmed, $dt, 'confirmed date set to date from XML';
    $problem->comments->delete;
};

my $problem2 = $problem_rs->create(
    {
        postcode     => 'EH99 1SP',
        latitude     => 1,
        longitude    => 1,
        areas        => 1,
        title        => '',
        detail       => '',
        used_map     => 1,
        user_id      => 1,
        name         => '',
        state        => 'confirmed',
        service      => '',
        cobrand      => 'default',
        cobrand_data => '',
        user         => $user,
        created      => DateTime->now(),
        lastupdate   => DateTime->now(),
        anonymous    => 1,
        external_id  => $problem->external_id,
        bodies_str   => $bodies{2651}->id,
    }
);

for my $test (
    {
        desc => 'identical external_ids on problem resolved using council',
        external_id => 638344,
        area_id => 2651,
        request_id => $problem2->external_id,
        request_id_ext => $problem2->id,
        p1_comments => 0,
        p2_comments => 1,
    },
    {
        desc => 'identical external_ids on comments resolved',
        external_id => 638344,
        area_id => 2482,
        request_id => $problem->external_id,
        request_id_ext => $problem->id,
        p1_comments => 1,
        p2_comments => 1,
    },
) {
    subtest $test->{desc} => sub {
        my $local_requests_xml = setup_xml($test->{request_id}, $test->{request_id_ext}, "");
        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

        my $update = Open311::GetServiceRequestUpdates->new( system_user => $user );
        $update->update_comments( $o, $bodies{$test->{area_id}} );

        is $problem->comments->count, $test->{p1_comments}, 'comment count for first problem';
        is $problem2->comments->count, $test->{p2_comments}, 'comment count for second problem';
    };
}

subtest 'using start and end date' => sub {
    my $local_requests_xml = $requests_xml;
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $local_requests_xml } );

    my $start_dt = DateTime->now();
    $start_dt->subtract( days => 1 );
    my $end_dt = DateTime->now();

    my $update = Open311::GetServiceRequestUpdates->new( 
        system_user => $user,
        start_date => $start_dt,
    );

    my $res = $update->update_comments( $o );
    is $res, 0, 'returns 0 if start but no end date';

    $update = Open311::GetServiceRequestUpdates->new( 
        system_user => $user,
        end_date => $end_dt,
    );

    $res = $update->update_comments( $o );
    is $res, 0, 'returns 0 if end but no start date';

    $update = Open311::GetServiceRequestUpdates->new( 
        system_user => $user,
        start_date => $start_dt,
        end_date => $end_dt,
    );

    $update->update_comments( $o, $bodies{2482} );

    my $start = $start_dt . '';
    my $end = $end_dt . '';

    my $uri = URI->new( $o->test_uri_used );
    my $c = CGI::Simple->new( $uri->query );

    is $c->param('start_date'), $start, 'start date used';
    is $c->param('end_date'), $end, 'end date used';
};

subtest 'check that existing comments are not duplicated' => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>open</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    <request_update>
    <update_id>638354</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>open</status>
    <description>This is a different note</description>
    <updated_datetime>UPDATED_DATETIME2</updated_datetime>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    my $comment = FixMyStreet::DB->resultset('Comment')->new(
        {
            problem => $problem,
            external_id => 638344,
            text => 'This is a note',
            user => $user,
            state => 'confirmed',
            mark_fixed => 0,
            anonymous => 0,
            confirmed => $dt,
        }
    );
    $comment->insert;

    is $problem->comments->count, 1, 'one comment before fetching updates';

    $requests_xml =~ s/UPDATED_DATETIME2/$dt/;
    my $confirmed = DateTime::Format::W3CDTF->format_datetime($comment->confirmed);
    $requests_xml =~ s/UPDATED_DATETIME/$confirmed/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
    );

    $update->update_comments( $o, $bodies{2482} );

    $problem->discard_changes;
    is $problem->comments->count, 2, 'two comments after fetching updates';

    $update->update_comments( $o, $bodies{2482} );
    $problem->discard_changes;
    is $problem->comments->count, 2, 're-fetching updates does not add comments';

    $problem->comments->delete;
    $update->update_comments( $o, $bodies{2482} );
    $problem->discard_changes;
    is $problem->comments->count, 2, 'if comments are deleted then they are added';
};

subtest 'check that can limit fetching to a body' => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>open</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    is $problem->comments->count, 0, 'one comment before fetching updates';

    $requests_xml =~ s/UPDATED_DATETIME/$dt/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

    my $update = Open311::GetServiceRequestUpdates->new(
        body => 'Oxfordshire',
        system_user => $user,
    );

    $update->fetch( $o );

    $problem->discard_changes;
    is $problem->comments->count, 0, 'no comments after fetching updates';

    $update = Open311::GetServiceRequestUpdates->new(
        body => 'Bromley',
        system_user => $user,
    );

    $update->fetch( $o );

    $problem->discard_changes;
    is $problem->comments->count, 1, '1 comment after fetching updates';
};

subtest 'check that external_status_code is stored correctly' => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>open</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    <external_status_code>060</external_status_code>
    </request_update>
    <request_update>
    <update_id>638354</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>open</status>
    <description>This is a different note</description>
    <updated_datetime>UPDATED_DATETIME2</updated_datetime>
    <external_status_code>101</external_status_code>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    my $dt2 = $dt->clone->subtract( hours => 1 );
    $requests_xml =~ s/UPDATED_DATETIME2/$dt/;
    $requests_xml =~ s/UPDATED_DATETIME/$dt2/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
    );

    $update->update_comments( $o, $bodies{2482} );

    $problem->discard_changes;
    is $problem->comments->count, 2, 'two comments after fetching updates';

    my @comments = $problem->comments->search(undef, { order_by => [ 'created' ] } )->all;

    is $comments[0]->get_extra_metadata('external_status_code'), "060", "correct external status code on first comment";
    is $comments[1]->get_extra_metadata('external_status_code'), "101", "correct external status code on second comment";

    is $problem->get_extra_metadata('external_status_code'), "101", "correct external status code";

};

subtest 'check that external_status_code triggers auto-responses' => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>open</status>
    <description></description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    <external_status_code>060</external_status_code>
    </request_update>
    </service_requests_updates>
    };

    my $response_template = $bodies{2482}->response_templates->create({
        title => "Acknowledgement",
        text => "Thank you for your report. We will provide an update within 24 hours.",
        auto_response => 1,
        external_status_code => "060"
    });

    $problem->comments->delete;

    $requests_xml =~ s/UPDATED_DATETIME/$dt/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
    );

    $update->update_comments( $o, $bodies{2482} );

    $problem->discard_changes;
    is $problem->comments->count, 1, 'one comment after fetching updates';

    my $comment = $problem->comments->first;

    is $problem->comments->first->text, "Thank you for your report. We will provide an update within 24 hours.", "correct external status code on first comment";
};

foreach my $test ( {
        desc => 'check that closed and then open comment results in correct state',
        dt1  => $dt->clone->subtract( hours => 1 ),
        dt2  => $dt,
    },
    {
        desc => 'check that old comments do not change problem status',
        dt1  => $dt->clone->subtract( minutes => 90 ),
        dt2  => $dt,
    }
) {
    subtest $test->{desc}  => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
        <service_requests_updates>
        <request_update>
        <update_id>638344</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>closed</status>
        <description>This is a note</description>
        <updated_datetime>UPDATED_DATETIME</updated_datetime>
        </request_update>
        <request_update>
        <update_id>638354</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>open</status>
        <description>This is a different note</description>
        <updated_datetime>UPDATED_DATETIME2</updated_datetime>
        </request_update>
        </service_requests_updates>
        };

        $problem->state( 'confirmed' );
        $problem->lastupdate( $dt->clone->subtract( hours => 3 ) );
        $problem->update;

        $requests_xml =~ s/UPDATED_DATETIME/$test->{dt1}/;
        $requests_xml =~ s/UPDATED_DATETIME2/$test->{dt2}/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
        );

        $update->update_comments( $o, $bodies{2482} );

        $problem->discard_changes;
        is $problem->comments->count, 2, 'two comments after fetching updates';
        is $problem->state, 'confirmed', 'correct problem status';
        $problem->comments->delete;
    };
}

foreach my $test ( {
        desc => 'normally alerts are not suppressed',
        num_alerts => 1,
        suppress_alerts => 0,
    },
    {
        desc => 'alerts suppressed if suppress_alerts set',
        num_alerts => 1,
        suppress_alerts => 1,
    },
    {
        desc => 'alert suppression ok even if no alerts',
        num_alerts => 0,
        suppress_alerts => 1,
    },
    {
        desc => 'alert suppression ok even if 2x alerts',
        num_alerts => 2,
        suppress_alerts => 1,
    }
) {
    subtest $test->{desc}  => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
        <service_requests_updates>
        <request_update>
        <update_id>638344</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>closed</status>
        <description>This is a note</description>
        <updated_datetime>UPDATED_DATETIME</updated_datetime>
        </request_update>
        </service_requests_updates>
        };

        $problem->state( 'confirmed' );
        $problem->lastupdate( $dt->clone->subtract( hours => 3 ) );
        $problem->update;

        my @alerts = map {
            my $alert = FixMyStreet::DB->resultset('Alert')->create( {
                alert_type => 'new_updates',
                parameter  => $problem->id,
                confirmed  => 1,
                user_id    => $problem->user->id,
            } )
        } (1..$test->{num_alerts});

        $requests_xml =~ s/UPDATED_DATETIME/$dt/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            suppress_alerts => $test->{suppress_alerts},
        );

        $update->update_comments( $o, $bodies{2482} );
        $problem->discard_changes;

        my $alerts_sent = FixMyStreet::DB->resultset('AlertSent')->search(
            {
                alert_id => [ map $_->id, @alerts ],
                parameter => $problem->comments->first->id,
            }
        );

        if ( $test->{suppress_alerts} ) {
            is $alerts_sent->count(), $test->{num_alerts}, 'alerts suppressed';
        } else {
            is $alerts_sent->count(), 0, 'alerts not suppressed';
        }

        $alerts_sent->delete;
        for my $alert (@alerts) {
            $alert->delete;
        }
        $problem->comments->delete;
    }
}

$response_template_fixed->delete;
foreach my $test ( {
        desc => 'normally blank text produces a warning',
        num_alerts => 1,
        blank_updates_permitted => 0,
    },
    {
        desc => 'no warning if blank updates permitted',
        num_alerts => 1,
        blank_updates_permitted => 1,
    },
) {
    subtest $test->{desc}  => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
        <service_requests_updates>
        <request_update>
        <update_id>638344</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>closed</status>
        <description></description>
        <updated_datetime>UPDATED_DATETIME</updated_datetime>
        </request_update>
        </service_requests_updates>
        };

        $problem->state( 'confirmed' );
        $problem->lastupdate( $dt->clone->subtract( hours => 3 ) );
        $problem->update;

        $requests_xml =~ s/UPDATED_DATETIME/$dt/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            blank_updates_permitted => $test->{blank_updates_permitted},
        );

        if ( $test->{blank_updates_permitted} ) {
            stderr_is { $update->update_comments( $o, $bodies{2482} ) } '', 'No error message'
        } else {
            stderr_like { $update->update_comments( $o, $bodies{2482} ) } qr/Couldn't determine update text for/, 'Error message displayed'
        }
        $problem->discard_changes;
        $problem->comments->delete;
    }
}

subtest 'check matching on fixmystreet_id overrides service_request_id' => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>8888888888888</service_request_id>
    <fixmystreet_id>@{[ $problem->id ]}</fixmystreet_id>
    <status>open</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    <request_update>
    <update_id>638354</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <fixmystreet_id>999999999</fixmystreet_id>
    <status>open</status>
    <description>This is a different note</description>
    <updated_datetime>UPDATED_DATETIME2</updated_datetime>
    </request_update>
    <request_update>
    <update_id>638356</update_id>
    <service_request_id></service_request_id>
    <fixmystreet_id>@{[ $problem->id ]}</fixmystreet_id>
    <status>investigating</status>
    <description>This is a last note</description>
    <updated_datetime>UPDATED_DATETIME3</updated_datetime>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    my $dt2 = $dt->clone->subtract( minutes => 30 );
    my $dt3 = $dt2->clone->subtract( minutes => 30 );
    $requests_xml =~ s/UPDATED_DATETIME3/$dt/;
    $requests_xml =~ s/UPDATED_DATETIME2/$dt2/;
    $requests_xml =~ s/UPDATED_DATETIME/$dt3/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
    );

    $update->update_comments( $o, $bodies{2482} );

    $problem->discard_changes;
    is $problem->comments->count, 2, 'two comments after fetching updates';

    my @comments = $problem->comments->search(undef, { order_by => [ 'created' ] } )->all;

    is $comments[0]->external_id, 638344, "correct first comment added";
    is $comments[1]->external_id, 638356, "correct second comment added";
};

subtest 'check bad fixmystreet_id is handled' => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>8888888888888</service_request_id>
    <fixmystreet_id>123456 654321</fixmystreet_id>
    <status>open</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    $requests_xml =~ s/UPDATED_DATETIME/$dt/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'servicerequestupdates.xml' => $requests_xml } );

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
    );

    warning_like {
        $update->update_comments( $o, $bodies{2482} )
    }
    qr/skipping bad fixmystreet id in updates for Bromley: \[123456 654321\], external id is 8888888888888/,
    "warning emitted for bad fixmystreet id";

    $problem->discard_changes;
    is $problem->comments->count, 0, 'no comments after fetching updates';
};
done_testing();

sub setup_xml {
    my ($id, $id_ext, $status, $description) = @_;
    my $xml = $requests_xml;
    my $updated_datetime = sprintf( '<updated_datetime>%s</updated_datetime>', $dt );
    $xml =~ s/UPDATED_DATETIME/$updated_datetime/;
    $xml =~ s#<service_request_id>\d+</service_request_id>#<service_request_id>$id</service_request_id>#;
    $xml =~ s#<service_request_id_ext>\d+</service_request_id_ext>#<service_request_id_ext>$id_ext</service_request_id_ext>#;
    $xml =~ s#<status>\w+</status>#<status>$status</status># if $status;
    $xml =~ s#<description>.+</description>#<description>$description</description># if defined $description;
    return $xml;


}
