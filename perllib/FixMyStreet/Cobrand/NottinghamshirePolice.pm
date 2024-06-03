=head1 NAME

FixMyStreet::Cobrand::NottinghamshirePolice - code specific to the Nottinghamshire Police cobrand.

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::NottinghamshirePolice;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use Moo;

=head2 Defaults

=over 4

=cut

sub council_area_id { 2236 }
sub council_area { 'Nottinghamshire'; }
sub council_name { 'Nottinghamshire Police' }
sub council_url { 'nottinghamshirepolice' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = "Nottinghamshire";

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '53.1337083457641,-1.00642123965732',
        span   => '0.713104976883301,0.678328244170235',
        bounds => [ 52.7894115139395, -1.34459045070673, 53.5025164908228, -0.666262206536495 ],
    };
}

sub enter_postcode_text { 'Enter a Nottinghamshire postcode, street name or area' }

sub privacy_policy_url {
    'https://www.nottinghamshire.pcc.police.uk/Document-Library/Public-Information/Policies-and-Procedures/People/Privacy-Notice-OPCCN-Feb-2023.pdf'
}

=item * Never allows anonymous reports.

=cut

sub allow_anonymous_reports { 0 }

=item * Users with a notts.police.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'notts.police.uk' }

=item problems_restriction

Only shows reports made on it, not those from FMS.com or others.

=cut

sub problems_restriction {
    my ($self, $rs) = @_;

    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search({
        "$table.cobrand" => "nottinghamshirepolice"
    });
}

sub problems_sql_restriction {
    my ($self, $item_table) = @_;

    return "AND cobrand = 'nottinghamshirepolice'";
}

=item problems_on_map_restriction

Same restriction on map as problems_restriction above.

=cut

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    $self->problems_restriction($rs);
}

sub updates_restriction {
    my ($self, $rs) = @_;
    return $rs->search({ 'problem.cobrand' => 'nottinghamshirepolice' }, { join => 'problem' });
}

1;
