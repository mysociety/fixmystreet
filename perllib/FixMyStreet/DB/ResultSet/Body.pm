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
    $rs->search({ 'me.deleted' => 0 });
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

=item with_parent_name

This adds the parent name associated with each body to the ResultSet,
in the parent_name column.

=cut

sub with_parent_name {
    my $rs = shift;
    $rs->search(undef, {
        '+select' => [ 'parent.name' ],
        '+as' => [ 'parent_name' ],
        join => 'parent',
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

=item with_defect_type_count

This adds the number of defect types associated with each body to the
ResultSet, in the defect_type_count column.

=cut

sub with_defect_type_count {
    my $rs = shift;
    $rs->search(undef, {
        '+select' => [ { count => 'defect_types.name' } ],
        '+as' => [ 'defect_type_count' ],
        join => 'defect_types',
        distinct => 1,
    });
}

=item with_children_count

This adds the number of children associated with each body to the
ResultSet, in the children_count column.

=cut

sub with_children_count {
    my $rs = shift;
    $rs->search(undef, {
        '+select' => [ { count => 'bodies.id' } ],
        '+as' => [ 'children_count' ],
        join => 'bodies',
        distinct => 1,
    });
}

=item all_sorted

This returns all results, as C<all()>, but sorted by their name (including
the translated names, if present), and as simple hashrefs not objects, for
performance reasons.

=back

=cut

sub all_sorted {
    my $rs = shift;

    # Use a HashRefInflator here to return simple hashrefs rather than full
    # objects. This is quicker if you have a large number of bodies; note
    # fetching only the columns you need provides even more of a speed up.
    my @bodies = $rs->search(undef, {
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    })->all;
    @bodies = sort { strcoll($a->{msgstr} || $a->{name}, $b->{msgstr} || $b->{name}) } @bodies;

    my $cobrand = $rs->result_source->schema->cobrand;

    foreach my $body (@bodies) {
        $body->{parent} = { id => $body->{parent}, name => $body->{parent_name} } if $body->{parent};

        # DEPRECATED: url(c, query_params) -> url
        $body->{url} = sub {
            my ($c, $args) = @_;
            return FixMyStreet::DB::Result::Body::_url($body, $cobrand, $args);
        };

        # DEPRECATED: get_column('area_count') -> area_count
        next unless defined $body->{area_count};
        $body->{get_column} = sub {
            my $key = shift;
            return $body->{$key};
        };
    }

    return @bodies;
}

1;
