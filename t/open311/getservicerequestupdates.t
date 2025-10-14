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
use File::Temp 'tempdir';
use FixMyStreet::DB;

my $user = FixMyStreet::DB->resultset('User')->find_or_create(
    {
        email => 'system_user@example.com'
    }
);

my %bodies = (
    2237 => FixMyStreet::DB->resultset("Body")->create({ name => 'Oxfordshire', cobrand => 'oxfordshire' }),
    2494 => FixMyStreet::DB->resultset("Body")->create({ name => 'Bexley', cobrand => 'bexley' }),
    2636 => FixMyStreet::DB->resultset("Body")->create({ name => 'Isle of Wight', cobrand => 'isleofwight' }),
    2482 => FixMyStreet::DB->resultset("Body")->create({
        name => 'Bromley',
        send_method => 'Open311',
        send_comments => 1,
        endpoint => 'endpoint',
        comment_user_id => $user->id,
        blank_updates_permitted => 1,
        cobrand => 'bromley',
    }),
    2648 => FixMyStreet::DB->resultset("Body")->create({
        name => 'Aberdeenshire',
        send_method => 'Open311',
        endpoint => 'endpoint',
        comment_user_id => $user->id,
        cobrand => 'aberdeenshire',
    }),
    2651 => FixMyStreet::DB->resultset("Body")->create({ name => 'Edinburgh' }),
);
$bodies{2237}->body_areas->create({ area_id => 2237 });
$bodies{2494}->body_areas->create({ area_id => 2494 });
$bodies{2636}->body_areas->create({ area_id => 2636 });

my $contact = FixMyStreet::DB->resultset('Contact')->find_or_create({
    state => 'confirmed',
    editor => 'Test',
    whenedited => \'current_timestamp',
    note => 'Created for test',
    body_id => $bodies{2482}->id,
    category => 'Potholes',
    email => 'potholes@example.com',
});

my $response_template = $bodies{2482}->response_templates->create({
    title => "investigating template",
    text => "We are investigating this report.",
    email_text => "Thank you - we're looking into this now",
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

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
        Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

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

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
    Open311->_inject_response('/servicerequestupdates.xml', $extended_requests_xml);

    my $res = $o->get_service_request_updates;
    is_deeply $res->[0], $expected_res, 'result looks correct';

};

my $problem_rs = FixMyStreet::DB->resultset('Problem');

sub create_problem {
    my ($body_id, $external_id) = @_;
    my $problem = $problem_rs->create({
        postcode     => 'EH99 1SP',
        latitude     => 1,
        longitude    => 1,
        areas        => 1,
        title        => '',
        detail       => '',
        used_map     => 1,
        user_id      => 1,
        name         => 'Test User',
        state        => 'confirmed',
        service      => '',
        cobrand      => 'default',
        cobrand_data => '',
        user         => $user,
        created      => DateTime->now()->subtract( days => 1 ),
        lastupdate   => DateTime->now()->subtract( days => 1 ),
        anonymous    => 1,
        external_id  => $external_id || int(rand(time())),
        bodies_str   => $body_id,
    });
    return $problem;
}

my $problem = create_problem($bodies{2482}->id);

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
        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', extended_statuses => $test->{extended_statuses} );
        Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

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
        is $c->send_state, 'processed', 'marked as processed so not resent';
        is $problem->state, $test->{end_state}, 'correct problem state';
        $problem->comments->delete;
    };
}

my $response_template_vars = $bodies{2482}->response_templates->create({
    title => "a placeholder action scheduled template",
    text => "We are investigating this report: {{description}}",
    auto_response => 1,
    state => "action scheduled"
});
subtest 'Check template placeholders' => sub {
    my $local_requests_xml = setup_xml($problem->external_id, $problem->id, 'ACTION_SCHEDULED', 'We will do this in the morning.');
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', extended_statuses => undef );
    Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

    $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
    $problem->state( 'fixed - council' );
    $problem->update;

    my $update = Open311::GetServiceRequestUpdates->new;
    $update->fetch($o);

    is $problem->comments->count, 1, 'comment count';
    $problem->discard_changes;

    my $c = FixMyStreet::DB->resultset('Comment')->search( { external_id => 638344 } )->first;
    ok $c, 'comment exists';
    is $c->text, "We are investigating this report: We will do this in the morning.", 'text correct';
    is $c->mark_fixed, 0, 'mark_closed correct';
    is $c->problem_state, 'action scheduled', 'problem_state correct';
    is $c->mark_open, 0, 'mark_open correct';
    is $c->state, 'confirmed', 'comment state correct';
    is $problem->state, 'action scheduled', 'correct problem state';
    $problem->comments->delete;
};

