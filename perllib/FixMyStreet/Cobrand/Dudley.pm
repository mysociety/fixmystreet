=head1 NAME

FixMyStreet::Cobrand::Dudley - code specific to the Dudley cobrand

=head1 SYNOPSIS

Dudley is a metropolitan district authority, with a Symology backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Dudley;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use Moo;
with 'FixMyStreet::Roles::Cobrand::OpenUSRN';

sub council_area_id { 2522 }
sub council_area { 'Dudley'; }
sub council_name { 'Dudley Borough Council' }
sub council_url { 'dudley' }

# Created with bin/fixmystreet.com/generate_council_location
sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    my $town = 'Dudley';
    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '52.4828778776603,-2.1087441438586',
        span   => '0.132208941295367,0.180437882042669',
        bounds => [ 52.4260142691841, -2.19194291862399, 52.5582232104795, -2.01150503658132 ],
        result_strip => ', West Midlands, England',
    };
}

=over 4

=item * dudley.gov.uk users can always be found in the admin

=cut

sub admin_user_domain { 'dudley.gov.uk' }

sub abuse_reports_only { 1 }

=item * Only open reports on map by default

=cut

sub on_map_default_status { 'open' }

=item * Potholes category only at present

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { -or => [
        'me.send_method' => undef, # Open311 categories, or National Highways
        'me.send_method' => '', # Open311 categories that have been edited in the admin
    ] } );
}

=item * Fetch the nearest USRN if we don't have it already

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
        }
    }
}

=item * Include the report URL in the Open311 submission

=cut

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
    ];

    return $open311_only;
}

=item * Send a confirmation email once the report has been sent, quoting its FMS ID

=cut

sub report_sent_confirmation_email { 'id' }

=item * Starts the map more zoomed in than the default

=cut

sub default_map_zoom { 5 }

=item * Also send an email on Open311 categories, if email provided

=back

=cut

sub open311_post_send {
    my ($self, $row, $h) = @_;

    return unless $row->external_id;
    return if $row->get_extra_metadata('extra_email_sent');

    my $emails = $self->feature('open311_email') or return;
    my $dest = $emails->{$row->category} or return;
    $dest = [ $dest, 'FixMyStreet' ];

    $row->push_extra_fields({ name => 'fixmystreet_id', description => 'FMS reference', value => $row->id });

    my $sender = FixMyStreet::SendReport::Email->new(
        use_verp => 0, use_replyto => 1, to => [ $dest ] );
    $sender->send($row, $h);
    if ($sender->success) {
        $row->set_extra_metadata(extra_email_sent => 1);
    }

    $row->remove_extra_field('fixmystreet_id');
}

1;
