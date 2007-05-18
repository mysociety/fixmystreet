#!/usr/bin/perl
#
# Page.pm:
# Various HTML stuff for the BCI site.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.pm,v 1.54 2007-05-18 20:05:07 matthew Exp $
#

package Page;

use strict;
use Carp;
use CGI::Fast qw(-no_xhtml);
use Error qw(:try);
use File::Slurp;
use LWP::Simple;
use POSIX qw(strftime);
use mySociety::Config;
use mySociety::DBHandle qw/select_all/;
use mySociety::EvEl;
use mySociety::WatchUpdate;
use mySociety::Web qw(ent NewURL);
BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
}

sub do_fastcgi {
    my $func = shift;

    try {
        my $W = new mySociety::WatchUpdate();
        while (my $q = new CGI::Fast()) {
            &$func($q);
            $W->exit_if_changed();
        }
    } catch Error::Simple with {
        my $E = shift;
        my $msg = sprintf('%s:%d: %s', $E->file(), $E->line(), $E->text());
        warn "caught fatal exception: $msg";
        warn "aborting";
        ent($msg);
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

=item header Q TITLE [PARAM VALUE ...]

Return HTML for the top of the page, given the TITLE text and optional PARAMs.

=cut
sub header ($$%) {
    my ($q, $title, %params) = @_;
    $title = '' unless $title;
    $title .= ' - ' if $title;
    $title = ent($title);

    my %permitted_params = map { $_ => 1 } qw(rss);
    foreach (keys %params) {
        croak "bad parameter '$_'" if (!exists($permitted_params{$_}));
    }

    print $q->header(-charset=>'utf-8');
    my $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en-gb">
    <head>
EOF
# Causes onLoad never to fire in IE...
# <!--[if lt IE 7.]>
# <script defer type="text/javascript" src="/pngfix.js"></script>
# <![endif]-->
    $html .= <<EOF;
        <script type="text/javascript" src="/yui/utilities.js"></script>
        <script type="text/javascript" src="/js.js"></script>
        <title>${title}Neighbourhood Fix-It</title>
        <style type="text/css">\@import url("/css.css");</style>
EOF
    if ($params{rss}) {
        $html .= '<link rel="alternate" type="application/rss+xml" title="'
            . $params{rss}[0] . '" href="' . $params{rss}[1] . '">';
    }
    $html .= <<EOF;
    </head>
    <body>
EOF
    my $home = !$title && $ENV{SCRIPT_NAME} eq '/index.cgi' && !$ENV{QUERY_STRING};
    $html .= $home ? '<h1 id="header">' : '<div id="header"><a href="/">';
    $html .= 'Neighbourhood Fix-It <span id="beta">' . _('Beta') . '</span>';
    $html .= $home ? '</h1>' : '</a></div>';
    $html .= '<div id="wrapper"><div id="content">';
    if (mySociety::Config::get('STAGING_SITE')) {
        $html .= '<p id="error">This is a developer site; things might break at any time, and councils are not sent emails (they\'d get annoyed!).</p>';
    }
    return $html;
}

=item footer

=cut
sub footer {
    return <<EOF;
</div></div>
<h2 class="v">Navigation</h2>
<ul id="navigation">
<li><a href="/">Report a problem</a></li>
<li><a href="/report">All reports</a></li>
<li><a href="/faq">Help</a></li>
<li><a href="/contact">Contact</a></li>
</ul>

<p id="footer">Built by <a href="http://www.mysociety.org/">mySociety</a>,
using some <a href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/bci">clever</a> <a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/services/TilMa">code</a>.</p>

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
            . footer();
    print $q->header(-content_length => length($html)), $html;
}

# display_map Q PARAMS
# PARAMS include:
# X,Y is bottom left tile of 2x2 grid
# TYPE is 1 if the map is clickable, 2 if clickable and has a form upload,
#     0 if not clickable
# PINS is HTML of pins to show
# PX,PY are coordinates of pin
# PRE/POST are HTML to show above/below map
sub display_map {
    my ($q, %params) = @_;
    $params{pins} ||= '';
    $params{pre} ||= '';
    $params{post} ||= '';
    my $px = defined($params{px}) ? $params{px}-254 : 0;
    my $py = defined($params{py}) ? 254-$params{py} : 0;
    my $x = $params{x}<=0 ? 0 : $params{x};
    my $y = $params{y}<=0 ? 0 : $params{y};
    my $url = mySociety::Config::get('TILES_URL');
    my $tiles_url = $url . $x . '-' . ($x+1) . ',' . $y . '-' . ($y+1) . '/RABX';
    my $tiles = LWP::Simple::get($tiles_url);
    throw Error::Simple("Unable to get tiles from URL $tiles_url\n") if !$tiles;
    my $tileids = RABX::unserialise($tiles);
    my $tl = $x . '.' . ($y+1);
    my $tr = ($x+1) . '.' . ($y+1);
    my $bl = $x . '.' . $y;
    my $br = ($x+1) . '.' . $y;
    return '<div id="side">' if (!$tileids->[0][0] || !$tileids->[0][1] || !$tileids->[1][0] || !$tileids->[1][1]);
    my $tl_src = $url . $tileids->[0][0];
    my $tr_src = $url . $tileids->[0][1];
    my $bl_src = $url . $tileids->[1][0];
    my $br_src = $url . $tileids->[1][1];

    my $out = '';
    my $img_type;
    if ($params{type}) {
        my $encoding = '';
        $encoding = ' enctype="multipart/form-data"' if ($params{type}==2);
        my $pc = $q->param('pc') || '';
        my $pc_enc = ent($pc);
        $out .= <<EOF;
<form action="./" method="post" id="mapForm"$encoding>
<input type="hidden" name="submit_map" value="1">
<input type="hidden" name="x" value="$x">
<input type="hidden" name="y" value="$y">
<input type="hidden" name="pc" value="$pc_enc">
EOF
        $img_type = '<input type="image"';
    } else {
        $img_type = '<img';
    }
    my $imgw = '254px';
    my $imgh = '254px';
    $out .= <<EOF;
<script type="text/javascript">
var x = $x - 2; var y = $y - 2;
var drag_x = $px; var drag_y = $py;
</script>
<div id="map_box">
$params{pre}
    <div id="map"><div id="drag">
        $img_type alt="NW map tile" id="t2.2" name="tile_$tl" src="$tl_src" style="top:0px; left:0px;">$img_type alt="NE map tile" id="t2.3" name="tile_$tr" src="$tr_src" style="top:0px; left:$imgw;"><br>$img_type alt="SW map tile" id="t3.2" name="tile_$bl" src="$bl_src" style="top:$imgh; left:0px;">$img_type alt="SE map tile" id="t3.3" name="tile_$br" src="$br_src" style="top:$imgh; left:$imgw;">
        $params{pins}
    </div>
EOF
    $out .= compass($q, $x, $y);
    $out .= <<EOF;
    </div>
    <p id="copyright">&copy; Crown copyright.  All rights reserved.
    Department for Constitutional Affairs 100037819&nbsp;2007</p>
$params{post}
EOF
    $out .= '</div>';
    $out .= '<div id="side">';
    return $out;
}

sub display_map_end {
    my ($type) = @_;
    my $out = '</div>';
    $out .= '</form>' if ($type);
    return $out;
}

sub display_pin {
    my ($q, $px, $py, $col, $num) = @_;
    $num = '' unless $num;
    my %cols = (red=>'R', green=>'G', blue=>'B', purple=>'P');
    my $out = '<img class="pin" src="/i/pin' . $cols{$col}
        . $num . '.gif" alt="Problem" style="top:' . ($py-59)
        . 'px; right:' . ($px-31) . 'px; position: absolute;">';
    return $out unless $_ && $_->{id} && $col ne 'blue';
    my $url = NewURL($q, id=>$_->{id}, x=>undef, y=>undef);
    $out = '<a title="' . $_->{title} . '" href="' . $url . '">' . $out . '</a>';
    return $out;
}

sub compass ($$$) {
    my ($q, $x, $y) = @_;
    my @compass;
    for (my $i=$x-1; $i<=$x+1; $i++) {
        for (my $j=$y-1; $j<=$y+1; $j++) {
            $compass[$i][$j] = NewURL($q, x=>$i, y=>$j);
        }
    }
    return <<EOF;
<table cellpadding="0" cellspacing="0" border="0" id="compass">
<tr valign="bottom">
<td align="right"><a href="${compass[$x-1][$y+1]}"><img src="/i/arrow-northwest.gif" alt="NW"></a></td>
<td align="center"><a href="${compass[$x][$y+1]}"><img src="/i/arrow-north.gif" vspace="3" alt="N"></a></td>
<td><a href="${compass[$x+1][$y+1]}"><img src="/i/arrow-northeast.gif" alt="NE"></a></td>
</tr>
<tr>
<td><a href="${compass[$x-1][$y]}"><img src="/i/arrow-west.gif" hspace="3" alt="W"></a></td>
<td align="center"><img src="/i/rose.gif" alt=""></td>
<td><a href="${compass[$x+1][$y]}"><img src="/i/arrow-east.gif" hspace="3" alt="E"></a></td>
</tr>
<tr valign="top">
<td align="right"><a href="${compass[$x-1][$y-1]}"><img src="/i/arrow-southwest.gif" alt="SW"></a></td>
<td align="center"><a href="${compass[$x][$y-1]}"><img src="/i/arrow-south.gif" vspace="3" alt="S"></a></td>
<td><a href="${compass[$x+1][$y-1]}"><img src="/i/arrow-southeast.gif" alt="SE"></a></td>
</tr>
</table>
EOF
}

# P is easting or northing
# BL is bottom left tile reference of displayed map
sub os_to_px {
    my ($p, $bl) = @_;
    return tile_to_px(os_to_tile($p), $bl);
}

# Convert tile co-ordinates to pixel co-ordinates from top right of map
# BL is bottom left tile reference of displayed map
sub tile_to_px {
    my ($p, $bl) = @_;
    $p = 508 - 254 * ($p - $bl);
    $p = int($p + .5 * ($p <=> 0));
    return $p;
}

# Tile co-ordinates are linear scale of OS E/N
# Will need more generalising when more zooms appear
sub os_to_tile {
    return $_[0] / (5000/31);
}
sub tile_to_os {
    return $_[0] * (5000/31);
}

sub click_to_tile {
    my ($pin_tile, $pin, $invert) = @_;
    $pin -= 254 while $pin > 254;
    $pin += 254 while $pin < 0;
    $pin = 254 - $pin if $invert; # image submits measured from top down
    return $pin_tile + $pin / 254;
}

# send_email TO (NAME) TEMPLATE-NAME PARAMETERS
sub send_email {
    my ($email, $name, $thing, %h) = @_;
    my $template = "$thing-confirm";
    $template = File::Slurp::read_file("$FindBin::Bin/../templates/emails/$template");
    my $to = $name ? [[$email, $name]] : $email;
    mySociety::EvEl::send({
        _template_ => $template,
        _parameters_ => \%h,
        From => [mySociety::Config::get('CONTACT_EMAIL'), 'Neighbourhood Fix-It'],
        To => $to,
    }, $email);
    my $out;
    my $action = ($thing eq 'alert') ? 'confirmed' : 'posted';
    $out = <<EOF;
<h1>Nearly Done! Now check your email...</h1>
<p>The confirmation email <strong>may</strong> take a few minutes to arrive &mdash; <em>please</em> be patient.</p>
<p>If you use web-based email or have 'junk mail' filters, you may wish to check your bulk/spam mail folders: sometimes, our messages are marked that way.</p>
<p>You must now click on the link within the email we've just sent you &mdash;
if you do not, your $thing will not be $action.</p>
<p>(Don't worry &mdash; we'll hang on to your $thing while you're checking your email.)</p>
EOF
    return $out;
}

sub prettify_epoch {
    my $s = shift;
    my @s = localtime($s);
    my $tt = strftime('%H:%M', @s);
    my @t = localtime();
    if (strftime('%Y%m%d', @s) eq strftime('%Y%m%d', @t)) {
        $tt = "$tt " . 'today';
    } elsif (strftime('%U', @s) eq strftime('%U', @t)) {
        $tt = "$tt, " . strftime('%A', @s);
    } elsif (strftime('%Y', @s) eq strftime('%Y', @t)) {
        $tt = "$tt, " . strftime('%A %e %B', @s);
    } else {
        $tt = "$tt, " . strftime('%a %e %B %Y', @s);
    }
    return $tt;
}

# argument is duration in seconds, rounds to the nearest minute
sub prettify_duration {
    my ($s, $nearest) = @_;
    if ($nearest eq 'week') {
        $s = int(($s+60*60*24*3.5)/60/60/24/7)*60*60*24*7;
    } elsif ($nearest eq 'day') {
        $s = int(($s+60*60*12)/60/60/24)*60*60*24;
    } elsif ($nearest eq 'hour') {
        $s = int(($s+60*30)/60/60)*60*60;
    } elsif ($nearest eq 'minute') {
        $s = int(($s+30)/60)*60;
        return 'less than a minute' if $s == 0;
    }
    my @out = ();
    _part(\$s, 60*60*24*7, 'week', \@out);
    _part(\$s, 60*60*24, 'day', \@out);
    _part(\$s, 60*60, 'hour', \@out);
    _part(\$s, 60, 'minute', \@out);
    return join(', ', @out);
}
sub _part {
    my ($s, $m, $w, $o) = @_;
    if ($$s >= $m) {
        my $i = int($$s / $m);
        push @$o, "$i $w" . ($i != 1 ? 's' : '');
        $$s -= $i * $m;
    }
}

# Simply so I can gettext the code without making the locale stuff all work
sub _ {
    return $_[0];
}

sub display_problem_text {
    my ($q, $problem) = @_;
    my $out = $q->h1(ent($problem->{title}));

    # Display information about problem
    $out .= '<p><em>Reported ';
    $out .= 'in the ' . ent($problem->{category}) . ' category '
        if $problem->{category} && $problem->{category} ne 'Other';
    $out .= ($problem->{anonymous}) ? 'anonymously' : "by " . ent($problem->{name});
    $out .= ' at ' . prettify_epoch($problem->{time});
    $out .= '; the map was not used so pin location may be inaccurate' unless ($problem->{used_map});
    if ($problem->{council}) {
        if ($problem->{whensent}) {
            $problem->{council} =~ s/\|.*//g;
            my @councils = split /,/, $problem->{council};
            my $areas_info = mySociety::MaPit::get_voting_areas_info(\@councils);
            my $council = join(' and ', map { canonicalise_council($areas_info->{$_}->{name}) } @councils);
            $out .= $q->br() . $q->small('Sent to ' . $council . ' ' .
                prettify_duration($problem->{whensent}, 'minute') . ' later');
        }
    } else {
        $out .= $q->br() . $q->small('Not reported to council');
    }
    $out .= '</em></p> <p>';
    $out .= ent($problem->{detail});
    $out .= '</p>';

    if ($problem->{photo}) {
        $out .= '<p align="center"><img src="/photo?id=' . $problem->{id} . '"></p>';
    }

    return $out;
}

# Display updates
sub display_problem_updates {
    my $id = shift;
    my $updates = select_all(
        "select id, name, extract(epoch from created) as created, text, mark_fixed, mark_open
         from comment where problem_id = ? and state='confirmed'
         order by created", $id);
    my $out = '';
    if (@$updates) {
        $out .= '<div id="updates">';
        $out .= '<h2>Updates</h2>';
        foreach my $row (@$updates) {
            $out .= "<div><a name=\"update_$row->{id}\"></a><em>";
            if ($row->{name}) {
                $out .= 'Posted by ' . ent($row->{name});
            } else {
                $out .= "Posted anonymously";
            }
            $out .= " at " . prettify_epoch($row->{created});
            $out .= ', marked fixed' if ($row->{mark_fixed});
            $out .= ', reopened' if ($row->{mark_open});
            $out .= '</em>';
            $out .= '<br>' . ent($row->{text}) . '</div>';
        }
        $out .= '</div>';
    }
    return $out;
}

sub canonicalise_council {
    my $c = shift;
    if ($c =~ /City of London/) {
        $c = "the $c";
    } else {
        $c =~ s/City of //;
    }
    $c =~ s/N\. /North /;
    $c =~ s/E\. /East /;
    $c =~ s/W\. /West /;
    $c =~ s/S\. /South /;
    return $c;
}

1;
