package FixMyStreet::TestMapIt;

use strict;
use warnings;
use FixMyStreet;
use mySociety::MaPit;
use Path::Tiny 'path';
use JSON;
use Data::Dumper;

my $orig = \&mySociety::MaPit::call;
my $cache_dir = path( FixMyStreet->config('GEO_CACHE'), 'mapit/' );
$cache_dir->mkpath;
my $cache_file = path( $cache_dir, 'cached.json' );

my $json = JSON->new->utf8->allow_nonref->canonical;

my $DATA;

sub import {

    my $offline = $ENV{OFFLINE_MAPIT} // 0;

    if ($offline eq 'DELETE') {
        $cache_file->remove;
        $offline = 0;
    }

    $DATA = $cache_file->is_file ? $json->decode( $cache_file->slurp_utf8 ) : {};

    my $new = sub ($$;%) {
        my $key = $json->encode( \@_ );

        if ($offline) {
            my $result_json = $DATA->{$key}
                or die "Offline mapit requested, but no object found for $key";
            return $json->decode($result_json);
        }
        else {
            my $result = $orig->(@_);
            my $result_json = $json->encode($result);
            $DATA->{$key} = $result_json;
            return $result;
        }
    };

    no strict 'refs'; no warnings 'redefine';
    *mySociety::MaPit::call = $new;
}

END {
    $cache_file->spew_utf8( $json->encode( $DATA ) );
}

1;
