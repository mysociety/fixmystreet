use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

foreach my $council (qw/southampton reading bromley/) {
    SKIP: {
        skip( "Need '$council' in ALLOWED_COBRANDS config", 3 )
            unless FixMyStreet::Cobrand->exists($council);
        ok $mech->host("$council.fixmystreet.com"), "change host to $council";
        $mech->get_ok('/');
        $mech->content_like( qr/$council/i );
    }
}

done_testing();
