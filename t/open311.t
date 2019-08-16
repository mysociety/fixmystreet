#!/usr/bin/env perl

use FixMyStreet::Test;
use File::Temp 'tempdir';
use Path::Tiny;
use Test::More;
use Test::Warn;
use FixMyStreet::DB;
use CGI::Simple;
use HTTP::Response;
use DateTime;
use DateTime::Format::W3CDTF;

use_ok( 'Open311' );

my $o = Open311->new();
ok $o, 'created object';

my $err_text = <<EOT
<?xml version="1.0" encoding="utf-8"?><errors><error><code>400</code><description>Service Code cannot be null -- can't proceed with the request.</description></error></errors>
EOT
;

is $o->_process_error( $err_text ), "400: Service Code cannot be null -- can't proceed with the request.\n", 'error text parsing';
is $o->_process_error( '503 - service unavailable' ), 'unknown error', 'error text parsing of bad error';

my $o2 = Open311->new( endpoint => 'http://127.0.0.1/open311/', jurisdiction => 'example.org' );

my $u = FixMyStreet::DB->resultset('User')->new( { email => 'test@example.org', name => 'A User' } );

for my $sfc (0..2) {
    my $p = FixMyStreet::DB->resultset('Problem')->new( {
        latitude => 1,
        longitude => 1,
        title => 'title',
        detail => 'detail',
        user => $u,
        id => 1,
        name => 'A User',
        cobrand => 'fixmystreet',
        send_fail_count => $sfc,
    } );
    my $expected_error = qr{Failed to submit problem 1 over Open311}ism;

    if ($sfc == 1) {
        warning_like {$o2->send_service_request( $p, { url => 'http://example.com/' }, 1 )} $expected_error, 'warning generated on failed call';
    } else {
        warning_like {$o2->send_service_request( $p, { url => 'http://example.com/' }, 1 )} undef, 'no warning generated on failed call';
    }
}

my $dt = DateTime->now();

my $user = FixMyStreet::DB->resultset('User')->new( {
    name => 'Test User',
    email => 'test@example.com',
} );

my $problem = FixMyStreet::DB->resultset('Problem')->new( {
    id => 80,
    external_id => 81,
    state => 'confirmed',
    title => 'a problem',
    detail => 'problem detail',
    category => 'pothole',
    latitude => 1,
    longitude => 2,
    user => $user,
    name => 'Test User',
    cobrand => 'fixmystreet',
} );

my $bromley = FixMyStreet::DB->resultset('Body')->new({ name => 'Bromley' });

subtest 'posting service request' => sub {
    my $extra = {
        url => 'http://example.com/report/1',
        easting => 'SET',
    };

    my $results = make_service_req( $problem, $extra, $problem->category, '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>' );

    is $results->{ res }, 248, 'got request id';

    my $description = <<EOT;
title: a problem

detail: problem detail

url: http://example.com/report/1

Submitted via FixMyStreet
EOT
;

    my $c = CGI::Simple->new( $results->{ req }->content );
    (my $c_description = $c->param('description')) =~ s/\r\n/\n/g;

    is $c->param('email'), $user->email, 'correct email';
    is $c->param('first_name'), 'Test', 'correct first name';
    is $c->param('last_name'), 'User', 'correct last name';
    is $c->param('lat'), 1, 'latitide correct';
    is $c->param('long'), 2, 'longitude correct';
    is $c_description, $description, 'description correct';
    is $c->param('service_code'), 'pothole', 'service code correct';
};

subtest 'posting service request with basic_description' => sub {
    my $extra = {
        url => 'http://example.com/report/1',
    };

    my $results = make_service_req(
        $problem,
        $extra,
        $problem->category,
        '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>',
        { extended_description => 0 },
    );

    is $results->{ res }, 248, 'got request id';

    my $c = CGI::Simple->new( $results->{ req }->content );

    is $c->param('description'), $problem->detail, 'description correct';
};

