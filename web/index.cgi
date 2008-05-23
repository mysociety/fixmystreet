#!/usr/bin/perl -w -I../perllib

# index.cgi:
# Main code for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.199 2008-05-23 09:53:10 matthew Exp $

use strict;
use Standard;

use Error qw(:try);
use File::Slurp;
use LWP::Simple;
use RABX;
use CGI::Carp;
use URI::Escape;

use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(select_all);
use mySociety::EmailUtil;
use mySociety::Gaze;
use mySociety::GeoUtil;
use mySociety::MaPit;
use mySociety::PostcodeUtil;
use mySociety::Random;
use mySociety::VotingArea;
use mySociety::Web qw(ent NewURL);

BEGIN {
    if (!dbh()->selectrow_array('select secret from secret for update of secret')) {
        local dbh()->{HandleError};
        dbh()->do('insert into secret (secret) values (?)', {}, unpack('h*', mySociety::Random::random_bytes(32)));
    }
    dbh()->commit();
}

# Main code for index.cgi
sub main {
    my $q = shift;

    my $out = '';
    my %params;
    if ($q->param('submit_problem') || ($q->param('submit_map') && $q->param('submit_map')==2)) {
        $params{title} = _('Submitting your report');
        ($out) = submit_problem($q);
    } elsif ($q->param('submit_update')) {
        $params{title} = _('Submitting your update');
        ($out) = submit_update($q);
    } elsif ($q->param('submit_map')) {
        ($out, %params) = display_form($q);
        $params{title} = _('Reporting a problem');
    } elsif ($q->param('id')) {
        ($out, %params) = display_problem($q);
        $params{title} .= ' - ' . _('Viewing a problem');
    } elsif ($q->param('pc') || ($q->param('x') && $q->param('y'))) {
        ($out, %params) = display_location($q);
        $params{title} = _('Viewing a location');
    } else {
        $out = front_page($q);
    }
    print Page::header($q, %params);
    print $out;
    my %footerparams;
    $footerparams{js} = $params{js} if $params{js};
    print Page::footer($q, %footerparams);
}
Page::do_fastcgi(\&main);

# Display front page
sub front_page {
    my ($q, $error) = @_;
    my $pc_h = ent($q->param('pc') || '');
    my $out = '<p id="expl"><strong>' . _('Report, view, or discuss local problems') . '</strong>';
    my $subhead = _('(like graffiti, fly tipping, broken paving slabs, or street lighting)');
    $subhead = '(like graffiti, fly tipping, or neighbourhood noise)' if $q->{site} eq 'scambs';
    $out .= '<br><small>' . $subhead . '</small>' if $subhead ne ' ';
    $out .= '</p>';
    $out .= '<p id="error">' . $error . '</p>' if ($error);
    my $fixed = Problems::recent_fixed();
    my $updates = Problems::number_comments();
    my $new = Problems::recent_new('1 week');
    my $new_text = 'in past week';
    if ($new > $fixed) {
        $new = Problems::recent_new('3 days');
        $new_text = 'recently';
    }
    $out .= '<form action="./" method="get" id="postcodeForm">';
    if (my $token = $q->param('flickr')) {
        my $id = mySociety::AuthToken::retrieve('flickr', $token);
        if ($id) {
            my $name = ent($q->param('name'));
            my $email = ent($q->param('email'));
            my $title = ent($q->param('title'));
            $out .= <<EOF;
<p style="margin-top:0;color: #cc0000;">Thanks for uploading your photo via Flickr! We need to locate your problem,
so please enter a nearby street name or postcode in the box below...</p>

<input type="hidden" name="flickr" value="$token">
<input type="hidden" name="submit_map" value="1">
<input type="hidden" name="name" value="$name">
<input type="hidden" name="email" value="$email">
<input type="hidden" name="title" value="$title">
<input type="hidden" name="anonymous" value="1">
EOF
        }
    }
    $out .= <<EOF;
<label for="pc">Enter a nearby UK postcode, or street name and area:</label>
&nbsp;<input type="text" name="pc" value="$pc_h" id="pc" size="10" maxlength="200">
&nbsp;<input type="submit" value="Go" id="submit">
</form>

<div id="front_intro">
EOF
    $out .= $q->h2(_('How to report a problem'));
    my $step4 = $q->li(_('We send it to the council on your behalf'));
    $step4 = '' if $q->{site} eq 'emptyhomes';
    $step4 = $q->li('The council receives your report and acts upon it')
        if $q->{site} eq 'scambs';
    $out .= $q->ol(
        $q->li(_('Enter a nearby UK postcode, or street name and area')),
        $q->li(_('Locate the problem on a map of the area')),
        $q->li(_('Enter details of the problem')),
        $step4
    );

    $out .= $q->h2(_('FixMyStreet updates'));
    $out .= $q->div({-id => 'front_stats'},
        $q->div("<big>$new</big> report" . ($new!=1?'s':''), $new_text),
        ($q->{site} ne 'emptyhomes' && $q->div("<big>$fixed</big> fixed in past month")),
        $q->div("<big>$updates</big> update" . ($updates!=1?'s':''), "on reports"),
    );

    $out .= <<EOF;
</div>

<div id="front_recent">
EOF

    my $recent_photos = Problems::recent_photos(3);
    $out .= $q->h2(_('Photos of recent reports')) . $recent_photos if $recent_photos;

    my $probs = Problems::recent();
    $out .= $q->h2(_('Recently reported problems')) . ' <ul>' if @$probs;
    foreach (@$probs) {
        $out .= '<li><a href="/?id=' . $_->{id} . '">'. ent($_->{title});
        $out .= '</a>';
    }
    $out .= '</ul>' if @$probs;
    $out .= '</div>';

    return $out;
}

