#!/usr/bin/perl -w -I../perllib

# index.cgi:
# Main code for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.325 2009-11-24 16:03:52 louise Exp $

use strict;
use Standard;
use Error qw(:try);
use File::Slurp;
use LWP::Simple;
use RABX;
use CGI::Carp;
use URI::Escape;

use CrossSell;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(select_all);
use mySociety::EmailUtil;
use mySociety::GeoUtil;
use mySociety::Locale;
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

    if (my $partial = $q->param('partial_token')) {
        # We have a partial token, so fetch data from database and see where we're at.
        my $id = mySociety::AuthToken::retrieve('partial', $partial);
        if ($id) {
            my @row = dbh()->selectrow_array(
                "select easting, northing, name, email, title, (photo is not null) as has_photo, phone
                    from problem where id=? and state='partial'", {}, $id);
            if (@row) {
                $q->param('anonymous', 1);
                $q->param('submit_map', 1);
                $q->param('easting', $row[0]);
                $q->param('northing', $row[1]);
                $q->param('name', $row[2]);
                $q->param('email', $row[3]);
                $q->param('title', $row[4]);
                $q->param('has_photo', $row[5]);
                $q->param('phone', $row[6]);
                $q->param('partial', $partial);
            } else {
                my $base = mySociety::Config::get('BASE_URL');
                print $q->redirect(-location => $base . '/report/' . $id);
            }
        }
    }

    my $out = '';
    my %params;
    if ($q->param('submit_problem')) {
        $params{title} = _('Submitting your report');
        ($out) = submit_problem($q);
    } elsif ($q->param('submit_update')) {
        $params{title} = _('Submitting your update');
        ($out) = submit_update($q);
    } elsif ($q->param('submit_map')) {
        ($out, %params) = display_form($q, [], {});
        $params{title} = _('Reporting a problem');
    } elsif ($q->param('id')) {
        ($out, %params) = display_problem($q, [], {});
        $params{title} .= ' - ' . _('Viewing a problem');
    } elsif ($q->param('pc') || ($q->param('x') && $q->param('y'))) {
        ($out, %params) = display_location($q);
        $params{title} = _('Viewing a location');
    } elsif ($q->param('cobrand_page') && ($q->{site} ne 'fixmystreet')) {
        ($out, %params) = Cobrand::cobrand_page($q);
        if (!$out) {
            $out = front_page($q);
        }
    } else {
        $out = front_page($q);
    }
    print Page::header($q, %params);
    print $out;
    my %footerparams;
    $footerparams{js} = $params{js} if $params{js};
    $footerparams{template} = $params{template} if $params{template};
    print Page::footer($q, %footerparams);
}
Page::do_fastcgi(\&main);

# Display front page
sub front_page {
    my ($q, $error) = @_;
    my $pc_h = ent($q->param('pc') || '');

    # Look up various cobrand things
    my $cobrand = Page::get_cobrand($q);
    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'postcodeForm', $q);
    my $form_action = Cobrand::url($cobrand, '/', $q);
    my $question = Cobrand::enter_postcode_text($cobrand, $q);

    my %vars = (
        error => $error || '',
        pc_h => $pc_h, 
        cobrand_form_elements => $cobrand_form_elements,
        form_action => $form_action,
        question => $question,
    );
    my $cobrand_front_page = Page::template_include('front-page', $q, Page::template_root($q), %vars);
    return $cobrand_front_page if $cobrand_front_page;

    my $out = '<p id="expl"><strong>' . _('Report, view, or discuss local problems') . '</strong>';
    my $subhead = _('(like graffiti, fly tipping, broken paving slabs, or street lighting)');
    $out .= '<br><small>' . $subhead . '</small>' if $subhead ne ' ';
    $out .= '</p>';
    #if (my $url = mySociety::Config::get('IPHONE_URL')) {
    #    my $getiphone = _("Get FixMyStreet on your iPhone");
    #    my $new = _("New!");
    #    if ($q->{site} eq 'fixmystreet') {
    #        $out .= <<EOF
#<p align="center" style="margin-bottom:0">
#<img width="23" height="12" alt="$new" src="/i/new.png" border="0">
#<a href="$url">$getiphone</a>
#</p>
#EOF
    #    }
    #}
    $out .= '<p class="error">' . $error . '</p>' if ($error);

    # Add pretty commas for display
    $out .= '<form action="' . $form_action . '" method="get" name="postcodeForm" id="postcodeForm">';
    if (my $token = $q->param('partial')) {
        my $id = mySociety::AuthToken::retrieve('partial', $token);
        if ($id) {
            my $thanks = _("Thanks for uploading your photo. We now need to locate your problem, so please enter a nearby street name or postcode in the box below&nbsp;:");
            $out .= <<EOF;
<p style="margin-top: 0; color: #cc0000;"><img align="right" src="/photo?id=$id" hspace="5">$thanks</p>

<input type="hidden" name="partial_token" value="$token">
EOF
        }
    }
    my $activate = _("Go");
    $out .= <<EOF;
<label for="pc">$question</label>
&nbsp;<input type="text" name="pc" value="$pc_h" id="pc" size="10" maxlength="200">
&nbsp;<input type="submit" value="$activate" id="submit">
$cobrand_form_elements
</form>

