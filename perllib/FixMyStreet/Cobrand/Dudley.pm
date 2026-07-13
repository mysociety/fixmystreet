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
    return {
        %{ $self->SUPER::disambiguate_location() },
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

=item * Fetch the nearest USRN if we don't have it already

=back

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
        }
    }
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
    ];

    return $open311_only;
}

1;
