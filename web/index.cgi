#!/usr/bin/perl -w

# index.pl:
# Main code for Neighbourhood Fix-It
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.23 2006-09-25 18:12:56 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use Error qw(:try);
use LWP::Simple;
use RABX;
use POSIX qw(strftime);
use CGI::Carp;

use Page;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);
use mySociety::Util;
use mySociety::MaPit;
use mySociety::Web qw(ent NewURL);

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
    mySociety::DBHandle::configure(
        Name => mySociety::Config::get('BCI_DB_NAME'),
        User => mySociety::Config::get('BCI_DB_USER'),
        Password => mySociety::Config::get('BCI_DB_PASS'),
        Host => mySociety::Config::get('BCI_DB_HOST', undef),
        Port => mySociety::Config::get('BCI_DB_PORT', undef)
    );

    if (!dbh()->selectrow_array('select secret from secret for update of secret')) {
        local dbh()->{HandleError};
        dbh()->do('insert into secret (secret) values (?)', {}, unpack('h*', mySociety::Util::random_bytes(32)));
    }
    dbh()->commit();

    mySociety::MaPit::configure();
}

# Main code for index.cgi
sub main {
    my $q = shift;

    my $out = '';
    if ($q->param('submit_problem')) {
        $out = submit_problem($q);
    } elsif ($q->param('submit_comment')) {
        $out = submit_comment($q);
    } elsif ($q->param('map')) {
        $out = display_form($q);
    } elsif ($q->param('id')) {
        $out = display_problem($q);
    } elsif ($q->param('pc')) {
        $out = display($q);
    } else {
        $out = front_page($q);
    }
    print Page::header($q, '');
    print $out;
    print Page::footer();
}
Page::do_fastcgi(\&main);

# Display front page
sub front_page {
    my ($q, $error) = @_;
    my $pc_h = ent($q->param('pc') || '');
    my $out = '<div id="relativediv">';
    $out .= <<EOF;
<p style="text-align: center; font-size: 150%; margin: 2em; font-weight: bolder;">Report or view local problems
like graffiti, fly tipping, broken paving slabs, or street lighting</p>
EOF
    $out .= '<p id="error">' . $error . 'Please try again.</p>' if ($error);
    $out .= <<EOF;
<form action="./" method="get" id="postcodeForm">
<label for="pc">Enter your postcode:</label>
<input type="text" name="pc" value="$pc_h" id="pc" size="10" maxlength="10">
<input type="submit" value="Go">
</form>

<p>Reports are sent directly to your local council &ndash; at the moment, we only cover <em>Newham, Lewisham, and Islington</em> councils.</p>

<p>Reporting a problem is hopefully very simple:</p>

<ol>
<li>Enter a postcode;
<li>Locate the problem on a high-scale map;
<li>Enter details of the problem;
<li>Submit to your council.
</ol>

</div>
EOF
    return $out;
}

