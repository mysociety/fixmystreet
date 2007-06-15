#!/usr/bin/perl -w

# photo.cgi:
# Display a photo for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: photo.cgi,v 1.5 2007-06-15 14:57:52 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use Error qw(:try);
use CGI::Carp;

use Page;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
    mySociety::DBHandle::configure(
        Name => mySociety::Config::get('BCI_DB_NAME'),
        User => mySociety::Config::get('BCI_DB_USER'),
        Password => mySociety::Config::get('BCI_DB_PASS'),
        Host => mySociety::Config::get('BCI_DB_HOST', undef),
        Port => mySociety::Config::get('BCI_DB_PORT', undef)
    );
}

sub main {
    my $q = shift;
    print $q->header(-type => 'image/jpeg',
        -expires => '+1y' );
    my $id = $q->param('id') || return;
    my $problem = dbh()->selectrow_arrayref(
        "select photo from problem where id=? and state in ('confirmed', 'fixed')
            and photo is not null", {}, $id);
    return unless $problem;
    my $photo = $problem->[0];
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
    dbh()->rollback();
}
Page::do_fastcgi(\&main);

