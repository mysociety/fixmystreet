package FixMyStreet::Roles::Translatable;

use Moo::Role;
use FixMyStreet;

has _translated  => (is => 'rw');

sub translated {
    my $self = shift;
    $self->_translated or $self->_translated({});
}

sub translate_around {
    my ($orig, $self) = (shift, shift);
    my $fallback = $self->$orig(@_);
    (my $col = (caller(2))[3]) =~ s/.*:://;
    $self->_translate($col, $fallback);
}

sub translate_column {
    my ($self, $col) = (shift, shift);
    my $fallback = $self->$col(@_);
    $self->_translate($col, $fallback);
}

sub _translate {
    my ($self, $col, $fallback) = @_;

    my $langs = FixMyStreet->config('LANGUAGES');
    return $fallback if !$langs || @$langs < 2;

    my %cols = $self->get_columns;
    return $cols{msgstr} if $cols{msgstr};

    my $schema = $self->result_source->schema;
    my $table = lc $self->result_source->source_name;
    my $id = $self->id;
    my $lang = $schema->lang || '';

    my $translated = $self->translated->{$col}{$lang};
    return $translated if $translated;

    if (ref $schema) {
        my $translation = $schema->resultset('Translation')->find({
            lang => $lang,
            tbl => $table,
            object_id => $id,
            col => $col
        });
        $fallback = $translation->msgstr if $translation;
    } else {
        warn "Can't use translation on this call to $table.$col";
    }
    $self->translated->{$col}{$lang} = $fallback;
    return $fallback;
};

# These next two functions (translation_for and and_translation_for) are
# convenience methods for use in the translation interface in the admin.
# They shouldn't be used else where as they don't take account of things
# like denormalised strings (e.g report category)
sub translation_for {
    my ($self, $col, $lang) = @_;

    my $schema = $self->result_source->schema;

    my $props = {
        tbl => lc $self->result_source->source_name,
        object_id => $self->id,
        col => $col
    };

    if ($lang) {
        $props->{lang} = $lang;
    }

    my $translations = $schema->resultset('Translation')->search($props);

    return $lang ? $translations->first : $translations;
}

sub add_translation_for {
    my ($self, $col, $lang, $msgstr) = @_;

    my $schema = $self->result_source->schema;

    my $props = {
        tbl => lc $self->result_source->source_name,
        object_id => $self->id,
        col => $col,
        lang => $lang,
        msgstr => $msgstr,
    };

    my $translation = $schema->resultset('Translation')->update_or_create(
        $props,
        { key => 'translation_tbl_object_id_col_lang_key' }
    );

    return $translation;
}

1;