for my $test (
    {
        desc  => 'extra values in service request',
        extra => [
            {
                name  => 'title',
                value => 'A title',
            }
        ],
        params => [
            [ 'attribute[title]', 'A title', 'extra parameter used correctly' ]
        ],
        debug_contains => 'attribute\[title\]: A title',
    },
    {
        desc  => 'undef extra values handled',
        extra => [
            {
                name  => 'title',
                value => undef,
            }
        ],
        params => [
            [ 'attribute[title]', '', 'undef extra parameter used correctly' ]
        ],
        # multi line warnings are not handled well so just match the
        # first line
        warning => qr/POST requests.xml/,
        debug_contains => 'attribute\[title\]: $',
    },
    {
        desc  => '0 extra values handled',
        extra => [
            {
                name  => 'title',
                value => 0,
            }
        ],
        params => [
            [ 'attribute[title]', '0', '0 extra parameter used correctly' ]
        ],
        debug_contains => 'attribute\[title\]: 0',
    },
    {
        desc  => 'first and last names in extra used correctly',
        extra => [
            {
                name  => 'first_name',
                value => 'First',
            },
            {
                name  => 'last_name',
                value => 'Last',
            },
        ],
        params => [
            [ 'first_name', 'First', 'first name correct' ],
            [ 'last_name',  'Last',  'last name correct' ],
            [ 'attribute[first_name]', undef, 'no first_name attribute param' ],
            [ 'attribute[last_name]',  'Last', 'last_name attribute param correct' ],
        ],
    },
    {
        desc => 'magic fms_extra parameters handled correctly',
        extra => [
            {
                name  => 'fms_extra_title',
                value => 'Extra title',
            }
        ],
        params => [
            [
                'attribute[title]',
                'Extra title',
                'fms_extra extra param used correctly'
            ]
        ],
    },
  )
{
    subtest $test->{desc} => sub {
        $problem->extra( $test->{extra} );

        my $extra = { url => 'http://example.com/report/1', };

        my $results;
        if ( $test->{warning} ) {
            warnings_exist {
                $results = make_service_req( $problem, $extra, $problem->category,
                '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>'
                );
            } [ $test->{warning} ], 'warning generated by service request call';
        } else {
            $results = make_service_req( $problem, $extra, $problem->category,
            '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>'
            );
        }
        my $c   = CGI::Simple->new( $results->{req}->content );

        if ( $test->{debug_contains} ) {
            like $results->{o}->debug_details, qr/$test->{debug_contains}/m, 'extra handled correctly in debug';
        }

        for my $param ( @{ $test->{params} } ) {
            is $c->param( $param->[0] ), $param->[1], $param->[2];
        }
    };
}

for my $test ( 
    {
        desc => 'Check uses report name over user name',
        name => 'Nom de Report',
        first_name => 'Nom',
        last_name => 'de Report',
    },
    {
        desc => 'Check single word name handled correctly',
        name => 'Nom',
        first_name => 'Nom',
        last_name => '',
    }
) {
    subtest $test->{desc} => sub {
        $problem->extra( undef );
        $problem->name( $test->{name} );
        my $extra = { url => 'http://example.com/report/1', };

        my $results = make_service_req( $problem, $extra, $problem->category,
'<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>'
        );
        my $c   = CGI::Simple->new( $results->{req}->content );

        is $c->param( 'first_name' ), $test->{first_name}, 'correct first name';
        is $c->param( 'last_name' ), $test->{last_name}, 'correct last name';
    };
}

for my $test (
    {
        desc => 'account_id handled correctly when present',
        account_id => '1c304134-ef12-c128-9212-123908123901',
    },
    {
        desc => 'account_id handled correctly when 0',
        account_id => '0'
    },
    {
        desc => 'account_id handled correctly when missing',
        account_id => undef
    }
) {
    subtest $test->{desc} => sub {
        $problem->extra( undef );
        my $extra = {
            url => 'http://example.com/report/1',
            defined $test->{account_id} ? ( account_id => $test->{account_id} ) : ()
        };

        my $results = make_service_req( $problem, $extra, $problem->category,
'<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>'
        );
        my $c   = CGI::Simple->new( $results->{req}->content );

        is $c->param( 'account_id' ), $test->{account_id}, 'correct account_id';
    };
}

