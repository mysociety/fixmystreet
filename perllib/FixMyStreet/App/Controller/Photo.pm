package FixMyStreet::App::Controller::Photo;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

use DateTime::Format::HTTP;
use Digest::SHA qw(sha1_hex);
use File::Path;
use File::Slurp;
use Image::Size;
use Path::Class;
use if !$ENV{TRAVIS}, 'Image::Magick';

=head1 NAME

FixMyStreet::App::Controller::Photo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Display a photo

=cut

sub during :LocalRegex('^([0-9a-f]{40})\.(temp|fulltemp)\.jpeg$') {
    my ( $self, $c ) = @_;
    my ( $hash, $size ) = @{ $c->req->captures };

    my $file = file( $c->config->{UPLOAD_DIR}, "$hash.jpeg" );
    my $photo = $file->slurp;

    if ( $size eq 'temp' ) {
        if ( $c->cobrand->default_photo_resize ) {
            $photo = _shrink( $photo, $c->cobrand->default_photo_resize );
        } else {
            $photo = _shrink( $photo, '250x250' );
        }
    }

    $c->forward( 'output', [ $photo ] );
}

sub index :LocalRegex('^(c/)?(\d+)(?:\.(full|tn|fp))?\.jpeg$') {
    my ( $self, $c ) = @_;
    my ( $is_update, $id, $size ) = @{ $c->req->captures };

    my @photo;
    if ( $is_update ) {
        @photo = $c->model('DB::Comment')->search( {
            id => $id,
            state => 'confirmed',
            photo => { '!=', undef },
        } );
    } else {
        # GoogleBot-Image is doing this for some reason?
        if ( $id =~ m{ ^(\d+) \D .* $ }x ) {
            return $c->res->redirect( $c->uri_with( { id => $1 } ), 301 );
        }

        $c->detach( 'no_photo' ) if $id =~ /\D/;
        @photo = $c->cobrand->problems->search( {
            id => $id,
            state => [ FixMyStreet::DB::Result::Problem->visible_states(), 'partial' ],
            photo => { '!=', undef },
        } );
    }

    $c->detach( 'no_photo' ) unless @photo;

    my $item = $photo[0];
    $c->detach( 'no_photo' ) unless $c->cobrand->allow_photo_display($item); # Should only be for reports, not updates
    my $photo = $item->photo;

    # If photo field contains a hash
    if (length($photo) == 40) {
        my $file = file( $c->config->{UPLOAD_DIR}, "$photo.jpeg" );
        $photo = $file->slurp;
    }

    if ( $size eq 'tn' ) {
        $photo = _shrink( $photo, 'x100' );
    } elsif ( $size eq 'fp' ) {
        $photo = _crop( $photo );
    } elsif ( $size eq 'full' ) {
    } elsif ( $c->cobrand->default_photo_resize ) {
        $photo = _shrink( $photo, $c->cobrand->default_photo_resize );
    } else {
        $photo = _shrink( $photo, '250x250' );
    }

    $c->forward( 'output', [ $photo ] );
}

sub output : Private {
    my ( $self, $c, $photo ) = @_;

    # Save to file
    File::Path::make_path( FixMyStreet->path_to( 'web', 'photo', 'c' )->stringify );
    File::Slurp::write_file( FixMyStreet->path_to( 'web', $c->req->path )->stringify, \$photo );

    $c->res->content_type( 'image/jpeg' );
    $c->res->body( $photo );
}

sub no_photo : Private {
    my ( $self, $c ) = @_;
    $c->detach( '/page_error_404_not_found', [ 'No photo' ] );
}

# Shrinks a picture to the specified size, but keeping in proportion.
sub _shrink {
    my ($photo, $size) = @_;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Scale(geometry => "$size>");
    throw Error::Simple("resize failed: $err") if "$err";
    $image->Strip();
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}

# Shrinks a picture to 90x60, cropping so that it is exactly that.
sub _crop {
    my ($photo) = @_;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Resize( geometry => "90x60^" );
    throw Error::Simple("resize failed: $err") if "$err";
    $err = $image->Extent( geometry => '90x60', gravity => 'Center' );
    throw Error::Simple("resize failed: $err") if "$err";
    $image->Strip();
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}

=head2 process_photo

Handle the photo - either checking and storing it after an upload or retrieving
it from the cache.

Store any error message onto 'photo_error' in stash.
=cut

sub process_photo : Private {
    my ( $self, $c ) = @_;

    return
         $c->forward('process_photo_upload')
      || $c->forward('process_photo_cache')
      || 1;    # always return true
}

sub process_photo_upload : Private {
    my ( $self, $c ) = @_;

    # check for upload or return
    my $upload = $c->req->upload('photo')
      || return;

    # check that the photo is a jpeg
    my $ct = $upload->type;
    $ct =~ s/x-citrix-//; # Thanks, Citrix
    # Had a report of a JPEG from an Android 2.1 coming through as a byte stream
    unless ( $ct eq 'image/jpeg' || $ct eq 'image/pjpeg' || $ct eq 'application/octet-stream' ) {
        $c->log->info('Bad photo tried to upload, type=' . $ct);
        $c->stash->{photo_error} = _('Please upload a JPEG image only');
        return;
    }

    # get the photo into a variable
    my $photo_blob = eval {
        my $filename = $upload->tempname;
        my $out = `jhead -se -autorot $filename 2>&1`;
        unless (defined $out) {
            my ($w, $h, $err) = Image::Size::imgsize($filename);
            die _("Please upload a JPEG image only") . "\n" if !defined $w || $err ne 'JPG';
        }
        die _("Please upload a JPEG image only") . "\n" if $out && $out =~ /Not JPEG:/;
        my $photo = $upload->slurp;
        return $photo;
    };
    if ( my $error = $@ ) {
        my $format = _(
"That image doesn't appear to have uploaded correctly (%s), please try again."
        );
        $c->stash->{photo_error} = sprintf( $format, $error );
        return;
    }

    # we have an image we can use - save it to the upload dir for storage
    my $cache_dir = dir( $c->config->{UPLOAD_DIR} );
    $cache_dir->mkpath;
    unless ( -d $cache_dir && -w $cache_dir ) {
        warn "Can't find/write to photo cache directory '$cache_dir'";
        return;
    }

    my $fileid = sha1_hex($photo_blob);
    $upload->copy_to( file($cache_dir, $fileid . '.jpeg') );

    # stick the hash on the stash, so don't have to reupload in case of error
    $c->stash->{upload_fileid} = $fileid;

    return 1;
}

=head2 process_photo_cache

Look for the upload_fileid parameter and check it matches a file on disk. If it
does return true and put fileid on stash, otherwise false.

=cut

sub process_photo_cache : Private {
    my ( $self, $c ) = @_;

    # get the fileid and make sure it is just a hex number
    my $fileid = $c->get_param('upload_fileid') || '';
    $fileid =~ s{[^0-9a-f]}{}gi;
    return unless $fileid;

    my $file = file( $c->config->{UPLOAD_DIR}, "$fileid.jpeg" );
    return unless -e $file;

    $c->stash->{upload_fileid} = $fileid;
    return 1;
}


=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
