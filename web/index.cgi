#!/usr/bin/perl -w

# index.pl:
# Main code for BCI - not really.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.2 2006-09-19 16:24:22 francis Exp $

use strict;
use CGI::Fast qw(-no_xhtml);
use Error qw(:try);

my $q;
try {
    while ($q = new CGI::Fast()) {
        print $q->header();
        my $x = $q->param('x') || 62;
        my $y = $q->param('y') || 171;
        my $zoom = $q->param('z') || 250;

        my $dir;
        if ($zoom == 25) {
            $dir = 'tl/';
        } else {
            $dir = 't/';
        }

        my $tl = $dir.$x.'.'.$y.'.png';
        my $tr = $dir.($x+1).'.'.$y.'.png';
        my $bl = $dir.$x.'.'.($y+1).'.png';
        my $br = $dir.($x+1).'.'.($y+1).'.png';

        my $url = sub {
            my ($x, $y, $z) = @_;
            $z = $zoom unless $z;
            return '?x=' . $x . '&amp;y=' . $y . '&amp;z=' . $z;
        };

        my $nw = &$url($x-1, $y-1);
        my $n = &$url($x, $y-1);
        my $ne = &$url($x+1, $y-1);
        my $w = &$url($x-1,$y);
        my $e = &$url($x+1,$y);
        my $sw = &$url($x-1, $y+1);
        my $s = &$url($x, $y+1);
        my $se = &$url($x+1, $y+1);
        print <<EOF;
        <!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
        <html lang="en-gb">
            <head>
                <title>MapOS testing</title>
                <script type="text/javascript" src="build/YAHOO.js"></script>
                <script type="text/javascript" src="build/dom.js"></script>
                <script type="text/javascript" src="build/event.js"></script>
                <script type="text/javascript" src="build/animation.js"></script>
                <script type="text/javascript">
                var x = $x;
                var y = $y;
                </script>
                <script type="text/javascript" src="js.js"></script>
                <style type="text/css">\@import url("css.css");</style>
            </head>
            <body>
                <h1>MapOS</h1>
                <p>Drag to move, double-click to centre, or use the arrows. Zoom's a bit of a jump (250,000:1 to 25,000:1 and back) but should be okay - if you double-click just before a zoom in, that's probably best.
                <strong>Bugs:</strong> None at this immediate moment</p>
                <div id="wrap">
                <div id="column">

        <table cellpadding="0" cellspacing="0" border="0" id="compass">
        <tr valign="bottom">
        <td align="right"><a href="$nw"><img src="i/arrow-northwest.gif" alt="NW"></a></td>
        <td align="center"><a href="$n"><img src="i/arrow-north.gif" vspace="3" alt="N"></a></td>
        <td><a href="$ne"><img src="i/arrow-northeast.gif" alt="NE"></a></td>
        </tr>
        <tr>
        <td><a href="$w"><img src="i/arrow-west.gif" hspace="3" alt="W"></a></td>
        <td align="center"><img src="i/rose.gif" alt=""></a></td>
        <td><a href="$e"><img src="i/arrow-east.gif" hspace="3" alt="E"></a></td>
        </tr>
        <tr valign="top">
        <td align="right"><a href="$sw"><img src="i/arrow-southwest.gif" alt="SW"></a></td>
        <td align="center"><a href="$s"><img src="i/arrow-south.gif" vspace="3" alt="S"></a></td>
        <td><a href="$se"><img src="i/arrow-southeast.gif" alt="SE"></a></td>
        </tr>
        </table>

        <p id="zoom" align="center">
EOF
        if ($zoom != 250) {
            printf('<a href="%s"><img src="i/zoomout.gif" alt="Zoom out" border="0"></a>', &$url(round($x/10)-1,round($y/10)-1,250) );
        }
        if ($zoom != 25) {
            print '<a href="' . &$url(($x+1)*10,($y+1)*10,25) . '"><img src="i/zoomin.gif" alt="Zoom in" border="0"></a>';
        }

        print <<EOF;
        </p>

                <div id="log"></div>
                </div>
                <div id="map">
                    <div id="drag">
                        <img id="2.2" nm="$tl" src="$tl" style="top:0px; left:0px;"><img id="3.2" nm="$tr" src="$tr" style="top:0px; left:250px;"><br><img id="2.3" nm="$bl" src="$bl" style="top:250px; left:0px;"><img id="3.3" nm="$br" src="$br" style="top:250px; left:250px;">
                    </div>
                </div>
                </div>
            </body>
        </html>
EOF
    }
} catch Error::Simple with {
    my $E = shift;
    my $msg = sprintf('%s:%d: %s', $E->file(), $E->line(), $E->text());
    warn "caught fatal exception: $msg";
    warn "aborting";
    encode_entities($msg);
    print "Status: 500\nContent-Type: text/html; charset=iso-8859-1\n\n",
            q(<p>Unfortunately, something went wrong. The text of the error
                    was:</p>),
            qq(<blockquote class="errortext">$msg</blockquote>),
            q(<p>Please try again later.);
};


