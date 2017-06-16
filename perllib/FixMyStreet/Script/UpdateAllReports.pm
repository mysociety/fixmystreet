package FixMyStreet::Script::UpdateAllReports;

use strict;
use warnings;

use FixMyStreet;
use FixMyStreet::DB;

use File::Path ();
use File::Slurp;
use JSON::MaybeXS;
use List::MoreUtils qw(zip);

my $fourweeks = 4*7*24*60*60;

# Age problems from when they're confirmed, except on Zurich
# where they appear as soon as they're created.
my $age_column = 'confirmed';
if ( FixMyStreet->config('BASE_URL') =~ /zurich|zueri/ ) {
    $age_column = 'created';
}

sub generate {
    my $problems = FixMyStreet::DB->resultset('Problem')->search(
        {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        },
        {
            columns => [
                'id', 'bodies_str', 'state', 'areas', 'cobrand',
                { duration => { extract => "epoch from current_timestamp-lastupdate" } },
                { age      => { extract => "epoch from current_timestamp-$age_column"  } },
            ]
        }
    );
    $problems = $problems->cursor; # Raw DB cursor for speed

    my ( %fixed, %open );
    my @cols = ( 'id', 'bodies_str', 'state', 'areas', 'cobrand', 'duration', 'age' );
    while ( my @problem = $problems->next ) {
        my %problem = zip @cols, @problem;
        my @bodies;
        my $cobrand = $problem{cobrand};

        if ( !$problem{bodies_str} ) {
            # Problem was not sent to any bodies, add to all areas
            @bodies = grep { $_ } split( /,/, $problem{areas} );
            $problem{bodies} = 0;
        } else {
            # Add to bodies it was sent to
            @bodies = split( /,/, $problem{bodies_str} );
            $problem{bodies} = scalar @bodies;
        }
        foreach my $body ( @bodies ) {
            my $duration_str = ( $problem{duration} > 2 * $fourweeks ) ? 'old' : 'new';
            my $type = ( $problem{duration} > 2 * $fourweeks )
                ? 'unknown'
                : ($problem{age} > $fourweeks ? 'older' : 'new');
            if (FixMyStreet::DB::Result::Problem->fixed_states()->{$problem{state}} || FixMyStreet::DB::Result::Problem->closed_states()->{$problem{state}}) {
                # Fixed problems are either old or new
                $fixed{$body}{$duration_str}++;
                $fixed{$cobrand}{$body}{$duration_str}++;
            } else {
                # Open problems are either unknown, older, or new
                $open{$body}{$type}++;
                $open{$cobrand}{$body}{$type}++;
            }
        }
    }

    my $body = encode_json( {
        fixed => \%fixed,
        open  => \%open,
    } );

    File::Path::mkpath( FixMyStreet->path_to( '../data/' )->stringify );
    File::Slurp::write_file( FixMyStreet->path_to( '../data/all-reports.json' )->stringify, \$body );
}

1;
