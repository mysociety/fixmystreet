package FixMyStreet::DB::ResultSet::Contact;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub me { join('.', shift->current_source_alias, shift || q{})  }

=head2 not_deleted

    $rs = $rs->not_deleted();

Filter down to not deleted contacts - which have C<deleted> set to false;

=cut

sub not_deleted {
    my $rs = shift;
    return $rs->search( { $rs->me('deleted') => 0 } );
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
