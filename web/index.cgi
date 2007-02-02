#!/usr/bin/perl -w

# index.cgi:
# Main code for Neighbourhood Fix-It
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.62 2007-02-02 12:23:07 matthew Exp $

# TODO
# Nothing is done about the update checkboxes - not stored anywhere on anything!

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use Error qw(:try);
use File::Slurp;
use Image::Magick;
use LWP::Simple;
use RABX;
use POSIX qw(strftime);
use CGI::Carp;
use Digest::MD5 qw(md5_hex);
use URI::Escape;

use Page;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);
use mySociety::GeoUtil;
use mySociety::Util;
use mySociety::MaPit;
use mySociety::VotingArea;
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
}

# Main code for index.cgi
sub main {
    my $q = shift;

    my $out = '';
    my $title = '';
    if ($q->param('submit_problem')) {
        $title = 'Submitting your problem';
        $out = submit_problem($q);
    } elsif ($q->param('submit_update')) {
        $title = 'Submitting your update';
        $out = submit_update($q);
    } elsif ($q->param('submit_map')) {
        $title = 'Reporting a problem';
        $out = display_form($q);
    } elsif ($q->param('id')) {
        $title = 'Viewing a problem';
        $out = display_problem($q);
    } elsif ($q->param('pc') || ($q->param('x') && $q->param('y'))) {
        $title = 'Viewing a location';
        $out = display_location($q);
    } else {
        $out = front_page($q);
    }
    print Page::header($q, $title);
    print $out;
    print Page::footer();
}
Page::do_fastcgi(\&main);

# Display front page
sub front_page {
    my ($q, $error) = @_;
    my $pc_h = ent($q->param('pc') || '');
    my $out = <<EOF;
<p id="expl">Report, view, or discuss local problems
like graffiti, fly tipping, broken paving slabs, or street lighting</p>
EOF
    $out .= '<p id="error">' . $error . '</p>' if ($error);
    $out .= <<EOF;
<form action="./" method="get" id="postcodeForm">
<label for="pc">Enter a nearby postcode, or street name and area:</label>
&nbsp;<input type="text" name="pc" value="$pc_h" id="pc" size="10" maxlength="200">
&nbsp;<input type="submit" value="Go">
</form>

<p>Reports are sent directly to the local council, apart from a few councils where we&rsquo;re missing details.</p>

<p>Reporting a problem is very simple:</p>

<ol>
<li>Enter a postcode or street name and area;
<li>Locate the problem on a high-scale map;
<li>Enter details of the problem;
<li>Submit to your council.
</ol>

EOF
    return $out;
}

sub submit_update {
    my $q = shift;
    my @vars = qw(id name email update fixed reopen);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my @errors;
    push(@errors, 'Please enter a message') unless $input{update};
    push(@errors, 'Please enter your name') unless $input{name};
    if (!$input{email}) {
        push(@errors, 'Please enter your email');
    } elsif (!mySociety::Util::is_valid_email($input{email})) {
        push(@errors, 'Please enter a valid email');
    }
    return display_problem($q, @errors) if (@errors);

    my $id = dbh()->selectrow_array("select nextval('comment_id_seq');");
    dbh()->do("insert into comment
        (id, problem_id, name, email, website, text, state, mark_fixed, mark_open)
        values (?, ?, ?, ?, ?, ?, 'unconfirmed', ?, ?)", {},
        $id, $input{id}, $input{name}, $input{email}, '', $input{update},
        $input{fixed}?'t':'f', $input{reopen}?'t':'f');
    my %h = ();
    $h{update} = $input{update};
    $h{name} = $input{name};
    $h{url} = mySociety::Config::get('BASE_URL') . '/C/' . mySociety::AuthToken::store('update', $id);
    dbh()->commit();

    my $out = Page::send_email($input{email}, $input{name}, 'update-confirm', %h);
    return $out;
}

