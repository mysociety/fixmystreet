package FixMyStreet::PhotoStorage;

use Moose;
use Digest::SHA qw(sha1_hex);
use Module::Load;
use FixMyStreet;

our $instance; # our, so tests can set to undef when testing different backends
sub backend {
    return $instance if $instance;
    my $class = 'FixMyStreet::PhotoStorage::';
    $class .= FixMyStreet->config('PHOTO_STORAGE_BACKEND') || 'FileSystem';
    load $class;
    $instance = $class->new();
    return $instance;
}

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
