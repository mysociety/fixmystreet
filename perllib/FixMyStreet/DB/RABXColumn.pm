package FixMyStreet::DB::RABXColumn;

use strict;
use warnings;

use IO::String;
use RABX;

=head1 NAME

FixMyStreet::DB::RABXColumn

=head2 DESCRIPTION

This is a helper component that will setup the RABX serialisation for some
fields. This is useful for when you want to persist some data structure such as
hashrefs etc.

This code will also change the default FilterColumn behaviour so that whenever
your set a column, or specify a RABX'd column in an ->update the value is saved
to the database. The default behaviour is to check if the value is already set,
and for hashrefs this means that changes to the contents are missed as it is
still the same hashref.

By putting all this code in one place there is also much less repetition.

=cut

# Store which columns are RABX cols.
# $RABX_COLUMNS{$class}{$col} = 1
my %RABX_COLUMNS = ();

sub _get_class_identifier {
    my $class = ref $_[0] || $_[0];
    $class =~ s/.*?(\w+)$/$1/;
    return $class;
}

=head1 METHODS

=head2 rabx_column

    # In one of your ::Result:: modules
    __PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
    __PACKAGE__->rabx_column('data');

This sets up the filtering to and from the database, and also changes the
set_filtered_column behaviour to not trust the cache.

=cut

sub rabx_column {
    my ($class, $col) = @_;

    my $data_type = $class->column_info($col)->{data_type};

    # Apply the filtering for this column
    $class->filter_column(
        $col => {
            filter_from_storage => sub {
                my $self = shift;
                my $ser  = shift;
                return undef unless defined $ser;
                # Some RABX columns are text, when they should be bytea. For
                # these we must re-encode the string returned from the
                # database, so that it is decoded again by RABX.
                utf8::encode($ser) if $data_type ne 'bytea';
                my $h = new IO::String($ser);
                return RABX::wire_rd($h);
            },
            filter_to_storage => sub {
                my $self = shift;
                my $data = shift;
                my $ser  = '';
                my $h    = new IO::String($ser);
                RABX::wire_wr( $data, $h );
                # Some RABX columns are text, when they should be bytea. For
                # these, we must re-decode the string encoded by RABX, so that
                # it is encoded again when saved to the db.
                utf8::decode($ser) if $data_type ne 'bytea';
                return $ser;
            },
        }
    );

    # store that this column is a RABX column.
    $RABX_COLUMNS{ _get_class_identifier($class) }{$col} = 1;
}

sub set_filtered_column {
    my ($self, $col, $val) = @_;

    # because filtered objects may be expensive to marshall for storage there
    # is a cache that attempts to detect if they have changed or not. For us
    # this cache breaks things and our marshalling is cheap, so clear it when
    # trying set a column.
    delete $self->{_filtered_column}{$col}
        if $RABX_COLUMNS{ _get_class_identifier($self) }{$col};

    return $self->next::method($col, $val);
}


1;
