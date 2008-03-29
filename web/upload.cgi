#!/usr/bin/perl -w -I../perllib -I../../perllib

# upload.cgi:
# Receiver of flash upload files
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: upload.cgi,v 1.1 2008-03-29 03:03:35 matthew Exp $

use strict;
use Standard -db;

use Error qw(:try);
use Image::Magick;
use mySociety::Random qw(random_bytes);

# Main code for index.cgi
sub main {
    my $q = shift;

    print $q->header(-type => 'text/plain');
    my $out = ' ';
    try {
        my $fh = $q->upload('Filedata');
        my $image;
        if ($fh) {
            $q->delete('photo'); # Can't check content/type when uploaded with Flash
            $image = process_photo($fh);
	    my $name = unpack('H*', random_bytes(12));
	    open FP, '>/data/vhost/matthew.bci.mysociety.org/photos/' . $name or throw Error::Simple('could not open file');
	    print FP $image;
	    close FP;
	    $out = $name;
        };
    } catch Error::Simple with {
        my $e = shift;
    };
    print $out;
}
Page::do_fastcgi(\&main);

sub process_photo {
    my $fh = shift;
    my $photo = Image::Magick->new;
    my $err = $photo->Read(file => \*$fh); # Mustn't be stringified
    close $fh;
    throw Error::Simple("read failed: $err") if "$err";
    $err = $photo->Scale(geometry => "250x250>");
    throw Error::Simple("resize failed: $err") if "$err";
    my @blobs = $photo->ImageToBlob();
    undef $photo;
    $photo = $blobs[0];
    return $photo;
}

