use strict; use warnings;

use Test::More;
use Test::Exception;

use Data::Rx;
use Open311::Endpoint::Schema;

my $schema = Open311::Endpoint::Schema->new->schema;

subtest 'comma tests' => sub {

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

subtest 'datetime tests' => sub {

    dies_ok {
        my $comma = $schema->make_schema({
            type => '/open311/datetime',
            zirble => 'fleem',
        });
    } 'Construction dies on extra keys';

    my $dt = $schema->make_schema({
        type => '/open311/datetime',
    });

    ok ! $dt->check( undef ), 'Undef is not a valid string';
    ok ! $dt->check( [] ),    'Reference is not a valid string';

    ok ! $dt->check( '9th Feb 2012' ), 'invalid datetime format';

    ok $dt->check( '1994-11-05T08:15:30-05:00' ), 'datetime format with offset';
    ok $dt->check( '1994-11-05T08:15:30+05:00' ), 'datetime format with positive';
    ok $dt->check( '1994-11-05T13:15:30Z' ),      'datetime format zulu';
};

subtest 'identifier tests' => sub {
    my $id = $schema->make_schema( '/open311/example/identifier' );

    ok ! $id->check( undef ), 'Undef is not a valid string';
    ok ! $id->check( '' ), 'Empty string is not a valid identifier';
    ok ! $id->check( 'foo bar' ), 'String with spaces is not a valid identifier';

    ok $id->check( 'foo' ),     'Ascii word string is a valid identifier';
    ok $id->check( 'foo_bar' ), 'Ascii word string is a valid identifier';
    ok $id->check( 'foo_123' ), 'Ascii word/num string is a valid identifier';
};

done_testing;

1;
