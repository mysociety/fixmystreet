#!/usr/bin/perl
#
# Page.pm:
# Various HTML stuff for the BCI site.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.pm,v 1.186 2009-09-28 10:43:58 louise Exp $
#

package Page;

use strict;
use Carp;
use mySociety::CGIFast qw(-no_xhtml);
use Error qw(:try);
use File::Slurp;
use HTTP::Date;
use Image::Magick;
use Image::Size;
use LWP::Simple;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use URI::Escape;

use Memcached;
use Problems;
use Utils;
use Cobrand;
use mySociety::Config;
use mySociety::DBHandle qw/dbh select_all/;
use mySociety::EvEl;
use mySociety::Gaze;
use mySociety::GeoUtil;
use mySociety::Locale;
use mySociety::MaPit;
use mySociety::PostcodeUtil;
use mySociety::TempFiles;
use mySociety::Tracking;
use mySociety::WatchUpdate;
use mySociety::Web qw(ent NewURL);

BEGIN {
    (my $dir = __FILE__) =~ s{/[^/]*?$}{};
    mySociety::Config::set_file("$dir/../conf/general");
}

my $lastmodified;

sub do_fastcgi {
    my ($func, $lm) = @_;

    try {
        my $W = new mySociety::WatchUpdate();
        while (my $q = new mySociety::Web()) {
            next if $lm && $q->Maybe304($lm);
            $lastmodified = $lm;
            microsite($q);
            &$func($q);
            dbh()->rollback() if $mySociety::DBHandle::conf_ok;
            $W->exit_if_changed();
        }
    } catch Error::Simple with {
        report_error(@_);
    } catch Error with {
        report_error(@_);
    };
    dbh()->rollback() if $mySociety::DBHandle::conf_ok;
    exit(0);
}

sub report_error {
    my $E = shift;
    my $msg = sprintf('%s:%d: %s', $E->file(), $E->line(), CGI::escapeHTML($E->text()));
    warn "caught fatal exception: $msg";
    warn "aborting";
    ent($msg);
    my $contact_email = mySociety::Config::get('CONTACT_EMAIL');
    my $trylater = sprintf(_('Please try again later, or <a href="mailto:%s">email us</a> to let us know.'), $contact_email);
    my $somethingwrong = _("Sorry! Something's gone wrong.");
    my $errortext = _("The text of the error was:");
    print "Status: 500\nContent-Type: text/html; charset=iso-8859-1\n\n",
            qq(<html><head><title>$somethingwrong</title></head></html>),
            q(<body>),
            qq(<h1>$somethingwrong</h1>),
            qq(<p>$trylater</p>),
            q(<hr>),
            qq(<p>$errortext</p>),
            qq(<blockquote class="errortext">$msg</blockquote>),
            q(</body></html>);
}

=item microsite Q

Work out what site we're on, template appropriately

=cut
sub microsite {
    my $q = shift;
    my $host = $ENV{HTTP_HOST} || '';
    $q->{site} = 'fixmystreet';
    my $allowed_cobrands = Cobrand::get_allowed_cobrands();
        foreach my $cobrand (@{$allowed_cobrands}){
        $q->{site} = $cobrand if $host =~ /$cobrand/;
    }

    my $lang;
    $lang = 'cy' if $host =~ /cy/;
    $lang = 'en-gb' if $host =~ /^en\./;
    Cobrand::set_lang_and_domain(get_cobrand($q), $lang);

    Problems::set_site_restriction($q);
    Memcached::set_namespace(mySociety::Config::get('BCI_DB_NAME') . ":");
}
=item get_cobrand Q

Return the cobrand for a query

=cut
sub get_cobrand {
    my $q = shift;
    my $cobrand = '';
    $cobrand = $q->{site} if $q->{site} ne 'fixmystreet';
    return $cobrand;
}

=item base_url_with_lang Q REVERSE EMAIL

Return the base URL for the site. Reverse the language component if REVERSE is set to one. If EMAIL is set to
one, return the base URL to use in emails.

=cut

