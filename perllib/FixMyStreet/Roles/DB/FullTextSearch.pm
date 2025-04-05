package FixMyStreet::Roles::DB::FullTextSearch;

use Moo::Role;
use FixMyStreet;

requires 'text_search_columns';
requires 'text_search_nulls';
requires 'text_search_translate';

sub search_text {
    my ($rs, $query) = @_;
    my %nulls = map { $_ => 1 } $rs->text_search_nulls;
    my @cols = map {
        my $col = $rs->me($_);
        $nulls{$_} ? "coalesce($col, '')" : $col;
    } $rs->text_search_columns;
    my $vector = join(" || ' ' || ", @cols);
    my $bind = '?';
    if (my $trans = $rs->text_search_translate) {
        my $replace = ' ' x length $trans;
        $vector = "translate($vector, '$trans', '$replace')";
        $bind = "translate(?, '$trans', '$replace')";
    }
    my $config = FixMyStreet->config('DB_FULL_TEXT_SEARCH_CONFIG') || 'english';
    $rs->search(\[ "to_tsvector('$config', $vector) @@ plainto_tsquery('$config', $bind)", $query ]);
}

1;