subtest 'test always_send_email' => sub {
    my $email = $user->email;
    $user->email(undef);
    my $extra = { url => 'http://example.com/report/1', };

    my $results = make_service_req(
        $problem, $extra, $problem->category,
        '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>',
        { always_send_email => 1 }
    );
    my $c = CGI::Simple->new( $results->{req}->content );

    is $c->param('email'), 'do-not-reply@example.org', 'correct email';
    $user->email($email);
};

sub make_comment {
    my $cobrand = shift;
    FixMyStreet::DB->resultset('Comment')->new( {
        id => 38362,
        user => $user,
        problem => $problem,
        anonymous => 0,
        text => 'this is a comment',
        confirmed => $dt,
        problem_state => 'confirmed',
        cobrand => $cobrand || 'default',
        extra => { title => 'Mr', email_alerts_requested => 0 },
    } );
}

subtest 'basic request update post parameters' => sub {
    my $comment = make_comment();
    my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );

    is $results->{ res }, 248, 'got update id';

    my $c = CGI::Simple->new( $results->{ req }->content );

    is $c->param('description'), 'this is a comment', 'description correct';
    is $c->param('email'), 'test@example.com', 'email correct';
    is $c->param('status'), 'OPEN', 'status correct';
    is $c->param('service_request_id'), 81, 'request id correct';
    is $c->param('updated_datetime'), DateTime::Format::W3CDTF->format_datetime($dt), 'correct date';
    is $c->param('title'), 'Mr', 'correct title';
    is $c->param('first_name'), 'Test', 'correct first name';
    is $c->param('last_name'), 'User', 'correct second name';
    is $c->param('media_url'), undef, 'no media url';
};

subtest 'extended request update post parameters' => sub {
    my $comment = make_comment('bromley');
    my $results;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'bromley',
    }, sub {
        $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );
    };

    is $results->{ res }, 248, 'got update id';

    my $c = CGI::Simple->new( $results->{ req }->content );

    is $c->param('description'), 'this is a comment', 'description correct';
    is $c->param('email'), 'test@example.com', 'email correct';
    is $c->param('status'), 'OPEN', 'status correct';
    is $c->param('service_request_id_ext'), 80, 'external request id correct';
    is $c->param('service_request_id'), 81, 'request id correct';
    is $c->param('public_anonymity_required'), 'FALSE', 'anon status correct';
    is $c->param('updated_datetime'), DateTime::Format::W3CDTF->format_datetime($dt), 'correct date';
    is $c->param('title'), 'Mr', 'correct title';
    is $c->param('first_name'), 'Test', 'correct first name';
    is $c->param('last_name'), 'User', 'correct second name';
    is $c->param('email_alerts_requested'), 'FALSE', 'email alerts flag correct';
    is $c->param('media_url'), undef, 'no media url';
};

subtest 'Hounslow update description is correct for same user' => sub {
    my $comment = make_comment('hounslow');
    my $results;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
    }, sub {
        $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );
    };

    is $results->{ res }, 248, 'got update id';

    my $c = CGI::Simple->new( $results->{ req }->content );

    is $c->param('description'), 'this is a comment', 'description correct';
    is $c->param('email'), 'test@example.com', 'email correct';
    is $c->param('status'), 'OPEN', 'status correct';
    is $c->param('service_request_id'), 81, 'request id correct';
    is $c->param('updated_datetime'), DateTime::Format::W3CDTF->format_datetime($dt), 'correct date';
    is $c->param('title'), 'Mr', 'correct title';
    is $c->param('first_name'), 'Test', 'correct first name';
    is $c->param('last_name'), 'User', 'correct second name';
    is $c->param('media_url'), undef, 'no media url';
};

