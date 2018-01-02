package FixMyStreet::DB::ResultSet::Body;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use POSIX qw(strcoll);

=head1 Name

FixMyStreet::DB::ResultSet::Body - a ResultSet class for the Body model.

=head1 Synopsis

    my @bodies = $rs->for_areas(1, 2)->active->with_area_count->translated->all_sorted;

=head1 Functions

=over

=item for_areas

This restricts the ResultSet to bodies covering the area IDs provided.

=cut

sub for_areas {
    my ( $rs, @areas ) = @_;

    my $result = $rs->search(
        { 'body_areas.area_id' => \@areas },
        { join => 'body_areas' }
    );
    return $result;
}

=item active

This restricts the ResultSet to bodies that are not marked as deleted.

=cut

sub active {
    my $rs = shift;
    $rs->search({ deleted => 0 });
}

=item translated

This joins the ResultSet to the translation table, adding the `msgstr`
column containing possible translations of the body name.

=cut

sub translated {
    my $rs = shift;
    my $schema = $rs->result_source->schema;
    $rs->search(undef, {
        '+columns' => { 'msgstr' => 'translations.msgstr' },
        join => 'translations',
        bind => [ 'name', $schema->lang, 'body' ],
    });
}

=item with_area_count

This adds the number of areas associated with each body to the ResultSet,
in the area_count column.

=cut

sub with_area_count {
    my $rs = shift;
    $rs->search(undef, {
        '+select' => [ { count => 'area_id' } ],
        '+as' => [ 'area_count' ],
        join => 'body_areas',
        distinct => 1,
    });
}

=item all_sorted

This returns all results, as C<all()>, but sorted by their name column
(which will be the translated names if present).

=back

=cut

sub all_sorted {
    my $rs = shift;
    my @bodies = $rs->all;
    @bodies = sort { strcoll($a->name, $b->name) } @bodies;
    return @bodies;
}

1;
