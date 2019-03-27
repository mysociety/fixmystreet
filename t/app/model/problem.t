use FixMyStreet::TestMech;
use FixMyStreet;
use FixMyStreet::App;
use FixMyStreet::DB;
use FixMyStreet::Script::Reports;
use Sub::Override;

my $problem_rs = FixMyStreet::DB->resultset('Problem');

my $problem = $problem_rs->new(
    {
        postcode     => 'EH99 1SP',
        latitude     => '54.5',
        longitude    => '-1.5',
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

my $visible_states = $problem->visible_states;
is_deeply $visible_states, {
    'confirmed'                   => 1,
    'investigating'               => 1,
    'in progress'                 => 1,
    'planned'                     => 1,
    'action scheduled'            => 1,
    'fixed'                       => 1,
    'fixed - council'             => 1,
    'fixed - user'                => 1,
    'unable to fix'               => 1,
    'not responsible'             => 1,
    'duplicate'                   => 1,
    'closed'                      => 1,
    'internal referral'           => 1,
    }, 'visible_states is correct';

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

my $user = FixMyStreet::DB->resultset('User')->find_or_create(
    {
        email => 'system_user@example.net'
    }
);

$problem->user( $user );
$problem->created( DateTime->now()->subtract( days => 1 ) );
$problem->lastupdate( DateTime->now()->subtract( days => 1 ) );
$problem->anonymous(1);
$problem->insert;

my $tz_local = DateTime::TimeZone->new( name => 'local' );

my $body = FixMyStreet::DB->resultset('Body')->new({
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
        is_in_progress => 0,
        is_closed   => 0,
    },
    {
        state => 'hidden',
        is_visible => 0,
        is_fixed    => 0,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 0,
    },
    {
        state => 'unconfirmed',
        is_visible => 0,
        is_fixed    => 0,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 0,
    },
    {
        state => 'confirmed',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_in_progress => 0,
        is_closed   => 0,
    },
    {
        state => 'investigating',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_in_progress => 1,
        is_closed   => 0,
    },
    {
        state => 'planned',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_in_progress => 1,
        is_closed   => 0,
    },
    {
        state => 'action scheduled',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_in_progress => 1,
        is_closed   => 0,
    },
    {
        state => 'in progress',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_in_progress => 1,
        is_closed   => 0,
    },
    {
        state => 'duplicate',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 1,
    },
    {
        state => 'not responsible',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 1,
    },
    {
        state => 'unable to fix',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 1,
    },
    {
        state => 'fixed',
        is_visible => 1,
        is_fixed    => 1,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 0,
    },
    {
        state => 'fixed - council',
        is_visible => 1,
        is_fixed    => 1,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 0,
    },
    {
        state => 'fixed - user',
        is_visible => 1,
        is_fixed    => 1,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 0,
    },
    {
        state => 'closed',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 0,
        is_in_progress => 0,
        is_closed   => 1,
    },
) {
    subtest $test->{state} . ' is fixed/open/closed/visible' => sub {
        $problem->state( $test->{state} );
        is $problem->is_visible, $test->{is_visible}, 'is_visible';
        is $problem->is_fixed, $test->{is_fixed}, 'is_fixed';
        is $problem->is_closed, $test->{is_closed}, 'is_closed';
        is $problem->is_open, $test->{is_open}, 'is_open';
        is $problem->is_in_progress, $test->{is_in_progress}, 'is_in_progress';
    };
}

my $mech = FixMyStreet::TestMech->new();

my %body_ids;
my @bodies;
for my $body (
    { area_id => 2651, name => 'City of Edinburgh Council' },
    { area_id => 2226, name => 'Gloucestershire County Council' },
    { area_id => 2326, name => 'Cheltenham Borough Council' },
    { area_id => 2333, name => 'Hart Council' },
    { area_id => 2227, name => 'Hampshire County Council' },
    { area_id => 14279, name => 'Ballymoney Borough Council' },
    { area_id => 2636, name => 'Isle of Wight Council' },
    { area_id => 2649, name => 'Fife Council' },
    { area_id => 14279, name => 'TransportNI (Western)' },
) {
    my $aid = $body->{area_id};
    my $body = $mech->create_body_ok($aid, $body->{name});
    if ($body_ids{$aid}) {
        $body_ids{$aid} = [ $body_ids{$aid}, $body->id ];
    } else {
        $body_ids{$aid} = $body->id;
    }
    push @bodies, $body;
}

# Let's make some contacts to send things to!
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
    body_id => $body_ids{14279}[1], # TransportNI
    category => 'Street lighting',
    email => 'roads.western@drdni.example.org',
}, {
    body_id => $body_ids{14279}[0], # Ballymoney
    category => 'Graffiti',
    email => 'highways@example.net',
}, {
    state => 'unconfirmed',
    body_id => $body_ids{2636}, # Isle of Wight
    category => 'potholes',
    email => '2636@example.com',
} ) {
    $mech->create_contact_ok( %$contact );
}

