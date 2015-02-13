#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
use FixMyStreet;
use FixMyStreet::App;
use mySociety::Locale;
use Sub::Override;

mySociety::Locale::gettext_domain('FixMyStreet');

my $problem_rs = FixMyStreet::App->model('DB::Problem');

my $problem = $problem_rs->new(
    {
        postcode     => 'EH99 1SP',
        latitude     => '51.5016605453401',
        longitude    => '-0.142497580865087',
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
    }
);

is $problem->confirmed,  undef, 'inflating null confirmed ok';
is $problem->whensent,   undef, 'inflating null confirmed ok';
is $problem->lastupdate, undef, 'inflating null confirmed ok';
is $problem->created,  undef, 'inflating null confirmed ok';

for my $test ( 
    {
        desc => 'more or less empty problem',
        changed => {},
        errors => {
            title => 'Please enter a subject',
            detail => 'Please enter some details',
            bodies => 'No council selected',
            name => 'Please enter your name',
        }
    },
    {
        desc => 'name too short',
        changed => {
            name => 'xx',
        },
        errors => {
            title => 'Please enter a subject',
            detail => 'Please enter some details',
            bodies => 'No council selected',
            name => 'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below',
        }
    },
    {
        desc => 'name is anonymous',
        changed => {
            name => 'anonymous',
        },
        errors => {
            title => 'Please enter a subject',
            detail => 'Please enter some details',
            bodies => 'No council selected',
            name => 'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below',
        }
    },
    {
        desc => 'correct name',
        changed => {
            name => 'A User',
        },
        errors => {
            title => 'Please enter a subject',
            detail => 'Please enter some details',
            bodies => 'No council selected',
        }
    },
    {
        desc => 'correct title',
        changed => {
            title => 'A Title',
        },
        errors => {
            detail => 'Please enter some details',
            bodies => 'No council selected',
        }
    },
    {
        desc => 'correct detail',
        changed => {
            detail => 'Some information about the problem',
        },
        errors => {
            bodies => 'No council selected',
        }
    },
    {
        desc => 'incorrectly formatted body',
        changed => {
            bodies_str => 'my body',
        },
        errors => {
            bodies => 'No council selected',
        }
    },
    {
        desc => 'correctly formatted body',
        changed => {
            bodies_str => '1001',
        },
        errors => {
        }
    },
    {
        desc => 'bad category',
        changed => {
            category => '-- Pick a category --',
        },
        errors => {
            category => 'Please choose a category',
        }
    },
    {
        desc => 'bad category',
        changed => {
            category => '-- Pick a property type --',
        },
        errors => {
            category => 'Please choose a property type',
        }
    },
    {
        desc => 'correct category',
        changed => {
            category => 'Horse!',
        },
        errors => {
        }
    },
) {
    $problem->$_( $test->{changed}->{$_} ) for keys %{$test->{changed}};

    subtest $test->{desc} => sub {
        is_deeply $problem->check_for_errors, $test->{errors}, 'check for errors';
    };
}

my $user = FixMyStreet::App->model('DB::User')->find_or_create(
    {
        email => 'system_user@example.com'
    }
);

$problem->user( $user );
$problem->created( DateTime->now()->subtract( days => 1 ) );
$problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
$problem->anonymous(1);
$problem->insert;

my $tz_local = DateTime::TimeZone->new( name => 'local' );

my $body = FixMyStreet::App->model('DB::Body')->new({
    name => 'Edinburgh City Council'
});