sub submit_problem {
    my $q = shift;
    my @vars = qw(council title detail name email phone pc easting northing);
    my %input = map { $_ => scalar $q->param($_) } @vars;
    my @errors;

    my $fh = $q->upload('photo');
    if ($fh) {
        my $ct = $q->uploadInfo($fh)->{'Content-Type'};
        my $cd = $q->uploadInfo($fh)->{'Content-Disposition'};
        # Must delete photo param, otherwise display functions get confused
        $q->delete('photo');
        push (@errors, 'Please upload a JPEG image only') unless
            ($ct eq 'image/jpeg' || $ct eq 'image/pjpeg');
    }

    push(@errors, 'No council selected') unless $input{council} && $input{council} =~ /^(?:-1|\d+)$/;
    push(@errors, 'Please enter a title') unless $input{title};
    push(@errors, 'Please enter some details') unless $input{detail};
    push(@errors, 'Please enter your name') unless $input{name};
    if (!$input{email}) {
        push(@errors, 'Please enter your email');
    } elsif (!mySociety::Util::is_valid_email($input{email})) {
        push(@errors, 'Please enter a valid email');
    }

    if ($input{easting} && $input{northing}) {
        if ($input{council} != -1) {
            my $councils = mySociety::MaPit::get_voting_area_by_location_en($input{easting}, $input{northing}, 'polygon', $mySociety::VotingArea::council_parent_types);
            my %councils = map { $_ => 1 } @$councils;
            push(@errors, 'That location is not part of that council') unless $councils{$input{council}};
            push(@errors, 'We do not yet have details for the council that covers that location') unless is_valid_council($input{council});
        }
    } elsif ($input{easting} || $input{northing}) {
        push(@errors, 'Somehow, you only have one co-ordinate. Please try again.');
    }
    
    return display_form($q, @errors) if (@errors);

    my $id = dbh()->selectrow_array("select nextval('problem_id_seq');");

    my $image;
    if ($fh) {
        $image = Image::Magick->new;
        $image->Read(file=>$fh);
        close $fh;
        $image->Scale(geometry=>"250x250>");
        my @blobs = $image->ImageToBlob();
        undef $image;
        $image = $blobs[0];
    }

    delete $input{council} if $input{council} == -1;

    # This is horrid
    my $s = dbh()->prepare("insert into problem
        (id, postcode, easting, northing, title, detail, name, email, phone, photo, state, council)
        values
        (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unconfirmed', ?)");
    $s->bind_param(1, $id);
    $s->bind_param(2, $input{pc});
    $s->bind_param(3, $input{easting});
    $s->bind_param(4, $input{northing});
    $s->bind_param(5, $input{title});
    $s->bind_param(6, $input{detail});
    $s->bind_param(7, $input{name});
    $s->bind_param(8, $input{email});
    $s->bind_param(9, $input{phone});
    $s->bind_param(10, $image, { pg_type => DBD::Pg::PG_BYTEA });
    $s->bind_param(11, $input{council});
    $s->execute();
    my %h = ();
    $h{title} = $input{title};
    $h{detail} = $input{detail};
    $h{name} = $input{name};
    $h{url} = mySociety::Config::get('BASE_URL') . '/P/' . mySociety::AuthToken::store('problem', $id);
    dbh()->commit();

    my $out = Page::send_email($input{email}, $input{name}, 'problem-confirm', %h);
    return $out;
}

sub display_form {
    my ($q, @errors) = @_;
    my ($pin_x, $pin_y, $pin_tile_x, $pin_tile_y);
    my @vars = qw(title detail name email phone pc easting northing x y skipped council);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    my @ps = $q->param;
    foreach (@ps) {
        ($pin_tile_x, $pin_tile_y, $pin_x) = ($1, $2, $q->param($_)) if /^tile_(\d+)\.(\d+)\.x$/;
        $pin_y = $q->param($_) if /\.y$/;
    }
    return display_location($q)
        unless $input{skipped} || ($pin_x && $pin_y)
            || ($input{easting} && $input{northing});

    my $out = '';
    my ($px, $py, $easting, $northing);
    if ($input{skipped}) {
        my ($x, $y, $e, $n, $error) = geocode($input{pc});
        $easting = $e; $northing = $n;
    } elsif ($pin_x && $pin_y) {
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
    my $all_councils = mySociety::MaPit::get_voting_area_by_location_en($easting, $northing, 'polygon', $mySociety::VotingArea::council_parent_types);
    my $areas_info = mySociety::MaPit::get_voting_areas_info($all_councils);
    my @councils = is_valid_council($all_councils);
    if ($input{skipped}) {
        $out .= <<EOF;
<form action="./" method="post">
<input type="hidden" name="pc" value="$input_h{pc}">
<input type="hidden" name="skipped" value="1">
<h1>Reporting a problem</h1>
EOF
    } else {
        my $pins = display_pin($q, $px, $py, 'purple');
        $out .= display_map($q, $input{x}, $input{y}, 2, 1, $pins);
        if ($px && $py) {
            $out .= <<EOF;
<script type="text/javascript">
drag_x = $px - 254; drag_y = 254 - $py;
</script>
EOF
        }
        $out .= '<h1>Reporting a problem</h1>';
        $out .= '<p>You have located the problem at the point marked with a purple pin on the map.
        If this is not the correct location, simply click on the map again.</p>';
    }
    if (@councils > 1) {
        $out .= '<p>This spot lies in more than one council area; if you want, please choose which
                council you wish to send the report to below:</p>';
        $out .= '<ul style="list-style-type:none">';
        my $c = 0;
        # XXX: We don't know the order of display here!
        foreach my $council (@councils) {
            $out .= '<li><input type="radio" name="council" value="' . $council . '"';
            $out .= ' checked' if ($input{council}==$council || (!$input{council} && !$c++));
            $out .= ' id="council' . $council . '"> <label class="n" for="council'
                . $council . '">' . $areas_info->{$council}->{name} . '</label></li>';
        }
        $out .= '</ul>';
    } elsif (@councils == 1) {
        $out .= '<p>This problem will be reported to <strong>'
            . $areas_info->{$councils[0]}->{name} . '</strong>.</p>';
        $out .= '<input type="hidden" name="council" value="' . $councils[0] . '">';
    } else {
        my $e = mySociety::Config::get('CONTACT_EMAIL');
        my $list = join(', ', map { $areas_info->{$_}->{name} } @$all_councils);
        my $n = @$all_councils;
        $out .= '<p>We do not yet have details for the council';
        $out .= ($n>1) ? 's that cover' : ' that covers';
        $out .= " this location. If you submit a problem here it will be
left on the site, but <strong>not</strong> reported to your council.
You can help us by finding a contact email address for local
problems for $list and emailing it to us at <a href='mailto:$e'>$e</a>.</p>";
        $out .= '<input type="hidden" name="council" value="-1">';
    }
    if ($input{skipped}) {
        $out .= '<p>Please fill in the form below with details of the problem, and
describe the location as precisely as possible in the details box.</p>';
    } else {
        $out .= '<p>Please fill in details of the problem below. Your council won\'t be able
to help unless you leave as much detail as you can, so please describe the
exact location of the problem (ie. on a wall or the floor), and so on.</p>';
    }
    $out .= '<input type="hidden" name="easting" value="' . $easting . '">
<input type="hidden" name="northing" value="' . $northing . '">';

    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    my $back = NewURL($q, submit_map => undef, "tile_$pin_tile_x.$pin_tile_y.x" => undef,
        "tile_$pin_tile_x.$pin_tile_y.y" => undef, skipped => undef);
    $out .= <<EOF;
<fieldset><legend>Problem details</legend>
<div><label for="form_title">Title:</label>
<input type="text" value="$input_h{title}" name="title" id="form_title" size="30"></div>
<div><label for="form_detail">Details:</label>
<textarea name="detail" id="form_detail" rows="7" cols="30">$input_h{detail}</textarea></div>
<div><label for="form_name">Name:</label>
<input type="text" value="$input_h{name}" name="name" id="form_name" size="30"></div>
<div><label for="form_email">Email:</label>
<input type="text" value="$input_h{email}" name="email" id="form_email" size="30"></div>
<div><label for="form_phone">Phone:</label>
<input type="text" value="$input_h{phone}" name="phone" id="form_phone" size="20">
<small>(optional, so the council can get in touch)</small></div>
<div><label for="form_photo">Photo:</label>
<input type="file" name="photo" id="form_photo"></div>
<div class="checkbox"><input type="submit" name="submit_problem" value="Submit"></div>
</fieldset>

<p align="right"><a href="$back">Back to listings</a></p>
EOF
    $out .= display_map_end(1);
    return $out;
}

sub display_location {
    my ($q, @errors) = @_;

    my @vars = qw(pc x y);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;

    my($error, $easting, $northing);
    my $x = $input{x}; my $y = $input{y};
    $x ||= 0; $x += 0;
    $y ||= 0; $y += 0;
    if (!$x && !$y) {
        try {
            ($x, $y, $easting, $northing, $error) = geocode($input{pc});
        } catch Error::Simple with {
            $error = shift;
        };
    }
    return geocode_choice($error) if (ref($error) eq 'ARRAY');
    return front_page($q, $error) if ($error);

    my ($pins, $current_map, $current, $fixed) = map_pins($q, $x, $y);
    my $out = display_map($q, $x, $y, 1, 1, $pins);
    $out .= '<h1>Click on the map to report a problem</h1>';
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    my $skipurl = NewURL($q, 'submit_map'=>1, skipped=>1);
    $out .= <<EOF;
<p style="font-size:83%">If you cannot see a map &ndash; if you have images turned off,
or are using a text only browser, for example &ndash; and you
wish to report a problem, please
<a href="$skipurl">skip this step</a> and we will ask you
to describe the location of your problem instead.</p>
EOF
    $out .= <<EOF;
<div>
<h2>Recent problems reported on this map</h2>
<ol id="current">
EOF
    foreach (@$current_map) {
        $out .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $out .= $_->{title};
        $out .= '</a></li>';
    }
    unless (@$current_map) {
        $out .= '<li>No problems have been reported yet.</li>';
    }
    my $list_start = @$current_map + 1;
    $out .= <<EOF;
    </ol>
    <h2>Recent problems reported within 10km</h2>
    <p><a href="/rss/$x,$y"><img align="right" src="/i/feed.png" width="16" height="16" title="RSS feed of recent local problems" alt="RSS feed" border="0"></a></p>
    <ol id="current_near" start="$list_start">
EOF
    foreach (@$current) {
        $out .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $out .= $_->{title} . ' (c. ' . int($_->{distance}/100+.5)/10 . 'km)';
        $out .= '</a></li>';
    }
    unless (@$current) {
        $out .= '<li>No problems have been reported yet.</li>';
    }
    $out .= <<EOF;
    </ol>
    <h2>Recent updates to problems?</h2>
    <h2>Recently fixed problems within 10km</h2>
    <ol>
EOF
    foreach (@$fixed) {
        $out .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $out .= $_->{title} . ' (c. ' . int($_->{distance}/100+.5)/10 . 'km)';
        $out .= '</a></li>';
    }
    unless (@$fixed) {
        $out .= '<li>No problems have been fixed yet</li>';
    }
    $out .= '</ol></div>';
    $out .= display_map_end(1);
    return $out;
}

sub display_problem {
    my ($q, @errors) = @_;

    my @vars = qw(id name email update fixed reopen x y);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    $input{x} ||= 0; $input{x} += 0;
    $input{y} ||= 0; $input{y} += 0;

    # Get all information from database
    my $problem = dbh()->selectrow_arrayref(
        "select state, easting, northing, title, detail, name, extract(epoch from created), photo
         from problem where id=? and state in ('confirmed','fixed')", {}, $input{id});
    return display_location($q, 'Unknown problem ID') unless $problem;
    my ($state, $easting, $northing, $title, $desc, $name, $time, $photo) = @$problem;
    my $x = os_to_tile($easting);
    my $y = os_to_tile($northing);
    my $x_tile = $input{x} || int($x);
    my $y_tile = $input{y} || int($y);

    my $px = os_to_px($easting, $x_tile);
    my $py = os_to_px($northing, $y_tile);

    my ($pins) = map_pins($q, $x_tile, $y_tile, $input{id});
    my $out = display_map($q, $x_tile, $y_tile, 0, 1, $pins);

    $out .= "<h1>$title</h1>";
    $out .= <<EOF;
<script type="text/javascript">
drag_x = $px - 254; drag_y = 254 - $py;
</script>
EOF

    # Display information about problem
    $out .= '<p><em>Reported by ' . $name . ' at ' . prettify_epoch($time);
    $out .= '</em></p> <p>';
    $out .= ent($desc);
    $out .= '</p>';

    if ($photo) {
        $out .= '<p align="center"><img src="/photo?id=' . $input{id} . '"></p>';
    }

    my $back = NewURL($q, id=>undef, x=>$x_tile, y=>$y_tile);
    $out .= '<p style="padding-bottom: 0.5em; border-bottom: dotted 1px #999999;" align="right"><a href="' . $back . '">Back to listings</a></p>';

    $out .= '<a href="/rss/'.$input_h{id}.'"><img align="right" src="/i/feed.png" width="16" height="16" title="RSS feed" alt="RSS feed of updates to this problem" border="0"></a> ';
    $out .= '<a id="email_alert" href="/alert?type=updates;id='.$input_h{id}.'"><img align="right" src="/i/email.png" width="16" height="16" title="Email alerts" alt="Email alerts of updates to this problem" border="0"></a>';
    $out .= <<EOF;
<form action="alert" method="post" id="email_alert_box">
<p>Receive email when updates are left on this problem</p>
<label class="n" for="alert_email">Email:</label>
<input type="text" name="email" id="alert_email" value="$input_h{email}" size="30">
<input type="hidden" name="id" value="$input_h{id}">
<input type="hidden" name="type" value="updates">
<input type="submit" value="Subscribe">
</form>
EOF

    # Display updates
    my $updates = select_all(
        "select id, name, extract(epoch from created) as created, text, mark_fixed, mark_open
         from comment where problem_id = ? and state='confirmed'
         order by created desc", $input{id});
    if (@$updates) {
        $out .= '<div id="updates">';
        $out .= '<h2>Updates</h2>';
        foreach my $row (@$updates) {
            $out .= "<div><a name=\"update_$row->{id}\"></a><em>Posted by $row->{name} at " . prettify_epoch($row->{created});
            $out .= ', marked fixed' if ($row->{mark_fixed});
            $out .= ', reopened' if ($row->{mark_open});
            $out .= '</em>';
            $out .= '<br>' . $row->{text} . '</div>';
        }
        $out .= '</div>';
    }
    $out .= '<h2>Provide an update</h2>';
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }

    my $fixed = ($input{fixed}) ? ' checked' : '';
    my $reopen = ($input{reopen}) ? ' checked' : '';
    my $fixedline = $state eq 'fixed' ? qq{
<div class="checkbox"><input type="checkbox" name="reopen" id="form_reopen" value="1"$reopen>
<label for="form_reopen">Is this problem still present?</label></div>
} : qq{
<div class="checkbox"><input type="checkbox" name="fixed" id="form_fixed" value="1"$fixed>
<label for="form_fixed">Has the problem been fixed?</label></div>
};
    $out .= <<EOF;
<form method="post" action="./">
<fieldset><legend>Update details</legend>
<input type="hidden" name="submit_update" value="1">
<input type="hidden" name="id" value="$input_h{id}">
<div><label for="form_name">Name:</label>
<input type="text" name="name" id="form_name" value="$input_h{name}" size="30"></div>
<div><label for="form_email">Email:</label>
<input type="text" name="email" id="form_email" value="$input_h{email}" size="30"></div>
<div><label for="form_update">Update:</label>
<textarea name="update" id="form_update" rows="7" cols="30">$input_h{update}</textarea></div>
$fixedline
<div class="checkbox"><input type="submit" value="Post"></div>
</fieldset>
</form>
EOF
    $out .= display_map_end(0);
    return $out;
}

sub map_pins {
    my ($q, $x, $y, $id) = @_;

    my $pins = '';
    my $min_e = tile_to_os($x);
    my $min_n = tile_to_os($y);
    my $mid_e = tile_to_os($x+1);
    my $mid_n = tile_to_os($y+1);
    my $max_e = tile_to_os($x+2);
    my $max_n = tile_to_os($y+2);

    my $current_map = select_all(
        "select id,title,easting,northing from problem where state='confirmed'
         and easting>=? and easting<? and northing>=? and northing<?
         order by created desc limit 9", $min_e, $max_e, $min_n, $max_n);
    my @ids = ();
    my $count_prob = 1;
    my $count_fixed = 1;
    foreach (@$current_map) {
        push(@ids, $_->{id});
        my $px = os_to_px($_->{easting}, $x);
        my $py = os_to_px($_->{northing}, $y);
        if ($_->{id}==$id) {
            $pins .= display_pin($q, $px, $py, 'blue');
        } else {
            $pins .= display_pin($q, $px, $py, 'red', $count_prob++);
        }
    }
    my $current = [];
    if (@$current_map < 9) {
        my $limit = 9 - @$current_map;
        $current = select_all(
            "select id, title, easting, northing, distance
                from problem_find_nearby(?, ?, 10) as nearby, problem
                where nearby.problem_id = problem.id
                and state = 'confirmed'" . (@ids ? ' and id not in (' . join(',' , @ids) . ')' : '') . "
             order by distance limit $limit", $mid_e, $mid_n);
        foreach (@$current) {
            my $px = os_to_px($_->{easting}, $x);
            my $py = os_to_px($_->{northing}, $y);
            if ($_->{id}==$id) {
                $pins .= display_pin($q, $px, $py, 'blue');
            } else {
                $pins .= display_pin($q, $px, $py, 'red', $count_prob++);
            }
        }
    }
    my $fixed = select_all(
        "select id, title, easting, northing, distance
            from problem_find_nearby(?, ?, 10) as nearby, problem
            where nearby.problem_id = problem.id and state='fixed'
         order by created desc limit 9", $mid_e, $mid_n);
    foreach (@$fixed) {
        my $px = os_to_px($_->{easting}, $x);
        my $py = os_to_px($_->{northing}, $y);
        if ($_->{id}==$id) {
            $pins .= display_pin($q, $px, $py, 'blue');
        } else {
            $pins .= display_pin($q, $px, $py, 'green', $count_fixed++);
        }
    }
    return ($pins, $current_map, $current, $fixed);
}

sub display_pin {
    my ($q, $px, $py, $col, $num) = @_;
    $num = '' unless $num;
    my %cols = (red=>'R', green=>'G', blue=>'B', purple=>'P');
    my $out = '<img class="pin" src="/i/pin' . $cols{$col}
        . $num . '.gif" alt="Problem" style="top:' . ($py-59)
        . 'px; right:' . ($px-31) . 'px; position: absolute;">';
    return $out unless $_->{id} && $col ne 'blue';
    my $url = NewURL($q, id=>$_->{id}, x=>undef, y=>undef);
    $out = '<a title="' . $_->{title} . '" href="' . $url . '">' . $out . '</a>';
    return $out;
}

# display_map Q X Y TYPE COMPASS PINS
# X,Y is bottom left tile of 2x2 grid
# TYPE is 1 if the map is clickable, 0 if not
# COMPASS is 1 to show the compass, 0 to not
# PINS is HTML of pins to show
sub display_map {
    my ($q, $x, $y, $type, $compass, $pins) = @_;
    $pins ||= '';
    $x = 0 if ($x<0);
    $y = 0 if ($y<0);
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
    if ($type) {
        my $encoding = '';
        $encoding = ' enctype="multipart/form-data"' if ($type==2);
        my $pc_enc = ent($q->param('pc'));
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
var drag_x = 0; var drag_y = 0;
</script>
    <div id="map"><div id="drag">
        $img_type alt="NW map tile" id="t2.2" name="tile_$tl" src="$tl_src" style="top:0px; left:0px;">$img_type alt="NE map tile" id="t2.3" name="tile_$tr" src="$tr_src" style="top:0px; left:$imgw;"><br>$img_type alt="SW map tile" id="t3.2" name="tile_$bl" src="$bl_src" style="top:$imgh; left:0px;">$img_type alt="SE map tile" id="t3.3" name="tile_$br" src="$br_src" style="top:$imgh; left:$imgw;">
        $pins
    </div></div>
EOF
    $out .= Page::compass($q, $x, $y) if $compass;
    $out .= '<div id="side">';
    return $out;
}

sub display_map_end {
    my ($type) = @_;
    my $out = '</div>';
    $out .= '</form>' if ($type);
    return $out;
}

sub geocode_choice {
    my $choices = shift;
    my $out = '<p>We found more than one match for that location:</p> <ul>';
    foreach my $choice (@$choices) {
        my $qs = $choice->[0];
        my $text = $choice->[1];
        $text =~ s/<\/?(?:b|i)>//g;
        $text =~ s/, United Kingdom//;
        $qs =~ s/,\+United\+Kingdom//;
        $out .= '<li><a href="/?pc=' . $qs . '">' . $text . "</a></li>\n";
    }
    $out .= '</ul>';
    return $out;
}

sub geocode {
    my ($s) = @_;
    my ($x, $y, $easting, $northing, $error);
    if (mySociety::Util::is_valid_postcode($s)) {
        try {
            my $location = mySociety::MaPit::get_location($s);
            $easting = $location->{easting};
            $northing = $location->{northing};
            my $xx = os_to_tile($easting);
            my $yy = os_to_tile($northing);
            $x = int($xx);
            $y = int($yy);
            $x -= 1 if ($xx - $x < 0.5);
            $y -= 1 if ($yy - $y < 0.5);
        } catch RABX::Error with {
            my $e = shift;
            if ($e->value() == mySociety::MaPit::BAD_POSTCODE
               || $e->value() == mySociety::MaPit::POSTCODE_NOT_FOUND) {
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

sub geocode_string {
    my $s = shift;
    $s = lc($s);
    $s =~ s/[^-&0-9a-z ']/ /g;
    $s = uri_escape($s);
    $s =~ s/%20/+/g;
    my $url = 'http://maps.google.co.uk/maps?output=js&q=' . $s;
    my $cache_dir = mySociety::Config::get('GEO_CACHE');
    my $cache_file = $cache_dir . md5_hex($url);
    my ($js, $error, $x, $y, $easting, $northing);
    if (-s $cache_file) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        $js = LWP::Simple::get($url);
        File::Slurp::write_file($cache_file, $js);
    }
    if ($js =~ /panel: '(.*?)'/ && $js =~ /We could not understand/) {
        $error = $1;
    } elsif ($js =~ /panel: '(.*?)'/) {
        my $refine = $1;
        while ($refine =~ /<div class=\\042ref\\042><a href=\\042\/maps\?q=(.*?)&.*?>(.*?)<\/a><\/div>/g) {
            push (@$error, [ $1, $2 ]);
        }
        $error = 'We could not understand that location.' unless $error;
    } else {
        $js =~ /center: {lat: (.*?),lng: (.*?)}/;
        my $lat = $1; my $lon = $2;
        ($easting,$northing) = mySociety::GeoUtil::wgs84_to_national_grid($lat, $lon, 'G');
        $x = int(os_to_tile($easting))-1;
        $y = int(os_to_tile($northing))-1;
    }
    return ($x, $y, $easting, $northing, $error);
}

sub is_valid_council {
    my $councils = shift;
    $councils = [ $councils ] unless ref($councils) eq 'ARRAY';
    my @councils_no_email = (2288,2402,2390,2252,2351,2430,2375,2285,2377,2374,2330,2454,2284,2378,2294,2312,2419,2386,2363,2353,2296,2300,2291,2268,2512,2504,2495,2510,
    2530,2516,2531,2545,2586,2554,2574,2580,2615,2596,2599,2601,2648,2652,2607,2582,14287,14317,14328,2225,2242,2222,2248,2246,2235,2224,2244,2236);

    my $invalid_councils;
    grep (vec($invalid_councils, $_, 1) = 1, @councils_no_email);

    # Cheltenham example: CTY=2226 DIS=2326
    # Check for covered council
    my @return;
    foreach my $council (@$councils) {
        push @return, $council unless vec($invalid_councils, $council, 1);
    }
    return @return;
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