my %common = (
    email => 'system_user@example.net',
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
        body          => $body_ids{2226},
        body_missing  => $body_ids{2649},
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
        body          => $body_ids{14279}[0],
        category      => 'Graffiti',
        longitude => -6.5,
        # As Ballmoney contact has same domain as reporter, the From line will
        # become a unique reply address and Reply-To will become the reporter
        reply_to => 1,
    }, {
        %common,
        desc          => 'directs NI correctly, 2',
        unset_whendef => 1,
        email_count   => 1,
        dear          => qr'Dear TransportNI \(Western\)',
        to            => qr'TransportNI \(Western\)" <roads',
        body          => $body_ids{14279}[1],
        category      => 'Street lighting',
        longitude => -6.5,
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
            MAPIT_URL => 'http://mapit.uk/',
            BASE_URL => 'http://www.fixmystreet.com',
        };
        if ( $test->{cobrand} && $test->{cobrand} =~ /hart/ ) {
            $override->{ALLOWED_COBRANDS} = [ 'hart' ];
        }

        $mech->clear_emails_ok;

        $problem_rs->search(
            {
                whensent => undef
            }
        )->update( { whensent => \'current_timestamp' } );

        $problem->discard_changes;
        $problem->update( {
            bodies_str => $test->{ body },
            bodies_missing => $test->{ body_missing },
            state => 'confirmed',
            confirmed => \'current_timestamp',
            whensent => $test->{ unset_whendef } ? undef : \'current_timestamp',
            category => $test->{ category } || 'potholes',
            name => $test->{ name },
            cobrand => $test->{ cobrand } || 'fixmystreet',
            longitude => $test->{longitude} || '-1.5',
        } );

        FixMyStreet::override_config $override, sub {
            FixMyStreet::Script::Reports::send();
        };

        $mech->email_count_is( $test->{ email_count } );
        if ( $test->{ email_count } ) {
            my $email = $mech->get_email;
            like $email->header('To'), $test->{ to }, 'to line looks correct';
            if ($test->{reply_to}) {
                is $email->header('Reply-To'), sprintf('"%s" <%s>', $test->{ name }, $test->{ email } ), 'Reply-To line looks correct';
                like $email->header('From'), qr/"$test->{name}" <fms-report-\d+-\w+\@example.org>/, 'from line looks correct';
            } else {
                is $email->header('From'), sprintf('"%s" <%s>', $test->{ name }, $test->{ email } ), 'from line looks correct';
            }
            like $email->header('Subject'), qr/A Title/, 'subject line looks correct';
            my $body = $mech->get_text_body_from_email($email);
            like $body, qr/A user of FixMyStreet/, 'email body looks a bit like a report';
            like $body, qr/Subject: A Title/, 'more email body checking';
            like $body, $test->{ dear }, 'Salutation looks correct';
            if ($test->{longitude}) {
                like $body, qr{Easting/Northing \(IE\): 297279/362371};
            } else {
                like $body, qr{Easting/Northing: };
            }

            if ( $test->{multiple} ) {
                like $body, qr/This email has been sent to several councils /, 'multiple body text correct';
            } elsif ( $test->{ missing } ) {
                like $body, $test->{ missing }, 'missing body information correct';
            }

            if ( $test->{url} ) {
                my $id = $problem->id;
                like $body, qr[$test->{url}fixmystreet.com/report/$id], 'URL present is correct';
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

subtest 'check can set multiple emails as a single contact' => sub {
    my $override = {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    };

    my $contact = {
        body_id => $body_ids{2651}, # Edinburgh
        category => 'trees',
        email => '2636@example.com,2636-2@example.com',
    };
    $mech->create_contact_ok( %$contact );

    $mech->clear_emails_ok;

    $problem_rs->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'current_timestamp' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $contact->{ body_id },
        state => 'confirmed',
        confirmed => \'current_timestamp',
        whensent => undef,
        category => 'trees',
        name => 'Test User',
        cobrand => 'fixmystreet',
        send_fail_count => 0,
    } );

    FixMyStreet::override_config $override, sub {
        FixMyStreet::Script::Reports::send();
    };

    $mech->email_count_is(1);
    my $email = $mech->get_email;
    is $email->header('To'), '"City of Edinburgh Council" <2636@example.com>, "City of Edinburgh Council" <2636-2@example.com>', 'To contains two email addresses';
};

