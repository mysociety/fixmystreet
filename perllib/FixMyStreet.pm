package FixMyStreet;

use strict;
use warnings;

use Path::Class;

=head1 NAME

FixMyStreet

=head1 DESCRIPTION

FixMyStreet is a webite where you can report issues and have them routed to the
correct authority so that they can be fixed.

Thus module has utility functions for the FMS project.

=head1 METHODS

=head2 path_to

    $path = FixMyStreet->path_to( 'conf/general' );

Returns an absolute Path::Class object representing the path to the arguments in
the FixMyStreet directory.

=cut

my $ROOT_DIR = file(__FILE__)->parent->parent->absolute;

sub path_to {
    my $self = shift;
    return $ROOT_DIR->file(@_);
}



1;