sub submit_update {
    my $q = shift;
    my @vars = qw(id name email update fixed upload_fileid);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my @errors;

    my $fh = $q->upload('photo');
    if ($fh) {
        my $err = Page::check_photo($q, $fh);
        push @errors, $err if $err;
    }

    push(@errors, _('Please enter a message')) unless $input{update} =~ /\S/;
    $input{name} = undef unless $input{name} =~ /\S/;
    if ($input{email} !~ /\S/) {
        push(@errors, _('Please enter your email'));
    } elsif (!mySociety::EmailUtil::is_valid_email($input{email})) {
        push(@errors, _('Please enter a valid email'));
    }

    my $image;
    if ($fh) {
        try {
            $image = Page::process_photo($fh);
        } catch Error::Simple with {
            my $e = shift;
            push(@errors, sprintf(_("That image doesn't appear to have uploaded correctly (%s), please try again."), $e));
        };
    }

    if ($input{upload_fileid}) {
        open FP, mySociety::Config::get('UPLOAD_CACHE') . $input{upload_fileid};
        $image = join('', <FP>);
        close FP;
    }

    return display_problem($q, @errors) if (@errors);

    my $id = dbh()->selectrow_array("select nextval('comment_id_seq');");
    Page::workaround_pg_bytea("insert into comment
        (id, problem_id, name, email, website, text, state, mark_fixed, photo)
        values (?, ?, ?, ?, '', ?, 'unconfirmed', ?, ?)", 7,
        $id, $input{id}, $input{name}, $input{email}, $input{update},
        $input{fixed} ? 't' : 'f', $image);

    my %h = ();
    $h{update} = $input{update};
    $h{name} = $input{name} ? $input{name} : _("Anonymous");
    my $base = mySociety::Config::get('BASE_URL');
    $base =~ s/matthew/emptyhomes.matthew/ if $q->{site} eq 'emptyhomes'; # XXX Temp
    $base =~ s/matthew/scambs.matthew/ if $q->{site} eq 'scambs'; # XXX Temp
    $h{url} = $base . '/C/' . mySociety::AuthToken::store('update', $id);
    dbh()->commit();

    my $out = Page::send_email($q, $input{email}, $input{name}, 'update', %h);
    return $out;
}