<div id="front_intro">
EOF
    $out .= $q->h2(_('How to report a problem'));
    $out .= $q->ol(
        $q->li($question),
        $q->li(_('Locate the problem on a map of the area')),
        $q->li(_('Enter details of the problem')),
        $q->li(_('We send it to the council on your behalf'))
    );

    
    $out .= Cobrand::front_stats(Page::get_cobrand($q), $q);

    $out .= <<EOF;
</div>

EOF

    my $recent_photos = Cobrand::recent_photos(Page::get_cobrand($q), 3);
    my $probs = Cobrand::recent(Page::get_cobrand($q));
    if (@$probs || $recent_photos){
         $out .= '<div id="front_recent">';
         $out .= $q->h2(_('Photos of recent reports')) . $recent_photos if $recent_photos;

         $out .= $q->h2(_('Recently reported problems')) . ' <ul>' if @$probs;
         foreach (@$probs) {
             $out .= '<li><a href="/report/' . $_->{id} . '">'. ent($_->{title});
             $out .= '</a>';
         }
         $out .= '</ul>' if @$probs;
    $out .= '</div>';
    }   

    return $out;
}

sub submit_update {
    my $q = shift;
    my @vars = qw(id name rznvy update fixed upload_fileid add_alert);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my @errors;
    my %field_errors;

    my $fh = $q->upload('photo');
    if ($fh) {
        my $err = Page::check_photo($q, $fh);
        push @errors, $err if $err;
    }
    $field_errors{update} = _('Please enter a message') unless $input{update} =~ /\S/;
    $input{name} = undef unless $input{name} =~ /\S/;
    if ($input{rznvy} !~ /\S/) {
        $field_errors{email} = _('Please enter your email');
    } elsif (!mySociety::EmailUtil::is_valid_email($input{rznvy})) {
        $field_errors{email} = _('Please enter a valid email');
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

    return display_problem($q, \@errors, \%field_errors) if (@errors || scalar(keys(%field_errors)));
    my $cobrand = Page::get_cobrand($q);
    my $cobrand_data = Cobrand::extra_update_data($cobrand, $q);
    my $id = dbh()->selectrow_array("select nextval('comment_id_seq');");
    Utils::workaround_pg_bytea("insert into comment
        (id, problem_id, name, email, website, text, state, mark_fixed, photo, lang, cobrand, cobrand_data)
        values (?, ?, ?, ?, '', ?, 'unconfirmed', ?, ?, ?, ?, ?)", 7,
        $id, $input{id}, $input{name}, $input{rznvy}, $input{update},
        $input{fixed} ? 't' : 'f', $image, $mySociety::Locale::lang, $cobrand, $cobrand_data);

    my %h = ();
    $h{update} = $input{update};
    $h{name} = $input{name} ? $input{name} : _("Anonymous");
    my $base = Page::base_url_with_lang($q, undef, 1);
    $h{url} = $base . '/C/' . mySociety::AuthToken::store('update', { id => $id, add_alert => $input{add_alert} } );
    dbh()->commit();

    my $out = Page::send_email($q, $input{rznvy}, $input{name}, 'update', %h);
    return $out;
}

sub submit_problem {
    my $q = shift;
    my @vars = qw(council title detail name email phone pc easting northing skipped anonymous category partial upload_fileid lat lon);
    my %input = map { $_ => scalar $q->param($_) } @vars;
    for (qw(title detail)) {
        $input{$_} = lc $input{$_} if $input{$_} !~ /[a-z]/;
        $input{$_} = ucfirst $input{$_};
        $input{$_} =~ s/\b(dog\s*)shit\b/$1poo/ig;
        $input{$_} =~ s/\b(porta)\s*([ck]abin|loo)\b/[$1ble $2]/ig;
        $input{$_} =~ s/kabin\]/cabin\]/ig;
    }
    my @errors;
    my %field_errors;

    if ($input{lat}) {
        try {
            ($input{easting}, $input{northing}) = mySociety::GeoUtil::wgs84_to_national_grid($input{lat}, $input{lon}, 'G');
        } catch Error::Simple with { 
            my $e = shift;
            push @errors, "We had a problem with the supplied co-ordinates - outside the UK?";
        };
    }

    my $fh = $q->upload('photo');
    if ($fh) {
        my $err = Page::check_photo($q, $fh);
        $field_errors{photo} = $err if $err;
    }

    $input{council} = 2260 if $q->{site} eq 'scambs'; # All reports go to S. Cambs
    push(@errors, _('No council selected')) unless ($input{council} && $input{council} =~ /^(?:-1|[\d,]+(?:\|[\d,]+)?)$/);
    $field_errors{title} = _('Please enter a subject') unless $input{title} =~ /\S/;
    $field_errors{detail} = _('Please enter some details') unless $input{detail} =~ /\S/;
    if ($input{name} !~ /\S/) {
        $field_errors{name} =  _('Please enter your name');
    } elsif (length($input{name}) < 5 || $input{name} !~ /\s/ || $input{name} =~ /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i) {
        $field_errors{name} = _('Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box');
    }
    if ($input{email} !~ /\S/) {
        $field_errors{email} = _('Please enter your email');
    } elsif (!mySociety::EmailUtil::is_valid_email($input{email})) {
        $field_errors{email} = _('Please enter a valid email');
    }
    if ($input{category} && $input{category} eq '-- Pick a category --') {
        $field_errors{category} = _('Please choose a category');
        $input{category} = '';
    } elsif ($input{category} && $input{category} eq _('-- Pick a property type --')) {
        $field_errors{category} = _('Please choose a property type');
        $input{category} = '';
    }

    return display_form($q, \@errors, \%field_errors) if (@errors || scalar keys %field_errors); # Short circuit

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
            if ($input{category} && $q->{site} ne 'emptyhomes') {
                my $categories = select_all("select area_id from contacts
                    where deleted='f' and area_id in ("
                    . $input{council} . ') and category = ?', $input{category});
                $field_errors{category} = _('Please choose a category') unless @$categories;
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
            $field_errors{photo} = sprintf(_("That image doesn't appear to have uploaded correctly (%s), please try again."), $e);
        };
    }

    if ($input{upload_fileid}) {
        open FP, mySociety::Config::get('UPLOAD_CACHE') . $input{upload_fileid};
        $image = join('', <FP>);
        close FP;
    }

    return display_form($q, \@errors, \%field_errors) if (@errors || scalar keys %field_errors);

    delete $input{council} if $input{council} eq '-1';
    my $used_map = $input{skipped} ? 'f' : 't';
    $input{category} = _('Other') unless $input{category};
    my ($id, $out);
    my $cobrand = Page::get_cobrand($q);
    my $cobrand_data = Cobrand::extra_problem_data($cobrand, $q);
    if (my $token = $input{partial}) {
        my $id = mySociety::AuthToken::retrieve('partial', $token);
        if ($id) {
            dbh()->do("update problem set postcode=?, easting=?, northing=?, title=?, detail=?,
                name=?, email=?, phone=?, state='confirmed', council=?, used_map='t',
                anonymous=?, category=?, areas=?, cobrand=?, cobrand_data=?, confirmed=ms_current_timestamp(),
                lastupdate=ms_current_timestamp() where id=?", {}, $input{pc}, $input{easting}, $input{northing},
                $input{title}, $input{detail}, $input{name}, $input{email},
                $input{phone}, $input{council}, $input{anonymous} ? 'f' : 't',
                $input{category}, $areas, $cobrand, $cobrand_data, $id);
            Utils::workaround_pg_bytea('update problem set photo=? where id=?', 1, $image, $id)
                if $image;
            dbh()->commit();
            $out = $q->p(sprintf(_('You have successfully confirmed your report and you can now <a href="%s">view it on the site</a>.'), "/report/$id"));
            my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
            if ($display_advert) {
                $out .= CrossSell::display_advert($q, $input{email}, $input{name});
            }
        } else {
            $out = $q->p('There appears to have been a problem updating the details of your report.
Please <a href="/contact">let us know what went on</a> and we\'ll look into it.');
        }
    } else {
        $id = dbh()->selectrow_array("select nextval('problem_id_seq');");
        Utils::workaround_pg_bytea("insert into problem
            (id, postcode, easting, northing, title, detail, name,
             email, phone, photo, state, council, used_map, anonymous, category, areas, lang, cobrand, cobrand_data)
            values
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unconfirmed', ?, ?, ?, ?, ?, ?, ?, ?)", 10,
            $id, $input{pc}, $input{easting}, $input{northing}, $input{title},
            $input{detail}, $input{name}, $input{email}, $input{phone}, $image,
            $input{council}, $used_map, $input{anonymous} ? 'f': 't', $input{category},
            $areas, $mySociety::Locale::lang, $cobrand, $cobrand_data);
        my %h = ();
        $h{title} = $input{title};
        $h{detail} = $input{detail};
        $h{name} = $input{name};
        my $base = Page::base_url_with_lang($q, undef, 1);
        $h{url} = $base . '/P/' . mySociety::AuthToken::store('problem', $id);
        dbh()->commit();

        $out = Page::send_email($q, $input{email}, $input{name}, 'problem', %h);

    }
    return $out;
}