subtest 'Hounslow update description is correct for a different user' => sub {
    my $user2 = FixMyStreet::DB->resultset('User')->new( {
        name => 'Another User',
        email => 'another@example.org',
    } );

    my $comment = make_comment('hounslow');
    $comment->user($user2);
    my $results;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
    }, sub {
        $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );
    };

    is $results->{ res }, 248, 'got update id';

    my $c = CGI::Simple->new( $results->{ req }->content );

    is $c->param('description'), "[This comment was not left by the original problem reporter] this is a comment", 'description correct';
    is $c->param('email'), 'another@example.org', 'email correct';
    is $c->param('status'), 'OPEN', 'status correct';
    is $c->param('service_request_id'), 81, 'request id correct';
    is $c->param('updated_datetime'), DateTime::Format::W3CDTF->format_datetime($dt), 'correct date';
    is $c->param('title'), 'Mr', 'correct title';
    is $c->param('first_name'), 'Another', 'correct first name';
    is $c->param('last_name'), 'User', 'correct second name';
    is $c->param('media_url'), undef, 'no media url';
};

subtest 'check media url set' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );

    my $image_path = path('t/app/controller/sample.jpg');
    $image_path->copy( path( $UPLOAD_DIR, '0123456789012345678901234567890123456789.jpeg' ) );

    my $comment = make_comment('fixmystreet');
    $comment->photo("0123456789012345678901234567890123456789");

    FixMyStreet::override_config {
        PHOTO_STORAGE_BACKEND => 'FileSystem',
        PHOTO_STORAGE_OPTIONS => {
            UPLOAD_DIR => $UPLOAD_DIR,
        },
    }, sub {
        my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );

        is $results->{ res }, 248, 'got update id';

        my $c = CGI::Simple->new( $results->{ req }->content );
        my $expected_path = '/c/' . $comment->id . '.0.full.jpeg';
        like $c->param('media_url'), qr/$expected_path/, 'image url included';
    };
};

foreach my $test (
    {
        desc => 'comment with fixed state sends status of CLOSED',
        state => 'fixed',
        status => 'CLOSED',
        extended => 'FIXED',
    },
    {
        desc => 'comment with fixed - user state sends status of CLOSED',
        state => 'fixed - user',
        status => 'CLOSED',
        extended => 'FIXED',
    },
    {
        desc => 'comment with fixed - council state sends status of CLOSED',
        state => 'fixed - council',
        status => 'CLOSED',
        extended => 'FIXED',
    },
    {
        desc => 'comment with duplicate state sends status of CLOSED',
        state => 'duplicate',
        anon  => 0,
        status => 'CLOSED',
        extended => 'DUPLICATE',
    },
    {
        desc => 'comment with not reponsible state sends status of CLOSED',
        state => 'not responsible',
        anon  => 0,
        status => 'CLOSED',
        extended => 'NOT_COUNCILS_RESPONSIBILITY',
    },
    {
        desc => 'comment with unable to fix state sends status of CLOSED',
        state => 'unable to fix',
        anon  => 0,
        status => 'CLOSED',
        extended => 'NO_FURTHER_ACTION',
    },
    {
        desc => 'comment with internal referral state sends status of CLOSED',
        state => 'internal referral',
        anon  => 0,
        status => 'CLOSED',
        extended => 'INTERNAL_REFERRAL',
    },
    {
        desc => 'comment with closed state sends status of CLOSED',
        state => 'closed',
        status => 'CLOSED',
    },
    {
        desc => 'comment with investigating state sends status of OPEN',
        state => 'investigating',
        status => 'OPEN',
        extended => 'INVESTIGATING',
    },
    {
        desc => 'comment with planned state sends status of OPEN',
        state => 'planned',
        status => 'OPEN',
        extended => 'ACTION_SCHEDULED',
    },
    {
        desc => 'comment with action scheduled state sends status of OPEN',
        state => 'action scheduled',
        anon  => 0,
        status => 'OPEN',
        extended => 'ACTION_SCHEDULED',
    },
    {
        desc => 'comment with in progress state sends status of OPEN',
        state => 'in progress',
        status => 'OPEN',
        extended => 'IN_PROGRESS',
    },
    {
        desc => 'comment that marks problem open sends OPEN if not mark_reopen',
        state => 'confirmed',
        status => 'OPEN',
        extended => 'OPEN',
        mark_open => 1,
    },
    {
        desc => 'comment that marks problem open sends REOPEN if mark_reopen',
        state => 'confirmed',
        status => 'OPEN',
        extended => 'REOPEN',
        mark_open => 1,
        mark_reopen => 1,
    },
) {
    subtest $test->{desc} => sub {
        my $comment = make_comment();
        $comment->problem_state( $test->{state} );
        $comment->problem->state( $test->{state} );
        $comment->mark_open(1) if $test->{mark_open};

        my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );

        my $c = CGI::Simple->new( $results->{ req }->content );
        is $c->param('status'), $test->{status}, 'correct status';

        if ( $test->{extended} ) {
            my $params = { extended_statuses => 1 };
            $params->{mark_reopen} = 1 if $test->{mark_reopen};
            my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>', $params );
            my $c = CGI::Simple->new( $results->{ req }->content );
            is $c->param('status'), $test->{extended}, 'correct extended status';
        }
    };
}