for my $test (
    {
        desc => 'request older than problem ignored',
        lastupdate => '',
        request => {
            updated_datetime => DateTime::Format::W3CDTF->new()->format_datetime( DateTime->now()->set_time_zone( $tz_local )->subtract( days => 2 ) ),
        },
        created => 0,
    },
    {
        desc => 'request newer than problem created',
        lastupdate => '',
        request => {
            updated_datetime => DateTime::Format::W3CDTF->new()->format_datetime( DateTime->now()->set_time_zone( $tz_local ) ),
            status => 'open',
            status_notes => 'this is an update from the council',
        },
        created => 1,
        state => 'confirmed',
        mark_fixed => 0,
        mark_open => 0,
    },
    {
        desc => 'update with state of closed fixes problem',
        lastupdate => '',
        request => {
            updated_datetime => DateTime::Format::W3CDTF->new()->format_datetime( DateTime->now()->set_time_zone( $tz_local ) ),
            status => 'closed',
            status_notes => 'the council have fixed this',
        },
        created => 1,
        state => 'fixed',
        mark_fixed => 1,
        mark_open => 0,
    },
    {
        desc => 'update with state of open leaves problem as fixed',
        lastupdate => '',
        request => {
            updated_datetime => DateTime::Format::W3CDTF->new()->format_datetime( DateTime->now()->set_time_zone( $tz_local ) ),
            status => 'open',
            status_notes => 'the council do not think this is fixed',
        },
        created => 1,
        start_state => 'fixed',
        state => 'fixed',
        mark_fixed => 0,
        mark_open => 0,
    },
) {
    subtest $test->{desc} => sub {
        # makes testing easier;
        $problem->comments->delete;
        $problem->created( DateTime->now()->subtract( days => 1 ) );
        $problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
        $problem->state( $test->{start_state} || 'confirmed' );
        $problem->update;
        my $w3c = DateTime::Format::W3CDTF->new();

        my $ret = $problem->update_from_open311_service_request( $test->{request}, $body, $user );
        is $ret, $test->{created}, 'return value';

        return unless $test->{created};

        $problem->discard_changes;
        is $problem->lastupdate, $w3c->parse_datetime($test->{request}->{updated_datetime}), 'lastupdate time';

        my $update = $problem->comments->first;

        ok $update, 'updated created';

        is $problem->state, $test->{state}, 'problem state';

        is $update->text, $test->{request}->{status_notes}, 'update text';
        is $update->mark_open, $test->{mark_open}, 'update mark_open flag';
        is $update->mark_fixed, $test->{mark_fixed}, 'update mark_fixed flag';
    };
}

for my $test ( 
    {
        state => 'partial',
        is_visible  => 0,
        is_fixed    => 0,
        is_open     => 0,
        is_closed   => 0,
    },
    {
        state => 'hidden',
        is_visible => 0,
        is_fixed    => 0,
        is_open     => 0,
        is_closed   => 0,
    },
    {
        state => 'unconfirmed',
        is_visible => 0,
        is_fixed    => 0,
        is_open     => 0,
        is_closed   => 0,
    },
    {
        state => 'confirmed',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_closed   => 0,
    },
    {
        state => 'investigating',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_closed   => 0,
    },
    {
        state => 'planned',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_closed   => 0,
    },
    {
        state => 'action scheduled',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_closed   => 0,
    },
    {
        state => 'in progress',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_closed   => 0,
    },
    {
        state => 'duplicate',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_closed   => 1,
    },
    {
        state => 'not responsible',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_closed   => 1,
    },
    {
        state => 'unable to fix',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_closed   => 1,
    },
    {
        state => 'fixed',
        is_visible => 1,
        is_fixed    => 1,
        is_open     => 0,
        is_closed   => 0,
    },
    {
        state => 'fixed - council',
        is_visible => 1,
        is_fixed    => 1,
        is_open     => 0,
        is_closed   => 0,
    },
    {
        state => 'fixed - user',
        is_visible => 1,
        is_fixed    => 1,
        is_open     => 0,
        is_closed   => 0,
    },
    {
        state => 'closed',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_closed   => 1,
    },
) {
    subtest $test->{state} . ' is fixed/open/closed/visible' => sub {
        $problem->state( $test->{state} );
        is $problem->is_visible, $test->{is_visible}, 'is_visible';
        is $problem->is_fixed, $test->{is_fixed}, 'is_fixed';
        is $problem->is_closed, $test->{is_closed}, 'is_closed';
        is $problem->is_open, $test->{is_open}, 'is_open';
    };
}

my $mech = FixMyStreet::TestMech->new();

my %contact_params = (
    confirmed => 1,
    deleted => 0,
    editor => 'Test',
    whenedited => \'ms_current_timestamp()',
    note => 'Created for test',
);

