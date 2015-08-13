#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use FixMyStreet;
use FixMyStreet::App;

my %tests = (
    nested_hash => { foo => 'bar', and => [ 'baz', 'bundy' ] },
    array  => [ 'foo', 'bar' ],
    scalar => 123,
);

my $token_rs = FixMyStreet::App->model('DB::Token');

foreach my $test_data_name ( sort keys %tests ) {
    my $test_data = $tests{$test_data_name};

    pass "--- testing token creation using '$test_data_name'";

    my $dbic_token =
      $token_rs->create( { scope => 'testing', data => $test_data } );
    my $token = $dbic_token->token;
    ok $token, "stored token '$token'";

    is_deeply $dbic_token->data, $test_data, "data stored correctly";

    # read back from database
    is_deeply $token_rs->find( { token => $token, scope => 'testing' } )->data,
      $test_data,
      "data read back correctly";

    # delete token
    ok $dbic_token->delete, "delete token";

    is $token_rs->find( { token => $token, scope => 'testing' } ),
      undef,
      "token gone";
}

# Test that the inflation and deflation works as expected
{
    my $token =
      $token_rs->create( { scope => 'testing', data => {} } );
    END { $token->delete() };

    # Add in temporary check to test that the data is updated as expected.
    is_deeply($token->data, {}, "data is empty");

    # store something in it
    $token->update({ data => { foo => 'bar' } });
    $token->discard_changes();
    is_deeply($token->data, { foo => 'bar' }, "data has content");

    # change the hash stored
    $token->update({ data => { baz => 'bundy' } });
    $token->discard_changes();
    is_deeply($token->data, { baz => 'bundy' }, "data has new content");

    # change the hashref in place
    {
        my $data = $token->data;
        $data->{baz} = 'new';
        $token->data( $data );
        $token->update();
        $token->discard_changes();
        is_deeply($token->data, { baz => 'new' }, "data has been updated");
    }

    # change the hashref in place
    {
        my $data = $token->data;
        $data->{baz} = 'new';
        $token->update({ data => $data });
        $token->discard_changes();
        is_deeply($token->data, { baz => 'new' }, "data has been updated");
    }

}

done_testing();
