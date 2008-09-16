#!/usr/bin/perl
#
# Page.pm:
# Various HTML stuff for the BCI site.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.pm,v 1.110 2008-09-16 16:02:40 matthew Exp $
#

package Page;

use strict;
use Carp;
use mySociety::CGIFast qw(-no_xhtml);
use Error qw(:try);
use File::Slurp;
use Image::Magick;
use LWP::Simple;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use URI::Escape;
use Problems;
use mySociety::Config;
use mySociety::DBHandle qw/dbh select_all/;
use mySociety::EvEl;
use mySociety::Gaze;
use mySociety::GeoUtil;
use mySociety::Locale;
use mySociety::MaPit;
use mySociety::PostcodeUtil;
use mySociety::Tracking;
use mySociety::WatchUpdate;
use mySociety::Web qw(ent NewURL);
BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
}

sub do_fastcgi {
    my $func = shift;

    try {
        my $W = new mySociety::WatchUpdate();
        while (my $q = new mySociety::CGIFast()) {
            microsite($q);
            &$func($q);
            dbh()->rollback() if $mySociety::DBHandle::conf_ok;
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
                q(<p>Please try again later, or <a href="mailto:team@fixmystreet.com">email us</a> to let us know.</p>),
                q(<hr>),
                q(<p>The text of the error was:</p>),
                qq(<blockquote class="errortext">$msg</blockquote>),
                q(</body></html>);
    };
    dbh()->rollback() if $mySociety::DBHandle::conf_ok;
    exit(0);
}

=item microsite Q

Work out what site we're on, template appropriately

=cut
sub microsite {
    my $q = shift;
    my $host = $ENV{HTTP_HOST} || '';
    $q->{site} = 'fixmystreet';
    $q->{site} = 'scambs' if $host =~ /scambs/;
    $q->{site} = 'emptyhomes' if $host =~ /emptyhomes/;

    if ($q->{site} eq 'emptyhomes') {
        mySociety::Locale::negotiate_language('en-gb,English,en_GB', 'en-gb');
        mySociety::Locale::gettext_domain('FixMyStreet-EmptyHomes');
        mySociety::Locale::change();
    } else {
        mySociety::Locale::gettext_domain('FixMyStreet');
    }

    if ($q->{site} eq 'scambs') {
        Problems::set_site_restriction('scambs');
    }
}

=item header Q [PARAM VALUE ...]

Return HTML for the top of the page, given PARAMs (TITLE is required).

=cut
sub header ($%) {
    my ($q, %params) = @_;

    my %permitted_params = map { $_ => 1 } qw(title rss js);
    foreach (keys %params) {
        croak "bad parameter '$_'" if (!exists($permitted_params{$_}));
    }

    my $title = $params{title} || '';
    $title .= ' - ' if $title;
    $title = ent($title);

    my $home = !$title && $ENV{SCRIPT_NAME} eq '/index.cgi' && !$ENV{QUERY_STRING};

    print $q->header(-charset => 'utf-8');

    my $html;
    if ($q->{site} eq 'scambs') {
        open FP, '../templates/website/scambs-header';
        $html = join('', <FP>);
        close FP;
        $html =~ s#<!-- TITLE -->#$title#;
    } elsif ($q->{site} eq 'emptyhomes') {
        open FP, '../templates/website/emptyhomes-header';
        $html = join('', <FP>);
        close FP;
        $html =~ s#<!-- TITLE -->#$title#;
    } else {
        $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en-gb">
    <head>
        <script type="text/javascript" src="/yui/utilities.js"></script>
<!-- 
        <script type="text/javascript" src="/jslib/swfupload/swfupload.js"></script>
        <script type="text/javascript" src="/jslib/swfupload/FileProgress.js"></script>
        <script type="text/javascript" src="/jslib/swfupload/swfupload.graceful_degradation.js"></script>
        <script type="text/javascript" src="/jslib/swfupload/swfupload_handlers.js"></script>
-->
        <script type="text/javascript" src="/js.js"></script>
        <title>${title}FixMyStreet</title>
        <style type="text/css">\@import url("/css/core.css"); \@import url("/css/main.css");</style>
<!--[if LT IE 7]>
<style type="text/css">\@import url("/css/ie6.css");</style>
<![endif]-->

        <!-- RSS -->
    </head>
    <body>
EOF
        $html .= $home ? '<h1 id="header">' : '<div id="header"><a href="/">';
        $html .= 'Fix<span id="my">My</span>Street';
        $html .= $home ? '</h1>' : '</a></div>';
        $html .= '<div id="wrapper"><div id="content">';
    }
    if ($params{rss}) {
        $html =~ s#<!-- RSS -->#<link rel="alternate" type="application/rss+xml" title="$params{rss}[0]" href="$params{rss}[1]">#;
    }
    if (mySociety::Config::get('STAGING_SITE')) {
        $html .= '<p id="error">This is a developer site; things might break at any time.</p>';
    }
    return $html;
}

=item footer

=cut
sub footer {
    my ($q, %params) = @_;
    my $extra = $params{extra};
    my $js = $params{js} || '';
    $js = ''; # Don't use fileupload JS at the moment

    if ($q->{site} eq 'scambs') {
        open FP, '../templates/website/scambs-footer';
        my $html = join('', <FP>);
        close FP;
        return $html;
    } elsif ($q->{site} eq 'emptyhomes') {
        open FP, '../templates/website/emptyhomes-footer';
        my $html = join('', <FP>);
        close FP;
        return $html;
    }

    my $pc = $q->param('pc') || '';
    $pc = "?pc=" . ent($pc) if $pc;
    $extra = $q->{scratch} if $q->{scratch}; # Overrides
    my $track = mySociety::Tracking::code($q, $extra);

    my $piwik = "";
    if (mySociety::Config::get('BASE_URL') eq "http://www.fixmystreet.com") {
        $piwik = <<EOF;
<!-- Piwik -->
<script type="text/javascript">
var pkBaseURL = (("https:" == document.location.protocol) ? "https://piwik.mysociety.org/" : "http://piwik.mysociety.org/");
document.write(unescape("%3Cscript src='" + pkBaseURL + "piwik.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
<!--
piwik_action_name = '';
piwik_idsite = 8;
piwik_url = pkBaseURL + "piwik.php";
piwik_log(piwik_action_name, piwik_idsite, piwik_url);
//-->
</script>
<noscript><img src="http://piwik.mysociety.org/piwik.php?i=1" style="border:0" alt=""></noscript>
<!-- /Piwik -->
EOF
    }

    return <<EOF;
</div></div>
<h2 class="v">Navigation</h2>
<ul id="navigation">
<li><a href="/">Report a problem</a></li>
<li><a href="/reports">All reports</a></li>
<li><a href="/alert$pc">Local alerts</a></li>
<li><a href="/faq">Help</a></li>
<li><a href="/contact">Contact</a></li>
</ul>

<a href="http://www.mysociety.org/"><img id="logo" src="/i/mysociety-dark.png" alt="View mySociety.org"><span id="logoie"></span></a>

<p id="footer">Built by <a href="http://www.mysociety.org/">mySociety</a>,
using some <a href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/bci">clever</a>&nbsp;<a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/services/TilMa">code</a>. Formerly <a href="/faq#nfi">Neighbourhood Fix-It</a>.</p>

$track

$js

$piwik

</body>
</html>
EOF
}

=item error_page Q MESSAGE

=cut
sub error_page ($$) {
    my ($q, $message);
    my $html = header($q, title=>"Error")
            . $q->p($message)
            . footer($q);
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
    my $mid_point = 254;
    if ($q->{site} eq 'emptyhomes' || $q->{site} eq 'scambs') { # Map is c. 380px wide
        $mid_point = 189;
    }
    my $px = defined($params{px}) ? $mid_point - $params{px} : 0;
    my $py = defined($params{py}) ? $mid_point - $params{py} : 0;
    my $x = int($params{x})<=0 ? 0 : $params{x};
    my $y = int($params{y})<=0 ? 0 : $params{y};
    my $url = mySociety::Config::get('TILES_URL');
    my $tiles_url = $url . $x . '-' . ($x+1) . ',' . $y . '-' . ($y+1) . '/RABX';
    my $tiles = LWP::Simple::get($tiles_url);
    return '<div id="map_box"> <div id="map"><div id="drag"> </div></div></div><div id="side">' if !$tiles;
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
<input type="hidden" name="x" id="formX" value="$x">
<input type="hidden" name="y" id="formY" value="$y">
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
var start_x = $px; var start_y = $py;
</script>
<div id="map_box">
$params{pre}
    <div id="map"><div id="drag">
        $img_type alt="NW map tile" id="t2.2" name="tile_$tl" src="$tl_src" style="top:0px; left:0;">$img_type alt="NE map tile" id="t2.3" name="tile_$tr" src="$tr_src" style="top:0px; left:$imgw;"><br>$img_type alt="SW map tile" id="t3.2" name="tile_$bl" src="$bl_src" style="top:$imgh; left:0;">$img_type alt="SE map tile" id="t3.3" name="tile_$br" src="$br_src" style="top:$imgh; left:$imgw;">
        <div id="pins">$params{pins}</div>
    </div>
EOF
    $out .= '<div id="watermark"></div>';
    $out .= compass($q, $x, $y);
    $out .= <<EOF;
    </div>
    <p id="copyright">&copy; Crown copyright.  All rights reserved.
    Ministry of Justice 100037819&nbsp;2008</p>
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
    $num = '' if !$num || $num > 9;
    my %cols = (red=>'R', green=>'G', blue=>'B', purple=>'P');
    my $out = '<img class="pin" src="/i/pin' . $cols{$col}
        . $num . '.gif" alt="' . _('Problem') . '" style="top:' . ($py-59)
        . 'px; left:' . ($px) . 'px; position: absolute;">';
    return $out unless $_ && $_->{id} && $col ne 'blue';
    my $url = NewURL($q, id=>$_->{id}, x=>undef, y=>undef);
    $out = '<a title="' . $_->{title} . '" href="' . $url . '">' . $out . '</a>';
    return $out;
}

sub map_pins {
    my ($q, $x, $y, $sx, $sy) = @_;

    my $pins = '';
    my $min_e = Page::tile_to_os($x-2); # Extra space to left/below due to rounding, I think
    my $min_n = Page::tile_to_os($y-2);
    #my $map_le = Page::tile_to_os($x);
    #my $map_ln = Page::tile_to_os($y);
    my $mid_e = Page::tile_to_os($x+1);
    my $mid_n = Page::tile_to_os($y+1);
    #my $map_re = Page::tile_to_os($x+2);
    #my $map_rn = Page::tile_to_os($y+2);
    my $max_e = Page::tile_to_os($x+3);
    my $max_n = Page::tile_to_os($y+3);

    my $around_map = Problems::around_map($min_e, $max_e, $min_n, $max_n);
    my @ids = ();
    #my $count_prob = 1;
    #my $count_fixed = 1;
    foreach (@$around_map) {
        push(@ids, $_->{id});
        my $px = Page::os_to_px($_->{easting}, $sx);
        my $py = Page::os_to_px($_->{northing}, $sy, 1);
        my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
        $pins .= Page::display_pin($q, $px, $py, $col); # , $count_prob++);
    }

    my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($mid_e, $mid_n, 'G');
    my $dist = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
    $dist = int($dist*10+0.5)/10;

    # XXX: Change to only show problems with extract(epoch from ms_current_timestamp()-lastupdate) < 8 weeks
    # And somehow display/link to old problems somewhere else...
    my $nearby = [];
    #if (@$current_map < 9) {
        my $limit = 20; # - @$current_map;
        $nearby = Problems::nearby($dist, join(',', @ids), $limit, $mid_e, $mid_n);
        foreach (@$nearby) {
            my $px = Page::os_to_px($_->{easting}, $sx);
            my $py = Page::os_to_px($_->{northing}, $sy, 1);
            my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
            $pins .= Page::display_pin($q, $px, $py, $col); #, $count_prob++);
        }
    #} else {
    #    @$current_map = @$current_map[0..8];
    #}

    #my $fixed = Problems::fixed_nearby($dist, $mid_e, $mid_n);
    #foreach (@$fixed) {
    #    my $px = Page::os_to_px($_->{easting}, $sx);
    #    my $py = Page::os_to_px($_->{northing}, $sy, 1);
    #    $pins .= Page::display_pin($q, $px, $py, 'green'); # , $count_fixed++);
    #}
    #if (@$fixed > 9) {
    #    @$fixed = @$fixed[0..8];
    #}

    return ($pins, $around_map, $nearby, $dist); # , $current_map, $current, '', $dist); # $fixed, $dist);
}

sub compass ($$$) {
    my ($q, $x, $y) = @_;
    my @compass;
    for (my $i=$x-1; $i<=$x+1; $i++) {
        for (my $j=$y-1; $j<=$y+1; $j++) {
            $compass[$i][$j] = NewURL($q, x=>$i, y=>$j);
        }
    }
    my $recentre = NewURL($q, x=>undef, y=>undef);
    return <<EOF;
<table cellpadding="0" cellspacing="0" border="0" id="compass">
<tr valign="bottom">
<td align="right"><a href="${compass[$x-1][$y+1]}"><img src="/i/arrow-northwest.gif" alt="NW"></a></td>
<td align="center"><a href="${compass[$x][$y+1]}"><img src="/i/arrow-north.gif" vspace="3" alt="N"></a></td>
<td><a href="${compass[$x+1][$y+1]}"><img src="/i/arrow-northeast.gif" alt="NE"></a></td>
</tr>
<tr>
<td><a href="${compass[$x-1][$y]}"><img src="/i/arrow-west.gif" hspace="3" alt="W"></a></td>
<td align="center"><a href="$recentre"><img src="/i/rose.gif" alt="Recentre"></a></td>
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
    my ($p, $bl, $invert) = @_;
    return tile_to_px(os_to_tile($p), $bl, $invert);
}

# Convert tile co-ordinates to pixel co-ordinates from top left of map
# BL is bottom left tile reference of displayed map
sub tile_to_px {
    my ($p, $bl, $invert) = @_;
    $p = 254 * ($p - $bl);
    $p = 508 - $p if $invert;
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

sub os_to_px_with_adjust {
    my ($q, $easting, $northing, $in_x, $in_y) = @_;

    my $x = Page::os_to_tile($easting);
    my $y = Page::os_to_tile($northing);
    my $x_tile = $in_x || int($x);
    my $y_tile = $in_y || int($y);
    my $px = Page::os_to_px($easting, $x_tile);
    my $py = Page::os_to_px($northing, $y_tile, 1);
    if ($q->{site} eq 'emptyhomes' || $q->{site} eq 'scambs') { # Map is 380px
        if ($py > 380) {
            $y_tile--;
            $py = Page::os_to_px($northing, $y_tile, 1);
        }
        if ($px > 380) {
            $x_tile--;
            $px = Page::os_to_px($easting, $x_tile);
        }
    }
    return ($x, $y, $x_tile, $y_tile, $px, $py);
}

# send_email TO (NAME) TEMPLATE-NAME PARAMETERS
sub send_email {
    my ($q, $email, $name, $thing, %h) = @_;
    my $template = "$thing-confirm";
    $template = File::Slurp::read_file("$FindBin::Bin/../templates/emails/$template");
    $template =~ s/FixMyStreet/Envirocrime/ if $q->{site} eq 'scambs';
    my $to = $name ? [[$email, $name]] : $email;
    my $sender = mySociety::Config::get('CONTACT_EMAIL');
    $sender =~ s/team/fms-DO-NOT-REPLY/;
    mySociety::EvEl::send({
        _template_ => _($template),
        _parameters_ => \%h,
        From => [ $sender, _('FixMyStreet')],
        To => $to,
    }, $email);

    my $action = ($thing eq 'alert') ? 'confirmed' : 'posted';
    $thing .= ' report' if $thing eq _('problem');
    $thing = 'expression of interest' if $thing eq 'tms';
    my $out = <<EOF;
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
    } elsif (strftime('%Y %U', @s) eq strftime('%Y %U', @t)) {
        $tt = "$tt, " . strftime('%A', @s);
    } elsif (strftime('%Y', @s) eq strftime('%Y', @t)) {
        $tt = "$tt, " . strftime('%A %e %B %Y', @s);
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
            my $council = join(' and ', map { $areas_info->{$_}->{name} } @councils);
            $out .= $q->br() . $q->small('Sent to ' . $council . ' ' .
                prettify_duration($problem->{whensent}, 'minute') . ' later');
        }
    } elsif ($q->{site} ne 'emptyhomes') {
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
        "select id, name, extract(epoch from created) as created, text,
         mark_fixed, mark_open, (photo is not null) as has_photo
         from comment where problem_id = ? and state='confirmed'
         order by created", $id);
    my $out = '';
    if (@$updates) {
        $out .= '<div id="updates">';
        $out .= '<h2>Updates</h2>';
        foreach my $row (@$updates) {
            $out .= "<div><p><a name=\"update_$row->{id}\"></a><em>";
            if ($row->{name}) {
                $out .= sprintf(_('Posted by %s'), ent($row->{name}));
            } else {
                $out .= _("Posted anonymously");
            }
            $out .= " at " . prettify_epoch($row->{created});
            $out .= ', ' . _('marked as fixed') if ($row->{mark_fixed});
            $out .= ', ' . _('reopened') if ($row->{mark_open});
            $out .= '</em></p>';
            $out .= '<p>' . ent($row->{text}) . '</p>';
            if ($row->{has_photo}) {
                $out .= '<p align="center"><img src="/photo?tn=1;c=' . $row->{id} . '"></p>';
            }
            $out .= '</div>';
        }
        $out .= '</div>';
    }
    return $out;
}

# geocode STRING
# Given a user-inputted string, try and convert it into co-ordinates using either
# MaPit if it's a postcode, or Google Maps API otherwise. Returns an array of
# data, including an error if there is one (which includes a location being in 
# Northern Ireland).
sub geocode {
    my ($s) = @_;
    my ($x, $y, $easting, $northing, $error);
    if (mySociety::PostcodeUtil::is_valid_postcode($s)) {
        try {
            my $location = mySociety::MaPit::get_location($s);
            my $island = $location->{coordsyst};
            throw RABX::Error("We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.") if $island eq 'I';
            $easting = $location->{easting};
            $northing = $location->{northing};
            my $xx = Page::os_to_tile($easting);
            my $yy = Page::os_to_tile($northing);
            $x = int($xx);
            $y = int($yy);
            $x -= 1 if ($xx - $x < 0.5);
            $y -= 1 if ($yy - $y < 0.5);
        } catch RABX::Error with {
            my $e = shift;
            if ($e->value() && ($e->value() == mySociety::MaPit::BAD_POSTCODE
               || $e->value() == mySociety::MaPit::POSTCODE_NOT_FOUND)) {
                $error = 'That postcode was not recognised, sorry.';
            } else {
                $error = $e;
            }
        }
    } else {
        ($x, $y, $easting, $northing, $error) = geocode_string($s);
    }
    return ($x, $y, $easting, $northing, $error);
}

# geocode_string STRING
# Canonicalises, looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (TILE_X, TILE_Y, EASTING, NORTHING, ERROR), where ERROR is
# either undef, a string, or an array of matches if there are more than one.
sub geocode_string {
    my $s = shift;
    $s = lc($s);
    $s =~ s/[^-&0-9a-z ']/ /g;
    $s =~ s/\s+/ /g;
    $s = uri_escape($s);
    $s =~ s/%20/+/g;
    my $url = 'http://maps.google.com/maps/geo?q=' . $s;
    my $cache_dir = mySociety::Config::get('GEO_CACHE');
    my $cache_file = $cache_dir . md5_hex($url);
    my ($js, $error, $x, $y, $easting, $northing);
    if (-s $cache_file) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        $url .= ',+United+Kingdom' unless $url =~ /united\++kingdom$/ || $url =~ /uk$/i;
        $url .= '&key=' . mySociety::Config::get('GOOGLE_MAPS_API_KEY');
        $js = LWP::Simple::get($url);
        File::Slurp::write_file($cache_file, $js) if $js && $js !~ /"code":6[12]0/;
    }

    if (!$js) {
        $error = 'Sorry, we had a problem parsing that location. Please try again.';
    } elsif ($js !~ /"code":200/) {
        $error = 'Sorry, we could not find that location.';
    } elsif ($js =~ /},{/) { # Multiple
        while ($js =~ /"address":"(.*?)"/g) {
            push (@$error, $1) unless $1 =~ /BT\d/;
        }
        $error = 'Sorry, we could not find that location.' unless $error;
    } elsif ($js =~ /BT\d/) {
        # Northern Ireland, hopefully
        $error = "We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.";
    } else {
        my ($accuracy) = $js =~ /"Accuracy": (\d)/;
        if ($accuracy < 4) {
            $error = 'Sorry, that location appears to be too general; please be more specific.';
        } else {
            $js =~ /"coordinates":\[(.*?),(.*?),/;
            my $lon = $1; my $lat = $2;
            try {
                ($easting, $northing) = mySociety::GeoUtil::wgs84_to_national_grid($lat, $lon, 'G');
                my $xx = Page::os_to_tile($easting);
                my $yy = Page::os_to_tile($northing);
                $x = int($xx);
                $y = int($yy);
                $x -= 1 if ($xx - $x < 0.5);
                $y -= 1 if ($yy - $y < 0.5);
            } catch Error::Simple with {
                $error = shift;
                $error = "That location doesn't appear to be in Britain; please try again."
                    if $error =~ /out of the area covered/;
            }
        }
    }
    return ($x, $y, $easting, $northing, $error);
}

# geocode_choice
# Prints response if there's more than one possible result
sub geocode_choice {
    my ($choices, $page) = @_;
    my $out = '<p>We found more than one match for that location. We show up to ten matches, please try a different search if yours is not here.</p> <ul>';
    foreach my $choice (@$choices) {
        $choice =~ s/, United Kingdom//;
        $choice =~ s/, UK//;
        my $url = uri_escape($choice);
        $url =~ s/%20/+/g;
        $out .= '<li><a href="' . $page . '?pc=' . $url . '">' . $choice . "</a></li>\n";
    }
    $out .= '</ul>';
    return $out;
}

sub short_name {
    my $name = shift;
    # Special case Durham as it's the only place with two councils of the same name
    return 'Durham+County' if ($name eq 'Durham County Council');
    return 'Durham+City' if ($name eq 'Durham City Council');
    $name =~ s/ (Borough|City|District|County) Council$//;
    $name =~ s/ Council$//;
    $name =~ s/ & / and /;
    $name = uri_escape($name);
    $name =~ s/%20/+/g;
    return $name;
}

sub check_photo {
    my ($q, $fh) = @_;
    my $ct = $q->uploadInfo($fh)->{'Content-Type'};
    my $cd = $q->uploadInfo($fh)->{'Content-Disposition'};
    # Must delete photo param, otherwise display functions get confused
    $q->delete('photo');
    return 'Please upload a JPEG image only' unless
        ($ct eq 'image/jpeg' || $ct eq 'image/pjpeg');
    return '';
}

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

sub workaround_pg_bytea {
    my ($st, $img_idx, @elements) = @_;
    my $s = dbh()->prepare($st);
    for (my $i=1; $i<=@elements; $i++) {
        if ($i == $img_idx) {
            $s->bind_param($i, $elements[$i-1], { pg_type => DBD::Pg::PG_BYTEA });
        } else {
            $s->bind_param($i, $elements[$i-1]);
        }
    }
    $s->execute();
}

sub scambs_categories {
    return ('Abandoned vehicles', 'Discarded hypodermic needles',
            'Dog fouling', 'Flytipping', 'Graffiti', 'Lighting (e.g. security lights)',
            'Litter', 'Neighbourhood noise');
}

1;
