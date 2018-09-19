package FixMyStreet::PhotoStorage;

use Moose;
use Digest::SHA qw(sha1_hex);


sub detect_type {
    my ($self, $photo) = @_;
    return 'jpeg' if $photo =~ /^\x{ff}\x{d8}/;
    return 'png' if $photo =~ /^\x{89}\x{50}/;
    return 'tiff' if $photo =~ /^II/;
    return 'gif' if $photo =~ /^GIF/;
    return '';
}

=head2 get_fileid

Calculates an identifier for a binary blob of photo data.
This is just the SHA1 hash of the blob currently.

=cut

sub get_fileid {
    my ($self, $photo_blob) = @_;
    return sha1_hex($photo_blob);
}



1;
