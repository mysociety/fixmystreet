=head1 NAME

FixMyStreet::Cobrand::Lincolnshire - code specific to the Lincolnshire cobrand

=head1 SYNOPSIS

Lincolnshire is a two-tier authority, and uses a Confirm back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Lincolnshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

use Moo;

=pod

Confirm backends expect some extra values and have some maximum lengths
for certain fields, implemented with a couple of roles.

=cut

with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

=head2 Defaults

=over 4

=cut

sub council_area_id { return 2232; }
sub council_area { return 'Lincolnshire'; }
sub council_name { return 'Lincolnshire County Council'; }
sub council_url { return 'lincolnshire'; }

=item * Lincolnshire is a two-tier authority

=cut

sub is_two_tier { 1 }

=item * Lincolnshire's /around map shows only open reports by default.

=cut

sub on_map_default_status { 'open' }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * We include the C<external_id> (Confirm reference) in the acknowledgement email.

=cut

sub report_sent_confirmation_email { 'external_id' }

=item * Users with a lincolnshire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'lincolnshire.gov.uk' }

=item * The default map zoom is set to 5.

=cut

sub default_map_zoom { 5 }

=item * The front page text is tweaked to explain existing report numbers
can be looked up.

=back

=cut

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Lincolnshire postcode, street name and area, or check an existing report number';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Lincolnshire',
        centre => '53.1128371079972,-0.237920757894981',
        span   => '0.976148231905086,1.17860658530345',
        bounds => [ 52.6402179235688, -0.820651304784901, 53.6163661554738, 0.357955280518546 ],
    };
}

=head2 lookup_site_code_config

We store Lincolnshire's street gazetteer in our Tilma, which is used to
look up the nearest road to the report for including in the data sent to
Confirm.

=cut

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/lincs",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "NSG",
    property => "Site_Code",
    accept_feature => sub { 1 }
} }

=head2 categories_restriction

Lincolnshire is a two-tier council, but don't want to display all
district-level categories on their cobrand - just a few, namely 'Litter',
'Street nameplates', 'Bench', 'Cycle rack', 'Litter bin', and 'Planter'.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { -or => [
        'body.name' => [ "Lincolnshire County Council", 'National Highways' ],

        # District categories:
        'me.category' => { -in => [
            'Litter',
            'Street nameplates',
            'Bench', 'Cycle rack', 'Litter bin', 'Planter',
        ] },
    ] } );
}

=head2 pin_colour

Lincolnshire uses the following pin colours:

=over 4

=item * grey: Not a Lincolnshire problem, or closed as 'not responsible'

=item * orange: 'investigating' or 'for triage'

=item * yellow: 'action scheduled' or 'in progress'

=item * green: Fixed

=item * blue: Otherwise closed

=item * red: Anything else (open)

=back

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    my $ext_status = $p->get_extra_metadata('external_status_code');

    return 'grey'
        if $p->state eq 'not responsible' || !$self->owns_problem($p);
    return 'orange'
        if $p->state eq 'investigating' || $p->state eq 'for triage';
    return 'yellow'
        if $p->state eq 'action scheduled' || $p->state eq 'in progress';
    return 'green' if $p->is_fixed;
    return 'blue' if $p->is_closed;
    return 'red';
}

=head2 open311_config

Our Confirm integration can handle multiple photos and the direct
uploading of private photos, so we set the flag for this.

=cut

around 'open311_config' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    $params->{upload_files} = 1;
    $self->$orig($row, $h, $params);
};

1;
