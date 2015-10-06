package FixMyStreet::App::Controller::Photo;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

use DateTime::Format::HTTP;
use Digest::SHA qw(sha1_hex);
use File::Path;
use File::Slurp;
use Path::Class;
use FixMyStreet::App::Model::PhotoSet;
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

sub index :LocalRegex('^(c/)?(\d+)(?:\.(\d+))?(?:\.(full|tn|fp))?\.jpeg$') {
    my ( $self, $c ) = @_;
    my ( $is_update, $id, $photo_number, $size ) = @{ $c->req->captures };

    my $item;
    if ( $is_update ) {
        ($item) = $c->model('DB::Comment')->search( {
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
        ($item) = $c->cobrand->problems->search( {
            id => $id,
            state => [ FixMyStreet::DB::Result::Problem->visible_states(), 'partial' ],
            photo => { '!=', undef },
        } );
    }

    $c->detach( 'no_photo' ) unless $item;

    $c->detach( 'no_photo' ) unless $c->cobrand->allow_photo_display($item); # Should only be for reports, not updates

    my $photo;
    if ($item->can('get_photoset')) {
        $photo = $item->get_photoset( $c )
            ->get_image_data( num => $photo_number, size => $size )
        or $c->detach( 'no_photo' );
    } else {
        $photo = $item->photo;
        # If photo field contains a hash
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
         $c->forward('process_photo_upload_or_cache')
      || $c->forward('process_photo_required')
      || 1;    # always return true
}

sub process_photo_upload_or_cache : Private {
    my ( $self, $c ) = @_;
    my @items = (
        ( map {
            /^photo/ ? # photo, photo1, photo2 etc.
                ($c->req->upload($_)) : ()
        } sort $c->req->upload),
        split /,/, ($c->get_param('upload_fileid') || '')
    );

    my $photoset = FixMyStreet::App::Model::PhotoSet->new({
        c => $c,
        data_items => \@items,
    });

    my $fileid = $photoset->data;

    $c->stash->{upload_fileid} = $fileid or return;
    return 1;
}

=head2 process_photo_required

Checks that a report has a photo attached if any of its Contacts
require it (by setting extra->photo_required == 1). Puts an error in
photo_error on the stash if it's required and missing, otherwise returns
true.

(Note that as we have reached this action, we *know* that the photo
is missing, otherwise it would have already been handled.)

=cut

sub process_photo_required : Private {
    my ( $self, $c ) = @_;

    # load the report
    my $report = $c->stash->{report} or return 1; # don't check photo for updates
    my $bodies = $c->stash->{bodies};

    my @contacts = $c->       #
      model('DB::Contact')    #
      ->not_deleted           #
      ->search(
        {
            body_id => [ keys %$bodies ],
            category => $report->category
        }
      )->all;
      foreach my $contact ( @contacts ) {
          if ( $contact->get_extra_metadata('photo_required') ) {
              $c->stash->{photo_error} = _("Photo is required.");
              return;
          }
      }

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