my %body_ids;
for my $body (
    { area_id => 2651, name => 'City of Edinburgh Council' },
    { area_id => 2226, name => 'Gloucestershire County Council' },
    { area_id => 2326, name => 'Cheltenham Borough Council' },
    { area_id => 2333, name => 'Hart Council' },
    { area_id => 2227, name => 'Hampshire County Council' },
    { area_id => 14279, name => 'Ballymoney Borough Council' },
    { area_id => 2636, name => 'Isle of Wight Council' },
    { area_id => 2649, name => 'Fife Council' },
) {
    my $aid = $body->{area_id};
    $body_ids{$aid} = $mech->create_body_ok($aid, $body->{name}, id => $body->{id})->id;
}

# Let's make some contacts to send things to!
my @contacts;
for my $contact ( {
    body_id => $body_ids{2651}, # Edinburgh
    category => 'potholes',
    email => 'test@example.org',
}, {
    body_id => $body_ids{2226}, # Gloucestershire
    category => 'potholes',
    email => '2226@example.org',
}, {
    body_id => $body_ids{2326}, # Cheltenham
    category => 'potholes',
    email => '2326@example.org',
}, {
    body_id => $body_ids{2333}, # Hart
    category => 'potholes',
    email => 'trees@example.com',
}, {
    body_id => $body_ids{2227}, # Hampshire
    category => 'potholes',
    email => 'highways@example.com',
}, {
    body_id => $body_ids{14279}, # Ballymoney
    category => 'Street lighting',
    email => 'roads.western@drdni.example.org',
}, {
    body_id => $body_ids{14279}, # Ballymoney
    category => 'Graffiti',
    email => 'highways@example.com',
}, {
    confirmed => 0,
    body_id => $body_ids{2636}, # Isle of Wight
    category => 'potholes',
    email => '2636@example.com',
} ) {
    my $new_contact = FixMyStreet::App->model('DB::Contact')->find_or_create( { %contact_params, %$contact } );
    ok $new_contact, "created test contact";
    push @contacts, $new_contact;
}

