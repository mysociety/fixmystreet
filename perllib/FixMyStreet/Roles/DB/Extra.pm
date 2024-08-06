package FixMyStreet::Roles::DB::Extra;
use Moo::Role;
use JSON::MaybeXS;

with 'FixMyStreet::Roles::Syslog';
has log_ident => (
    is => 'ro',
    default => 'db_extra'
);

=head1 NAME

FixMyStreet::Roles::DB::Extra - role for accessing {extra} field

=head1 SYNOPSIS

This is to applied to a DB class like Problem or Contacts that has a rich {extra} field:

    use Moo;
    with 'FixMyStreet::Roles::DB::Extra';

Then:

    $contact->set_extra_fields(
        { name => 'pothole_size', ... },
        { name => 'pothole_shape, ... } );
    my $metas = $contact->get_extra_fields();

And

    # e.g. for sites like Zurich (but handled gracefully otherwise)
    $problem->set_extra_metadata( overdue => 1 );
    if ($problem->get_extra_metadata('overdue')) { ... }

=head1 METHODS

=cut

# Data out of the database is sorted by key length first. So in case we are
# comparing data straight out of there, decode/encode first so we know it will
# be the same layout
around _eq_column_values => sub {
    my ($orig, $self, $col, $old, $new) = @_;
    if ($col eq 'extra') {
        $old = $self->_column_to_storage($col, $self->_column_from_storage($col, $old));
    }
    return $self->$orig($col, $old, $new);
};

=head2 set_extra_metadata

    $problem->set_extra_metadata(overdue => 1);

=cut

sub set_extra_metadata {
    my ($self, %new) = @_;
    my $extra = $self->get_extra();

    if ($self->id) {
        $self->log('set_extra_metadata on ' . $self->id);
        $self->log($extra);
        $self->log(%new);
    }

    $self->extra({ %$extra, %new });
};

=head2 set_extra_metadata_if_undefined

    $problem->set_extra_metadata_if_undefined(overdue => 1);
    # as above, but won't set if, for example 'overdue' is already set to 0

=cut

sub set_extra_metadata_if_undefined {
    my ($self, $key, $value) = @_;
    my $extra = $self->get_extra();

    return if defined $extra->{$key};

    if ($self->id) {
        $self->log('set_extra_metadata_if_undefined on ' . $self->id);
        $self->log($extra);
        $self->log($key);
        $self->log($value);
    }

    $self->extra({ %$extra, $key => $value });
};

=head2 unset_extra_metadata

    $contact->unset_extra_metadata('photo_required');

=cut

sub unset_extra_metadata {
    my ($self, $key) = @_;
    my $extra = $self->get_extra();

    return 1 unless exists $extra->{$key};
    delete $extra->{$key};
    $self->extra($extra);
};

=head2 update_extra_metadata

This immediately updates the database with the new data (so update in the
DBIx::Class sense, not like update_extra_field), using the PostgreSQL ||
operator, to not affect anything else in the column. It then refetches the
data from the database so as to be up-to-date. Other changes on the object
will be saved, apart from any changes already made to extra.

=cut

sub update_extra_metadata {
    my ($self, %new) = @_;

    $self->update({
        extra => \[ "coalesce(extra, '{}') || ?", encode_json(\%new) ],
    });
    $self->discard_changes;
}

=head2 get_extra_metadata

    my $metadata = $problem->get_extra_metadata;
    my $overdue = $problem->get_extra_metadata('overdue');
    my $type = $problem->get_extra_metadata('type', '');

=cut

my $META_FIELD = '_fields';

sub get_extra_metadata {
    my ($self, $key, $default) = @_;
    my $extra = $self->get_extra();

    my %extra = %$extra;
    delete $extra{$META_FIELD};
    return $key ? ($extra{$key} // $default) : \%extra;
};

=head2 get_extra_fields

    my $metas = $problem->get_extra_fields();

=cut

sub get_extra_fields {
    my ($self) = @_;
    my $extra = $self->get_extra();

    return $extra->{$META_FIELD} ||= do {
        my $metas = [];
        $self->extra({ %$extra, $META_FIELD => $metas });
        $metas;
    };
}

=head2 set_extra_fields

    $problem->set_extra_fields( { ... }, { ... } );

=cut

sub set_extra_fields {
    my ($self, @fields) = @_;
    my $extra = $self->get_extra();

    if ($self->id) {
        $self->log('set_extra_fields on ' . $self->id);
        $self->log($extra);
        $self->log(@fields);
    }

    $self->extra({ %$extra, $META_FIELD => \@fields });
}

=head2 push_extra_fields

    $problem->push_extra_fields( { ... } );

like set_extra_fields, but pushes the new fields onto the end of the existing list.

=cut

sub push_extra_fields {
    my ($self, @fields) = @_;
    my $extra = $self->get_extra();

    my $existing = $self->get_extra_fields;

    if ($self->id) {
        $self->log('push_extra_fields on ' . $self->id);
        $self->log($extra);
        $self->log(@fields);
        $self->log($existing);
    }

    $self->extra({ %$extra, $META_FIELD => [ @$existing, @fields ] });
}

=head2 update_extra_field

    $problem->update_extra_field( { ... } );

Given an extra field, will replace one with the same code in the
existing list of fields, or add to the end if not present.
Returns true if it was already present, false if newly added.

=cut

sub update_extra_field {
    my ($self, $field) = @_;

    # Can operate on list that uses code (Contact) or name (Problem),
    # but make sure we have one of them
    my $attr;
    $attr = 'code' if $field->{code};
    $attr = 'name' if $field->{name};
    die unless $attr;

    my $existing = $self->get_extra_fields;
    my $found;
    foreach (@$existing) {
        if ($_->{$attr} eq $field->{$attr}) {
            $_ = $field;
            $found = 1;
        }
    }
    if (!$found) {
        push @$existing, $field;
    }

    $self->set_extra_fields(@$existing);
    return $found;
}

=head2 remove_extra_field

    $problem->remove_extra_field( $code );

Given an extra field code, will remove it from the list of fields.

=cut

sub remove_extra_field {
    my ($self, $code) = @_;

    my @fields = @{ $self->get_extra_fields() };
    @fields = grep { ($_->{code} || $_->{name}) ne $code } @fields;
    $self->set_extra_fields(@fields);
}

=head1 HELPER METHODS

For internal use mostly.

=head2 dirty_extra

Set the extra field as dirty.  (e.g. signalling that the DB object should be
updated).

=cut

sub dirty_extra {
    my $self = shift;
    $self->make_column_dirty('extra');
    return 1;
}

=head2 get_extra

Get the extra data.  If this is not set, then returns a {}

=cut

sub get_extra {
    my ($self) = @_;
    my $extra = $self->extra or do {
        my $extra = {};
        $self->extra({});
        return $extra;
    };

    if (ref $extra eq 'ARRAY') {
        # upgrade layout transparently
        $extra = { $META_FIELD => $extra };
        $self->extra($extra);
    }

    return $extra;
}

=head2 get_extra_field_value

Return the value of a field stored in `_fields` in extra, or undefined if
it's not present.

=cut

sub get_extra_field_value {
    my ($self, $name) = @_;

    my @fields = @{ $self->get_extra_fields() };

    my ($field) = grep { $_->{name} eq $name } @fields;
    return $field->{value};
}

=head2 get_extra_field

    my $field = $problem->get_extra_field(name => 'field_name');

Return a field stored in `_fields` in extra, or undefined if it's not present.
Can use either `name` or `code` to identify the field.

=cut

sub get_extra_field {
    my ($self, %opts) = @_;

    my @fields = @{ $self->get_extra_fields() };

    my $comparison = $opts{code} ? 'code' : 'name';

    my ($field) = grep { $_->{$comparison} && $_->{$comparison} eq $opts{$comparison} } @fields;
    return $field;
}

1;
