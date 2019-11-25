package FixMyStreet::Auth::GoogleAuth;

use parent 'Auth::GoogleAuth';

use strict;
use warnings;
use Image::PNG::QRCode 'qrpng';
use URI;

# Overridden to return a data: URI of the image
sub qr_code {
    my $self = shift;
    my ( $secret32, $key_id, $issuer, $return_otpauth ) = @_;

    # Make issuer a bit nicer to read
    $issuer =~ s{https?://}{};

    my $otpauth = $self->SUPER::qr_code($secret32, $key_id, $issuer, 1);
    return $otpauth if $return_otpauth;

    my $u = URI->new('data:');
    $u->media_type('image/png');
    $u->data(qrpng(text => $otpauth));
    return $u;
}

1;
