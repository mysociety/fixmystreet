#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use FixMyStreet;
use FixMyStreet::App;
use mySociety::Locale;

mySociety::Locale::gettext_domain('FixMyStreet');

my $problem_rs = FixMyStreet::App->model('DB::Problem');

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
    }
);

is $problem->confirmed_local,  undef, 'inflating null confirmed ok';
is $problem->whensent_local,   undef, 'inflating null confirmed ok';
is $problem->lastupdate_local, undef, 'inflating null confirmed ok';
is $problem->created_local,  undef, 'inflating null confirmed ok';

for my $test ( 
    {
        desc => 'more or less empty problem',
        changed => {},
        errors => {
            title => 'Please enter a subject',
            detail => 'Please enter some details',
            council => 'No council selected',
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
            council => 'No council selected',
            name => 'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box',
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
            council => 'No council selected',
            name => 'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box',
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
            council => 'No council selected',
        }
    },
    {
        desc => 'correct title',
        changed => {
            title => 'A Title',
        },
        errors => {
            detail => 'Please enter some details',
            council => 'No council selected',
        }
    },
    {
        desc => 'correct detail',
        changed => {
            detail => 'Some information about the problem',
        },
        errors => {
            council => 'No council selected',
        }
    },
    {
        desc => 'incorrectly formatted council',
        changed => {
            council => 'my council',
        },
        errors => {
            council => 'No council selected',
        }
    },
    {
        desc => 'correctly formatted council',
        changed => {
            council => '1001',
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

for my $test (
    {
        desc => 'request older than problem ignored',
        lastupdate => '',
        request => {
            updated_datetime => DateTime::Format::W3CDTF->new()->format_datetime( DateTime->now()->set_time_zone( $tz_local )->subtract( days => 2 ) ),
        },
        council => {
            name => 'Edinburgh City Council',
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
        council => {
            name => 'Edinburgh City Council',
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
        council => {
            name => 'Edinburgh City Council',
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
        council => {
            name => 'Edinburgh City Council',
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

        my $ret = $problem->update_from_open311_service_request( $test->{request}, $test->{council}, $user );
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
        state => 'in progress',
        is_visible => 1,
        is_fixed    => 0,
        is_open     => 1,
        is_closed   => 0,
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

$problem->comments->delete;
$problem->delete;
$user->delete;

done_testing();