subtest 'check can turn on report sent email alerts' => sub {
    my $send_confirmation_mail_override = Sub::Override->new(
        "FixMyStreet::Cobrand::Default::report_sent_confirmation_email",
        sub { return 'external_id'; }
    );
    $mech->clear_emails_ok;

    $problem_rs->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'current_timestamp' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $body_ids{2651},
        state => 'confirmed',
        confirmed => \'current_timestamp',
        whensent => undef,
        category => 'potholes',
        name => 'Test User',
        cobrand => 'fixmystreet',
        send_fail_count => 0,
    } );

    FixMyStreet::Script::Reports::send();

    $mech->email_count_is( 2 );
    my @emails = $mech->get_email;
    my $email = $emails[0];

    like $email->header('To'),qr/City of Edinburgh Council/, 'to line looks correct';
    is $email->header('From'), '"Test User" <system_user@example.net>', 'from line looks correct';
    like $email->header('Subject'), qr/A Title/, 'subject line looks correct';
    my $body = $mech->get_text_body_from_email($email);
    like $body, qr/A user of FixMyStreet/, 'email body looks a bit like a report';
    like $body, qr/Subject: A Title/, 'more email body checking';
    like $body, qr/Dear City of Edinburgh Council/, 'Salutation looks correct';

    $problem->discard_changes;
    ok defined( $problem->whensent ), 'whensent set';

    $email = $emails[1];
    like $email->header('Subject'), qr/FixMyStreet Report Sent/, 'report sent email title correct';
    $body = $mech->get_text_body_from_email($email);
    like $body, qr/to submit your report/, 'report sent body correct';

    $send_confirmation_mail_override->restore();
};


subtest 'check iOS app store test reports not sent' => sub {
    $mech->clear_emails_ok;

    $problem_rs->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'current_timestamp' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $body_ids{2651},
        title => 'App store test',
        state => 'confirmed',
        confirmed => \'current_timestamp',
        whensent => undef,
        category => 'potholes',
        send_fail_count => 0,
    } );

    FixMyStreet::Script::Reports::send();

    $mech->email_count_is( 0 );

    $problem->discard_changes();
    is $problem->state, 'hidden', 'iOS test reports are hidden automatically';
    is $problem->whensent, undef, 'iOS test reports are not sent';
};

subtest 'check reports from abuser not sent' => sub {
    $mech->clear_emails_ok;

    $problem_rs->search(
        {
            whensent => undef
        }
    )->update( { whensent => \'current_timestamp' } );

    $problem->discard_changes;
    $problem->update( {
        bodies_str => $body_ids{2651},
        title => 'Report',
        state => 'confirmed',
        confirmed => \'current_timestamp',
        whensent => undef,
        category => 'potholes',
        send_fail_count => 0,
    } );

    FixMyStreet::Script::Reports::send();

    $mech->email_count_is( 1 );

    $problem->discard_changes();
    ok $problem->whensent, 'Report has been sent';

    $problem->update( {
        state => 'confirmed',
        confirmed => \'current_timestamp',
        whensent => undef,
    } );

    my $abuse = FixMyStreet::DB->resultset('Abuse')->create( { email => $problem->user->email } );

    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();

    $mech->email_count_is( 0 );

    $problem->discard_changes();
    is $problem->state, 'hidden', 'reports from abuse user are hidden automatically';
    is $problem->whensent, undef, 'reports from abuse user are not sent';

    ok $abuse->delete(), 'user removed from abuse table';
};

subtest 'check response templates' => sub {
    my $c1 = $mech->create_contact_ok(category => 'Potholes', body_id => $body_ids{2651}, email => 'p');
    my $c2 = $mech->create_contact_ok(category => 'Graffiti', body_id => $body_ids{2651}, email => 'g');
    my $t1 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body_ids{2651}, title => "Title 1", text => "Text 1" });
    my $t2 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body_ids{2651}, title => "Title 2", text => "Text 2" });
    my $t3 = FixMyStreet::DB->resultset('ResponseTemplate')->create({ body_id => $body_ids{2651}, title => "Title 3", text => "Text 3" });
    $t1->add_to_contacts($c1);
    $t2->add_to_contacts($c2);
    my ($problem) = $mech->create_problems_for_body(1, $body_ids{2651}, 'TITLE');
    is $problem->response_templates, 1, 'Only the global template returned';
    ($problem) = $mech->create_problems_for_body(1, $body_ids{2651}, 'TITLE', { category => 'Potholes' });
    is $problem->response_templates, 2, 'Global and pothole templates returned';
};

