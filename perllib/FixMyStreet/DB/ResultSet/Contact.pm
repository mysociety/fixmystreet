package FixMyStreet::DB::ResultSet::Contact;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

=head2 not_deleted

    $rs = $rs->not_deleted();

Filter down to not deleted contacts - which have C<deleted> set to false;

=cut

sub not_deleted {
    my $rs = shift;
    return $rs->search( { deleted => 0 } );
}

sub summary_count {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        $restriction,
        {
            group_by => ['confirmed'],
            select   => [ 'confirmed', { count => 'id' } ],
            as       => [qw/confirmed confirmed_count/]
        }
    );
}

1;
