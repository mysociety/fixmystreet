#!/usr/bin/perl -w -I../perllib

# photo.cgi:
# Display a photo for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: photo.cgi,v 1.8 2008-03-28 16:36:48 matthew Exp $

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
            id=? and state in ('confirmed', 'fixed', 'flickr') and photo is not
            null", {}, $id);
    }
    return unless $photo;
    $photo = $photo->[0];
    if ($q->param('tn')) {
        use Image::Magick;
        my $image = Image::Magick->new;
        $image->BlobToImage($photo);
        my $err = $image->Scale(geometry => "x100>");
        throw Error::Simple("resize failed: $err") if "$err";
        my @blobs = $image->ImageToBlob();
        undef $image;
        $photo = $blobs[0];
    }

    print $photo;
}
Page::do_fastcgi(\&main);

