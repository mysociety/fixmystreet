use strict; use warnings;

use Test::More;
use Test::Exception;

use Data::Rx;
use Open311::Endpoint::Schema;

my $schema = Open311::Endpoint::Schema->new->schema;

subtest 'enum schema' => sub {

    dies_ok {
        my $comma = $schema->make_schema({
            type => '/open311/comma',
        });
    } 'Construction dies on no contents';

    dies_ok {
        my $comma = $schema->make_schema({
            type => '/open311/comma',
            contents => '/open311/status',
            zirble => 'fleem',
        });
    } 'Construction dies on extra arguments';

    my $comma = $schema->make_schema({
        type => '/open311/comma',
        contents => '/open311/status',
        trim => 1,
    });

    ok ! $comma->check( undef ), 'Undef is not a valid string';
    ok ! $comma->check( [] ),    'Reference is not a valid string';

    ok ! $comma->check( 'zibble' ),      'invalid string';
    ok ! $comma->check( 'open,zibble' ),  'an invalid element';

    ok $comma->check( 'open' ),         'single value';
    ok $comma->check( 'open,closed' ), 'multiple values ok';
    ok $comma->check( 'open, closed ' ), 'spaces trimmed ok';
};

done_testing;

1;