my %common = (
    email => 'system_user@example.com',
    name => 'Andrew Smith',
);
foreach my $test ( {
        %common,
        desc          => 'sends an email',
        unset_whendef => 1,
        email_count   => 1,
        dear          => qr'Dear City of Edinburgh Council',
        to            => qr'City of Edinburgh Council',
        body          => $body_ids{2651},
    }, {
        %common,
        desc          => 'no email sent if no unsent problems',
        unset_whendef => 0,
        email_count   => 0,
        body          => $body_ids{2651},
    }, {
        %common,
        desc          => 'email to two tier council',
        unset_whendef => 1,
        email_count   => 1,
        to            => qr'Cheltenham Borough Council.*Gloucestershire County Council',
        dear          => qr'Dear Cheltenham Borough Council and Gloucestershire County',
        body          => $body_ids{2226} . ',' . $body_ids{2326},
        multiple      => 1,
    }, {
        %common,
        desc          => 'email to two tier council with one missing details',
        unset_whendef => 1,
        email_count   => 1,
        to            => qr'Gloucestershire County Council" <2226@example',
        dear          => qr'Dear Gloucestershire County Council,',
        body          => $body_ids{2226}  . '|' . $body_ids{2649},
        missing       => qr'problem might be the responsibility of Fife.*Council'ms,
    }, {
        %common,
        desc          => 'email to two tier council that only shows district, district',
        unset_whendef => 1,
        email_count   => 1,
        to            => qr'Hart Council',
        dear          => qr'Dear Hart Council,',
        body          => $body_ids{2333},
        cobrand       => 'hart',
        url           => 'hart.',
    }, {
        %common,
        desc          => 'email to two tier council that only shows district, county',
        unset_whendef => 1,
        email_count   => 1,
        to            => qr'Hampshire County Council" <highways@example',
        dear          => qr'Dear Hampshire County Council,',
        body          => $body_ids{2227},
        cobrand       => 'hart',
        url           => 'www.',
    }, {
        %common,
        desc          => 'directs NI correctly, 1',
        unset_whendef => 1,
        email_count   => 1,
        dear          => qr'Dear Ballymoney Borough Council',
        to            => qr'Ballymoney Borough Council',
        body          => $body_ids{14279},
        category      => 'Graffiti',
    }, {
        %common,
        desc          => 'directs NI correctly, 2',
        unset_whendef => 1,
        email_count   => 1,
        dear          => qr'Dear Roads Service \(Western\)',
        to            => qr'Roads Service \(Western\)" <roads',
        body          => $body_ids{14279},
        category      => 'Street lighting',
    }, {
        %common,
        desc          => 'does not send to unconfirmed contact',
        unset_whendef => 1,
        stays_unsent  => 1,
        email_count   => 0,
        body          => $body_ids{2636},
    },
) {
    subtest $test->{ desc } => sub {
        my $override = {
            ALLOWED_COBRANDS => [ 'fixmystreet' ],
            BASE_URL => 'http://www.fixmystreet.com',
            MAPIT_URL => 'http://mapit.mysociety.org/',
        };
        if ( $test->{cobrand} && $test->{cobrand} =~ /hart/ ) {
            $override->{ALLOWED_COBRANDS} = [ 'hart' ];
        }

        $mech->clear_emails_ok;

        FixMyStreet::App->model('DB::Problem')->search(
            {
                whensent => undef
            }
        )->update( { whensent => \'ms_current_timestamp()' } );

        $problem->discard_changes;
        $problem->update( {
            bodies_str => $test->{ body },
            state => 'confirmed',
            confirmed => \'ms_current_timestamp()',
            whensent => $test->{ unset_whendef } ? undef : \'ms_current_timestamp()',
            category => $test->{ category } || 'potholes',
            name => $test->{ name },
            cobrand => $test->{ cobrand } || 'fixmystreet',
        } );

        FixMyStreet::override_config $override, sub {
            FixMyStreet::App->model('DB::Problem')->send_reports();
        };

        $mech->email_count_is( $test->{ email_count } );
        if ( $test->{ email_count } ) {
            my $email = $mech->get_email;
            like $email->header('To'), $test->{ to }, 'to line looks correct';
            is $email->header('From'), sprintf('"%s" <%s>', $test->{ name }, $test->{ email } ), 'from line looks correct';
            like $email->header('Subject'), qr/A Title/, 'subject line looks correct';
            like $email->body, qr/A user of FixMyStreet/, 'email body looks a bit like a report';
            like $email->body, qr/Subject: A Title/, 'more email body checking';
            like $email->body, $test->{ dear }, 'Salutation looks correct';

            if ( $test->{multiple} ) {
                like $email->body, qr/This email has been sent to several councils /, 'multiple body text correct';
            } elsif ( $test->{ missing } ) {
                like $email->body, $test->{ missing }, 'missing body information correct';
            }

            if ( $test->{url} ) {
                my $id = $problem->id;
                like $email->body, qr[$test->{url}fixmystreet.com/report/$id], 'URL present is correct';
            }

            $problem->discard_changes;
            ok defined( $problem->whensent ), 'whensent set';
        }
        if ( $test->{stays_unsent} ) {
            $problem->discard_changes;
            ok !defined( $problem->whensent ), 'whensent not set';
        }
    };
}

subtest 'check can set mutiple emails as a single contact' => sub {
    my $override = {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        BASE_URL => 'http://www.fixmystreet.com',
        MAPIT_URL => 'http://mapit.mysociety.org/',
    };

    my $contact = {
        body_id => $body_ids{2651}, # Edinburgh
        category => 'trees',
        email => '2636@example.com,2636-2@example.com',
    };
    my $new_contact = FixMyStreet::App->model('DB::Contact')->find_or_create( {
            %contact_params, 
            %$contact } );
    ok $new_contact, "created multiple email test contact";

    $mech->clear_emails_ok;

    FixMyStreet::App->model('DB::Problem')->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'ms_current_timestamp()' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $contact->{ body_id },
        state => 'confirmed',
        confirmed => \'ms_current_timestamp()',
        whensent => undef,
        category => 'trees',
        name => 'Test User',
        cobrand => 'fixmystreet',
        send_fail_count => 0,
    } );

    FixMyStreet::override_config $override, sub {
        FixMyStreet::App->model('DB::Problem')->send_reports();
    };

    $mech->email_count_is(1);
    my $email = $mech->get_email;
    is $email->header('To'), '"City of Edinburgh Council" <2636@example.com>, "City of Edinburgh Council" <2636-2@example.com>', 'To contains two email addresses';
};