sub submit_problem {
    my $q = shift;
    my @vars = qw(council title detail name email phone pc easting northing skipped anonymous category flickr upload_fileid);
    my %input = map { $_ => scalar $q->param($_) } @vars;
    for (qw(title detail)) {
        $input{$_} = lc $input{$_} if $input{$_} !~ /[a-z]/;
        $input{$_} = ucfirst $input{$_};
        $input{$_} =~ s/\b(dog\s*)shit\b/$1poo/ig;
    }
    my @errors;

    my $fh = $q->upload('photo');
    if ($fh) {
        my $err = Page::check_photo($q, $fh);
        push @errors, $err if $err;
    }

    $input{council} = -1 if $q->{site} eq 'emptyhomes'; # Not sent to council
    $input{council} = 2260 if $q->{site} eq 'scambs'; # All reports go to S. Cambs

    push(@errors, _('No council selected')) unless ($input{council} && $input{council} =~ /^(?:-1|[\d,]+(?:\|[\d,]+)?)$/);
    push(@errors, _('Please enter a subject')) unless $input{title} =~ /\S/;
    push(@errors, _('Please enter some details')) unless $input{detail} =~ /\S/;
    if ($input{name} !~ /\S/) {
        push @errors, _('Please enter your name');
    } elsif (length($input{name}) < 5 || $input{name} !~ /\s/ || $input{name} =~ /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i) {
        push @errors, _('Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box');
    }
    if ($input{email} !~ /\S/) {
        push(@errors, _('Please enter your email'));
    } elsif (!mySociety::EmailUtil::is_valid_email($input{email})) {
        push(@errors, _('Please enter a valid email'));
    }
    if ($input{category} && $input{category} eq '-- Pick a category --') {
        push (@errors, _('Please choose a category'));
        $input{category} = '';
    }
 
    return display_form($q, @errors) if (@errors); # Short circuit

    my $areas;
    if ($input{easting} && $input{northing}) {
        $areas = mySociety::MaPit::get_voting_areas_by_location(
            { easting=>$input{easting}, northing=>$input{northing} },
            'polygon', [qw(WMC CTY CED DIS DIW MTD MTW COI COP LGD LGE UTA UTE UTW LBO LBW LAC SPC WAC NIE)]
        );
        if ($input{council} =~ /^[\d,]+(\|[\d,]+)?$/) {
            my $no_details = $1 || '';
            my %va = map { $_ => 1 } @$mySociety::VotingArea::council_parent_types;
            my %councils;
            foreach (keys %$areas) {
                $councils{$_} = 1 if $va{$areas->{$_}};
            }
            my @input_councils = split /,|\|/, $input{council};
            foreach (@input_councils) {
                if (!$councils{$_}) {
                    push(@errors, _('That location is not part of that council'));
                    last;
                }
            }

            if ($no_details) {
                $input{council} =~ s/\Q$no_details\E//;
                @input_councils = split /,/, $input{council};
            }

            # Check category here, won't be present if council is -1
            my @valid_councils = @input_councils;
            if ($input{category}) {
                my $categories = select_all("select area_id from contacts
                    where deleted='f' and area_id in ("
                    . $input{council} . ') and category = ?', $input{category});
                push (@errors, 'Please choose a category') unless @$categories;
                @valid_councils = map { $_->{area_id} } @$categories;
                foreach my $c (@valid_councils) {
                    if ($no_details =~ /$c/) {
                        push(@errors, _('We have details for that council'));
                        $no_details =~ s/,?$c//;
                    }
                }
            }
            $input{council} = join(',', @valid_councils) . $no_details;
        }
        $areas = ',' . join(',', sort keys %$areas) . ',';
    } elsif ($input{easting} || $input{northing}) {
        push(@errors, _('Somehow, you only have one co-ordinate. Please try again.'));
    } else {
        push(@errors, _('You haven\'t specified any sort of co-ordinates. Please try again.'));
    }
    
    my $image;
    if ($fh) {
        try {
            $image = Page::process_photo($fh);
        } catch Error::Simple with {
            my $e = shift;
            push(@errors, sprintf(_("That image doesn't appear to have uploaded correctly (%s), please try again."), $e));
        };
    }

    if ($input{upload_fileid}) {
        open FP, mySociety::Config::get('UPLOAD_CACHE') . $input{upload_fileid};
        $image = join('', <FP>);
        close FP;
    }

    return display_form($q, @errors) if (@errors);

    delete $input{council} if $input{council} eq '-1';
    my $used_map = $input{skipped} ? 'f' : 't';
    $input{category} = _('Other') unless $input{category};

    my ($id, $out);
    if (my $token = $input{flickr}) {
        my $id = mySociety::AuthToken::retrieve('flickr', $token);
        if ($id) {
            dbh()->do("update problem set postcode=?, easting=?, northing=?, title=?, detail=?,
                name=?, email=?, phone=?, state='confirmed', council=?, used_map='t',
                anonymous=?, category=?, confirmed=ms_current_timestamp(),
                lastupdate=ms_current_timestamp() where id=?", {}, $input{pc}, $input{easting}, $input{northing},
                $input{title}, $input{detail}, $input{name}, $input{email},
                $input{phone}, $input{council}, $input{anonymous} ? 'f' : 't',
                $input{category}, $id);
            dbh()->commit();
            $out = $q->p(sprintf(_('You have successfully confirmed your report and you can now <a href="%s">view it on the site</a>.'), "/?id=$id"));
        } else {
            $out = $q->p(_('There appears to have been a problem.'));
        }
    } else {
        $id = dbh()->selectrow_array("select nextval('problem_id_seq');");
        Page::workaround_pg_bytea("insert into problem
            (id, postcode, easting, northing, title, detail, name,
             email, phone, photo, state, council, used_map, anonymous, category, areas, send_questionnaire)
            values
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unconfirmed', ?, ?, ?, ?, ?, ?)", 10,
            $id, $input{pc}, $input{easting}, $input{northing}, $input{title},
            $input{detail}, $input{name}, $input{email}, $input{phone}, $image,
            $input{council}, $used_map, $input{anonymous} ? 'f': 't', $input{category},
            $areas, $q->{site} eq 'emptyhomes' ? 'f' : 't');
        my %h = ();
        $h{title} = $input{title};
        $h{detail} = $input{detail};
        $h{name} = $input{name};
        my $base = mySociety::Config::get('BASE_URL');
        $base =~ s/matthew/emptyhomes.matthew/ if $q->{site} eq 'emptyhomes'; # XXX Temp
        $base =~ s/matthew/scambs.matthew/ if $q->{site} eq 'scambs'; # XXX Temp
        $h{url} = $base . '/P/' . mySociety::AuthToken::store('problem', $id);
        dbh()->commit();

        $out = Page::send_email($q, $input{email}, $input{name}, _('problem'), %h);

    }
    return $out;
}

sub display_form {
    my ($q, @errors) = @_;
    my ($pin_x, $pin_y, $pin_tile_x, $pin_tile_y) = (0,0,0,0);
    my @vars = qw(title detail name email phone pc easting northing x y skipped council anonymous flickr upload_fileid);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    my @ps = $q->param;
    foreach (@ps) {
        ($pin_tile_x, $pin_tile_y, $pin_x) = ($1, $2, $q->param($_)) if /^tile_(\d+)\.(\d+)\.x$/;
        $pin_y = $q->param($_) if /\.y$/;
    }
    return display_location($q)
        unless ($pin_x && $pin_y)
            || ($input{easting} && $input{northing})
            || ($input{skipped} && $input{x} && $input{y})
            || ($input{skipped} && $input{pc})
            || ($input{flickr} && $input{pc});

    my $out = '';
    my ($px, $py, $easting, $northing);
    if ($input{skipped}) {
        # Map is being skipped
        if ($input{x} && $input{y}) {
            $easting = Page::tile_to_os($input{x});
            $northing = Page::tile_to_os($input{y});
        } else {
            my ($x, $y, $e, $n, $error) = Page::geocode($input{pc});
            $easting = $e; $northing = $n;
        }
    } elsif ($pin_x && $pin_y) {
        # Map was clicked on
        $pin_x = Page::click_to_tile($pin_tile_x, $pin_x);
        $pin_y = Page::click_to_tile($pin_tile_y, $pin_y, 1);
        $input{x} ||= int($pin_x) - 1;
        $input{y} ||= int($pin_y) - 1;
        $px = Page::tile_to_px($pin_x, $input{x});
        $py = Page::tile_to_px($pin_y, $input{y}, 1);
        $easting = Page::tile_to_os($pin_x);
        $northing = Page::tile_to_os($pin_y);
    } elsif ($input{flickr} && $input{pc} && !$input{easting} && !$input{northing}) {
        my ($x, $y, $e, $n, $error) = Page::geocode($input{pc});
        $easting = $e; $northing = $n;
        $input{x} = int(Page::os_to_tile($easting));
        $input{y} = int(Page::os_to_tile($northing));
        $px = Page::os_to_px($easting, $input{x});
        $py = Page::os_to_px($northing, $input{y}, 1);
    } else {
        # Normal form submission
        my ($x, $y, $tile_x, $tile_y);
        ($x, $y, $tile_x, $tile_y, $px, $py) = Page::os_to_px_with_adjust($q, $input{easting}, $input{northing}, undef, undef);
        $input{x} = $tile_x;
        $input{y} = $tile_y;
        $easting = $input_h{easting};
        $northing = $input_h{northing};
    }

    my $all_councils = mySociety::MaPit::get_voting_areas_by_location(
        { easting => $easting, northing => $northing },
        'polygon', $mySociety::VotingArea::council_parent_types);

    if ($q->{site} eq 'scambs') {
        delete $all_councils->{2218};
        return display_location($q, _('That location is not within the boundary of South Cambridgeshire District Council - you can report problems elsewhere in Great Britain using <a href="http://www.fixmystreet.com/">FixMyStreet</a>.')) unless $all_councils->{2260};
    }
    $all_councils = [ keys %$all_councils ];
    return display_location($q, _('That spot does not appear to be covered by a council - if it is past the shoreline, for example, please specify the closest point on land.')) unless @$all_councils;
    my $areas_info = mySociety::MaPit::get_voting_areas_info($all_councils);

    # Look up categories for this council or councils
    my $category = '';
    my %council_ok;
    if ($q->{site} ne 'emptyhomes') { # No category
        my $categories = select_all("select area_id, category from contacts
            where deleted='f' and area_id in (" . join(',', @$all_councils) . ')');
        @$categories = sort { $a->{category} cmp $b->{category} } @$categories;
        my @categories;
        foreach (@$categories) {
            $council_ok{$_->{area_id}} = 1;
            next if $_->{category} eq _('Other');
            push @categories, $_->{category};
        }
        if ($q->{site} eq 'scambs') {
            @categories = Page::scambs_categories();
        }
        if (@categories) {
            @categories = ('-- Pick a category --', @categories, _('Other'));
            $category = $q->div($q->label({'for'=>'form_category'}, _('Category:')), 
                $q->popup_menu(-name=>'category', -values=>\@categories,
                    -attributes=>{id=>'form_category'})
            );
        }
    }

    my @councils = keys %council_ok;
    my $details;
    if (@councils == @$all_councils) {
        $details = 'all';
    } elsif (@councils == 0) {
        $details = 'none';
    } else {
        $details = 'some';
    }

    if ($input{skipped}) {
        $out .= <<EOF;
<form action="./" method="post">
<input type="hidden" name="pc" value="$input_h{pc}">
<input type="hidden" name="x" value="$input_h{x}">
<input type="hidden" name="y" value="$input_h{y}">
<input type="hidden" name="skipped" value="1">
EOF
        $out .= $q->h1(_('Reporting a problem')) . '<ul>';
    } else {
        my $pins = Page::display_pin($q, $px, $py, 'purple');
        $out .= Page::display_map($q, x => $input{x}, y => $input{y}, type => 2,
            pins => $pins, px => $px, py => $py );
        $out .= $q->h1(_('Reporting a problem')) . ' ';
        $out .= $q->p(_('You have located the problem at the point marked with a purple pin on the map.
If this is not the correct location, simply click on the map again. '));
    }

    if ($q->{site} ne 'emptyhomes') { # No "send to council" blurb
        if ($details eq 'all') {
            $out .= '<p>All the information you provide here will be sent to <strong>'
                . join('</strong> or <strong>', map { $areas_info->{$_}->{name} } @$all_councils)
                . '</strong>. On the site, we will show the subject and details of the problem,
                plus your name if you give us permission.';
            $out .= '<input type="hidden" name="council" value="' . join(',',@$all_councils) . '">';
        } elsif ($details eq 'some') {
            my $e = mySociety::Config::get('CONTACT_EMAIL');
            my %councils = map { $_ => 1 } @councils;
            my @missing;
            foreach (@$all_councils) {
                push @missing, $_ unless $councils{$_};
            }
            my $n = @missing;
            my $list = join(' or ', map { $areas_info->{$_}->{name} } @missing);
            $out .= '<p>All the information you provide here will be sent to <strong>'
                . join('</strong> or <strong>', map { $areas_info->{$_}->{name} } @councils)
                . '</strong>. On the site, we will show the subject and details of the problem,
                plus your name if you give us permission.';
            $out .= ' We do <strong>not</strong> yet have details for the other council';
            $out .= ($n>1) ? 's that cover' : ' that covers';
            $out .= " this location. You can help us by finding a contact email address for local
problems for $list and emailing it to us at <a href='mailto:$e'>$e</a>.";
            $out .= '<input type="hidden" name="council" value="' . join(',', @councils)
                . '|' . join(',', @missing) . '">';
        } else {
            my $e = mySociety::Config::get('CONTACT_EMAIL');
            my $list = join(' or ', map { $areas_info->{$_}->{name} } @$all_councils);
            my $n = @$all_councils;
            $out .= '<p>We do not yet have details for the council';
            $out .= ($n>1) ? 's that cover' : ' that covers';
            $out .= " this location. If you submit a problem here it will be
left on the site, but <strong>not</strong> reported to the council.
You can help us by finding a contact email address for local
problems for $list and emailing it to us at <a href='mailto:$e'>$e</a>.";
            $out .= '<input type="hidden" name="council" value="-1">';
        }
    }
    if ($input{skipped}) {
        $out .= $q->p(_('Please fill in the form below with details of the problem,
and describe the location as precisely as possible in the details box.'));
    } elsif ($q->{site} eq 'scambs') {
        $out .= '<p>Please fill in details of the problem below. We won\'t be able
to help unless you leave as much detail as you can, so please describe the exact location of
the problem (e.g. on a wall), what it is, how long it has been there, a description (and a
photo of the problem if you have one), etc.';
    } elsif ($details ne 'none') {
        $out .= '<p>Please fill in details of the problem below. The council won\'t be able
to help unless you leave as much detail as you can, so please describe the exact location of
the problem (e.g. on a wall), what it is, how long it has been there, a description (and a
photo of the problem if you have one), etc.';
    } elsif ($q->{site} eq 'emptyhomes') {
        $out .= <<EOF;
<p>Please fill in details of the empty property below, giving the state of the
property, what type of property is and any other information you feel is relevant.
Please be polite, concise and to the point; writing your message entirely in
block capitals makes it hard to read, as does a lack of punctuation.</p>
EOF
    } else {
        $out .= $q->p(_('Please fill in details of the problem below.'));
    }
    $out .= '
<input type="hidden" name="easting" value="' . $easting . '">
<input type="hidden" name="northing" value="' . $northing . '">';

    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    my $anon = ($input{anonymous}) ? ' checked' : ($input{title} ? '' : ' checked');
    $out .= '<div id="problem_form">';
    $out .= $q->h2('Empty property details form') if $q->{site} eq 'emptyhomes';
    $out .= <<EOF;
<div id="fieldset">
$category
EOF
    $out .= <<EOF;
<div><label for="form_title">Subject:</label>
<input type="text" value="$input_h{title}" name="title" id="form_title" size="30"></div>
EOF
    $out .= <<EOF;
<div><label for="form_detail">Details:</label>
<textarea name="detail" id="form_detail" rows="7" cols="26">$input_h{detail}</textarea></div>
EOF
    if (my $token = $input{flickr}) {
        my $id = mySociety::AuthToken::retrieve('flickr', $token);
        if ($id) {
            $out .= '<p>The photo you uploaded was:</p> <input type="hidden" name="flickr" value="' . $token . '">';
            $out .= '<p align="center"><img src="/photo?id=' . $id . '"></p>';
        }
    } else {
        $out .= <<EOF;
<div id="fileupload_flashUI" style="display:none">
<label for="form_photo">Photo:</label>
<input type="text" id="txtfilename" disabled="true" style="background-color: #ffffff;">
<input type="button" value="Browse..." onclick="document.getElementById('txtfilename').value=''; swfu.cancelUpload(); swfu.selectFile();">
<input type="hidden" name="upload_fileid" id="upload_fileid" value="$input_h{upload_fileid}">
</div>
<div id="fileupload_normalUI">
<label for="form_photo">Photo:</label>
<input type="file" name="photo" id="form_photo">
</div>
EOF
    }
    $out .= <<EOF;
<div><label for="form_name">Name:</label>
<input type="text" value="$input_h{name}" name="name" id="form_name" size="30"></div>
<div class="checkbox"><input type="checkbox" name="anonymous" id="form_anonymous" value="1"$anon>
<label for="form_anonymous">Can we show your name on the site?</label>
<small>(we never show your email address or phone number)</small></div>
<div><label for="form_email">Email:</label>
<input type="text" value="$input_h{email}" name="email" id="form_email" size="30"></div>
<div><label for="form_phone">Phone:</label>
<input type="text" value="$input_h{phone}" name="phone" id="form_phone" size="15">
<small>(optional)</small></div>
EOF
    if ($q->{site} eq 'scambs') {
        $out .= <<EOF;
<p>Please note:</p>
<ul>
<li>Please be polite, concise and to the point.
<li>Please do not be abusive.
<li>Writing your message entirely in block capitals makes it hard to read,
as does a lack of punctuation.
</ul>
EOF
    } elsif ($q->{site} ne 'emptyhomes') {
        $out .= <<EOF;
<p>Please note:</p>
<ul>
<li>Please be polite, concise and to the point.
<li>Please do not be abusive &mdash; abusing your council devalues the service for all users.
<li>Writing your message entirely in block capitals makes it hard to read,
as does a lack of punctuation.
<li>Remember that FixMyStreet is primarily for reporting physical
problems that can be fixed. If your problem is not appropriate for
submission via this site remember that you can contact your council
directly using their own website.
</ul>
EOF
    }
    $out .= <<EOF;
<p align="right"><input type="submit" name="submit_problem" value="Submit"></p>
</div>
</div>
EOF
    $out .= Page::display_map_end(1);
    my %params = (
        js => <<EOF
<script type="text/javascript" defer>
swfu = new SWFUpload(swfu_settings);
</script>
EOF
    );
    return ($out, %params);
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
    return front_page($q, @errors) unless $x || $y || $input{pc};
    if (!$x && !$y) {
        try {
            ($x, $y, $easting, $northing, $error) = Page::geocode($input{pc});
        } catch Error::Simple with {
            $error = shift;
        };
    }
    return Page::geocode_choice($error, '/') if (ref($error) eq 'ARRAY');
    return front_page($q, $error) if ($error);

    my ($pins, $current_map, $current, $fixed, $dist) = map_pins($q, $x, $y);
    my $out = Page::display_map($q, x => $x, y => $y, type => 1, pins => $pins );
    $out .= $q->h1(_('Problems in this area'));
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    my $skipurl = NewURL($q, 'submit_map'=>1, skipped=>1);
    $out .= $q->p({-id=>'text_map'}, _('To report a problem, simply <strong>click on the map</strong> at the correct location.'));
    $out .= $q->p({-id=>'text_no_map'}, sprintf(_("<small>If you cannot see a map &ndash; if you have images turned off,
or are using a text only browser, for example &ndash; and you
wish to report a problem, please
<a href='%s'>skip this step</a> and we will ask you
to describe the location of the problem instead.</small>"), $skipurl));
    $out .= '<div>' . $q->h2(_('Recent problems reported near here'));
    my $list = '';
    foreach (@$current_map) {
        $list .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $list .= $_->{title};
        $list .= '</a></li>';
    }
    if (@$current_map) {
        $out .= '<ol id="current">' . $list . '</ol>';
    } else {
        $out .= $q->p(_('No problems have been reported yet.'));
    }
    $out .= $q->h2({-id => 'closest_problems'}, sprintf(_('Closest problems within %skm'), $dist));
    my $email_me = _('Email me problems');
    my $rss_title = _('RSS feed of recent local problems');
    my $rss_alt = _('RSS feed');
    my $u_pc = uri_escape($input{pc});
    $out .= <<EOF;
    <div id="alert_links">
    <a id="email_alert" href="/alert?pc=$u_pc;type=local;feed=local:$x:$y;alert=Subscribe">$email_me</a>
     &nbsp; <span id="rss_link"><a href="/rss/$x,$y"><img src="/i/feed.png" width="16" height="16" title="$rss_title" alt="$rss_alt" border="0" style="vertical-align: middle"></a></span>
    </div>
EOF
    $list = '';
    foreach (@$current) {
        $list .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $list .= $_->{title} . ' <small>(' . int($_->{distance}/100+.5)/10 . 'km)</small>';
        $list .= '</a></li>';
    }
    if (@$current) {
        my $list_start = @$current_map + 1;
        $out .= '<ol id="current_near" start="' . $list_start . '">' . $list . '</ol>';
    } else {
        $out .= $q->p(_('No problems have been reported yet.'));
    }
    $out .= $q->h2(sprintf(_('Recently fixed problems within %skm'), $dist));
    $list = '';
    foreach (@$fixed) {
        $list .= '<li><a href="' . NewURL($q, id=>$_->{id}, x=>undef, y=>undef) . '">';
        $list .= $_->{title} . ' <small>(' . int($_->{distance}/100+.5)/10 . 'km)</small>';
        $list .= '</a></li>';
    }
    if (@$fixed) {
        $out .= "<ol>$list</ol>\n";
    } else {
        $out .= $q->p(_('No problems have been fixed yet'));
    }
    $out .= '</div>';
    $out .= Page::display_map_end(1);

    my %params = (
        rss => [ _('Recent local problems, FixMyStreet'), "/rss/$x,$y" ]
    );

    return ($out, %params);
}

sub display_problem {
    my ($q, @errors) = @_;

    my @vars = qw(id name email update fixed upload_fileid x y);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    $input{x} ||= 0; $input{x} += 0;
    $input{y} ||= 0; $input{y} += 0;

    # Get all information from database
    return display_location($q, 'Unknown problem ID') if $input{id} =~ /\D/;
    my $problem = Problems::fetch_problem($input{id});
    return display_location($q, 'Unknown problem ID') unless $problem;
    return front_page($q, 'That problem has been hidden from public view as it contained inappropriate public details') if $problem->{state} eq 'hidden';
    my ($x, $y, $x_tile, $y_tile, $px, $py) = Page::os_to_px_with_adjust($q, $problem->{easting}, $problem->{northing}, $input{x}, $input{y});

    my $out = '';

    my $pins = Page::display_pin($q, $px, $py, 'blue');
    $out .= Page::display_map($q, x => $x_tile, y => $y_tile, type => 0,
        pins => $pins, px => $px, py => $py );
    if ($q->{site} ne 'emptyhomes' && $problem->{state} eq 'confirmed' && $problem->{duration} > 8*7*24*60*60) {
        $out .= $q->p({id => 'unknown'}, _('This problem is old and of unknown status.'))
    }
    if ($problem->{state} eq 'fixed') {
        $out .= $q->p({id => 'fixed'}, _('This problem has been fixed') . '.')
    }
    $out .= Page::display_problem_text($q, $problem);

    $out .= $q->p({align=>'right'},
        $q->small($q->a({href => '/contact?id=' . $input{id}}, 'Offensive? Unsuitable? Tell us'))
    );

    # Try and have pin near centre of map
    $x_tile -= 1 if $x - $x_tile < 0.5;
    $y_tile -= 1 if $y - $y_tile < 0.5;
    my $back = NewURL($q, id=>undef, x=>$x_tile, y=>$y_tile, submit_update=>undef);
    $out .= '<p style="padding-bottom: 0.5em; border-bottom: dotted 1px #999999;" align="right"><a href="'
        . $back . '">' . _('More problems nearby') . '</a></p>';
    $out .= '<div id="alert_links">';
    $out .= '<a id="email_alert" href="/alert?type=updates;id='.$input_h{id}.'">' . _('Email me updates') . '</a>';
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
    $out .= ' &nbsp; <span id="rss_link"><a href="/rss/'.$input_h{id}.'"><img src="/i/feed.png" width="16" height="16" title="' . _('RSS feed') . '" alt="' . _('RSS feed of updates to this problem') . '" border="0" style="vertical-align: middle"></a></span>';
    $out .= '</div>';

    $out .= Page::display_problem_updates($input{id});
    $out .= '<div id="update_form">';
    $out .= $q->h2(_('Provide an update'));
    $out .= $q->p($q->small(_('Please note that updates are not sent to the council.')))
        unless $q->{site} eq 'emptyhomes'; # No council blurb
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }

    my $fixed = ($input{fixed}) ? ' checked' : '';
    my $fixedline = $problem->{state} eq 'fixed' ? '' : qq{
<div class="checkbox"><input type="checkbox" name="fixed" id="form_fixed" value="1"$fixed>
<label for="form_fixed">} . _('This problem has been fixed') . qq{</label></div>
};
    $out .= <<EOF;
<form method="post" action="./" id="fieldset" enctype="multipart/form-data">
<input type="hidden" name="submit_update" value="1">
<input type="hidden" name="id" value="$input_h{id}">
<div><label for="form_name">Name:</label>
<input type="text" name="name" id="form_name" value="$input_h{name}" size="20"> (optional)</div>
<div><label for="form_email">Email:</label>
<input type="text" name="email" id="form_email" value="$input_h{email}" size="20"></div>
<div><label for="form_update">Update:</label>
<textarea name="update" id="form_update" rows="7" cols="30">$input_h{update}</textarea></div>
$fixedline
<div id="fileupload_flashUI" style="display:none">
<label for="form_photo">Photo:</label>
<input type="text" id="txtfilename" disabled="true" style="background-color: #ffffff;">
<input type="button" value="Browse..." onclick="document.getElementById('txtfilename').value=''; swfu.cancelUpload(); swfu.selectFile();">
<input type="hidden" name="upload_fileid" id="upload_fileid" value="$input_h{upload_fileid}">
</div>
<div id="fileupload_normalUI">
<label for="form_photo">Photo:</label>
<input type="file" name="photo" id="form_photo">
</div>
<div class="checkbox"><input type="submit" id="update_post" value="Post"></div>
</form>
</div>
EOF
    $out .= Page::display_map_end(0);
    my $js = <<EOF;
<script type="text/javascript" defer>
swfu = new SWFUpload(swfu_settings);
</script>
EOF

    my %params = (
        rss => [ _('Updates to this problem, FixMyStreet'), "/rss/$input_h{id}" ],
        js => $js,
        title => $problem->{title}
    );
    return ($out, %params);
}

sub map_pins {
    my ($q, $x, $y) = @_;

    my $pins = '';
    my $min_e = Page::tile_to_os($x-1);
    my $min_n = Page::tile_to_os($y-1);
    my $mid_e = Page::tile_to_os($x+1);
    my $mid_n = Page::tile_to_os($y+1);
    my $max_e = Page::tile_to_os($x+3);
    my $max_n = Page::tile_to_os($y+3);

    my $current_map = Problems::current_on_map($min_e, $max_e, $min_n, $max_n);
    my @ids = ();
    my $count_prob = 1;
    my $count_fixed = 1;
    foreach (@$current_map) {
        push(@ids, $_->{id});
        my $px = Page::os_to_px($_->{easting}, $x);
        my $py = Page::os_to_px($_->{northing}, $y, 1);
        $pins .= Page::display_pin($q, $px, $py, 'red', $count_prob++);
    }

    my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($mid_e, $mid_n, 'G');
    my $dist = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
    $dist = int($dist*10+0.5)/10;

    # XXX: Change to only show problems with extract(epoch from ms_current_timestamp()-lastupdate) < 8 weeks
    # And somehow display/link to old problems somewhere else...
    my $current = [];
    if (@$current_map < 9) {
        my $limit = 9 - @$current_map;
        $current = Problems::current_nearby($dist, join(',', @ids), $limit, $mid_e, $mid_n);
        foreach (@$current) {
            my $px = Page::os_to_px($_->{easting}, $x);
            my $py = Page::os_to_px($_->{northing}, $y, 1);
            $pins .= Page::display_pin($q, $px, $py, 'red', $count_prob++);
        }
    }
    my $fixed = Problems::fixed_nearby($dist, $mid_e, $mid_n);
    foreach (@$fixed) {
        my $px = Page::os_to_px($_->{easting}, $x);
        my $py = Page::os_to_px($_->{northing}, $y, 1);
        $pins .= Page::display_pin($q, $px, $py, 'green', $count_fixed++);
    }
    return ($pins, $current_map, $current, $fixed, $dist);
}