subtest 'Check Aberdeenshire template interpolation' => sub {
    my $tpl = $bodies{2648}->response_templates->create({
        title => "a placeholder in progress template",
        text => "Target date: {{targetDate}}\nCategory: {{featureCCAT}}\nSpeed limit: {{featureSPD}}",
        auto_response => 1,
        state => "in progress"
    });

    my $aber_problem = create_problem($bodies{2648}->id);
    my $local_requests_xml = setup_xml($aber_problem->external_id, $aber_problem->id, 'IN_PROGRESS', '',
        '<targetDate>2025-12-31T10:30:00</targetDate><featureCCAT>3A</featureCCAT><featureSPD>60mph</featureSPD>');

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

    $aber_problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
    $aber_problem->state( 'confirmed' );
    $aber_problem->update;

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2648},
    );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'aberdeenshire',
    }, sub {
        $update->process_body;
    };

    $aber_problem->discard_changes;
    is $aber_problem->comments->count, 1, 'comment count';

    my $c = $aber_problem->comments->first;
    ok $c, 'comment exists';
    is $c->text, "Target date: 31/12/2025\nCategory: 3A\nSpeed limit: 60mph", 'template correctly interpolated';
    $aber_problem->comments->delete;
    $aber_problem->delete;
    $tpl->delete;
};

my $problemB = create_problem($bodies{2237}->id);

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
        my $local_requests_xml = setup_xml($problemB->external_id, $problemB->id, $test->{comment_status});
        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

        $problemB->lastupdate( DateTime->now()->subtract( days => 1 ) );
        $problemB->state( $test->{start_state} );
        $problemB->update;

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{2237},
        );
        $update->process_body;


        is $problemB->comments->count, 1, 'comment count';
        $problemB->discard_changes;

        my $c = FixMyStreet::DB->resultset('Comment')->search( { external_id => 638344 } )->first;
        ok $c, 'comment exists';
        is $c->problem_state, $test->{problem_state}, 'problem_state correct';
        is $problemB->state, $test->{end_state}, 'correct problem state';
        $problemB->comments->delete;
    };
}

for (
    { id => 2494, cobrand => 'bexley' },
    { id => 2636, cobrand => 'isleofwight' }
) {
    subtest "Marking report as fixed closes it for updates ($_->{cobrand})" => sub {
        my $local_requests_xml = setup_xml($problemB->external_id, $problemB->id, 'CLOSED');
        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

        $problemB->update( { bodies_str => $bodies{$_->{id}}->id } );

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{$_->{id}},
        );
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => $_->{cobrand},
        }, sub {
            $update->process_body;
        };

        $problemB->discard_changes;
        is $problemB->comments->count, 1, 'comment count';
        is $problemB->get_extra_metadata('closed_updates'), 1;
        $problemB->comments->delete;
    };
}

subtest 'Update with media_url includes image in update' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
  FixMyStreet::override_config {
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
  }, sub {
    my $guard = LWP::Protocol::PSGI->register(t::Mock::Static->to_psgi_app, host => 'example.com');

    my $local_requests_xml = setup_xml($problem->external_id, 1, "");
    $local_requests_xml =~ s#</service_request_id>#</service_request_id>
        <media_url>http://example.com/image.jpeg</media_url>#;
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

    $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
    $problem->state('confirmed');
    $problem->update;

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );
    $update->process_body;

    is $problem->comments->count, 1, 'comment count';
    my $c = $problem->comments->first;
    is $c->external_id, 638344;
    is $c->photo, '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg', 'photo exists';
    $problem->comments->delete;
  };
};

