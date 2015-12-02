package FixMyStreet::Roles::Extra;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::Extra - role for accessing {extra} field

=head1 SYNOPSIS

This is to applied to a DB class like Problem or Contacts that has a rich {extra} field:

    use Moo;
    with 'FixMyStreet::Roles::Extra';

Then:

    $contact->set_extra_fields(
        { name => 'pothole_size', ... },
        { name => 'pothole_shape, ... } );
    my $metas = $contact->get_extra_fields();

And

    # e.g. for sites like Zurich (but handled gracefully otherwise)
    $problem->set_extra_metadata( overdue => 1 );
    if ($problem->get_extra_metadata( 'overdue')) { ... }

=head1 METHODS

=head2 set_extra_metadata

    $problem->set_extra_metadata( overdue => 1);

=cut

sub set_extra_metadata {
    my ($self,  $key, $value) = @_;
    my $extra = $self->get_extra();

    $self->extra({ %$extra, $key => $value });
};

=head2 set_extra_metadata_if_undefined

    $problem->set_extra_metadata_if_undefined( overdue => 1);
    # as above, but won't set if, for example 'overdue' is already set to 0

=cut

sub set_extra_metadata_if_undefined {
    my ($self, $key, $value) = @_;
    my $extra = $self->get_extra();

    return if defined $extra->{$key};
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

=head2 get_extra_metadata

    my $overdue = $problem->get_extra_metadata('overdue');

=cut

sub get_extra_metadata {
    my ($self, $key) = @_;
    my $extra = $self->get_extra();

    return $extra->{$key};
};

=head2 get_extra_metadata_as_hashref

    my $hashref = $contact->get_extra_metadata_as_hashref();

=cut

my $META_FIELD = '_fields';

sub get_extra_metadata_as_hashref {
    my ($self) = @_;
    my $extra = $self->get_extra();

    my %extra = %$extra;
    delete $extra{$META_FIELD};
    return \%extra;
}

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

    $self->extra({ %$extra, $META_FIELD => [ @$existing, @fields ] });
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

1;
