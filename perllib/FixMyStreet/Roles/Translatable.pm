package FixMyStreet::Roles::Translatable;

use Moo::Role;

sub translate_around {
    my ($orig, $self) = (shift, shift);
    my $fallback = $self->$orig(@_);
    (my $col = (caller(2))[3]) =~ s/.*:://;
    $self->_translate($col, $fallback);
}

sub translate {
    my ($self, $col) = (shift, shift);
    my $fallback = $self->$col(@_);
    $self->_translate($col, $fallback);
}

sub _translate {
    my ($self, $col, $fallback) = @_;

    my $schema = $self->result_source->schema;
    my $table = lc $self->result_source->source_name;
    my $id = $self->id;

    if (ref $schema) {
        my $translation = $schema->resultset('Translation')->find({
            lang => $schema->lang,
            tbl => $table,
            object_id => $id,
            col => $col
        });
        return $translation->msgstr if $translation;
    } else {
        warn "Can't use translation on this call to $table.$col";
    }
    return $fallback;
};

1;