sub submit_comment {
    my $q = shift;
    my @vars = qw(id name email comment updates);
    my %input = map { $_ => $q->param($_) } @vars;
    my @errors;
    push(@errors, 'Please enter a comment') unless $input{comment};
    push(@errors, 'Please enter your name') unless $input{name};
    push(@errors, 'Please enter your email') unless $input{email};
    return display_problem($q, @errors) if (@errors);

    dbh()->do("insert into comment
        (problem_id, name, email, website, text, state)
        values (?, ?, ?, ?, ?, 'unconfirmed')", {},
        $input{id}, $input{name}, $input{email}, '', $input{comment});
    dbh()->commit();

    # Send confirmation email

    my $out = <<EOF;
<h2>Nearly Done! Now check your email...</h2>
<p>The confirmation email <strong>may</strong> take a few minutes to arrive &mdash; <em>please</em> be patient.</p>
<p>If you use web-based email or have 'junk mail' filters, you may wish to check your bulk/spam mail folders: sometimes, our messages are marked that way.</p>
<p>You must now click on the link within the email we've just sent you -
<br>if you do not, your comment will not be posted.</p>
<p>(Don't worry - we'll hang on to your comment while you're checking your email.)</p>
EOF
    return $out;
}

sub submit_problem {
    my $q = shift;
    my @vars = qw(title detail name email pc easting northing updates);
    my %input = map { $_ => $q->param($_) } @vars;
    my @errors;
    push(@errors, 'Please enter a title') unless $input{title};
    push(@errors, 'Please enter some details') unless $input{detail};
    push(@errors, 'Please enter your name') unless $input{name};
    push(@errors, 'Please enter your email') unless $input{email};
    return display_form($q, @errors) if (@errors);

    dbh()->do("insert into problem
        (postcode, easting, northing, title, detail, name, email, state)
        values
        (?, ?, ?, ?, ?, ?, ?, 'unconfirmed')", {},
        $input{pc}, $input{easting}, $input{northing}, $input{title},
        $input{detail}, $input{name}, $input{email}
    );
    dbh()->commit();

    # Send confirmation email

    my $out = <<EOF;
<h2>Nearly Done! Now check your email...</h2>
<p>The confirmation email <strong>may</strong> take a few minutes to arrive &mdash; <em>please</em> be patient.</p>
<p>If you use web-based email or have 'junk mail' filters, you may wish to check your bulk/spam mail folders: sometimes, our messages are marked that way.</p>
<p>You must now click on the link within the email we've just sent you -
<br>if you do not, your problem will not be posted on the site.</p>
<p>(Don't worry - we'll hang on to your information while you're checking your email.)</p>
EOF
    return $out;
}

sub display_form {
    my ($q, @errors) = @_;
    my ($pin_x, $pin_y, $pin_tile_x, $pin_tile_y);
    my @vars = qw(title detail name email updates pc easting northing x y skipped);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    my @ps = $q->param;
    foreach (@ps) {
        ($pin_tile_x, $pin_tile_y, $pin_x) = ($1, $2, $q->param($_)) if /^tile_(\d+)\.(\d+)\.x$/;
        $pin_y = $q->param($_) if /\.y$/;
    }
    return display($q)
        unless $input{skipped} || ($pin_x && $pin_y)
            || ($input{easting} && $input{northing});

    my $out = '';
    $out .= '<h2>Reporting a problem</h2>';
    if ($input{skipped}) {
        $out .= '<p>Please fill in the form below with details of the problem:</p>';
    } else {
        my ($px, $py, $easting, $northing);
        if ($pin_x && $pin_y) {
            # Map was clicked on
	    $pin_x = click_to_tile($pin_tile_x, $pin_x);
	    $pin_y = click_to_tile($pin_tile_y, $pin_y, 1);
            $px = tile_to_px($pin_x, $input{x});
            $py = tile_to_px($pin_y, $input{y});
            $easting = tile_to_os($pin_x);
            $northing = tile_to_os($pin_y);
        } else {
            # Normal form submission
            $px = os_to_px($input{easting}, $input{x});
            $py = os_to_px($input{northing}, $input{y});
            $easting = $input_h{easting};
            $northing = $input_h{northing};
        }
        $out .= display_map($q, $input{x}, $input{y}, 1, 0);
        $out .= '<p>You have located the problem at the location marked with a yellow pin on the map. If this is not the correct location, simply click on the map again.</p>
<p>Please fill in details of the problem below:</p>';
        $out .= display_pin($px, $py, 'yellow');
        $out .= '<input type="hidden" name="easting" value="' . $easting . '">
<input type="hidden" name="northing" value="' . $northing . '">';
    }

    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    my $updates = (!defined($q->param('updates')) || $input{updates}) ? ' checked' : '';
    $out .= <<EOF;
<fieldset>
<div><label for="form_title">Title:</label>
<input type="text" value="$input_h{title}" name="title" id="form_title" size="30"> (work out from details?)</div>
<div><label for="form_detail">Details:</label>
<textarea name="detail" id="form_detail" rows="7" cols="30">$input_h{detail}</textarea></div>
<div><label for="form_name">Name:</label>
<input type="text" value="$input_h{name}" name="name" id="form_name" size="30"></div>
<div><label for="form_email">Email:</label>
<input type="text" value="$input_h{email}" name="email" id="form_email" size="30"></div>
<div class="checkbox"><input type="checkbox" name="updates" id="form_updates" value="1"$updates>
<label for="form_updates">Receive updates about this problem</label></div>
<div class="checkbox"><input type="submit" name="submit_problem" value="Submit"></div>
</fieldset>
EOF
    $out .= display_map_end(1);
    return $out;
}

sub display {
    my ($q, @errors) = @_;

    my $pc = $q->param('pc');
    my($error, $x, $y, $name);
    try {
        ($name, $x, $y) = postcode_check($q, $pc);
    } catch RABX::Error with {
        my $e = shift;
        if ($e->value() == mySociety::MaPit::BAD_POSTCODE
           || $e->value() == mySociety::MaPit::POSTCODE_NOT_FOUND) {
            $error = 'That postcode was not recognised, sorry. ';
        } else {
            $error = $e;
        }
    } catch Error::Simple with {
        my $e = shift;
	$error = $e;
    };
    return front_page($q, $error) if ($error);

    my $out = "<h2>$name</h2>";
    $out .= display_map($q, $x, $y, 1, 1);
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    $out .= <<EOF;
<p>To <strong>report a problem</strong>, please select the location of it on the map.
Use the arrows to the left of the map to scroll around.</p>
EOF

    # These lists are currently global; should presumably be local to map!
    $out .= <<EOF;
    <div>
    <h2>Problems already reported</h2>
    <ul id="current">
EOF
    my $current = select_all(
        "select id,title,easting,northing from problem where state='confirmed'
         order by created desc limit 3");
    foreach (@$current) {
        my $px = os_to_px($_->{easting}, $x);
        my $py = os_to_px($_->{northing}, $y);
        $out .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $out .= display_pin($px, $py);
        $out .= $_->{title};
        $out .= '</a></li>';
    }
    unless (@$current) {
        $out .= '<li>No problems have been reported yet.</li>';
    }
    $out .= <<EOF;
    </ul>
    <h2>Recently fixed problems</h2>
    <ul>
EOF
    my $fixed = select_all(
        "select id,title from problem where state='fixed'
         order by created desc limit 3");
    foreach (@$fixed) {
        $out .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $out .= $_->{title};
        $out .= '</a></li>';
    }
    unless (@$fixed) {
        $out .= '<li>No problems have been fixed yet</li>';
    }
    my $skipurl = NewURL($q, 'map'=>1, skipped=>1);
    $out .= '</ul></div>';
    $out .= <<EOF;
<p>If you cannot see a map &ndash; if you have images turned off,
or are using a text only browser, for example &ndash; please
<a href="$skipurl">skip this step</a> and we will ask you
to describe the location of your problem instead.</p>
EOF
    $out .= display_map_end(1);
    return $out;
}

sub display_pin {
    my ($px, $py, $col) = @_;
    $col = 'red' unless $col;
    return '' if ($px<0 || $px>508 || $py<0 || $py>508);
    return '<img src="/i/pin_'.$col.'.png" alt="Problem" style="top:' . ($py-20) . 'px; right:' . ($px-6) . 'px; position: absolute;">';
}

sub display_problem {
    my ($q, @errors) = @_;

    my @vars = qw(id name email comment updates x y);
    my %input = map { $_ => $q->param($_) } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    $input{x} += 0;
    $input{y} += 0;

    # Get all information from database
    my $problem = dbh()->selectrow_arrayref(
        "select easting, northing, title, detail, name, extract(epoch from created)
         from problem where id=? and state='confirmed'", {}, $input{id});
    return display($q, 'Unknown problem ID') unless $problem;
    my ($easting, $northing, $title, $desc, $name, $time) = @$problem;
    my $x = os_to_tile($easting);
    my $y = os_to_tile($northing);
    my $x_tile = $input{x} || int($x);
    my $y_tile = $input{y} || int($y);
    my $created = time();

    my $px = os_to_px($easting, $x_tile);
    my $py = os_to_px($northing, $y_tile);

    my $out = '';
    $out .= "<h2>$title</h2>";
    $out .= display_map($q, $x_tile, $y_tile, 0, 1);

    # Display information about problem
    $out .= '<p>';
    $out .= display_pin($px, $py);
    $out .= '<em>Reported by ' . $name . ' at ' . prettify_epoch($time);
    $out .= '</em></p> <p>';
    $out .= ent($desc);
    $out .= '</p>';

    # Display comments
    my $comments = select_all(
        "select id, name, whenposted, text
         from comment where problem_id = ? and state='confirmed'
         order by whenposted desc", $input{id});
    if (@$comments) {
        $out .= '<h3>Comments</h3>';
        foreach my $row (@$comments) {
            $out .= "$row->{name} $row->{text}";
        }
    }
    $out .= '<h3>Add Comment</h3>';
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    my $updates = $input{updates} ? ' checked' : '';
    # XXX: Should we have website too?
    $out .= <<EOF;
<form method="post" action="./">
<fieldset>
<input type="hidden" name="submit_comment" value="1">
<input type="hidden" name="id" value="$input_h{id}">
<div><label for="form_name">Name:</label>
<input type="text" name="name" id="form_name" value="$input_h{name}" size="30"></div>
<div><label for="form_email">Email:</label>
<input type="text" name="email" id="form_email" value="$input_h{email}" size="30"> (needed?)</div>
<div><label for="form_comment">Comment:</label>
<textarea name="comment" id="form_comment" rows="7" cols="30">$input_h{comment}</textarea></div>
<div class="checkbox"><input type="checkbox" name="updates" id="form_updates" value="1"$updates>
<label for="form_updates">Receive updates about this problem</label></div>
<div class="checkbox"><input type="submit" value="Post"></div>
</fieldset>
</form>
EOF
    $out .= display_map_end(0);
    return $out;
}

# display_map Q X Y TYPE COMPASS
# X,Y is bottom left tile of 2x2 grid
# TYPE is 1 if the map is clickable, 0 if not
# COMPASS is 1 to show the compass, 0 to not
sub display_map {
    my ($q, $x, $y, $type, $compass) = @_;
    my $url = mySociety::Config::get('TILES_URL');
    my $tiles_url = $url . $x . '-' . ($x+1) . ',' . $y . '-' . ($y+1) . '/RABX';
    my $tiles = LWP::Simple::get($tiles_url);
    throw Error::Simple("Unable to get tiles from URL $tiles_url\n") if !$tiles;
    my $tileids = RABX::unserialise($tiles);
    my $tl = $x . '.' . ($y+1);
    my $tr = ($x+1) . '.' . ($y+1);
    my $bl = $x . '.' . $y;
    my $br = ($x+1) . '.' . $y;
    my $tl_src = $url . $tileids->[0][0];
    my $tr_src = $url . $tileids->[0][1];
    my $bl_src = $url . $tileids->[1][0];
    my $br_src = $url . $tileids->[1][1];

    my $out = '';
    my $img_type;
    if ($type) {
        my $pc_enc = ent($q->param('pc'));
        $out .= <<EOF;
<form action="./" method="post">
<input type="hidden" name="map" value="1">
<input type="hidden" name="x" value="$x">
<input type="hidden" name="y" value="$y">
<input type="hidden" name="pc" value="$pc_enc">
EOF
        $img_type = '<input type="image"';
    } else {
        $img_type = '<img';
    }
    $out .= <<EOF;
<div id="relativediv">
    <div id="map">
        $img_type id="2.2" name="tile_$tl" src="$tl_src" style="top:0px; left:0px;">$img_type id="3.2" name="tile_$tr" src="$tr_src" style="top:0px; left:254px;"><br>$img_type id="2.3" name="tile_$bl" src="$bl_src" style="top:254px; left:0px;">$img_type id="3.3" name="tile_$br" src="$br_src" style="top:254px; left:254px;">
    </div>
EOF
    $out .= Page::compass($q, $x, $y) if $compass;
    $out .= '<div id="content">';
    return $out;
}

sub display_map_end {
    my ($type) = @_;
    my $out = '</div></div>';
    $out .= '</form>' if ($type);
    return $out;
}

# Checks the postcode is in one of the two London boroughs
# and sets default X/Y co-ordinates if not provided in the URI
sub postcode_check {
    my ($q, $pc) = @_;
    my $areas;
    $areas = mySociety::MaPit::get_voting_areas($pc);

    # Check for London Borough
    throw Error::Simple("I'm afraid that postcode isn't in our covered area.\n") if (!$areas || !$areas->{LBO});

    # Check for Lewisham or Newham
    my $lbo = $areas->{LBO};
    throw Error::Simple("I'm afraid that postcode isn't in our covered London boroughs.\n") unless ($lbo == 2510 || $lbo == 2492 || $lbo == 2507);

    my $area_info = mySociety::MaPit::get_voting_area_info($lbo);
    my $name = $area_info->{name};

    my $x = $q->param('x') || 0;
    my $y = $q->param('y') || 0;
    $x += 0;
    $y += 0;
    if (!$x && !$y) {
        my $location = mySociety::MaPit::get_location($pc);
        my $northing = $location->{northing};
        my $easting = $location->{easting};
        $x = int(os_to_tile($easting));
        $y = int(os_to_tile($northing));
    }
    return ($name, $x, $y);
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
    $pin = 254 - $pin if $invert; # image submits measured from top down
    return $pin_tile + $pin / 254;
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

