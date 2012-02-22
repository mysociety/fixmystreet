package FixMyStreet::App::Controller::Photo;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

use DateTime::Format::HTTP;

=head1 NAME

FixMyStreet::App::Controller::Photo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Display a photo

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->req->param('id');
    my $comment = $c->req->param('c');
    $c->detach( 'no_photo' ) unless $id || $comment;

    my @photo;
    if ( $comment ) {
        @photo = $c->model('DB::Comment')->search( {
            id => $comment,
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
    if ( $c->req->param('tn' ) ) {
        $photo = _shrink( $photo, 'x100' );
    } elsif ( $c->req->param('fp' ) ) {
        $photo = _crop( $photo );
    } elsif ( $c->cobrand->default_photo_resize ) {
        $photo = _shrink( $photo, $c->cobrand->default_photo_resize );
    }

    my $dt = DateTime->now();
    $dt->set_year( $dt->year + 1 );

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
    my $err = $image->Extent( geometry => '90x60', gravity => 'Center' );
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
