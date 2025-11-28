=head1 NAME

BexleyContracts - handles contract ID lookup for Bexley pre-WasteWorks subscriptions.

=head1 SYNOPSIS

Bexley provided a CSV file of UPRN to contract ID mappings for garden waste
subscriptions that were created before the WasteWorks integration. This module
provides lookup functionality to find contract IDs for legacy subscriptions
that need to be cancelled.

The CSV is imported into a SQLite database by running:
C<bin/bexley/make-bexley-contract-db --csv=/path/to/csv>

=head1 DATABASE SCHEMA

The database contains a single contracts table which
stores UPRN, contract ID, and bank reference for each subscription.
Note that a single UPRN may have multiple contracts (e.g., if a property
subscribed, cancelled, and re-subscribed over time).

=cut

package BexleyContracts;

use strict;
use warnings;

use DBI;
use FixMyStreet;

=head2 database_file

Database is in C<../data/bexley-contracts.sqlite>

=cut

sub database_file {
    FixMyStreet->path_to('../data/bexley-contracts.sqlite');
}

sub connect_db {
    die $! unless -e database_file();

    return DBI->connect( 'dbi:SQLite:dbname=' . database_file(),
        undef, undef );
}

=head2 contract_ids_for_uprn

Given a UPRN, returns an arrayref of contract IDs associated with that property.
Returns an empty arrayref if no contracts are found.

A single UPRN may have multiple contract IDs if the property had multiple
subscriptions over time.

=cut

sub contract_ids_for_uprn {
    my $uprn = shift;

    my $db = connect_db() or return [];

    my $contracts = $db->selectall_arrayref(
        <<"SQL",
  SELECT contract_id
    FROM contracts
   WHERE uprn = ?
SQL
        { Slice => {} },
        $uprn,
    );

    return [ map { $_->{contract_id} } @$contracts ];
}

1;
