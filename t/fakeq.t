use strict;
use warnings;

use Test::More;

use_ok 'FixMyStreet::FakeQ';

# create a new object and check that it returns what we want.
my $fake_q = FixMyStreet::FakeQ->new(
    {
        params => { foo => 'bar' },    #
        site => 'boing'
    }
);

is $fake_q->{site}, 'boing', 'got site verbatim';
is $fake_q->param('foo'),     'bar', 'got set param';
is $fake_q->param('not_set'), undef, 'got undef for not set param';

# check that setting site to 'default' gets translated to fixmystreet
is FixMyStreet::FakeQ->new( { site => 'default' } )->{site}, 'fixmystreet',
  "'default' site becomes 'fixmystreet'";

done_testing();