subtest 'Other image type media_url' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
  FixMyStreet::override_config {
    PHOTO_STORAGE_BACKEND => 'FileSystem',
    PHOTO_STORAGE_OPTIONS => {
        UPLOAD_DIR => $UPLOAD_DIR,
    },
  }, sub {
    my $guard = LWP::Protocol::PSGI->register(t::Mock::Static->to_psgi_app, host => 'example.com');

    my $local_requests_xml = setup_xml($problem->external_id, 1, "");
    $local_requests_xml =~ s#</service_request_id>#</service_request_id>
        <media_url>http://example.com/image.gif</media_url>#;
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

    $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
    $problem->state('confirmed');
    $problem->update;

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );
    $update->process_body;

    is $problem->comments->count, 1, 'comment count';
    my $c = $problem->comments->first;
    is $c->external_id, 638344;
    is $c->photo, 'b3aac4d2d68ac3486e9ecb99cd5f5c6c7be18335.gif', 'photo exists';
    $problem->comments->delete;
  };
};

subtest 'Update with customer_reference adds reference to problem' => sub {
    my $guard = LWP::Protocol::PSGI->register(t::Mock::Static->to_psgi_app, host => 'example.com');

    my $local_requests_xml = setup_xml($problem->external_id, 1, "");
    $local_requests_xml =~ s#</service_request_id>#</service_request_id>
        <customer_reference>REFERENCE</customer_reference>#;
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

    $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
    $problem->state('confirmed');
    $problem->update;

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );
    $update->process_body;

    $problem->discard_changes;
    is $problem->comments->count, 1, 'comment count';
    my $c = $problem->comments->first;
    is $c->external_id, 638344;
    is $problem->get_extra_metadata('customer_reference'), 'REFERENCE';
    $problem->comments->delete;
};

subtest 'date for comment correct' => sub {
    my $local_requests_xml = setup_xml($problem->external_id, $problem->id, "");
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );
    FixMyStreet::override_config {
        TIME_ZONE => 'Australia/Sydney',
    }, sub {
        $update->process_body;
    };

    my $comment = $problem->comments->first;
    is $comment->created, $dt, 'created date set to date from XML';
    is $comment->confirmed, $dt, 'confirmed date set to date from XML';
    $problem->comments->delete;
};

my $problem2 = create_problem($bodies{2651}->id, $problem->external_id);

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
        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{$test->{area_id}},
        );
        $update->process_body;

        is $problem->comments->count, $test->{p1_comments}, 'comment count for first problem';
        is $problem2->comments->count, $test->{p2_comments}, 'comment count for second problem';
    };
}

subtest 'using start and end date' => sub {
    my $local_requests_xml = $requests_xml;
    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $local_requests_xml);

    my $start_dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new);
    my $end_dt = $start_dt->clone;
    $start_dt->subtract( days => 1 );

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        start_date => $start_dt,
        end_date => $end_dt,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    $update->process_body;

    my $start = $start_dt . '';
    my $end = $end_dt . '';

    my $uri = $o->test_req_used->uri;
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

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);
    $update->process_body;

    $problem->discard_changes;
    is $problem->comments->count, 2, 'two comments after fetching updates';

    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);
    $update->process_body;
    $problem->discard_changes;
    is $problem->comments->count, 2, 're-fetching updates does not add comments';

    $problem->comments->delete;
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);
    $update->process_body;
    $problem->discard_changes;
    is $problem->comments->count, 2, 'if comments are deleted then they are added';
};

subtest "hides duplicate updates from endpoint" => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>UPDATE_1</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>IN_PROGRESS</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };
    my $requests_xml2 = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>UPDATE_2</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>IN_PROGRESS</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    my $update_dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new);

    $requests_xml =~ s/UPDATED_DATETIME/$update_dt/g;
    $requests_xml2 =~ s/UPDATED_DATETIME/$update_dt/g;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);
    $update->process_body;
    $problem->discard_changes;
    is $problem->comments->count, 1;
    is $problem->comments->search({ state => 'confirmed' })->count, 1;

    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml2);
    $update->process_body;
    $problem->discard_changes;
    is $problem->comments->count, 2;
    is $problem->comments->search({ state => 'confirmed' })->count, 1;

};

