package FixMyStreet::DB::ResultSet::UserPlannedReport;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub active {
    my $rs = shift;
    $rs->search({ removed => undef });
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