subtest 'check can turn on report sent email alerts' => sub {
    my $send_confirmation_mail_override = Sub::Override->new(
        "FixMyStreet::Cobrand::Default::report_sent_confirmation_email",
        sub { return 1; }
    );
    $mech->clear_emails_ok;

    FixMyStreet::App->model('DB::Problem')->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'ms_current_timestamp()' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $body_ids{2651},
        state => 'confirmed',
        confirmed => \'ms_current_timestamp()',
        whensent => undef,
        category => 'potholes',
        name => 'Test User',
        cobrand => 'fixmystreet',
        send_fail_count => 0,
    } );

    FixMyStreet::App->model('DB::Problem')->send_reports();

    $mech->email_count_is( 2 );
    my @emails = $mech->get_email;
    my $email = $emails[0];

    like $email->header('To'),qr/City of Edinburgh Council/, 'to line looks correct';
    is $email->header('From'), '"Test User" <system_user@example.com>', 'from line looks correct';
    like $email->header('Subject'), qr/A Title/, 'subject line looks correct';
    like $email->body, qr/A user of FixMyStreet/, 'email body looks a bit like a report';
    like $email->body, qr/Subject: A Title/, 'more email body checking';
    like $email->body, qr/Dear City of Edinburgh Council/, 'Salutation looks correct';

    $problem->discard_changes;
    ok defined( $problem->whensent ), 'whensent set';

    $email = $emails[1];
    like $email->header('Subject'), qr/FixMyStreet Report Sent/, 'report sent email title correct';
    like $email->body, qr/to submit your report/, 'report sent body correct';

    $send_confirmation_mail_override->restore();
};


subtest 'check iOS app store test reports not sent' => sub {
    $mech->clear_emails_ok;

    FixMyStreet::App->model('DB::Problem')->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'ms_current_timestamp()' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $body_ids{2651},
        title => 'App store test',
        state => 'confirmed',
        confirmed => \'ms_current_timestamp()',
        whensent => undef,
        category => 'potholes',
        send_fail_count => 0,
    } );

    FixMyStreet::App->model('DB::Problem')->send_reports();

    $mech->email_count_is( 0 );

    $problem->discard_changes();
    is $problem->state, 'hidden', 'iOS test reports are hidden automatically';
    is $problem->whensent, undef, 'iOS test reports are not sent';
};

subtest 'check reports from abuser not sent' => sub {
    $mech->clear_emails_ok;

    FixMyStreet::App->model('DB::Problem')->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'ms_current_timestamp()' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $body_ids{2651},
        title => 'Report',
        state => 'confirmed',
        confirmed => \'ms_current_timestamp()',
        whensent => undef,
        category => 'potholes',
        send_fail_count => 0,
    } );

    FixMyStreet::App->model('DB::Problem')->send_reports();

    $mech->email_count_is( 1 );

    $problem->discard_changes();
    ok $problem->whensent, 'Report has been sent';

    $problem->update( {
        state => 'confirmed',
        confirmed => \'ms_current_timestamp()',
        whensent => undef,
    } );

    my $abuse = FixMyStreet::App->model('DB::Abuse')->create( { email => $problem->user->email } );

    $mech->clear_emails_ok;
    FixMyStreet::App->model('DB::Problem')->send_reports();

    $mech->email_count_is( 0 );

    $problem->discard_changes();
    is $problem->state, 'hidden', 'reports from abuse user are hidden automatically';
    is $problem->whensent, undef, 'reports from abuse user are not sent';

    ok $abuse->delete(), 'user removed from abuse table';
};

END {
    $problem->comments->delete if $problem;
    $problem->delete if $problem;
    $mech->delete_user( $user ) if $user;

    foreach (@contacts) {
        $_->delete;
    }

    done_testing();
}