subtest "hides duplicate updates with photo from endpoint" => sub {
    my $guard = LWP::Protocol::PSGI->register(t::Mock::Static->to_psgi_app, host => 'example.com');

    my $update_dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new);
    my $template = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>UPDATE_{n}</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>FIXED</status>
    <description>This is a note</description>
    <updated_datetime>$update_dt</updated_datetime>
    <media_url>http://example.com/image.jpeg</media_url>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    (my $requests_xml = $template) =~ s/{n}/1/;
    (my $requests_xml2 = $template) =~ s/{n}/2/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);
    $update->process_body;
    $problem->discard_changes;
    is $problem->comments->count, 1;
    is $problem->comments->search({ state => 'confirmed' })->count, 1;
    is $problem->comments->search({ state => 'confirmed' })->first->photo,
        '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';

    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml2);
    $update->process_body;
    $problem->discard_changes;
    is $problem->comments->count, 2;
    is $problem->comments->search({ state => 'confirmed' })->count, 1;
    is $problem->comments->search({ state => 'confirmed' })->first->photo,
        '74e3362283b6ef0c48686fb0e161da4043bbcc97.jpeg';

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

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        bodies => ['Oxfordshire'],
        system_user => $user,
    );

    $update->fetch( $o );

    $problem->discard_changes;
    is $problem->comments->count, 0, 'no comments after fetching updates';

    $update = Open311::GetServiceRequestUpdates->new(
        bodies => ['Bromley'],
        system_user => $user,
    );

    $update->fetch( $o );

    $problem->discard_changes;
    is $problem->comments->count, 1, '1 comment after fetching updates';
};

subtest 'check that can exclude fetching from a body' => sub {
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

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        bodies_exclude => ['Bromley'],
        system_user => $user,
    );

    $update->fetch( $o );

    $problem->discard_changes;
    is $problem->comments->count, 0, 'no comments after fetching updates';

    $update = Open311::GetServiceRequestUpdates->new(
        bodies_exclude => ['Oxfordshire'],
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

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    $update->process_body;

    $problem->discard_changes;
    is $problem->comments->count, 2, 'two comments after fetching updates';

    my @comments = $problem->comments->order_by('created')->all;

    is $comments[0]->get_extra_metadata('external_status_code'), "060", "correct external status code on first comment";
    is $comments[1]->get_extra_metadata('external_status_code'), "101", "correct external status code on second comment";

    is $problem->get_extra_metadata('external_status_code'), "101", "correct external status code";

    $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638364</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>open</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    <external_status_code></external_status_code>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    my $dt3 = $dt->clone->add( minutes => 1 );
    $requests_xml =~ s/UPDATED_DATETIME/$dt3/;

    $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    $update->process_body;

    $problem->discard_changes;
    is $problem->get_extra_metadata('external_status_code'), '', "external status code unset";
};

for my $test (
        {
            template_options => {
                title => "Acknowledgement",
                text => "Thank you for your report. We will provide an update within 24 hours.",
                email_text => "Thank you for your report. This is the email text template text.",
                auto_response => 1,
                state => '',
                external_status_code => "060"
            },
            result => "Thank you for your report. This is the email text template text.",
            test_comment => 'Template email_text attached to comment'
        },
        {
            template_options => {
                title => "Acknowledgement",
                text => "Thank you for your report. We will provide an update within 24 hours.",
                auto_response => 1,
                state => '',
                external_status_code => "060"
            },
            result => undef,
            test_comment => 'No template email_text attached to comment'
        },
) {
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

        my $response_template = $bodies{2482}->response_templates->create($test->{ template_options });
        $problem->comments->delete;
        $problem->set_extra_metadata('external_status_code', '');
        $problem->update;

        $requests_xml =~ s/UPDATED_DATETIME/$dt/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{2482},
        );

        $update->process_body;

        $problem->discard_changes;

        is $problem->comments->count, 1, 'one comment after fetching updates';

        is $problem->comments->first->text, "Thank you for your report. We will provide an update within 24 hours.", "correct external status code on first comment";
        is $problem->comments->first->private_email_text, $test->{ result }, $test->{ test_comment };
        $response_template->delete;
    };
};

