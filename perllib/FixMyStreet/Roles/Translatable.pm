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

    # Deal with the fact problem table has denormalized copy of category string
    if ($table eq 'problem' && $col eq 'category') {
        my $body_id = $self->bodies_str_ids->[0];
        return $fallback unless $body_id && $body_id =~ /^[0-9]+$/;
        my $contact = $schema->resultset("Contact")->find( {
            body_id => $body_id,
            category => $fallback,
        } );
        return $fallback unless $contact; # Shouldn't happen, but some tests
        $table = 'contact';
        $id = $contact->id;
    }

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