for my $test (
    {
        desc => 'public comment sets public_anonymity_required to false',
        state => 'confirmed',
        anon  => 0,
        status => 'OPEN',
    },
    {
        desc => 'anonymous commment sets public_anonymity_required to true',
        state => 'confirmed',
        anon  => 1,
        status => 'OPEN',
    },
) {
    subtest $test->{desc} => sub {
        my $comment = make_comment('bromley');
        $comment->problem_state( $test->{state} );
        $comment->problem->state( $test->{state} );
        $comment->anonymous( $test->{anon} );

        my $results;
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'bromley',
        }, sub {
            $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );
        };

        my $c = CGI::Simple->new( $results->{ req }->content );
        is $c->param('public_anonymity_required'), $test->{anon} ? 'TRUE' : 'FALSE', 'correct anonymity';
    };
}

my $dt2 = $dt->clone;
$dt2->add( 'minutes' => 1 );

for my $test (
    {
        desc => 'comment with fixed - council state sends status of CLOSED even if problem is open',
        state => 'fixed - council',
        problem_state => 'confirmed',
        status => 'CLOSED',
        extended => 'FIXED',
    },
    {
        desc => 'comment marked open sends status of OPEN even if problem is closed',
        state => 'confirmed',
        problem_state => 'fixed - council',
        status => 'OPEN',
        extended => 'OPEN',
    },
    {
        desc => 'comment with no problem state falls back to report state',
        state => '',
        problem_state => 'fixed - council',
        status => 'CLOSED',
        extended => 'FIXED',
    },
) {
    subtest $test->{desc} => sub {
        my $comment = make_comment();
        $comment->problem_state( $test->{state} );
        $comment->problem->state( $test->{problem_state} );
        my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );

        my $c = CGI::Simple->new( $results->{ req }->content );
        is $c->param('status'), $test->{status}, 'correct status';

        if ( $test->{extended} ) {
            my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>', { extended_statuses => 1 } );
            my $c = CGI::Simple->new( $results->{ req }->content );
            is $c->param('status'), $test->{extended}, 'correct extended status';
        }
    };
}


