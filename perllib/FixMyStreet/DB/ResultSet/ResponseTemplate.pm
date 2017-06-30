package FixMyStreet::DB::ResultSet::ResponseTemplate;
use base 'DBIx::Class::ResultSet';

use Moo;
use HTML::Entities;

with('FixMyStreet::Roles::ContactExtra');

sub join_table {
    return 'contact_response_templates';
}

sub name_column {
    'title';
}

sub map_extras {
    my ($rs, @ts) = @_;
    return map {
        my $out = { id => encode_entities($_->text), name => encode_entities($_->title) };
        $out->{state} = encode_entities($_->state) if $_->state;
        $out;
    } @ts;
}

1;

