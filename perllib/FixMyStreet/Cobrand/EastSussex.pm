package FixMyStreet::Cobrand::EastSussex;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_area_id { return 2224; }

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    my $contact = $row->category_row;
    my $fields = $contact->get_extra_fields;
    for my $field ( @$fields ) {
        if ($field->{variable} && !$field->{automated}) {
            my $text = $row->detail;
            my $q = $row->get_extra_field_value( $field->{code} ) || '';
            $text .= "\n\n" . $field->{description} . "\n" . $q;
            $row->detail($text);
        }
    }
}

sub open311_post_send {
    my ($self, $row, $h, $contact) = @_;

    my $fields = $contact->get_extra_fields;
    my $text = $row->detail;
    my $added = '';
    for my $field ( @$fields ) {
        if ($field->{variable} && !$field->{automated}) {
            my $q = $row->get_extra_field_value( $field->{code} ) || '';
            $added .= "\n\n" . $field->{description} . "\n" . $q;
        }
    }

    $text =~ s/\Q$added\E//;
    $row->detail($text);
}

1;
