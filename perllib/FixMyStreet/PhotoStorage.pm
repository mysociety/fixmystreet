package FixMyStreet::PhotoStorage;

use MIME::Base64;
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


=head2 base64_decode_upload

base64 decode the temporary on-disk uploaded file if
it's encoded that way. Modifies the file in-place.
Catalyst::Request::Upload doesn't do this automatically
unfortunately.

=cut

sub base64_decode_upload {
    my ( $c, $upload ) = @_;

    my $transfer_encoding = $upload->headers->header('Content-Transfer-Encoding');
    if (defined $transfer_encoding && $transfer_encoding eq 'base64') {
        my $decoded = decode_base64($upload->slurp);
        if (open my $fh, '>', $upload->tempname) {
            binmode $fh;
            print $fh $decoded;
            close $fh
        } else {
            if ($c) {
                $c->log->info('Couldn\'t open temp file to save base64 decoded image: ' . $!);
                $c->stash->{photo_error} = _("Sorry, we couldn't save your file(s), please try again.");
            }
            return ();
        }
    }

}


1;
