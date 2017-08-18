package FixMyStreet::DB::ResultSet::UserPlannedReport;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub active {
    my $rs = shift;

    # If we have been prefetched we can't use `active` as that'll blow away the
    # cache and query the DB due to the `removed IS NULL` clause. So let's do
    # the filtering here instead, if the query has been prefetched.
    if ( $rs->get_cache ) {
        my @users = grep { !defined($_->removed) } $rs->all;
        $rs->set_cache(\@users);
        $rs;
    } else {
        $rs->search({ removed => undef });
    }
}

sub for_report {
    my $rs = shift;
    my $problem_id = shift;
    $rs->search({ report_id => $problem_id });
}

sub remove {
    my $rs = shift;
    $rs->update({ removed => \'current_timestamp' });
}

1;