for my $test (
    {
        desc         => 'update name name taken from comment over user',
        comment_name => 'First Last',
        user_name    => 'Personal Family',
        extra        => undef,
        first_name   => 'First',
        last_name    => 'Last'
    },
    {
        desc         => 'update name name taken from user if no comment name',
        comment_name => '',
        user_name    => 'Personal Family',
        extra        => undef,
        first_name   => 'Personal',
        last_name    => 'Family'
    },
    {
        desc         => 'update name taken from extra if available',
        comment_name => 'First Last',
        user_name    => 'Personal Family',
        extra        => { first_name => 'Forename', last_name => 'Surname', title => 'Ms' },
        first_name   => 'Forename',
        last_name    => 'Surname'
    },
  )
{
    subtest $test->{desc} => sub {
        my $comment = make_comment();
        $comment->name( $test->{comment_name} );
        $user->name( $test->{user_name} );
        $comment->extra( $test->{ extra } );

        my $results = make_update_req( $comment,
'<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>'
        );

        my $c = CGI::Simple->new( $results->{req}->content );
        is $c->param('first_name'), $test->{first_name}, 'first name correct';
        is $c->param('last_name'),  $test->{last_name},  'last name correct';
    };
}

for my $test (
    {
        desc             => 'use lat long forces lat long even if map not used',
        use_latlong      => 1,
        postcode         => 'EH99 1SP',
        used_map         => 0,
        includes_latlong => 1,
    },
    {
        desc => 'no use lat long and no map sends address instead of lat long',
        use_latlong      => 0,
        postcode         => 'EH99 1SP',
        used_map         => 0,
        includes_latlong => 0,
    },
    {
        desc             => 'no use lat long but used map sends lat long',
        use_latlong      => 0,
        postcode         => 'EH99 1SP',
        used_map         => 1,
        includes_latlong => 1,
    },
    {
        desc             => 'no use lat long, no map and no postcode sends lat long',
        use_latlong      => 0,
        postcode         => '',
        used_map         => 0,
        includes_latlong => 1,
    },
    {
        desc             => 'no use lat long, no map and no postcode sends lat long',
        use_latlong      => 0,
        notpinpoint      => 1,
        postcode         => '',
        used_map         => 0,
        includes_latlong => 0,
    }
) {
    subtest $test->{desc} => sub {
        my $extra = { url => 'http://example.com/report/1', };
        $problem->used_map( $test->{used_map} );
        $problem->postcode( $test->{postcode} );

        my $results = make_service_req(
            $problem,
            $extra,
            $problem->category,
            '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>',
            { always_send_latlong => $test->{use_latlong},
              send_notpinpointed => $test->{notpinpoint} },
        );

        is $results->{ res }, 248, 'got request id';

        my $c = CGI::Simple->new( $results->{ req }->content );

        if ( $test->{notpinpoint} ) {
            is $c->param('lat'), undef, 'no latitude';
            is $c->param('long'), undef, 'no longitude';
            is $c->param('address_string'), undef, 'no address';
            is $c->param('address_id'), '#NOTPINPOINTED#', 'has not pinpointed';
        } elsif ( $test->{includes_latlong} ) {
            ok $c->param('lat'), 'has latitude';
            ok $c->param('long'), 'has longitude';
            is $c->param('address_string'), undef, 'no address';
        } else {
            is $c->param('lat'), undef, 'no latitude';
            is $c->param('long'), undef, 'no latitude';
            is $c->param('address_string'), $test->{postcode}, 'has address';
        }
    };
}

$problem->send_fail_count(1);
my $comment = make_comment();
$comment->send_fail_count(1);

subtest 'No request id in reponse' => sub {
    my $results;
    warning_like {
        $results = make_service_req(
            $problem,
            { url => 'http://example.com/report/1' },
            $problem->category,
            '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id></service_request_id></request></service_requests>' 
        );
    } qr/Failed to submit problem \d+ over Open311/, 'correct error message for missing request_id';

    is $results->{ res }, 0, 'No request_id is a failure';
};

subtest 'Bad data in request_id element in reponse' => sub {
    my $results;
    warning_like {
        $results = make_service_req(
            $problem,
            { url => 'http://example.com/report/1' },
            $problem->category,
            '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id><bad_data>BAD</bad_data></service_request_id></request></service_requests>' 
        );
    } qr/Failed to submit problem \d+ over Open311/, 'correct error message for bad data in request_id';

    is $results->{ res }, 0, 'No request_id is a failure';
};

