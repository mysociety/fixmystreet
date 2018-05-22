package FixMyStreet::DB::ResultSet::ResponseTemplate;
use base 'DBIx::Class::ResultSet';

use Moo;

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
        my $out = { id => $_->text, name => $_->title };
        $out->{state} = $_->state if $_->state;
        $out;
    } @ts;
}

1;