subtest 'check that no external_status_code and no state change does not trigger incorrect template' => sub {
    $problem->state('action scheduled');
    $problem->set_extra_metadata(external_status_code => '123');
    $problem->update;

    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>action_scheduled</status>
    <description></description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    <external_status_code></external_status_code>
    </request_update>
    </service_requests_updates>
    };

    $problem->comments->delete;

    $requests_xml =~ s/UPDATED_DATETIME/$dt/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    stderr_like { $update->process_body } qr/Couldn't determine update text for/, 'Error message displayed';

    $problem->discard_changes;
    is $problem->comments->count, 1, 'comment is still created after fetching updates';
    is $problem->comments->first->state, 'hidden', '...but it is hidden';
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

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{2482},
        );

        $update->process_body;

        $problem->discard_changes;
        is $problem->comments->count, 2, 'two comments after fetching updates';
        is $problem->state, 'confirmed', 'correct problem status';
        $problem->comments->delete;
    };
}

foreach my $test (
    {
        desc => 'check that new comment confirmed date greater than report sent date when originally the same',
        dt1 => $dt,
        dt2 => $dt
    },
    {
        desc => 'check that new comment is not dated earlier than report sent date when originally earlier',
        dt1 => $dt,
        dt2 => $dt->subtract(seconds => 10)
    }
) {
    subtest $test->{desc} => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
        <service_requests_updates>
        <request_update>
        <update_id>638354</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>open</status>
        <description>This is a different note</description>
        <updated_datetime>UPDATED_DATETIME</updated_datetime>
        </request_update>
        </service_requests_updates>
        };

        $problem->state( 'confirmed' );

        $problem->whensent( $test->{dt1} );
        $problem->update;

        $requests_xml =~ s/UPDATED_DATETIME/$test->{dt2}/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{2482},
        );

        $update->process_body;

        $problem->discard_changes;

        is $problem->comments->count, 1, 'one comment after fetching updates';
        my $comment = $problem->comments->first;
        is $comment->confirmed, $problem->whensent->add( seconds => 1), 'Comment date a second after report date';
        $problem->comments->delete;
    };
}

foreach my $test (
    {
        desc => 'check that new comment confirmed date greater than auto-internal comment date when originally the same',
        dt1 => $dt,
        dt2 => $dt
    },
    {
        desc => 'check that new comment is not dated earlier than auto-internal comment date when originally earlier',
        dt1 => $dt,
        dt2 => $dt->subtract(seconds => 10)
    }
) {
    subtest $test->{desc} => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
        <service_requests_updates>
        <request_update>
        <update_id>638354</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>open</status>
        <description>This is a different note</description>
        <updated_datetime>UPDATED_DATETIME</updated_datetime>
        </request_update>
        </service_requests_updates>
        };

        $problem->state( 'fixed - council' );
        $problem->whensent( $test->{dt1} );

        my $auto_comment = FixMyStreet::DB->resultset('Comment')->find_or_create( {
            problem_state => 'fixed - council',
            problem_id => $problem->id,
            user_id    => $user->id,
            name       => 'User',
            text       => "Thank you. Your report has been fixed",
            state      => 'confirmed',
            confirmed  => 'now()',
            external_id => 'auto-internal',
        } );

        $problem->update;
        $auto_comment->confirmed($test->{dt1});

        $requests_xml =~ s/UPDATED_DATETIME/$test->{dt2}/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{2482},
        );

        $update->process_body;

        $problem->discard_changes;

        is $problem->comments->count, 2, 'two comment after fetching updates';

        my @updates = $problem->comments->order_by('created')->all;
        is $updates[0]->external_id, 'auto-internal', "Automatic update is the earlier update";
        is $updates[1]->created, $updates[0]->created->add( seconds => 1), "New update is one second later than automatic update";
        $problem->comments->delete;
    };
}

my $response_template_in_progress = $bodies{2482}->response_templates->create({
    title => "Acknowledgement 1",
    text => "Thank you for your report. We will provide an update within 48 hours.",
    auto_response => 1,
    state => "in progress"
});