sub base_url_with_lang {
    my ($q, $reverse, $email) = @_;
    my $base;
    if ($email) {
        $base = Cobrand::base_url_for_emails(get_cobrand($q));
    } else {
        $base = Cobrand::base_url(get_cobrand($q));
    }
    return $base unless $q->{site} eq 'emptyhomes';
    my $lang = $mySociety::Locale::lang;
    if ($reverse && $lang eq 'en-gb') {
        $base =~ s{http://}{$&cy.};
    } elsif ($reverse) {
        $base =~ s{http://}{$&en.};
    } elsif ($lang eq 'cy') {
        $base =~ s{http://}{$&cy.};
    } else {
        $base =~ s{http://}{$&en.};
    }
    return $base;
}

=item template_root 

Returns the path from which template files will be read. 

=cut 

sub template_root{
    return '/../templates/website/cobrands/';
}

=item template_vars QUERY LANG

Return a hash of variables that can be substituted into header and footer templates.
QUERY is the incoming request
LANG is the language the templates will be rendered in.

=cut

sub template_vars ($$){
    my ($q, $lang) = @_;
    my %vars;
    my $host = base_url_with_lang($q, undef);
    my $lang_url = base_url_with_lang($q, 1);
    $lang_url .= $ENV{REQUEST_URI} if $ENV{REQUEST_URI};
    %vars = (
        'report' => _('Report a problem'),
        'reports' => _('All reports'),
        'alert' => _('Local alerts'),
        'faq' => _('Help'),
        'about' => _('About us'),
        'site_title' => Cobrand::site_title(get_cobrand($q)),
        'host' => $host,
        'lang_code' => $lang,
        'lang' => $lang eq 'en-gb' ? 'Cymraeg' : 'English',
        'lang_url' => $lang_url,
    );
    return \%vars;
}

=item template Q [PARAM VALUE ...]

Return the correct template given PARAMs

=cut
sub template($%){
    my ($q, %params) = @_;        
    my $template;
    if ($params{template}){
        $template = $params{template};
    }else{
        $template = $q->{site};
    }
    return $template;
}

=item template_header TITLE TEMPLATE Q LANG 

Return HTML for the templated top of a page, given a 
title, template name, request, language and template root.

=cut

sub template_header{
     
    my ($title, $template, $q, $lang, $template_root) = @_;
    (my $file = __FILE__) =~ s{/[^/]*?$}{};
    open FP, $file . $template_root . $q->{site} . '/' . $template . '-header';
    my $html = join('', <FP>);
    close FP;
    my $vars = template_vars($q, $lang);
    $vars->{title} = $title;
    $html =~ s#{{ ([a-z_]+) }}#$vars->{$1}#g;
    return $html;

}

=item header Q [PARAM VALUE ...]

Return HTML for the top of the page, given PARAMs (TITLE is required).

=cut
sub header ($%) {
    my ($q, %params) = @_;
    my $default_params = Cobrand::header_params(get_cobrand($q));
    my %default_params = %{$default_params};
    %params = (%default_params, %params);
    my %permitted_params = map { $_ => 1 } qw(title rss js expires lastmodified template cachecontrol);
    foreach (keys %params) {
        croak "bad parameter '$_'" if (!exists($permitted_params{$_}));
    }

    my $title = $params{title} || '';
    $title .= ' - ' if $title;
    $title = ent($title);

    my $home = !$title && $ENV{SCRIPT_NAME} eq '/index.cgi' && !$ENV{QUERY_STRING};

    my %head = ();
    $head{-expires} = $params{expires} if $params{expires};
    $head{'-last-modified'} = time2str($params{lastmodified}) if $params{lastmodified};
    $head{'-last-modified'} = time2str($lastmodified) if $lastmodified;
    $head{'-cache-control'} = $params{cachecontrol} if $params{cachecontrol};
    print $q->header(%head);

    my $html;
    my $lang = $mySociety::Locale::lang;
    if ($q->{site} ne 'fixmystreet') {
        my $template = template($q, %params);
        $html = template_header($title, $template, $q, $lang, template_root());
    } else {
        my $fixmystreet = _('FixMyStreet');
        $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="$lang">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <script type="text/javascript" src="/yui/utilities.js"></script>
        <script type="text/javascript" src="/js.js"></script>
        <title>${title}$fixmystreet</title>
        <style type="text/css">\@import url("/css/core.css"); \@import url("/css/main.css");</style>
<!--[if LT IE 7]>
<style type="text/css">\@import url("/css/ie6.css");</style>
<![endif]-->

        <!-- RSS -->
    </head>
    <body>
EOF
        $html .= $home ? '<h1 id="header">' : '<div id="header"><a href="/">';
        $html .= _('Fix<span id="my">My</span>Street');
        $html .= $home ? '</h1>' : '</a></div>';
        $html .= '<div id="wrapper"><div id="content">';
    }
    if ($params{rss}) {
        $html =~ s#<!-- RSS -->#<link rel="alternate" type="application/rss+xml" title="$params{rss}[0]" href="$params{rss}[1]">#;
    }
    if (mySociety::Config::get('STAGING_SITE')) {
        $html .= '<p class="error">' . _("This is a developer site; things might break at any time.") . '</p>';
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

    if ($q->{site} ne 'fixmystreet') {
        (my $file = __FILE__) =~ s{/[^/]*?$}{};
        my $template = template($q, %params);
        open FP, $file . template_root() . $q->{site} . '/' . $template . '-footer';
        my $html = join('', <FP>);
        close FP;
        my $lang = $mySociety::Locale::lang;
        if ($q->{site} eq 'emptyhomes' && $lang eq 'cy') {
            $html =~ s/25 Walter Road<br>Swansea/25 Heol Walter<br>Abertawe/;
        }
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
<noscript><img width=1 height=1 src="http://piwik.mysociety.org/piwik.php?idsite=8" style="border:0" alt=""></noscript>
<!-- /Piwik -->
EOF
    }

    my $navigation = _('Navigation');
    my $report = _("Report a problem");
    my $reports = _("All reports");
    my $alerts = _("Local alerts");
    my $help = _("Help");
    my $contact = _("Contact");
    my $orglogo = _('<a href="http://www.mysociety.org/"><img id="logo" width="133" height="26" src="/i/mysociety-dark.png" alt="View mySociety.org"><span id="logoie"></span></a>');
    my $creditline = _('Built by <a href="http://www.mysociety.org/">mySociety</a>, using some <a href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/bci">clever</a>&nbsp;<a href="https://secure.mysociety.org/cvstrac/dir?d=mysociety/services/TilMa">code</a>.');

    return <<EOF;
</div></div>
<h2 class="v">$navigation</h2>
<ul id="navigation">
<li><a href="/">$report</a></li>
<li><a href="/reports">$reports</a></li>
<li><a href="/alert$pc">$alerts</a></li>
<li><a href="/faq">$help</a></li>
<li><a href="/contact">$contact</a></li>
</ul>

$orglogo

<p id="footer">$creditline</p>

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
    my $html = header($q, title=>_("Error"))
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
    if ($q->{site} eq 'scambs') { # Map is c. 380px wide
        $mid_point = 189;
    }
    my $px = defined($params{px}) ? $mid_point - $params{px} : 0;
    my $py = defined($params{py}) ? $mid_point - $params{py} : 0;
    my $x = int($params{x})<=0 ? 0 : $params{x};
    my $y = int($params{y})<=0 ? 0 : $params{y};
    my $url = mySociety::Config::get('TILES_URL');
    my $tiles_url = $url . $x . '-' . ($x+1) . ',' . $y . '-' . ($y+1) . '/RABX';
    my $tiles = LWP::Simple::get($tiles_url);
    return '<div id="map_box"> <div id="map"><div id="drag">' . _("Unable to fetch the map tiles from the tile server.") . '</div></div></div><div id="side">' if !$tiles;
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
    my $cobrand = Page::get_cobrand($q);
    my $root_path_js = Cobrand::root_path_js($cobrand);
    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'mapForm', $q);
    my $img_type;
    if ($params{type}) {
        my $encoding = '';
        $encoding = ' enctype="multipart/form-data"' if ($params{type}==2);
        my $pc = $q->param('pc') || '';
        my $pc_enc = ent($pc);
        $out .= <<EOF;
<form action="/" method="post" name="mapForm" id="mapForm"$encoding>
<input type="hidden" name="submit_map" value="1">
<input type="hidden" name="x" id="formX" value="$x">
<input type="hidden" name="y" id="formY" value="$y">
<input type="hidden" name="pc" value="$pc_enc">
$cobrand_form_elements
EOF
        $img_type = '<input type="image"';
    } else {
        $img_type = '<img';
    }
    my $imgw = '254px';
    my $imgh = '254px';
    $out .= <<EOF;
<script type="text/javascript">
var fms_x = $x - 2; var fms_y = $y - 2;
var start_x = $px; var start_y = $py;
$root_path_js
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
    my $copyright = _('Crown copyright. All rights reserved. Ministry of Justice');
    $out .= <<EOF;
    </div>
    <p id="copyright">&copy; $copyright 100037819&nbsp;2008</p>
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
    my $host = base_url_with_lang($q, undef);
    my %cols = (red=>'R', green=>'G', blue=>'B', purple=>'P');
    my $out = '<img class="pin" src="' . $host . '/i/pin' . $cols{$col}
        . $num . '.gif" alt="' . _('Problem') . '" style="top:' . ($py-59)
        . 'px; left:' . ($px) . 'px; position: absolute;">';
    return $out unless $_ && $_->{id} && $col ne 'blue';
    my $url = NewURL($q, -retain => 1, -url => '/report/' . $_->{id}, pc => undef);
    $out = '<a title="' . ent($_->{title}) . '" href="' . $url . '">' . $out . '</a>';
    return $out;
}

sub map_pins {
    my ($q, $x, $y, $sx, $sy, $interval) = @_;

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

    my $around_map = Problems::around_map($min_e, $max_e, $min_n, $max_n, $interval);
    my @ids = ();
    foreach (@$around_map) {
        push(@ids, $_->{id});
        my $px = Page::os_to_px($_->{easting}, $sx);
        my $py = Page::os_to_px($_->{northing}, $sy, 1);
        my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
        $pins .= Page::display_pin($q, $px, $py, $col);
    }

    my $dist;
    mySociety::Locale::in_gb_locale {
        my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($mid_e, $mid_n, 'G');
        $dist = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
    };
    $dist = int($dist*10+0.5)/10;

    my $limit = 20; # - @$current_map;
    my $nearby = Problems::nearby($dist, join(',', @ids), $limit, $mid_e, $mid_n, $interval);
    foreach (@$nearby) {
        my $px = Page::os_to_px($_->{easting}, $sx);
        my $py = Page::os_to_px($_->{northing}, $sy, 1);
        my $col = $_->{state} eq 'fixed' ? 'green' : 'red';
        $pins .= Page::display_pin($q, $px, $py, $col);
    }

    return ($pins, $around_map, $nearby, $dist);
}

sub compass ($$$) {
    my ($q, $x, $y) = @_;
    my @compass;
    for (my $i=$x-1; $i<=$x+1; $i++) {
        for (my $j=$y-1; $j<=$y+1; $j++) {
            $compass[$i][$j] = NewURL($q, x=>$i, y=>$j);
        }
    }
    my $recentre = NewURL($q);
    my $host = base_url_with_lang($q, undef);
    return <<EOF;
<table cellpadding="0" cellspacing="0" border="0" id="compass">
<tr valign="bottom">
<td align="right"><a rel="nofollow" href="${compass[$x-1][$y+1]}"><img src="$host/i/arrow-northwest.gif" alt="NW" width=11 height=11></a></td>
<td align="center"><a rel="nofollow" href="${compass[$x][$y+1]}"><img src="$host/i/arrow-north.gif" vspace="3" alt="N" width=13 height=11></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y+1]}"><img src="$host/i/arrow-northeast.gif" alt="NE" width=11 height=11></a></td>
</tr>
<tr>
<td><a rel="nofollow" href="${compass[$x-1][$y]}"><img src="$host/i/arrow-west.gif" hspace="3" alt="W" width=11 height=13></a></td>
<td align="center"><a rel="nofollow" href="$recentre"><img src="$host/i/rose.gif" alt="Recentre" width=35 height=34></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y]}"><img src="$host/i/arrow-east.gif" hspace="3" alt="E" width=11 height=13></a></td>
</tr>
<tr valign="top">
<td align="right"><a rel="nofollow" href="${compass[$x-1][$y-1]}"><img src="$host/i/arrow-southwest.gif" alt="SW" width=11 height=11></a></td>
<td align="center"><a rel="nofollow" href="${compass[$x][$y-1]}"><img src="$host/i/arrow-south.gif" vspace="3" alt="S" width=13 height=11></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y-1]}"><img src="$host/i/arrow-southeast.gif" alt="SE" width=11 height=11></a></td>
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
    if ($q->{site} eq 'scambs') { # Map is 380px
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
# TEMPLATE-NAME is currently one of problem, update, alert, tms
sub send_email {
    my ($q, $email, $name, $thing, %h) = @_;
    my $file_thing = $thing;
    $file_thing = 'empty property' if $q->{site} eq 'emptyhomes' && $thing eq 'problem'; # Needs to be in English
    my $template = "$file_thing-confirm";
    $template = File::Slurp::read_file("$FindBin::Bin/../templates/emails/$template");
    my $to = $name ? [[$email, $name]] : $email;
    my $sender = Cobrand::contact_email(get_cobrand($q));
    $sender =~ s/team/fms-DO-NOT-REPLY/;
    mySociety::EvEl::send({
        _template_ => _($template),
        _parameters_ => \%h,
        From => [ $sender, _('FixMyStreet')],
        To => $to,
    }, $email);

    my ($action, $worry);
    if ($thing eq 'problem') {
        $action = _('your problem will not be posted');
        $worry = _("we'll hang on to your problem report while you're checking your email.");
    } elsif ($thing eq 'update') {
        $action = _('your update will not be posted');
        $worry = _("we'll hang on to your update while you're checking your email.");
    } elsif ($thing eq 'alert') {
        $action = _('your alert will not be activated');
        $worry = _("we'll hang on to your alert while you're checking your email.");
    } elsif ($thing eq 'tms') {
        $action = 'your expression of interest will not be registered';
        $worry = "we'll hang on to your expression of interest while you're checking your email.";
    }
    my $out = sprintf(_(<<EOF), $action, $worry);
<h1>Nearly Done! Now check your email...</h1>
<p>The confirmation email <strong>may</strong> take a few minutes to arrive &mdash; <em>please</em> be patient.</p>
<p>If you use web-based email or have 'junk mail' filters, you may wish to check your bulk/spam mail folders: sometimes, our messages are marked that way.</p>
<p>You must now click the link in the email we've just sent you &mdash;
if you do not, %s.</p>
<p>(Don't worry &mdash; %s)</p>
EOF
    return $out;
}

sub prettify_epoch {
    my $s = shift;
    my @s = localtime($s);
    my $tt = strftime('%H:%M', @s);
    my @t = localtime();
    if (strftime('%Y%m%d', @s) eq strftime('%Y%m%d', @t)) {
        $tt = "$tt " . _('today');
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
        return _('less than a minute') if $s == 0;
    }
    my @out = ();
    _part(\$s, 60*60*24*7, _('week'), \@out);
    _part(\$s, 60*60*24, _('day'), \@out);
    _part(\$s, 60*60, _('hour'), \@out);
    _part(\$s, 60, _('minute'), \@out);
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
    $out .= '<p><em>';
    if ($q->{site} eq 'emptyhomes') {
        my $category = _($problem->{category});
        utf8::decode($category); # So that Welsh to Welsh doesn't encode already-encoded UTF-8
        if ($problem->{anonymous}) {
            $out .= sprintf(_('%s, reported anonymously at %s'), ent($category), prettify_epoch($problem->{time}));
        } else {
            $out .= sprintf(_('%s, reported by %s at %s'), ent($category), ent($problem->{name}), prettify_epoch($problem->{time}));
        }
    } else {
        if ($problem->{service} && $problem->{category} && $problem->{category} ne 'Other' && $problem->{anonymous}) {
            $out .= sprintf(_('Reported by %s in the %s category anonymously at %s'), ent($problem->{service}), ent($problem->{category}), prettify_epoch($problem->{time}));
        } elsif ($problem->{service} && $problem->{category} && $problem->{category} ne 'Other') {
            $out .= sprintf(_('Reported by %s in the %s category by %s at %s'), ent($problem->{service}), ent($problem->{category}), ent($problem->{name}), prettify_epoch($problem->{time}));
        } elsif ($problem->{service} && $problem->{anonymous}) {
            $out .= sprintf(_('Reported by %s anonymously at %s'), ent($problem->{service}), prettify_epoch($problem->{time}));
        } elsif ($problem->{service}) {
            $out .= sprintf(_('Reported by %s by %s at %s'), ent($problem->{service}), ent($problem->{name}), prettify_epoch($problem->{time}));
        } elsif ($problem->{category} && $problem->{category} ne 'Other' && $problem->{anonymous}) {
            $out .= sprintf(_('Reported in the %s category anonymously at %s'), ent($problem->{category}), prettify_epoch($problem->{time}));
        } elsif ($problem->{category} && $problem->{category} ne 'Other') {
            $out .= sprintf(_('Reported in the %s category by %s at %s'), ent($problem->{category}), ent($problem->{name}), prettify_epoch($problem->{time}));
        } elsif ($problem->{anonymous}) {
            $out .= sprintf(_('Reported anonymously at %s'), prettify_epoch($problem->{time}));
        } else {
            $out .= sprintf(_('Reported by %s at %s'), ent($problem->{name}), prettify_epoch($problem->{time}));
        }
    }
    $out .= '; ' . _('the map was not used so pin location may be inaccurate') unless ($problem->{used_map});
    if ($problem->{council}) {
        if ($problem->{whensent}) {
            $problem->{council} =~ s/\|.*//g;
            my @councils = split /,/, $problem->{council};
            my $areas_info = mySociety::MaPit::get_voting_areas_info(\@councils);
            my $council = join(' and ', map { $areas_info->{$_}->{name} } @councils);
            $out .= $q->br() . $q->small(sprintf(_('Sent to %s %s later'), $council, prettify_duration($problem->{whensent}, 'minute')));
        }
    } else {
        $out .= $q->br() . $q->small(_('Not reported to council'));
    }
    $out .= '</em></p>';
    my $detail = $problem->{detail};
    $detail =~ s/\r//g;
    foreach (split /\n{2,}/, $detail) {
        $out .= '<p>' . ent($_) . '</p>';
    }

    if ($problem->{photo}) {
        my $dims = Image::Size::html_imgsize(\$problem->{photo});
        $out .= "<p align='center'><img alt='' $dims src='/photo?id=$problem->{id}'></p>";
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
        $out .= '<h2>' . _('Updates') . '</h2>';
        foreach my $row (@$updates) {
            $out .= "<div><p><a name=\"update_$row->{id}\"></a><em>";
            if ($row->{name}) {
                $out .= sprintf(_('Posted by %s at %s'), ent($row->{name}), prettify_epoch($row->{created}));
            } else {
                $out .= sprintf(_('Posted anonymously at %s'), prettify_epoch($row->{created}));
            }
            $out .= ', ' . _('marked as fixed') if ($row->{mark_fixed});
            $out .= ', ' . _('reopened') if ($row->{mark_open});
            $out .= '</em></p>';
            my $text = $row->{text};
            $text =~ s/\r//g;
            foreach (split /\n{2,}/, $text) {
                $out .= '<p>' . ent($_) . '</p>';
            }
            if ($row->{has_photo}) {
                $out .= '<p><img alt="" height=100 src="/photo?tn=1;c=' . $row->{id} . '"></p>';
            }
            $out .= '</div>';
        }
        $out .= '</div>';
    }
    return $out;
}

# geocode STRING QUERY
# Given a user-inputted string, try and convert it into co-ordinates using either
# MaPit if it's a postcode, or Google Maps API otherwise. Returns an array of
# data, including an error if there is one (which includes a location being in 
# Northern Ireland). The information in the query may be used by cobranded versions
# of the site to diambiguate locations.
sub geocode {
    my ($s, $q) = @_;
    my ($x, $y, $easting, $northing, $error);
    if (mySociety::PostcodeUtil::is_valid_postcode($s)) {
        try {
            my $location = mySociety::MaPit::get_location($s);
            my $island = $location->{coordsyst};
            throw RABX::Error(_("We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.")) if $island eq 'I';
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
                $error = _('That postcode was not recognised, sorry.');
            } else {
                $error = $e;
            }
        }
    } else {
        ($x, $y, $easting, $northing, $error) = geocode_string($s, $q);
    }
    return ($x, $y, $easting, $northing, $error);
}

# geocode_string STRING QUERY
# Canonicalises, looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (TILE_X, TILE_Y, EASTING, NORTHING, ERROR), where ERROR is
# either undef, a string, or an array of matches if there are more than one. The 
# information in the query may be used to disambiguate the location in cobranded versions
# of the site. 
sub geocode_string {
    my ($s, $q) = @_;
    $s = Cobrand::disambiguate_location(get_cobrand($q), $s, $q);
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
        $url .= '&sensor=false&gl=uk&key=' . mySociety::Config::get('GOOGLE_MAPS_API_KEY');
        $js = LWP::Simple::get($url);
        File::Slurp::write_file($cache_file, $js) if $js && $js !~ /"code":6[12]0/;
    }
    if (!$js) {
        $error = _('Sorry, we could not parse that location. Please try again.');
    } elsif ($js !~ /"code" *: *200/) {
        $error = _('Sorry, we could not find that location.');
    } elsif ($js =~ /}, *{/) { # Multiple
        while ($js =~ /"address" *: *"(.*?)",\s*"AddressDetails" *:.*?"PostalCodeNumber" *: *"(.*?)"/gs) {
            my $address = $1;
            my $pc = $2;
            $address =~ s/UK/$pc, UK/;
            push (@$error, $address) unless $address =~ /BT\d/;
        }
        $error = _('Sorry, we could not find that location.') unless $error;
    } elsif ($js =~ /BT\d/) {
        # Northern Ireland, hopefully
        $error = _("We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.");
    } else {
        my ($accuracy) = $js =~ /"Accuracy" *: *(\d)/;
        if ($accuracy < 4) {
            $error = _('Sorry, that location appears to be too general; please be more specific.');
        } else {
            $js =~ /"coordinates" *: *\[ *(.*?), *(.*?),/;
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
                $error = _('That location does not appear to be in Britain; please try again.')
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
    my $out = '<p>' . _('We found more than one match for that location. We show up to ten matches, please try a different search if yours is not here.') . '</p> <ul>';
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
    return _('Please upload a JPEG image only') unless
        ($ct eq 'image/jpeg' || $ct eq 'image/pjpeg');
    return '';
}

sub process_photo {
    my $fh = shift;
    my $import = shift;

    my $photo = Image::Magick->new;
    my $err = $photo->Read(file => \*$fh); # Mustn't be stringified
    close $fh;
    throw Error::Simple("read failed: $err") if "$err";
    $err = $photo->Scale(geometry => "250x250>");
    throw Error::Simple("resize failed: $err") if "$err";
    my @blobs = $photo->ImageToBlob();
    undef $photo;
    $photo = $blobs[0];
    return $photo unless $import; # Only check orientation for iPhone imports at present

    # Now check if it needs orientating
    my $filename;
    ($fh, $filename) = mySociety::TempFiles::named_tempfile('.jpeg');
    print $fh $photo;
    close $fh;
    my $out = `jhead -se -autorot $filename`;
    if ($out) {
        open(FP, $filename) or throw Error::Simple($!);
        $photo = join('', <FP>);
        close FP;
    }
    unlink $filename;
    return $photo;
}

sub scambs_categories {
    return ('Abandoned vehicles', 'Discarded hypodermic needles',
            'Dog fouling', 'Flytipping', 'Graffiti', 'Lighting (e.g. security lights)',
            'Litter', 'Neighbourhood noise');
}

1;
