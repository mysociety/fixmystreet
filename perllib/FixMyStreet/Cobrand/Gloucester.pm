=head1 NAME

FixMyStreet::Cobrand::Gloucester - code specific to the Gloucester cobrand

=head1 SYNOPSIS

We integrate with Gloucester's Alloy back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Gloucester;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';

=head2 Defaults

=over 4

=cut

sub council_area_id { '2325' }
sub council_area { 'Gloucester' }
sub council_name { 'Gloucester City Council' }
sub council_url { 'gloucester' }

=item * Users with a gloucester.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'gloucester.gov.uk' }

=item * Gloucester use their own privacy policy

=cut

sub privacy_policy_url {
    'https://www.gloucester.gov.uk/about-the-council/data-protection-and-freedom-of-information/data-protection/'
}

=item * Doesn't allow the reopening of reports

=cut

sub reopening_disallowed { 1 }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Override the default text for entering a postcode or street name

=cut

sub enter_postcode_text {
    return 'Enter a Gloucester postcode or street name';
}

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=item * It has a default map zoom of 3

=cut

sub default_map_zoom { 5 }

=item * Ignores some categories that are not relevant to Gloucester

=cut

sub categories_restriction {
    my ($self, $rs) = @_;

    return $rs->search({
        'me.category' => {
            -not_in => [
                'Giant Hogweed',
                'Himalayan Balsam',
                'Japanese Knotweed',
                'Nettles, brambles, dandelions etc.',
                'Ragwort',
            ],
            -not_like => 'Ash Tree located on%',
        },
    });
}

=item * TODO: Don't show reports before the go-live date

=cut

# sub cut_off_date { '2024-03-31' }

=pod

=back

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Gloucester';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.8493825813624,-2.24025312382298',
        span   => '0.0776436939868574,0.12409536555503',
        bounds => [
            51.8075803711933, -2.30135343437398,
            51.8852240651802, -2.17725806881895
        ],
    };
}

# Include details of selected assets from their WFS service in the the alloy
# report description.
sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    if (my $wfs_asset_info = $row->get_extra_field_value('wfs_asset_info')) {
        my $text = "Asset Info: $wfs_asset_info\n\n" . $row->get_extra_field_value('description');
        $row->update_extra_field({ name => 'description', value => $text });
    }
}

# For categories where user has said they have witnessed activity, send
# an email
sub open311_post_send {
    my ( $self, $row, $h ) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    return if $row->get_extra_metadata('extra_email_sent');

    return if ( $row->get_extra_field_value('did_you_witness') || '' ) ne 'Yes';

    my $emails = $self->feature('open311_email') or return;
    my $dest = $emails->{$row->category} or return;

    my $sender = FixMyStreet::SendReport::Email->new( to => [$dest] );
    $sender->send( $row, $h );

    if ($sender->success) {
        $row->update_extra_metadata(extra_email_sent => 1);
    }
}

1;
