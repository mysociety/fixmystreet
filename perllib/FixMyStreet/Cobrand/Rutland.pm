=head1 NAME

FixMyStreet::Cobrand::Rutland - code specific to the Rutland cobrand

=head1 SYNOPSIS

Rutland is a unitary authority, with a Salesforce backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Rutland;
use base 'FixMyStreet::Cobrand::UKCouncils';

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::Cobrand::OpenUSRN';
with 'FixMyStreet::Roles::Open311Multi';

use strict;
use warnings;

sub council_area_id { return 2600; }
sub council_area { return 'Rutland'; }
sub council_name { return 'Rutland County Council'; }
sub council_url { return 'rutland'; }

=over 4

=item * Rutland's Salesforce endpoint only allows titles up to 254 characters and names up to 40 characters in length.
But their Confirm backend uses the Confirm Role validation

=cut

around report_validation => sub {
    my ($orig, $self) = (shift, shift);

    my ($report, $errors) = @_;
    my $contact = FixMyStreet::DB->resultset('Contact')->find({
        body_id => $self->body->id,
        category => $report->category,
    });

    if ($contact->email =~ /^Confirm-/) {
        $self->$orig(@_);
    } else {
        if ( length( $report->title ) > 254 ) {
            $errors->{title} = sprintf( _('Summaries are limited to %s characters in length. Please shorten your summary'), 254 );
        }

        if ( length( $report->name ) > 40 ) {
            $errors->{name} = sprintf( _('Names are limited to %d characters in length.'), 40 );
        }

        return $errors;
    }
};

=item * It copes with multiple photos.

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
}

=item * SalesForce receives specified extra data, but Confirm uses default from ConfirmOpen311 role

=cut

around open311_extra_data_include => sub {
    my ($orig, $self) = (shift, shift);
    my ($row, $h, $contact) = @_;

    my $data = $self->$orig(@_);

    if ($contact->email !~ /^Confirm-/) {
        push @$data, (
                      { name => 'external_id', value => $row->id },
                      $h->{closest_address} ? { name => 'closest_address', value => "$h->{closest_address}" } : (),
                     );
    };

    return $data;
};

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
        result_strip => ', Rutland, England',
        bounds => [52.524755166940075, -0.8217480325342802, 52.7597945702699, -0.4283542728893742]
    };
}

=item * Rutland does not send questionnaires, or ask whether you've reported before.

=cut

sub send_questionnaires { 0 }

sub ask_ever_reported {
    return 0;
}

=item * Rutland's map defaults to showing open reports only.

=back

=cut

sub on_map_default_status { 'open' }

=item * Customised pin colours

Rutland have
- Cross icon - grey - for closed
- Tick icon - green - for fixed
- Traffic cone icon - yellow - for open (confirmed)
- Roadworker icon - orange - for in progress/investigating

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    return 'grey-cross' if $p->is_closed || ($context ne 'reports' && !$self->owns_problem($p));
    return 'green-tick' if $p->is_fixed;
    return 'yellow-cone' if $p->state eq 'confirmed';
    return 'orange-work'; # all the other `open_states` like "in progress"
}

1;
