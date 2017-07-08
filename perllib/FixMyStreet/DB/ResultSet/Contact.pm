package FixMyStreet::DB::ResultSet::Contact;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub me { join('.', shift->current_source_alias, shift || q{})  }

=head2 not_deleted

    $rs = $rs->not_deleted();

Filter down to not deleted contacts (so active or inactive).

=cut

sub not_deleted {
    my $rs = shift;
    return $rs->search( { $rs->me('state') => { '!=' => 'deleted' } } );
}

sub active {
    my $rs = shift;
    $rs->search( { $rs->me('state') => [ 'unconfirmed', 'confirmed' ] } );
}

sub summary_count {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        $restriction,
        {
            group_by => ['state'],
            select   => [ 'state', { count => 'id' } ],
            as       => [qw/state state_count/]
        }
    );
}

1;
