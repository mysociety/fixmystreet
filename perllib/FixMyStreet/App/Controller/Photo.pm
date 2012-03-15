package FixMyStreet::App::Controller::Photo;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

use DateTime::Format::HTTP;
use Path::Class;

=head1 NAME

FixMyStreet::App::Controller::Photo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Display a photo

=cut

sub during :LocalRegex('^([0-9a-f]{40})\.temp\.jpeg$') {
    my ( $self, $c ) = @_;
    my ( $hash ) = @{ $c->req->captures };

    my $file = file( $c->config->{UPLOAD_DIR}, "$hash.jpeg" );
    my $photo = $file->slurp;

    if ( $c->cobrand->default_photo_resize ) {
        $photo = _shrink( $photo, $c->cobrand->default_photo_resize );
    } else {
        $photo = _shrink( $photo, '250x250' );
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

    my $photo = $photo[0]->photo;

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

    my $dt = DateTime->now()->add( years => 1 );

    $c->res->content_type( 'image/jpeg' );
    $c->res->header( 'expires', DateTime::Format::HTTP->format_datetime( $dt ) );
    $c->res->body( $photo );
}

sub no_photo : Private {
    my ( $self, $c ) = @_;
    $c->detach( '/page_error_404_not_found', [ 'No photo' ] );
}

# Shrinks a picture to the specified size, but keeping in proportion.
sub _shrink {
    my ($photo, $size) = @_;
    use Image::Magick;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Scale(geometry => "$size>");
    throw Error::Simple("resize failed: $err") if "$err";
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}

# Shrinks a picture to 90x60, cropping so that it is exactly that.
sub _crop {
    my ($photo) = @_;
    use Image::Magick;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Resize( geometry => "90x60^" );
    throw Error::Simple("resize failed: $err") if "$err";
    $err = $image->Extent( geometry => '90x60', gravity => 'Center' );
    throw Error::Simple("resize failed: $err") if "$err";
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