for my $test (
    {
        external_code => '090',
        description => 'check numeric external status code in response template override state',
    },
    {
        external_code => 'futher',
        description => 'check alpha external status code in response template override state',
    },
) {
    subtest $test->{description} => sub {
        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
        <service_requests_updates>
        <request_update>
        <update_id>638344</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>in_progress</status>
        <description></description>
        <updated_datetime>UPDATED_DATETIME</updated_datetime>
        <external_status_code></external_status_code>
        </request_update>
        <request_update>
        <update_id>638345</update_id>
        <service_request_id>@{[ $problem->external_id ]}</service_request_id>
        <status>in_progress</status>
        <description></description>
        <updated_datetime>UPDATED_DATETIME2</updated_datetime>
        <external_status_code>@{[ $test->{external_code} ]}</external_status_code>
        </request_update>
        </service_requests_updates>
        };

        my $response_template = $bodies{2482}->response_templates->create({
            # the default ordering uses the title of the report so
            # make sure this comes second
            title => "Acknowledgement 2",
            text => "Thank you for your report. We will provide an update within 24 hours.",
            auto_response => 1,
            state => '',
            external_status_code => $test->{external_code}
        });

        $problem->update({ state => "confirmed" });
        $problem->comments->delete;

        my $dt2 = $dt->clone->add( minutes => 1 );
        $requests_xml =~ s/UPDATED_DATETIME/$dt/;
        $requests_xml =~ s/UPDATED_DATETIME2/$dt2/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            current_open311 => $o,
            current_body => $bodies{2482},
        );

        $update->process_body;

        $problem->discard_changes;
        is $problem->comments->count, 2, 'two comment after fetching updates';

        my @comments = $problem->comments->order_by('confirmed');

        is $comments[0]->text, "Thank you for your report. We will provide an update within 48 hours.", "correct external status code on first comment";
        is $comments[1]->text, "Thank you for your report. We will provide an update within 24 hours.", "correct external status code on second comment";
        $problem->comments->delete;
        $response_template->delete;
    };
}
$response_template_in_progress->delete;

subtest 'check an email template does not match incorrectly' => sub {
    my $email_template = $bodies{2482}->response_templates->create({
        title => "Acknowledgement 1",
        text => "An email template of some sort",
        auto_response => 1,
        external_status_code => 123,
        state => "in progress"
    });
    my $response_template = $bodies{2482}->response_templates->create({
        title => "Acknowledgement 2",
        text => "A normal in progress response template",
        auto_response => 1,
        external_status_code => '',
        state => "in progress"
    });

    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>in_progress</status>
    <external_status_code>456</external_status_code>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };
    $requests_xml =~ s/UPDATED_DATETIME/@{[$dt->clone->subtract( minutes => 62 )]}/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    $problem->state( 'confirmed' );
    $problem->lastupdate( $dt->clone->subtract( hours => 1 ) );
    $problem->update;

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );
    $update->process_body;

    $problem->discard_changes;
    is $problem->comments->count, 1, 'one comment after fetching updates';
    is $problem->state, 'in progress', 'correct problem status';
    is $problem->comments->first->text, 'A normal in progress response template';

    $problem->comments->delete;
    $email_template->delete;
    $response_template->delete;
};

subtest 'check any-category and certain category templates co-exist' => sub {
    my $in_progress_template = $bodies{2482}->response_templates->create({
        title => "Acknowledgement 1",
        text => "An in progress template for all categories",
        auto_response => 1,
        state => "in progress"
    });
    my $in_progress_template_cat = $bodies{2482}->response_templates->create({
        title => "Acknowledgement 2",
        text => "An in progress template for one category",
        auto_response => 1,
        state => "in progress"
    });
    $in_progress_template_cat->contact_response_templates->find_or_create({
        contact_id => $contact->id,
    });

    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>in_progress</status>
    <external_status_code>456</external_status_code>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };
    $requests_xml =~ s/UPDATED_DATETIME/@{[$dt->clone->subtract( minutes => 62 )]}/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    for ({
        category => $contact->category,
        template => 'An in progress template for one category',
    }, {
        category => 'Other',
        template => 'An in progress template for all categories',
    }) {
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);
        $problem->state( 'confirmed' );
        $problem->lastupdate( $dt->clone->subtract( hours => 1 ) );
        $problem->category($_->{category});
        $problem->update;
        $update->process_body;

        $problem->discard_changes;
        is $problem->comments->count, 1, 'one comment after fetching updates';
        is $problem->state, 'in progress', 'correct problem status';
        is $problem->comments->first->text, $_->{template};

        $problem->comments->delete;
    }

    $in_progress_template->delete;
    $in_progress_template_cat->contact_response_templates->delete;
    $in_progress_template_cat->delete;
};

