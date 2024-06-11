package FixMyStreet::DB::ResultSet::ResponseTemplate;
use base 'FixMyStreet::DB::ResultSet';

use Moo;

with('FixMyStreet::Roles::DB::ContactExtra');

sub join_table {
    return 'contact_response_templates';
}

sub name_column {
    'title';
}

sub map_extras {
    my ($rs, $params, @ts) = @_;
    return map {
        my $out = { id => $_->text, name => $_->title };
        $out->{state} = $_->state if $_->state;
        $out;
    } @ts;
}

1;

