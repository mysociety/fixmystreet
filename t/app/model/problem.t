#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use FixMyStreet;
use FixMyStreet::App;

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
