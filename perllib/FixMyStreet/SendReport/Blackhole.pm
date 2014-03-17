package FixMyStreet::SendReport::Blackhole;

use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::SendReport'; }

use FixMyStreet::App;
use mySociety::Config;

sub send {
    my ( $self, $row, $h ) = @_;
    return -1;
}

1;
