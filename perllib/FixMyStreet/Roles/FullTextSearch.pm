package FixMyStreet::Roles::FullTextSearch;

use Moo::Role;
use FixMyStreet;

requires 'text_search_columns';

sub search_text {
    my ($rs, $query) = @_;
    my @cols = map { $rs->me($_) } $rs->text_search_columns;
    my $vector = "translate(" . join(" || ' ' || ", @cols) . ", '/.', '  ')";
    my $config = FixMyStreet->config('DB_FULL_TEXT_SEARCH_CONFIG') || 'english';
    $rs->search(\[ "to_tsvector('$config', $vector) @@ plainto_tsquery('$config', ?)", $query ]);
}

1;

