package FixMyStreet::Cobrand::EastSussex;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_area_id { return 2224; }

sub open311_extra_data {
    my ($self, $row, $h, $contact) = @_;

    my $fields = $contact->get_extra_fields;
    my $text = '';
    for my $field ( @$fields ) {
        if (($field->{variable} || '') eq 'true' && !$field->{automated}) {
            my $q = $row->get_extra_field_value( $field->{code} ) || '';
            $text .= "\n\n" . $field->{description} . "\n" . $q;
        }
    }
    $row->detail($row->detail . $text);
    return (undef, ['sect_label', 'road_name', 'area_name']);
}

=head2 should_skip_sending_update

We do not currently send updates.

=cut

sub should_skip_sending_update {
    my ($self, $update ) = @_;
    return 1;
}

1;
