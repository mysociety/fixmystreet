package FixMyStreet::Cobrand::Merton;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2500 }
sub council_area { 'Merton' }
sub council_name { 'Merton Council' }
sub council_url { 'merton' }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = "Merton";

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '51.4099496632915,-0.197255310605401',
        span   => '0.0612811278185319,0.130096741684365',
        bounds => [ 51.3801834993027, -0.254262247988426, 51.4414646271213, -0.124165506304061 ],
    };
}

sub enter_postcode_text { 'Enter a postcode, street name and area, or check an existing report number' }

sub admin_user_domain { 'merton.gov.uk' }

sub privacy_policy_url { "https://www.merton.gov.uk/legal/privacy-and-cookies" }

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

1;
