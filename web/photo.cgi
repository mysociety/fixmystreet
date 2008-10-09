#!/usr/bin/perl -w -I../perllib

# photo.cgi:
# Display a photo for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: photo.cgi,v 1.11 2008-10-09 14:20:54 matthew Exp $

use strict;
use Standard;
use Error qw(:try);
use CGI::Carp;

sub main {
    my $q = shift;
    print $q->header(-type => 'image/jpeg',
        -expires => '+1y' );
    my $id = $q->param('id');
    my $c = $q->param('c');
    return unless ($id || $c);
    my $photo;
    if ($c) {
        $photo = dbh()->selectrow_arrayref("select photo from comment where
            id=? and state = 'confirmed' and photo is not null", {}, $c);
    } else {
        $photo = dbh()->selectrow_arrayref( "select photo from problem where
            id=? and state in ('confirmed', 'fixed', 'partial') and photo is not
            null", {}, $id);
    }
    return unless $photo;
    $photo = $photo->[0];
    if ($q->param('tn')) {
        $photo = resize($photo, 'x100');
    } elsif ($q->{site} eq 'emptyhomes') {
        $photo = resize($photo, '195x');
    }

    print $photo;
}
Page::do_fastcgi(\&main);

sub resize {
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
