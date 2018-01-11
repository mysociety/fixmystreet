package FixMyStreet::SendReport::Email::BathNES;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub get_template {
    my ( $self, $row ) = @_;
    if ( $row->category eq 'Street Light Fault' ) {
        return 'bathnes/submit-street-light-fault.txt';
    } else {
        return 'submit.txt';
    }
}

1;