subtest 'No update id in reponse' => sub {
    my $results;
    warning_like {
        $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id></update_id></request_update></service_request_updates>' )
    } qr/Failed to submit comment \d+ over Open311/, 'correct error message for missing update_id';

    is $results->{ res }, 0, 'No update_id is a failure';
};

subtest 'error response' => sub {
    my $results;
    warning_like {
        $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><errors><error><code>400</code><description>There was an error</description</error></errors>' )
    } qr/Failed to submit comment \d+ over Open311.*There was an error/, 'correct error messages for general error';

    is $results->{ res }, 0, 'error in response is a failure';
};

for my $test (
    {
        desc              => 'deviceid not sent by default',
        use_service_as_id => 0,
        service           => 'iPhone',
    },
    {
        desc              => 'if use_service_as_id set then deviceid sent with service as id',
        use_service_as_id => 1,
        service           => 'iPhone',
    },
    {
        desc              => 'no deviceid sent if service is blank',
        use_service_as_id => 1,
        service           => '',
    },
  )
{
    subtest $test->{desc} => sub {
        my $extra = { url => 'http://example.com/report/1', };
        $problem->service( $test->{service} );

        my $results = make_service_req(
            $problem,
            $extra,
            $problem->category,
            '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>',
            { use_service_as_deviceid => $test->{use_service_as_id} },
        );

        is $results->{res}, 248, 'got request id';

        my $c = CGI::Simple->new( $results->{req}->content );

        if ( $test->{use_service_as_id} and $test->{service} ) {
            is $c->param('deviceid'), $test->{service}, 'deviceid set to service';
        }
        else {
            is $c->param('deviceid'), undef, 'no deviceid is set';
        }
    };
}

subtest 'check FixaMinGata' => sub {
    $problem->cobrand('fixamingata');
    $problem->detail("MØØse");
    my $extra = {
        url => 'http://example.com/report/1',
    };
    my $results = make_service_req( $problem, $extra, $problem->category, '<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>' );
    is $results->{ res }, 248, 'got request id';
    my $description = <<EOT;
Titel: a problem

Beskrivning: MØØse

Länk till ärendet: http://example.com/report/1

Skickad via FixaMinGata
EOT
;
    my $c = CGI::Simple->new( $results->{ req }->content );
    (my $c_description = $c->param('description')) =~ s/\r\n/\n/g;
    utf8::decode($c_description);
    is $c_description, $description, 'description correct';
};

done_testing();


sub make_update_req {
    my $comment = shift;
    my $xml = shift;
    my $open311_args = shift || {};

    my $params = {
        object       => $comment,
        xml          => $xml,
        method       => 'post_service_request_update',
        path         => 'servicerequestupdates.xml',
        open311_conf => $open311_args,
    };

    return _make_req( $params );
}

sub make_service_req {
    my $problem      = shift;
    my $extra        = shift;
    my $service_code = shift;
    my $xml          = shift;
    my $open311_args = shift || {};

    return _make_req(
        {
            object       => $problem,
            xml          => $xml,
            method       => 'send_service_request',
            path         => 'requests.xml',
            method_args  => [ $extra, $service_code ],
            open311_conf => $open311_args,
        }
    );
}

sub _make_req {
    my $args = shift;

    my $object       = $args->{object};
    my $xml          = $args->{xml};
    my $method       = $args->{method};
    my $path         = $args->{path};
    my %open311_conf = %{ $args->{open311_conf} || {} };
    my @args         = @{ $args->{method_args} || [] };

    $open311_conf{'test_mode'} = 1;
    $open311_conf{'end_point'} = 'http://localhost/o311';
    $open311_conf{fixmystreet_body} = $bromley;
    my $o =
      Open311->new( %open311_conf );

    my $test_res = HTTP::Response->new();
    $test_res->code(200);
    $test_res->message('OK');
    $test_res->content($xml);

    $o->test_get_returns( { $path => $test_res } );

    my $res = $o->$method($object, @args);

    my $req = $o->test_req_used;

    return { res => $res, req => $req, o => $o };
}