subtest 'check that first comment always updates state'  => sub {
    my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
    <service_requests_updates>
    <request_update>
    <update_id>638344</update_id>
    <service_request_id>@{[ $problem->external_id ]}</service_request_id>
    <status>in_progress</status>
    <description>This is a note</description>
    <updated_datetime>UPDATED_DATETIME</updated_datetime>
    </request_update>
    </service_requests_updates>
    };

    $problem->state( 'confirmed' );
    $problem->lastupdate( $dt->clone->subtract( hours => 1 ) );
    $problem->update;

    $requests_xml =~ s/UPDATED_DATETIME/@{[$dt->clone->subtract( minutes => 62 )]}/;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    $update->process_body;

    $problem->discard_changes;
    is $problem->comments->count, 1, 'one comment after fetching updates';
    is $problem->state, 'in progress', 'correct problem status';
    $problem->comments->delete;
};

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

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            suppress_alerts => $test->{suppress_alerts},
            current_open311 => $o,
            current_body => $bodies{2482},
        );

        $update->process_body;
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

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
            system_user => $user,
            blank_updates_permitted => $test->{blank_updates_permitted},
            current_open311 => $o,
            current_body => $bodies{2482},
        );

        if ( $test->{blank_updates_permitted} ) {
            stderr_is { $update->process_body } '', 'No error message'
        } else {
            stderr_like { $update->process_body } qr/Couldn't determine update text for/, 'Error message displayed'
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

    my $dt2 = $dt->clone->subtract( minutes => 30 );
    my $dt3 = $dt2->clone->subtract( minutes => 30 );
    $requests_xml =~ s/UPDATED_DATETIME3/$dt/;
    $requests_xml =~ s/UPDATED_DATETIME2/$dt2/;
    $requests_xml =~ s/UPDATED_DATETIME/$dt3/;

    $problem->whensent( $dt3->clone->subtract( minutes => 30 ) );
    $problem->update;
    $problem->comments->delete;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    $update->process_body;

    $problem->discard_changes;
    is $problem->comments->count, 2, 'two comments after fetching updates';

    my @comments = $problem->comments->order_by('created')->all;

    is $comments[0]->external_id, 638344, "correct first comment added";
    is $comments[1]->external_id, 638356, "correct second comment added";
};

subtest 'check bad fixmystreet_id is handled' => sub {
    my $requests_xml = update_xml('638344', '8888888888888', 'This is a note', fms_id => '123456 654321');

    $problem->comments->delete;

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com');
    Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    warning_like {
        $update->process_body
    }
    qr/skipping bad fixmystreet id in updates for Bromley: \[123456 654321\], external id is 8888888888888/,
    "warning emitted for bad fixmystreet id";

    $problem->discard_changes;
    is $problem->comments->count, 0, 'no comments after fetching updates';
};

