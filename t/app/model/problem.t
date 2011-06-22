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

done_testing();
