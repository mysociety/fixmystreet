=head1 NAME

FixMyStreet::Cobrand::Rutland - code specific to the Rutland cobrand

=head1 SYNOPSIS

Rutland is a unitary authority, with a Salesforce backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Rutland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2600; }
sub council_area { return 'Rutland'; }
sub council_name { return 'Rutland County Council'; }
sub council_url { return 'rutland'; }

=over 4

=item * Rutland's endpoint only allows titles up to 254 characters and names up to 40 characters in length.

=cut

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->title ) > 254 ) {
        $errors->{title} = sprintf( _('Summaries are limited to %s characters in length. Please shorten your summary'), 254 );
    }

    if ( length( $report->name ) > 40 ) {
        $errors->{name} = sprintf( _('Names are limited to %d characters in length.'), 40 );
    }

    return $errors;
}

=item * It copes with multiple photos.

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
}

=item * It receives some extra data, such as the FixMyStreet ID, closest address, and title/detail in separate fields.

=cut

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    return [
        { name => 'external_id', value => $row->id },
        { name => 'title', value => $row->title },
        { name => 'description', value => $row->detail },
        $h->{closest_address} ? { name => 'closest_address', value => "$h->{closest_address}" } : (),
    ];
}

=item * It provides extra hints to be shown alongside category/group options in the reporting interface.

=cut

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    my ($hint) = grep { $_->{code} eq 'hint' } @$meta;
    my ($group_hint) = grep { $_->{code} eq 'group_hint' } @$meta;
    @$meta = grep { $_->{code} ne 'hint' && $_->{code} ne 'group_hint' } @$meta;

    # Rutland provide HTML that we want to store for display on the frontend.
    $contact->set_extra_metadata(
        category_hint => $hint->{description},
        group_hint => $group_hint->{description},
    );
}

=item * We try and restrict geocoding to the bounding box of Rutland.

=cut

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        bounds => [52.524755166940075, -0.8217480325342802, 52.7597945702699, -0.4283542728893742]
    };
}

=item * Rutland does not send questionnaires, or ask whether you've reported before.

=cut

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

=item * Rutland's map defaults to showing open reports only.

=back

=cut

sub on_map_default_status { 'open' }

1;