sub display_form {
    my ($q, $errors, $field_errors) = @_;
    my @errors = @$errors;
    my %field_errors = %{$field_errors};
    my $cobrand = Page::get_cobrand($q);
    push @errors, _('There were problems with your report. Please see below.') if (scalar keys %field_errors && $cobrand ne 'emptyhomes');

    my ($pin_x, $pin_y, $pin_tile_x, $pin_tile_y) = (0,0,0,0);
    my @vars = qw(title detail name email phone pc easting northing x y skipped council anonymous partial upload_fileid lat lon);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;

    # Convert lat/lon to easting/northing if given
    if ($input{lat}) {
        try {
            ($input{easting}, $input{northing}) = mySociety::GeoUtil::wgs84_to_national_grid($input{lat}, $input{lon}, 'G');
            $input_h{easting} = $input{easting};
            $input_h{northing} = $input{northing};
        } catch Error::Simple with { 
            my $e = shift;
            push @errors, "We had a problem with the supplied co-ordinates - outside the UK?";
        };
    }

    # Get tile co-ordinates if map clicked
    ($input{x}) = $input{x} =~ /^(\d+)/; $input{x} ||= 0;
    ($input{y}) = $input{y} =~ /^(\d+)/; $input{y} ||= 0;
    my @ps = $q->param;
    foreach (@ps) {
        ($pin_tile_x, $pin_tile_y, $pin_x) = ($1, $2, $q->param($_)) if /^tile_(\d+)\.(\d+)\.x$/;
        $pin_y = $q->param($_) if /\.y$/;
    }

    # We need either a map click, an E/N, to be skipping the map, or be filling in a partial form
    return display_location($q, @errors)
        unless ($pin_x && $pin_y)
            || ($input{easting} && $input{northing})
            || ($input{skipped} && $input{x} && $input{y})
            || ($input{skipped} && $input{pc})
            || ($input{partial} && $input{pc});

    # Work out some co-ordinates from whatever we've got
    my ($px, $py, $easting, $northing);
    if ($input{skipped}) {
        # Map is being skipped
        if ($input{x} && $input{y}) {
            $easting = Page::tile_to_os($input{x});
            $northing = Page::tile_to_os($input{y});
        } else {
            my ($x, $y, $e, $n, $error) = Page::geocode($input{pc}, $q);
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
    } elsif ($input{partial} && $input{pc} && !$input{easting} && !$input{northing}) {
        my ($x, $y, $error);
        try {
            ($x, $y, $easting, $northing, $error) = Page::geocode($input{pc}, $q);
        } catch Error::Simple with {
            $error = shift;
        };
        return Page::geocode_choice($error, '/', $q) if ref($error) eq 'ARRAY';
        return front_page($q, $error) if $error;
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

    # Look up councils and do checks for the point we've got
    my $parent_types = $mySociety::VotingArea::council_parent_types;
    $parent_types = [qw(DIS LBO MTD UTA LGD COI)] # No CTY
        if $q->{site} eq 'emptyhomes';
    # XXX: I think we want in_gb_locale around the next line, needs testing
    my $all_councils = mySociety::MaPit::get_voting_areas_by_location(
        { easting => $easting, northing => $northing },
        'polygon', $parent_types);

    # Let cobrand do a check
    my ($success, $error_msg) = Cobrand::council_check($cobrand, $all_councils, $q, 'submit_problem');    
    if (!$success){
        return display_location($q, $error_msg);
    }

    # Ipswich & St Edmundsbury are responsible for everything in their areas, no Suffolk
    delete $all_councils->{2241} if $all_councils->{2446} || $all_councils->{2443};

    # Norwich is responsible for everything in its areas, no Norfolk
    delete $all_councils->{2233} if $all_councils->{2391};

    $all_councils = [ keys %$all_councils ];
    return display_location($q, _('That spot does not appear to be covered by a council.
If you have tried to report an issue past the shoreline, for example,
please specify the closest point on land.')) unless @$all_councils;
    my $areas_info = mySociety::MaPit::get_voting_areas_info($all_councils);

    # Look up categories for this council or councils
    my $category = '';
    my (%council_ok, @categories);
    my $categories = select_all("select area_id, category from contacts
        where deleted='f' and area_id in (" . join(',', @$all_councils) . ')');
    if ($q->{site} ne 'emptyhomes') {
        @$categories = sort { $a->{category} cmp $b->{category} } @$categories;
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
            $category = _('Category:');
        }
    } else {
        foreach (@$categories) {
            $council_ok{$_->{area_id}} = 1;
        }
        @categories = (_('-- Pick a property type --'), _('Empty house or bungalow'),
            _('Empty flat or maisonette'), _('Whole block of empty flats'),
            _('Empty office or other commercial'), _('Empty pub or bar'),
            _('Empty public building - school, hospital, etc.'));
        $category = _('Property type:');
    }
    $category = $q->label({'for'=>'form_category'}, $category) .
        $q->popup_menu(-name=>'category', -values=>\@categories, -id=>'form_category',
            -attributes=>{id=>'form_category'})
        if $category;

    # Work out what help text to show, depending on whether we have council details
    my @councils = keys %council_ok;
    my $details;
    if (@councils == @$all_councils) {
        $details = 'all';
    } elsif (@councils == 0) {
        $details = 'none';
    } else {
        $details = 'some';
    }

    # Forms that allow photos need a different enctype
    my $allow_photo_upload = Cobrand::allow_photo_upload($cobrand);
    my $enctype = '';
    if ($allow_photo_upload) {
         $enctype = ' enctype="multipart/form-data"';
    }

    my %vars;
    $vars{input_h} = \%input_h;
    $vars{field_errors} = \%field_errors;
    if ($input{skipped}) {
       my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'mapSkippedForm', $q);
       my $form_action = Cobrand::url($cobrand, '/', $q); 
       $vars{form_start} = <<EOF;
<form action="$form_action" method="post" name="mapSkippedForm"$enctype>
<input type="hidden" name="pc" value="$input_h{pc}">
<input type="hidden" name="x" value="$input_h{x}">
<input type="hidden" name="y" value="$input_h{y}">
<input type="hidden" name="skipped" value="1">
$cobrand_form_elements
<div>
EOF
    } else {
        my $pins = Page::display_pin($q, $px, $py, 'purple');
        my $type;
        if ($allow_photo_upload) {
            $type = 2;
        } else {
            $type = 1;
        }
        $vars{form_start} = Page::display_map($q, x => $input{x}, 'y' => $input{y}, type => $type,
            pins => $pins, px => $px, py => $py );
        my $partial_id;
        if (my $token = $input{partial}) {
            $partial_id = mySociety::AuthToken::retrieve('partial', $token);
            if ($partial_id) {
                $vars{form_start} .= $q->p({id=>'unknown'}, 'Please note your report has
                <strong>not yet been sent</strong>. Choose a category
                and add further information below, then submit.');
            }
        }
        $vars{text_located} = $q->p(_('You have located the problem at the point marked with a purple pin on the map.
If this is not the correct location, simply click on the map again. '));
    }
    $vars{page_heading} = $q->h1(_('Reporting a problem'));

    if ($details eq 'all') {
        my $council_list = join('</strong> or <strong>', map { $areas_info->{$_}->{name} } @$all_councils);
        if ($q->{site} eq 'emptyhomes'){
            $vars{text_help} = '<p>' . sprintf(_('All the information you provide here will be sent to <strong>%s</strong>.
On the site, we will show the subject and details of the problem, plus your
name if you give us permission.'), $council_list);
        } else {
            $vars{text_help} = '<p>' . sprintf(_('All the information you provide here will be sent to <strong>%s</strong>.
The subject and details of the problem will be public, plus your
name if you give us permission.'), $council_list);
        }
        $vars{text_help} .= '<input type="hidden" name="council" value="' . join(',',@$all_councils) . '">';
    } elsif ($details eq 'some') {
        my $e = Cobrand::contact_email($cobrand);
        my %councils = map { $_ => 1 } @councils;
        my @missing;
        foreach (@$all_councils) {
            push @missing, $_ unless $councils{$_};
        }
        my $n = @missing;
        my $list = join(' or ', map { $areas_info->{$_}->{name} } @missing);
        $vars{text_help} = '<p>All the information you provide here will be sent to <strong>'
            . join('</strong> or <strong>', map { $areas_info->{$_}->{name} } @councils)
            . '</strong>. The subject and details of the problem will be public, plus your
name if you give us permission.';
        $vars{text_help} .= ' We do <strong>not</strong> yet have details for the other council';
        $vars{text_help} .= ($n>1) ? 's that cover' : ' that covers';
        $vars{text_help} .= " this location. You can help us by finding a contact email address for local
problems for $list and emailing it to us at <a href='mailto:$e'>$e</a>.";
        $vars{text_help} .= '<input type="hidden" name="council" value="' . join(',', @councils)
            . '|' . join(',', @missing) . '">';
    } else {
        my $e = Cobrand::contact_email($cobrand);
        my $list = join(' or ', map { $areas_info->{$_}->{name} } @$all_councils);
        my $n = @$all_councils;
        if ($q->{site} ne 'emptyhomes') {
            $vars{text_help} = '<p>We do not yet have details for the council';
            $vars{text_help} .= ($n>1) ? 's that cover' : ' that covers';
            $vars{text_help} .= " this location. If you submit a problem here the subject and details 
of the problem will be public, but the problem will <strong>not</strong> be reported to the council.
You can help us by finding a contact email address for local
problems for $list and emailing it to us at <a href='mailto:$e'>$e</a>.";
        } else {
            $vars{text_help} = _("<p>We do not yet have details for the council that covers
this location. If you submit a report here it will be left on the site, but
not reported to the council &ndash; please still leave your report, so that
we can show to the council the activity in their area.");
        }
        $vars{text_help} .= '<input type="hidden" name="council" value="-1">';
    }

    if ($input{skipped}) {
        $vars{text_help} .= $q->p(_('Please fill in the form below with details of the problem,
and describe the location as precisely as possible in the details box.'));
    } elsif ($q->{site} eq 'scambs') {
        $vars{text_help} .= '<p>Please fill in details of the problem below. We won\'t be able
to help unless you leave as much detail as you can, so please describe the exact location of
the problem (e.g. on a wall), what it is, how long it has been there, a description (and a
photo of the problem if you have one), etc.';
    } elsif ($q->{site} eq 'emptyhomes') {
        $vars{text_help} .= $q->p(_(<<EOF));
Please fill in details of the empty property below, saying what type of
property it is e.g. an empty home, block of flats, office etc. Tell us
something about its condition and any other information you feel is relevant.
There is no need for you to give the exact address. Please be polite, concise
and to the point; writing your message entirely in block capitals makes it hard
to read, as does a lack of punctuation.
EOF
    } elsif ($details ne 'none') {
        $vars{text_help} .= $q->p(_('Please fill in details of the problem below. The council won\'t be able
to help unless you leave as much detail as you can, so please describe the exact location of
the problem (e.g. on a wall), what it is, how long it has been there, a description (and a
photo of the problem if you have one), etc.'));
    } else {
        $vars{text_help} .= $q->p(_('Please fill in details of the problem below.'));
    }

    $vars{text_help} .= '
<input type="hidden" name="easting" value="' . $easting . '">
<input type="hidden" name="northing" value="' . $northing . '">';

    if (@errors) {
        $vars{errors} = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }

    my $anon = ($input{anonymous}) ? ' checked' : ($input{title} ? '' : ' checked');

    $vars{form_heading} = $q->h2(_('Empty property details form')) if $q->{site} eq 'emptyhomes';
    $vars{subject_label} = _('Subject:');
    $vars{detail_label} = _('Details:');
    $vars{photo_label} = _('Photo:');
    $vars{name_label} = _('Name:');
    $vars{email_label} = _('Email:');
    $vars{phone_label} = _('Phone:');
    $vars{optional} = _('(optional)');
    if ($q->{site} eq 'emptyhomes') {
        $vars{anonymous} = _('Can we show your name on the site?');
    } else {
        $vars{anonymous} = _('Can we show your name publicly?');
    }
    $vars{anonymous2} = _('(we never show your email address or phone number)');

    my $partial_id;
    if (my $token = $input{partial}) {
        $partial_id = mySociety::AuthToken::retrieve('partial', $token);
        if ($partial_id) {
            $vars{partial_field} = '<input type="hidden" name="partial" value="' . $token . '">';
        }
    }
    my $photo_input = ''; 
    if ($allow_photo_upload) {
         $photo_input = <<EOF;
<div id="fileupload_normalUI">
<label for="form_photo">$vars{photo_label}</label>
<input type="file" name="photo" id="form_photo">
</div>
EOF
    }
    if ($partial_id && $q->param('has_photo')) {
        $vars{photo_field} = "<p>The photo you uploaded was:</p> <p><img src='/photo?id=$partial_id'></p>";
    } else {
        $vars{photo_field} = $photo_input;
    }

    if ($q->{site} eq 'scambs') {
        $vars{text_notes} = <<EOF;
<p>Please note:</p>
<ul>
<li>Please be polite, concise and to the point.</li>
<li>Please do not be abusive.</li>
<li>Writing your message entirely in block capitals makes it hard to read,
as does a lack of punctuation.</li>
</ul>
EOF
    } elsif ($q->{site} ne 'emptyhomes') {
        $vars{text_notes} = <<EOF;
<p>Please note:</p>
<ul>
<li>We will only use your personal
information in accordance with our <a href="/faq#privacy">privacy policy.</a></li>
<li>Please be polite, concise and to the point.</li>
<li>Please do not be abusive &mdash; abusing your council devalues the service for all users.</li>
<li>Writing your message entirely in block capitals makes it hard to read,
as does a lack of punctuation.</li>
<li>Remember that FixMyStreet is primarily for reporting physical
problems that can be fixed. If your problem is not appropriate for
submission via this site remember that you can contact your council
directly using their own website.</li>
</ul>
EOF
    }

    %vars = (%vars, 
        category => $category,
        map_end => Page::display_map_end(1),
        url_home => Cobrand::url($cobrand, '/', $q),
        submit_button => _('Submit')
    );
    return (Page::template_include('report-form', $q, Page::template_root($q), %vars));
}

sub display_location {
    my ($q, @errors) = @_;
    my @vars = qw(pc x y all_pins no_pins);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    if ($input{y} =~ /favicon/) {
        my $base = mySociety::Config::get('BASE_URL');
        print $q->redirect(-location => $base . '/favicon.ico', -status => 301);
        return '';
    }
    my($error, $easting, $northing);
    (my $x) = $input{x} =~ /^(\d+)/; $x ||= 0;
    (my $y) = $input{y} =~ /^(\d+)/; $y ||= 0;
    return front_page($q, @errors) unless $x || $y || $input{pc};
    if (!$x && !$y) {
        try {
            ($x, $y, $easting, $northing, $error) = Page::geocode($input{pc}, $q);
        } catch Error::Simple with {
            $error = shift;
        };
    }
    return Page::geocode_choice($error, '/', $q) if (ref($error) eq 'ARRAY');
    return front_page($q, $error) if ($error);

    my $cobrand = Page::get_cobrand($q);

    # Deal with pin hiding/age
    my ($hide_link, $hide_text, $all_link, $all_text, $interval);
    if ($input{all_pins}) {
        $all_link = NewURL($q, -retain=>1, no_pins=>undef, all_pins=>undef);
        $all_text = _('Hide stale reports');
    } else {
        $all_link = NewURL($q, -retain=>1, no_pins=>undef, all_pins=>1);
        $all_text = _('Include stale reports');
        $interval = '6 months';
    }
    my ($pins, $on_map, $around_map, $dist) = Page::map_pins($q, $x, $y, $x, $y, $interval);
    if ($input{no_pins}) {
        $hide_link = NewURL($q, -retain=>1, no_pins=>undef);
        $hide_text = _('Show pins');
        $pins = '';
    } else {
        $hide_link = NewURL($q, -retain=>1, no_pins=>1);
        $hide_text = _('Hide pins');
    }
    my $map_links = "<p id='sub_map_links'><a id='hide_pins_link' href='$hide_link'>$hide_text</a> | <a id='all_pins_link' href='$all_link'>$all_text</a></p> <input type='hidden' id='all_pins' name='all_pins' value='$input_h{all_pins}'>";
   
    my $on_list = '';
    foreach (@$on_map) {
        my $report_url = NewURL($q, -retain => 1, -url => '/report/' . $_->{id}, pc => undef, x => undef, 'y' => undef);
        $report_url = Cobrand::url($cobrand, $report_url, $q);  
        $on_list .= '<li><a href="' . $report_url . '">';
        $on_list .= $_->{title};
        $on_list .= '</a>';
        $on_list .= ' <small>' . _('(fixed)') . '</small>' if $_->{state} eq 'fixed';
        $on_list .= '</li>';
    }
    $on_list = $q->li(_('No problems have been reported yet.'))
        unless $on_list;

    my $around_list = '';
    foreach (@$around_map) {
        my $report_url = Cobrand::url($cobrand, NewURL($q, -retain => 1, -url => '/report/' . $_->{id}, pc => undef, x => undef, 'y' => undef), $q);  
        $around_list .= '<li><a href="' . $report_url . '">';
        my $dist = int($_->{distance}/100+0.5);
        $dist = $dist / 10;
        $around_list .= $_->{title} . ' <small>(' . $dist . 'km)</small>';
        $around_list .= '</a>';
        $around_list .= ' <small>' . _('(fixed)') . '</small>' if $_->{state} eq 'fixed';
        $around_list .= '</li>';
    }
    $around_list = $q->li(_('No problems found.'))
        unless $around_list;

    my $url_skip = NewURL($q, -retain=>1, 'submit_map'=>1, skipped=>1);
    my %vars = (
        'map' => Page::display_map($q, x => $x, 'y' => $y, type => 1, pins => $pins, post => $map_links ),
        map_end => Page::display_map_end(1),
        url_home => Cobrand::url($cobrand, '/', $q),
        url_rss => Cobrand::url($cobrand, NewURL($q, -retain => 1, -url=> "/rss/$x,$y", pc => undef, x => undef, 'y' => undef), $q),
        url_email => Cobrand::url($cobrand, NewURL($q, -retain => 1, pc => undef, -url=>'/alert', x=>$x, 'y'=>$y, feed=>"local:$x:$y"), $q),
        url_skip => $url_skip,
        email_me => _('Email me new local problems'),
        rss_alt => _('RSS feed'),
        rss_title => _('RSS feed of recent local problems'),
        reports_on_around => $on_list,
        reports_nearby => $around_list,
        heading_problems => _('Problems in this area'),
        heading_on_around => _('Reports on and around the map'),
        heading_closest => sprintf(_('Closest nearby problems <small>(within&nbsp;%skm)</small>'), $dist),
        distance => $dist,
        errors => @errors ? '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>' : '',
        text_to_report => _('To report a problem, simply
        <strong>click on the map</strong> at the correct location.'),
        text_skip => sprintf(_("<small>If you cannot see the map, <a href='%s' rel='nofollow'>skip this
        step</a>.</small>"), $url_skip),
    );

    my %params = (
        rss => [ _('Recent local problems, FixMyStreet'), "/rss/$x,$y" ]
    );

    return (Page::template_include('map', $q, Page::template_root($q), %vars), %params);
}

sub display_problem {
    my ($q, $errors, $field_errors) = @_;
    my @errors = @$errors;
    my %field_errors = %{$field_errors};
    my $cobrand = Page::get_cobrand($q);
    push @errors, _('There were problems with your update. Please see below.') if (scalar keys %field_errors && $cobrand ne 'emptyhomes');

    my @vars = qw(id name rznvy update fixed add_alert upload_fileid x y submit_update);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    ($input{x}) = $input{x} =~ /^(\d+)/; $input{x} ||= 0;
    ($input{y}) = $input{y} =~ /^(\d+)/; $input{y} ||= 0;
    my $base = Cobrand::base_url($cobrand);

    # Some council with bad email software
    if ($input{id} =~ /^3D\d+$/) {
        $input{id} =~ s/^3D//;
        print $q->redirect(-location => $base . '/report/' . $input{id}, -status => 301);
        return '';
    }

    # Redirect old /?id=NNN URLs to /report/NNN
    if (!@errors && !scalar keys %field_errors && $ENV{SCRIPT_URL} eq '/') {
        print $q->redirect(-location => $base . '/report/' . $input{id}, -status => 301);
        return '';
    }

    # Get all information from database
    return display_location($q, _('Unknown problem ID')) if !$input{id} || $input{id} =~ /\D/;
    my $problem = Problems::fetch_problem($input{id});
    return display_location($q, _('Unknown problem ID')) unless $problem;
    return front_page($q, _('That report has been removed from FixMyStreet.')) if $problem->{state} eq 'hidden';
    my ($x, $y, $x_tile, $y_tile, $px, $py) = Page::os_to_px_with_adjust($q, $problem->{easting}, $problem->{northing}, $input{x}, $input{y});

    # Try and have pin near centre of map
    if (!$input{x} && $x - $x_tile < 0.5) {
        $x_tile -= 1;
        $px = Page::os_to_px($problem->{easting}, $x_tile);
    }
    if (!$input{y} && $y - $y_tile < 0.5) {
        $y_tile -= 1;
        $py = Page::os_to_px($problem->{northing}, $y_tile, 1);
    }

    my %vars;
    my $extra_data = Cobrand::extra_data($cobrand, $q);
    my $google_link = Cobrand::base_url_for_emails($cobrand, $extra_data)
        . '/report/' . $problem->{id};
    my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($problem->{easting}, $problem->{northing}, 'G');
    my $map_links = "<p id='sub_map_links'><a href='http://maps.google.co.uk/maps?output=embed&amp;z=16&amp;q="
        . URI::Escape::uri_escape_utf8($problem->{title} . ' - ' . $google_link) . "\@$lat,$lon'>View on Google Maps</a></p>";
    my $pins = Page::display_pin($q, $px, $py, 'blue');
    $vars{map_start} = Page::display_map($q, x => $x_tile, 'y' => $y_tile, type => 0,
        pins => $pins, px => $px, py => $py, post => $map_links );

    if ($q->{site} ne 'emptyhomes' && $problem->{state} eq 'confirmed' && $problem->{duration} > 8*7*24*60*60) {
        $vars{banner} = $q->p({id => 'unknown'}, _('This problem is old and of unknown status.'))
    }
    if ($problem->{state} eq 'fixed') {
        $vars{banner} = $q->p({id => 'fixed'}, _('This problem has been fixed') . '.')
    }

    $vars{problem_title} = ent($problem->{title});
    $vars{problem_meta} = Page::display_problem_meta_line($q, $problem);
    $vars{problem_detail} = Page::display_problem_detail($problem);
    $vars{problem_photo} = Page::display_problem_photo($q, $problem);

    my $contact_url = Cobrand::url($cobrand, NewURL($q, -retain => 1, pc => undef, -url=>'/contact?id=' . $input{id}), $q);
    $vars{unsuitable} = $q->a({rel => 'nofollow', href => $contact_url}, _('Offensive? Unsuitable? Tell us'));

    my $back = Cobrand::url($cobrand, NewURL($q, -url => '/', 'x' => $x_tile, 'y' => $y_tile, -retain => 1, pc => undef, id => undef ), $q);
    $vars{more_problems} = '<a href="' . $back . '">' . _('More problems nearby') . '</a>';

    $vars{url_home} = Cobrand::url($cobrand, '/', $q),

    $vars{alert_link} = Cobrand::url($cobrand, NewURL($q, -url => '/alert?type=updates;id='.$input_h{id}, -retain => 1, pc => undef ), $q);
    $vars{alert_text} = _('Email me updates');
    $vars{email_label} = _('Email:');
    $vars{subscribe} = _('Subscribe');
    $vars{blurb} = _('Receive email when updates are left on this problem');
    $vars{cobrand_form_elements1} = Cobrand::form_elements($cobrand, 'alerts', $q);
    $vars{form_alert_action} = Cobrand::url($cobrand, '/alert', $q);
    $vars{rss_url} = Cobrand::url($cobrand,  NewURL($q, -retain=>1, -url => '/rss/'.$input_h{id}, pc => undef, id => undef), $q);
    $vars{rss_title} = _('RSS feed');
    $vars{rss_alt} = _('RSS feed of updates to this problem');

    $vars{problem_updates} = Page::display_problem_updates($input{id}, $q);
    $vars{update_heading} = $q->h2(_('Provide an update'));
    $vars{update_blurb} = $q->p($q->small(_('Please note that updates are not sent to the council. If you leave your name it will be public. Your information will only be used in accordance with our <a href="/faq#privacy">privacy policy</a>')))
        unless $q->{site} eq 'emptyhomes'; # No council blurb

    if (@errors) {
        $vars{errors} = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    
    $vars{field_errors} = \%field_errors;

    my $fixed = ($input{fixed}) ? ' checked' : '';
    $vars{add_alert_checked} = ($input{add_alert} || !$input{submit_update}) ? ' checked' : '';
    $vars{fixedline_box} = $problem->{state} eq 'fixed' ? ''
        : qq{<input type="checkbox" name="fixed" id="form_fixed" value="1"$fixed>};
    $vars{fixedline_label} = $problem->{state} eq 'fixed' ? ''
        : qq{<label for="form_fixed">} . _('This problem has been fixed') . qq{</label>};
    $vars{name_label} = _('Name:');
    $vars{update_label} = _('Update:');
    $vars{alert_label} = _('Alert me to future updates');
    $vars{post_label} = _('Post');
    $vars{cobrand_form_elements} = Cobrand::form_elements($cobrand, 'updateForm', $q);
    my $allow_photo_upload = Cobrand::allow_photo_upload($cobrand);
    if ($allow_photo_upload) {
        my $photo_label = _('Photo:');
        $vars{photo_element} = <<EOF;
<div id="fileupload_normalUI">
<label for="form_photo">$photo_label</label>
<input type="file" name="photo" id="form_photo">
</div>
EOF
    }
 
    $vars{form_action} = Cobrand::url($cobrand, '/', $q);
    if ($allow_photo_upload) {
        $vars{enctype} = ' enctype="multipart/form-data"';
    }
    $vars{map_end} = Page::display_map_end(0);
    my %params = (
        rss => [ _('Updates to this problem, FixMyStreet'), "/rss/$input_h{id}" ],
        title => $problem->{title}
    );

    $vars{input_h} = \%input_h;
    my $page = Page::template_include('problem', $q, Page::template_root($q), %vars);
    return ($page, %params);
}

