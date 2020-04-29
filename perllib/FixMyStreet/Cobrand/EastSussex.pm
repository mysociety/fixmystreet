package FixMyStreet::Cobrand::EastSussex;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_area_id { return 2224; }

sub open311_extra_data {
    my ($self, $row, $h, $extra, $contact) = @_;

    $h->{es_original_detail} = $row->detail;

    $contact = $row->category_row;
    my $fields = $contact->get_extra_fields;
    my $text = '';
    for my $field ( @$fields ) {
        if (($field->{variable} || '') eq 'true' && !$field->{automated}) {
            my $q = $row->get_extra_field_value( $field->{code} ) || '';
            $text .= "\n\n" . $field->{description} . "\n" . $q;
        }
    }
    $row->detail($row->detail . $text);
    return ();
}

sub open311_post_send {
    my ($self, $row, $h, $contact) = @_;

    $row->detail($h->{es_original_detail});
}

1;