subtest 'Category changes' => sub {
    # Create additional category contact for testing
    my $lighting_contact = FixMyStreet::DB->resultset('Contact')->create({
        state => 'confirmed',
        editor => 'Test',
        whenedited => \'current_timestamp',
        note => 'Created for test',
        body_id => $bodies{2482}->id,
        category => 'Street Lighting',
        email => 'lighting@example.com',
    });
    my $deleted_contact = FixMyStreet::DB->resultset('Contact')->create({
        state => 'deleted',
        editor => 'Test',
        whenedited => \'current_timestamp',
        note => 'Created for test',
        body_id => $bodies{2482}->id,
        category => 'Other',
        email => 'other@example.com',
    });

    my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com' );
    my $update = Open311::GetServiceRequestUpdates->new(
        system_user => $user,
        current_open311 => $o,
        current_body => $bodies{2482},
    );

    subtest 'Category change creates comment' => sub {
        # Reset problem to original category
        $problem->update({ category => 'Potholes' });
        $problem->comments->delete;

        my $requests_xml = update_xml('category_change_1', $problem->external_id, 'Status update with category change', category => 'Street Lighting');
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        $update->process_body;
        $problem->discard_changes;

        # Check category was changed
        is $problem->category, 'Street Lighting', 'Category was updated from Potholes to Street Lighting';

        # Check comment was created
        is $problem->comments->count, 2, 'Two comments created - one for update, one for category change';

        my $category_comment = $problem->comments->search({ text => { like => '%Category changed%' } })->first;
        ok $category_comment, 'Category change comment was created';
        like $category_comment->text, qr/Category changed from.*Potholes.*to.*Street Lighting/, 'Comment has correct category change text';
        is $category_comment->user_id, $user->id, 'Comment created by system user';
        is $category_comment->send_state, 'processed', 'Comment send_state is processed';
    };

    subtest 'No comment when category unchanged' => sub {
        # Clear existing comments
        $problem->comments->delete;

        my $requests_xml = update_xml('category_same_1', $problem->external_id, 'Status update with same category', category => 'Street Lighting');
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        $update->process_body;
        $problem->discard_changes;

        # Check category unchanged
        is $problem->category, 'Street Lighting', 'Category remains the same';

        # Check only one comment was created (for the update, not category change)
        is $problem->comments->count, 1, 'Only one comment created for update';

        my $category_comment = $problem->comments->search({ text => { like => '%Category changed%' } })->first;
        ok !$category_comment, 'No category change comment created when category unchanged';
    };

    subtest 'Deleted category does not change category or create comment' => sub {
        # Clear existing comments and set known category
        $problem->comments->delete;
        $problem->update({ category => 'Street Lighting' });

        my $requests_xml = update_xml('category_deleted_1', $problem->external_id, 'Status update with deleted category', category => 'Other');
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        $update->process_body;
        $problem->discard_changes;

        # Check category unchanged
        is $problem->category, 'Street Lighting', 'Category unchanged with invalid category';

        # Check only one comment was created (for the update, not category change)
        is $problem->comments->count, 1, 'Only one comment created for update';

        my $category_comment = $problem->comments->search({ text => { like => '%Category changed%' } })->first;
        ok !$category_comment, 'No category change comment created for invalid category';
    };

    subtest 'Invalid category does not change category or create comment' => sub {
        # Clear existing comments and set known category
        $problem->comments->delete;
        $problem->update({ category => 'Street Lighting' });

        my $requests_xml = update_xml('category_invalid_1', $problem->external_id, 'Status update with invalid category', category => 'Invalid Category');
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        $update->process_body;
        $problem->discard_changes;

        # Check category unchanged
        is $problem->category, 'Street Lighting', 'Category unchanged with invalid category';

        # Check only one comment was created (for the update, not category change)
        is $problem->comments->count, 1, 'Only one comment created for update';

        my $category_comment = $problem->comments->search({ text => { like => '%Category changed%' } })->first;
        ok !$category_comment, 'No category change comment created for invalid category';
    };
};

done_testing();

sub setup_xml {
    my ($id, $id_ext, $status, $description, $extras) = @_;
    my $xml = $requests_xml;
    my $updated_datetime = sprintf( '<updated_datetime>%s</updated_datetime>', $dt );
    $xml =~ s/UPDATED_DATETIME/$updated_datetime/;
    $xml =~ s#<service_request_id>\d+</service_request_id>#<service_request_id>$id</service_request_id>#;
    $xml =~ s#<service_request_id_ext>\d+</service_request_id_ext>#<service_request_id_ext>$id_ext</service_request_id_ext>#;
    $xml =~ s#<status>\w+</status>#<status>$status</status># if $status;
    $xml =~ s#<description>.+</description>#<description>$description</description># if defined $description;
    $xml =~ s#</request_update>#<extras>$extras</extras></request_update># if defined $extras;
    return $xml;
}

sub update_xml {
    my ($id, $problem_id, $text, %extra) = @_;
    my $xml = <<XML;
<service_requests_updates>
<request_update>
<update_id>$id</update_id>
<service_request_id>$problem_id</service_request_id>
<status>open</status>
<description>$text</description>
<updated_datetime>$dt</updated_datetime>
XML
    if ($extra{category}) {
        $xml .= "<extras><category>$extra{category}</category></extras>";
    }
    if ($extra{fms_id}) {
        $xml .= "<fixmystreet_id>$extra{fms_id}</fixmystreet_id>";
    }
    $xml .= <<XML;
</request_update>
</service_requests_updates>
XML
    return $xml;
}