subtest 'check duplicate reports' => sub {
    my ($problem1, $problem2) = $mech->create_problems_for_body(2, $body_ids{2651}, 'TITLE');
    $problem1->set_extra_metadata(duplicate_of => $problem2->id);
    $problem1->state('duplicate');
    $problem1->update;
    $problem2->set_extra_metadata(duplicates => [ $problem1->id ]);
    $problem2->update;

    is $problem1->duplicate_of->title, $problem2->title, 'problem1 returns correct problem from duplicate_of';
    is scalar @{ $problem2->duplicates }, 1, 'problem2 has correct number of duplicates';
    is $problem2->duplicates->[0]->title, $problem1->title, 'problem2 includes problem1 in duplicates';
};

subtest 'generates a tokenised url for a user' => sub {
    my ($problem) = $mech->create_problems_for_body(1, $body_ids{2651}, 'TITLE');
    my $url = $problem->tokenised_url($user);
    (my $token = $url) =~ s/\/M\///g;

    like $url, qr/\/M\//, 'problem generates tokenised url';

    my $token_obj = FixMyStreet::App->model('DB::Token')->find( {
        scope => 'email_sign_in', token => $token
    } );
    is $token, $token_obj->token, 'token is generated in database with correct scope';
    is $token_obj->data->{r}, $problem->url, 'token has correct redirect data';
};

subtest 'stores params in a token' => sub {
    my ($problem) = $mech->create_problems_for_body(1, $body_ids{2651}, 'TITLE');
    my $url = $problem->tokenised_url($user, { foo => 'bar', baz => 'boo'});
    (my $token = $url) =~ s/\/M\///g;

    my $token_obj = FixMyStreet::App->model('DB::Token')->find( {
        scope => 'email_sign_in', token => $token
    } );

    is_deeply $token_obj->data->{p}, { foo => 'bar', baz => 'boo'}, 'token has correct params';
};

subtest 'get report time ago in appropriate format' => sub {
    my ($problem) = $mech->create_problems_for_body(1, $body_ids{2651}, 'TITLE');

    $problem->update( {
      confirmed => DateTime->now->subtract( minutes => 2)
    } );
    is $problem->time_ago, '2 minutes', 'problem returns time ago in minutes';

    $problem->update( {
      confirmed => DateTime->now->subtract( hours => 18)
    } );
    is $problem->time_ago, '18 hours', 'problem returns time ago in hours';

    $problem->update( {
      confirmed => DateTime->now->subtract( days => 4)
    } );
    is $problem->time_ago, '4 days', 'problem returns time ago in days';

    $problem->update( {
      confirmed => DateTime->now->subtract( weeks => 3 )
    } );
    is $problem->time_ago, '3 weeks', 'problem returns time ago in weeks';

    $problem->update( {
      confirmed => DateTime->now->subtract( months => 4 )
    } );
    is $problem->time_ago, '4 months', 'problem returns time ago in months';

    $problem->update( {
      confirmed => DateTime->now->subtract( years => 2 )
    } );
    is $problem->time_ago, '2 years', 'problem returns time ago in years';
};

subtest 'time ago works with other dates' => sub {
    my ($problem) = $mech->create_problems_for_body(1, $body_ids{2651}, 'TITLE');

    $problem->update( {
      lastupdate => DateTime->now->subtract( days => 4)
    } );
    is $problem->time_ago('lastupdate'), '4 days', 'problem returns last updated time ago in days';
};

subtest 'return how many days ago a problem was reported' => sub {
    my ($problem) = $mech->create_problems_for_body(1, $body_ids{2651}, 'TITLE');
    $problem->update( {
      confirmed => DateTime->now->subtract( weeks => 2  )
    } );
    is $problem->days_ago, 14, 'days_ago returns the amount of days';

    $problem->update( {
      lastupdate => DateTime->now->subtract( days => 4)
    } );

    is $problem->days_ago('lastupdate'), 4, 'days_ago allows other dates to be specified';
};

END {
    done_testing();
}
