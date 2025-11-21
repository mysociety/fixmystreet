=head1 NAME

FixMyStreet::Cobrand::Dumfries - code specific to the Dumfries and Galloway cobrand

=head1 SYNOPSIS

Dumfries and Galloway is a unitary authority, with an Alloy backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Dumfries;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use Moo;
with 'FixMyStreet::Roles::MyGovScotOIDC';

use strict;
use warnings;

sub council_area_id { return 2656; }
sub council_area { return 'Dumfries and Galloway'; }
sub council_name { return 'Dumfries and Galloway Council'; }
sub council_url { return 'dumfries'; }

=item * Custom postcode text which includes hint about reference number search

=cut

sub enter_postcode_text {
    'Enter a Dumfries and Galloway post code or street name and area, or a reference number of a problem previously reported'
}

=item * Dumfries use their own privacy policy

=cut

sub privacy_policy_url { 'https://www.dumfriesandgalloway.gov.uk/sites/default/files/2025-03/privacy-notice-customer-services-centres-dumfries-and-galloway-council.pdf' }


=head2 open311_get_update_munging

Dumfries want certain fields shown in updates on FMS.

These values, if present, are passed back from open311-adapter in the <extras>
element. If the template being used for this update has placeholders matching
any field configured in the 'response_template_variables' Config entry, they
get replaced with the value from extras, or an empty string otherwise.

=cut

sub open311_get_update_munging {
    my ($self, $comment, $state, $request) = @_;

    my $text = $self->open311_get_update_munging_template_variables($comment->text, $request);
    $comment->text($text);

    if ( $text = $comment->private_email_text ) {
        $text = $self->open311_get_update_munging_template_variables(
            $text, $request );
        $comment->private_email_text($text);
    }
}

=item * Make a few improvements to the display of geocoder results

Remove 'Dumfries and Galloway' and 'Alba / Scotland', skip any that don't mention Dumfries and Galloway at all

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Dumfries and Galloway';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '55.0706745777256,-3.95683358209527',
        span   => '0.830832259321063,2.33028835283733',
        bounds => [ 54.6332195775134, -5.18762505731414, 55.4640518368344, -2.8573367044768 ],
        result_only_if => 'Dumfries and Galloway',
        result_strip => ', Dumfries and Galloway, Alba / Scotland',
    };
}

1;
