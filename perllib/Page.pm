#!/usr/bin/perl
#
# Page.pm:
# Various HTML stuff for the BCI site.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.pm,v 1.4 2006-09-19 17:20:19 francis Exp $
#

package Page;

use strict;
use Carp;
use CGI::Fast qw(-no_xhtml);
use HTML::Entities;
use Error qw(:try);

sub do_fastcgi {
    my $func = shift;

    try {
        while (my $q = new CGI::Fast()) {
            &$func($q);
        }
    } catch Error::Simple with {
        my $E = shift;
        my $msg = sprintf('%s:%d: %s', $E->file(), $E->line(), $E->text());
        warn "caught fatal exception: $msg";
        warn "aborting";
        encode_entities($msg);
        print "Status: 500\nContent-Type: text/html; charset=iso-8859-1\n\n",
                q(<html><head><title>Sorry! Something's gone wrong.</title></head></html>),
                q(<body>),
                q(<h1>Sorry! Something's gone wrong.</h1>),
                q(<p>Please try again later, or <a href="mailto:team@neighbourhoodfixit.com">email us</a> to let us know.</p>),
                q(<hr>),
                q(<p>The text of the error was:</p>),
                qq(<blockquote class="errortext">$msg</blockquote>),
                q(</body></html);
    };
}

sub url {
    my ($x, $y) = @_;
    return '?x=' . $x . ';y=' . $y;
}

=item header Q TITLE [PARAM VALUE ...]

Return HTML for the top of the page, given the TITLE text and optional PARAMs.

=cut
sub header ($$%) {
    my ($q, $title, %params) = @_;
    
    my %permitted_params = map { $_ => 1 } qw();
    foreach (keys %params) {
        croak "bad parameter '$_'" if (!exists($permitted_params{$_}));
    }

    my $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en-gb">
    <head>
        <title>Neighbourhood Fix-It</title>
        <style type="text/css">\@import url("css.css");</style>
    </head>
    <body>
        <h1>Neighbourhood Fix-It</h1>
	<div id="content">
EOF
    return $html;
}

=item footer Q

=cut
sub footer ($) {
    my ($q) = @_;
    return <<EOF;
</div>
</body>
</html>
EOF
}

=item error_page Q MESSAGE

=cut
sub error_page ($$) {
    my ($q, $message);
    my $html = header($q, "Error")
            . $q->p($message)
            . footer($q);
    print $q->header(-content_length => length($html)), $html;
}

sub compass ($$) {
    my ($x, $y) = @_;
    my $nw = url($x-1, $y-1);
    my $n = url($x, $y-1);
    my $ne = url($x+1, $y-1);
    my $w = url($x-1,$y);
    my $e = url($x+1,$y);
    my $sw = url($x-1, $y+1);
    my $s = url($x, $y+1);
    my $se = url($x+1, $y+1);
    return <<EOF;
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
EOF
}

1;
