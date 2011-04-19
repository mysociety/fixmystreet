#!/usr/bin/perl -w -I../perllib
#
# index.cgi:
# Main code for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org

use strict;
use Standard;
use Utils;
use Encode;
use Error qw(:try);
use File::Slurp;
use CGI::Carp;
use POSIX qw(strcoll);
use URI::Escape;

# use Carp::Always;

use CrossSell;
use FixMyStreet::Geocode;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(select_all);
use mySociety::EmailUtil;
use mySociety::Locale;
use mySociety::MaPit;
use mySociety::PostcodeUtil;
use mySociety::Random;
use mySociety::VotingArea;
use mySociety::Web qw(ent NewURL);
use Utils;

sub debug (@) {
    return;
    my ( $format, @args ) = @_;
    warn sprintf $format, map { defined $_ ? $_ : 'undef' } @args;
}

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
                "select latitude, longitude, name, email, title, (photo is not null) as has_photo, phone, detail
                    from problem where id=? and state='partial'", {}, $id);
            if (@row) {
                $q->param('anonymous', 1);
                $q->param('submit_map', 1);
                $q->param('latitude', $row[0]);
                $q->param('longitude', $row[1]);
                $q->param('name', $row[2]);
                $q->param('email', $row[3]);
                $q->param('title', $row[4]);
                $q->param('has_photo', $row[5]);
                $q->param('phone', $row[6]);
                $q->param('detail', $row[7]);
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
        ($out, %params) = submit_problem($q);
    } elsif ($q->param('submit_update')) {
        $params{title} = _('Submitting your update');
        ($out, %params) = submit_update($q);
    } elsif ($q->param('submit_map')) {
        ($out, %params) = display_form($q, [], {});
        $params{title} = _('Reporting a problem');
    } elsif ($q->param('id')) {
        ($out, %params) = display_problem($q, [], {});
        $params{title} .= ' - ' . _('Viewing a problem');
    } elsif ($q->param('pc') || ($q->param('x') && $q->param('y')) || ($q->param('lat') || $q->param('lon'))) {
        ($out, %params) = display_location($q);
        $params{title} = _('Viewing a location');
    } elsif ($q->param('e') && $q->param('n')) {
        ($out, %params) = redirect_from_osgb_to_wgs84($q);
    } else {
        ($out, %params) = front_page($q);
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
    my ($q, $error, $status_code) = @_;
    my $pc_h = ent($q->param('pc') || '');

    # Look up various cobrand things
    my $cobrand = Page::get_cobrand($q);
    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'postcodeForm', $q);
    my $form_action = Cobrand::url($cobrand, '/', $q);
    my $question = Cobrand::enter_postcode_text($cobrand, $q);
    $question = _("Enter a nearby GB postcode, or street name and area")
        unless $question;
    my %params = ('context' => 'front-page');
    $params{status_code} = $status_code if $status_code;
    my %vars = (
        error => $error || '',
        pc_h => $pc_h, 
        cobrand_form_elements => $cobrand_form_elements,
        form_action => $form_action,
        question => "$question:",
    );
    my $cobrand_front_page = Page::template_include('front-page', $q, Page::template_root($q), %vars);
    return ($cobrand_front_page, %params) if $cobrand_front_page;

    my $out = '<p id="expl"><strong>' . _('Report, view, or discuss local problems') . '</strong>';
    my $subhead = _('(like graffiti, fly tipping, broken paving slabs, or street lighting)');
    $subhead = '(like graffiti, fly tipping, or broken paving slabs)'
        if $q->{site} eq 'southampton';
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
<label for="pc">$question:</label>
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
             $out .= '</a></li>';
         }
         $out .= '</ul>' if @$probs;
    $out .= '</div>';
    }   

    return ($out, %params);
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

    my $out = Page::send_confirmation_email($q, $input{rznvy}, $input{name}, 'update', %h);
    return $out;
}

sub submit_problem {
    my $q = shift;
    my @vars = qw(council title detail name email phone pc skipped anonymous category partial upload_fileid latitude longitude);
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

    my $cobrand = Page::get_cobrand($q);

    # If in UK and we have a lat,lon coocdinate check it is in UK
    if ( $input{latitude} && mySociety::Config::get('COUNTRY') eq 'GB' ) {
        try {
            Utils::convert_latlon_to_en( $input{latitude}, $input{longitude} );
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
    if ($input{category} && $input{category} eq _('-- Pick a category --')) {
        $field_errors{category} = _('Please choose a category');
        $input{category} = '';
    } elsif ($input{category} && $input{category} eq _('-- Pick a property type --')) {
        $field_errors{category} = _('Please choose a property type');
        $input{category} = '';
    }

    return display_form($q, \@errors, \%field_errors) if (@errors || scalar keys %field_errors); # Short circuit

    my $areas;
    if (defined $input{latitude} && defined $input{longitude}) {
        my $mapit_query = "4326/$input{longitude},$input{latitude}";
        $areas = mySociety::MaPit::call( 'point', $mapit_query );
        if ($input{council} =~ /^[\d,]+(\|[\d,]+)?$/) {
            my $no_details = $1 || '';
            my @area_types = Cobrand::area_types($cobrand);
            my %va = map { $_ => 1 } @area_types;
            my %councils;
            my $london = 0;
            foreach (keys %$areas) {
                $councils{$_} = 1 if $va{$areas->{$_}->{type}};
                $london = 1 if $areas->{$_}->{type} eq 'LBO' && $q->{site} ne 'emptyhomes';
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
                @input_councils = split(/,/, $input{council});
            }

            # Check category here, won't be present if council is -1
            my @valid_councils = @input_councils;
            if ($london) {
                $field_errors{category} = _('Please choose a category')
                    unless Utils::london_categories()->{$input{category}};
                @valid_councils = $input{council};
            } elsif ($input{category} && $q->{site} ne 'emptyhomes') {
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
    } elsif (defined $input{latitude} || defined $input{longitude}) {
        push(@errors, _('Somehow, you only have one co-ordinate. Please try again.'));
    } else {
        push(@errors, _("You haven't specified any sort of co-ordinates. Please try again."));
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
    my $cobrand_data = Cobrand::extra_problem_data($cobrand, $q);
    if (my $token = $input{partial}) {
        my $id = mySociety::AuthToken::retrieve('partial', $token);
        if ($id) {
            dbh()->do("update problem set postcode=?, latitude=?, longitude=?, title=?, detail=?,
                name=?, email=?, phone=?, state='confirmed', council=?, used_map='t',
                anonymous=?, category=?, areas=?, cobrand=?, cobrand_data=?, confirmed=ms_current_timestamp(),
                lastupdate=ms_current_timestamp() where id=?", {}, $input{pc}, $input{latitude}, $input{longitude},
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
            (id, postcode, latitude, longitude, title, detail, name,
             email, phone, photo, state, council, used_map, anonymous, category, areas, lang, cobrand, cobrand_data)
            values
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unconfirmed', ?, ?, ?, ?, ?, ?, ?, ?)", 10,
            $id, $input{pc}, $input{latitude}, $input{longitude}, $input{title},
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

        $out = Page::send_confirmation_email($q, $input{email}, $input{name}, 'problem', %h);

    }
    return $out;
}

sub display_form {
    my ($q, $errors, $field_errors) = @_;
    my @errors = @$errors;
    my %field_errors = %{$field_errors};
    my $cobrand = Page::get_cobrand($q);
    push @errors, _('There were problems with your report. Please see below.') if (scalar keys %field_errors);

    my ($pin_x, $pin_y, $pin_tile_x, $pin_tile_y) = (0,0,0,0);
    my @vars = qw(title detail name email phone pc latitude longitude x y skipped council anonymous partial upload_fileid);

    my %input   = ();
    my %input_h = ();

    foreach my $key (@vars) {
        my $val = $q->param($key);
        $input{$key} = defined($val) ? $val : '';   # '0' is valid for longitude
        $input_h{$key} = ent( $input{$key} );
    }

    # Convert lat/lon to easting/northing if given
    # if ($input{lat}) {
    #     try {
    #         ($input{easting}, $input{northing}) = mySociety::GeoUtil::wgs84_to_national_grid($input{lat}, $input{lon}, 'G');
    #         $input_h{easting} = $input{easting};
    #         $input_h{northing} = $input{northing};
    #     } catch Error::Simple with { 
    #         my $e = shift;
    #         push @errors, "We had a problem with the supplied co-ordinates - outside the UK?";
    #     };
    # }

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
            || ($input{latitude} && $input{longitude})
            || ($input{skipped} && $input{pc})
            || ($input{partial} && $input{pc});

    # Work out some co-ordinates from whatever we've got
    my ($latitude, $longitude);
    if ($input{skipped}) {
        # Map is being skipped
        if ( length $input{latitude} && length $input{longitude} ) {
            $latitude  = $input{latitude};
            $longitude = $input{longitude};
        } else {
            my ( $lat, $lon, $error ) =
              FixMyStreet::Geocode::lookup( $input{pc}, $q );
            $latitude  = $lat;
            $longitude = $lon;
        }
    } elsif ($pin_x && $pin_y) {

        # Map was clicked on (tilma, or non-JS OpenLayers, for example)
        ($latitude, $longitude) = FixMyStreet::Map::click_to_wgs84($q, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y);

    } elsif ( $input{partial} && $input{pc} && !length $input{latitude} && !length $input{longitude} ) {
        my $error;
        try {
            ($latitude, $longitude, $error) = FixMyStreet::Geocode::lookup($input{pc}, $q);
        } catch Error::Simple with {
            $error = shift;
        };
        return FixMyStreet::Geocode::list_choices($error, '/', $q) if ref($error) eq 'ARRAY';
        return front_page($q, $error) if $error;
    } else {
        # Normal form submission
        $latitude  = $input_h{latitude};
        $longitude = $input_h{longitude};
    }

    # Shrink, as don't need accuracy plus we want them as English strings
    ($latitude, $longitude) = map { Utils::truncate_coordinate($_) } ( $latitude, $longitude );

    # Look up councils and do checks for the point we've got
    my @area_types = Cobrand::area_types($cobrand);
    # XXX: I think we want in_gb_locale around the next line, needs testing
    my $all_councils = mySociety::MaPit::call('point', "4326/$longitude,$latitude", type => \@area_types);

    # Let cobrand do a check
    my ($success, $error_msg) = Cobrand::council_check($cobrand, { all_councils => $all_councils }, $q, 'submit_problem');
    if (!$success) {
        return front_page($q, $error_msg);
    }

    if (mySociety::Config::get('COUNTRY') eq 'GB') {
        # Ipswich & St Edmundsbury are responsible for everything in their areas, not Suffolk
        delete $all_councils->{2241} if $all_councils->{2446} || $all_councils->{2443};

        # Norwich is responsible for everything in its areas, not Norfolk
        delete $all_councils->{2233} if $all_councils->{2391};

    } elsif (mySociety::Config::get('COUNTRY') eq 'NO') {

        # Oslo is both a kommune and a fylke, we only want to show it once
        delete $all_councils->{301} if $all_councils->{3};

    }

    return display_location($q, _('That spot does not appear to be covered by a council.
If you have tried to report an issue past the shoreline, for example,
please specify the closest point on land.')) unless %$all_councils;

    # Look up categories for this council or councils
    my $category = '';
    my (%council_ok, @categories);
    my $categories = select_all("select area_id, category from contacts
        where deleted='f' and area_id in (" . join(',', keys %$all_councils) . ')');
    my $first_council = (values %$all_councils)[0];
    if ($q->{site} eq 'emptyhomes') {
        foreach (@$categories) {
            $council_ok{$_->{area_id}} = 1;
        }
        @categories = (_('-- Pick a property type --'), _('Empty house or bungalow'),
            _('Empty flat or maisonette'), _('Whole block of empty flats'),
            _('Empty office or other commercial'), _('Empty pub or bar'),
            _('Empty public building - school, hospital, etc.'));
        $category = _('Property type:');
    } elsif ($first_council->{type} eq 'LBO') {
        $council_ok{$first_council->{id}} = 1;
        @categories = (_('-- Pick a category --'), sort keys %{ Utils::london_categories() } );
        $category = _('Category:');
    } else {
        @$categories = sort { strcoll($a->{category}, $b->{category}) } @$categories;
        foreach (@$categories) {
            $council_ok{$_->{area_id}} = 1;
            next if $_->{category} eq _('Other');
            next if $q->{site} eq 'southampton' && $_->{category} eq 'Street lighting';
            push @categories, $_->{category};
        }
        if ($q->{site} eq 'scambs') {
            @categories = Page::scambs_categories();
        }
        if (@categories) {
            @categories = (_('-- Pick a category --'), @categories, _('Other'));
            $category = _('Category:');
        }
    }
    $category = $q->label({'for'=>'form_category'}, $category) .
        $q->popup_menu(-name=>'category', -values=>\@categories, -id=>'form_category',
            -attributes=>{id=>'form_category'})
        if $category;

    # Work out what help text to show, depending on whether we have council details
    my @councils = keys %council_ok;
    my $details;
    if (@councils == scalar keys %$all_councils) {
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
<input type="hidden" name="latitude" value="$latitude">
<input type="hidden" name="longitude" value="$longitude">
<input type="hidden" name="pc" value="$input_h{pc}">
<input type="hidden" name="skipped" value="1">
$cobrand_form_elements
<div id="skipped-map">
EOF
    } else {
        my $type;
        if ($allow_photo_upload) {
            $type = 2;
        } else {
            $type = 1;
        }
        $vars{form_start} = FixMyStreet::Map::display_map($q,
            latitude => $latitude, longitude => $longitude,
            type => $type,
            pins => [ [ $latitude, $longitude, 'purple' ] ],
        );
        my $partial_id;
        if (my $token = $input{partial}) {
            $partial_id = mySociety::AuthToken::retrieve('partial', $token);
            if ($partial_id) {
                $vars{form_start} .=
                    $q->p({ id => 'unknown' },
                          _('Please note your report has <strong>not yet been sent</strong>. Choose a category and add further information below, then submit.'));
            }
        }
        $vars{text_located} = $q->p(_('You have located the problem at the point marked with a purple pin on the map.
If this is not the correct location, simply click on the map again. '));
    }
    $vars{page_heading} = $q->h1(_('Reporting a problem'));

    if ($details eq 'all') {
        my $council_list = join('</strong>' . _(' or ') . '<strong>', map { $_->{name} } values %$all_councils);
        if ($q->{site} eq 'emptyhomes') {
            $vars{text_help} = '<p>' . sprintf(_('All the information you provide here will be sent to <strong>%s</strong>.
On the site, we will show the subject and details of the problem, plus your
name if you give us permission.'), $council_list);
        } elsif ($first_council->{type} eq 'LBO') {
            $vars{text_help} = '<p>' . sprintf(_('All the information you
            provide here will be sent to <strong>%s</strong> or a relevant
            local body such as TfL, via the London Report-It system. The
            subject and details of the problem will be public, plus your name
            if you give us permission.'), $council_list);
        } else {
            $vars{text_help} = '<p>' . sprintf(_('All the information you provide here will be sent to <strong>%s</strong>.
The subject and details of the problem will be public, plus your
name if you give us permission.'), $council_list);
        }
        $vars{text_help} .= '<input type="hidden" name="council" value="' . join(',', keys %$all_councils) . '">';
    } elsif ($details eq 'some') {
        my $e = Cobrand::contact_email($cobrand);
        my %councils = map { $_ => 1 } @councils;
        my @missing;
        foreach (keys %$all_councils) {
            push @missing, $_ unless $councils{$_};
        }
        my $n = @missing;
        my $list = join(_(' or '), map { $all_councils->{$_}->{name} } @missing);
        $vars{text_help} = '<p>' . _('All the information you provide here will be sent to') . ' <strong>'
            . join('</strong>' . _(' or ') . '<strong>', map { $all_councils->{$_}->{name} } @councils)
            . '</strong>. ';
        $vars{text_help} .= _('The subject and details of the problem will be public, plus your name if you give us permission.');
        $vars{text_help} .= ' ' . mySociety::Locale::nget(
            'We do <strong>not</strong> yet have details for the other council that covers this location.',
            'We do <strong>not</strong> yet have details for the other councils that cover this location.',
            $n
        );
        $vars{text_help} .=  ' ' . sprintf(_("You can help us by finding a contact email address for local problems for %s and emailing it to us at <a href='mailto:%s'>%s</a>."), $list, $e, $e);
        $vars{text_help} .= '<input type="hidden" name="council" value="' . join(',', @councils)
            . '|' . join(',', @missing) . '">';
    } else {
        my $e = Cobrand::contact_email($cobrand);
        my $list = join(_(' or '), map { $_->{name} } values %$all_councils);
        my $n = scalar keys %$all_councils;
        if ($q->{site} ne 'emptyhomes') {
            $vars{text_help} = '<p>';
            $vars{text_help} .= mySociety::Locale::nget(
                'We do not yet have details for the council that covers this location.',
                'We do not yet have details for the councils that cover this location.',
                $n
            );
            $vars{text_help} .= _("If you submit a problem here the subject and details of the problem will be public, but the problem will <strong>not</strong> be reported to the council.");
            $vars{text_help} .= sprintf(_("You can help us by finding a contact email address for local problems for %s and emailing it to us at <a href='mailto:%s'>%s</a>."), $list, $e, $e);
        } else {
            $vars{text_help} = '<p>'
              . _('We do not yet have details for the council that covers this location.')
              . ' '
              . _("If you submit a report here it will be left on the site, but not reported to the council &ndash; please still leave your report, so that we can show to the council the activity in their area.");
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

    if (@errors) {
        $vars{errors} = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }

    $vars{anon} = ($input{anonymous}) ? ' checked' : ($input{title} ? '' : ' checked');

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
            $vars{partial_field} .= '<input type="hidden" name="has_photo" value="' . $q->param('has_photo') . '">';
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

    if ($q->{site} ne 'emptyhomes') {
        $vars{text_notes} =
            $q->p(_("Please note:")) .
            "<ul>" .
            $q->li(_("We will only use your personal information in accordance with our <a href=\"/faq#privacy\">privacy policy.</a>")) .
            $q->li(_("Please be polite, concise and to the point.")) .
            $q->li(_("Please do not be abusive &mdash; abusing your council devalues the service for all users.")) .
            $q->li(_("Writing your message entirely in block capitals makes it hard to read, as does a lack of punctuation.")) .
            $q->li(_("Remember that FixMyStreet is primarily for reporting physical problems that can be fixed. If your problem is not appropriate for submission via this site remember that you can contact your council directly using their own website."));
        $vars{text_notes} .=
            $q->li(_("FixMyStreet and the Guardian are providing this service in partnership in <a href=\"/faq#privacy\">certain cities</a>. In those cities, both have access to any information submitted, including names and email addresses, and will use it only to ensure the smooth running of the service, in accordance with their privacy policies."))
            if mySociety::Config::get('COUNTRY') eq 'GB';
        $vars{text_notes} .= "</ul>\n";
    }

    %vars = (%vars, 
        category => $category,
        map_end => FixMyStreet::Map::display_map_end(1),
        url_home => Cobrand::url($cobrand, '/', $q),
        submit_button => _('Submit')
    );
    return (Page::template_include('report-form', $q, Page::template_root($q), %vars),
        robots => 'noindex,nofollow',
        js => FixMyStreet::Map::header_js(),
    );
}

# redirect from osgb
sub redirect_from_osgb_to_wgs84 {
    my ($q) = @_;

    my $e = $q->param('e');
    my $n = $q->param('n');

    my ( $lat, $lon ) = Utils::convert_en_to_latlon_truncated( $e, $n );

    my $lat_lon_url = NewURL(
        $q,
        -retain => 1,
        e       => undef,
        n       => undef,
        lat     => $lat,
        lon     => $lon
    );

    print $q->redirect(
        -location => $lat_lon_url,
        -status   => 301,            # permanent
    );

    return '';
}

sub display_location {
    my ($q, @errors) = @_;
    my $cobrand = Page::get_cobrand($q);
    my @vars = qw(pc x y lat lon all_pins no_pins);

    my %input   = ();
    my %input_h = ();

    foreach my $key (@vars) {
        my $val = $q->param($key);
        $input{$key} = defined($val) ? $val : '';   # '0' is valid for longitude
        $input_h{$key} = ent( $input{$key} );
    }

    my $latitude  = $input{lat};
    my $longitude = $input{lon};

    # X/Y referring to tiles old-school
    (my $x) = $input{x} =~ /^(\d+)/; $x ||= 0;
    (my $y) = $input{y} =~ /^(\d+)/; $y ||= 0;

    return front_page( $q, @errors )
      unless ( $x && $y )
      || $input{pc}
      || ( $latitude ne '' && $longitude ne '' );

    if ( $x && $y ) {

        # Convert the tile co-ordinates to real ones.
        ( $latitude, $longitude ) =
          FixMyStreet::Map::tile_xy_to_wgs84( $x, $y );
    }
    elsif ( $latitude && $longitude ) {

        # Don't need to do anything
    }
    else {
        my $error;
        try {
            ( $latitude, $longitude, $error ) =
              FixMyStreet::Geocode::lookup( $input{pc}, $q );

            debug 'Looked up postcode "%s": lat: "%s", lon: "%s", error: "%s"',
              $input{pc}, $latitude, $longitude, $error;
        }
        catch Error::Simple with {
            $error = shift;
        };
        return FixMyStreet::Geocode::list_choices( $error, '/', $q )
          if ( ref($error) eq 'ARRAY' );
        return front_page( $q, $error ) if $error;
    }

    # Check this location is okay to be displayed for the cobrand
    my ($success, $error_msg) = Cobrand::council_check($cobrand, { lat => $latitude, lon => $longitude }, $q, 'display_location');
    return front_page($q, $error_msg) unless $success;

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

    my ($on_map_all, $on_map, $around_map, $dist) = FixMyStreet::Map::map_features($q, $latitude, $longitude, $interval);
    my @pins;
    foreach (@$on_map_all) {
        push @pins, [ $_->{latitude}, $_->{longitude}, ($_->{state} eq 'fixed' ? 'green' : 'red'), $_->{id} ];
    }
    my $on_list = '';
    foreach (@$on_map) {
        my $report_url = NewURL($q, -url => '/report/' . $_->{id});
        $report_url = Cobrand::url($cobrand, $report_url, $q);  
        $on_list .= '<li><a href="' . $report_url . '">';
        $on_list .= ent($_->{title}) . '</a> <small>(';
        $on_list .= Page::prettify_epoch($q, $_->{time}, 1) . ')</small>';
        $on_list .= ' <small>' . _('(fixed)') . '</small>' if $_->{state} eq 'fixed';
        $on_list .= '</li>';
    }
    $on_list = $q->li(_('No problems have been reported yet.'))
        unless $on_list;

    my $around_list = '';
    foreach (@$around_map) {
        my $report_url = Cobrand::url($cobrand, NewURL($q, -url => '/report/' . $_->{id}), $q);
        $around_list .= '<li><a href="' . $report_url . '">';
        my $dist = int($_->{distance}*10+0.5);
        $dist = $dist / 10;
        $around_list .= ent($_->{title}) . '</a> <small>(';
        $around_list .= Page::prettify_epoch($q, $_->{time}, 1) . ', ';
        $around_list .= $dist . 'km)</small>';
        $around_list .= ' <small>' . _('(fixed)') . '</small>' if $_->{state} eq 'fixed';
        $around_list .= '</li>';
        push @pins, [ $_->{latitude}, $_->{longitude}, ($_->{state} eq 'fixed' ? 'green' : 'red'), $_->{id} ];
    }
    $around_list = $q->li(_('No problems found.'))
        unless $around_list;

    if ($input{no_pins}) {
        $hide_link = NewURL($q, -retain=>1, no_pins=>undef);
        $hide_text = _('Show pins');
        @pins = ();
    } else {
        $hide_link = NewURL($q, -retain=>1, no_pins=>1);
        $hide_text = _('Hide pins');
    }
    my $map_links = "<p id='sub_map_links'><a id='hide_pins_link' rel='nofollow' href='$hide_link'>$hide_text</a>";
    if (mySociety::Config::get('COUNTRY') eq 'GB') {
        $map_links .= " | <a id='all_pins_link' rel='nofollow' href='$all_link'>$all_text</a></p> <input type='hidden' id='all_pins' name='all_pins' value='$input_h{all_pins}'>";
    } else {
        $map_links .= "</p>";
    }

    # truncate the lat,lon for nicer rss urls, and strings for outputting
    my ( $short_lat, $short_lon ) =
      map { Utils::truncate_coordinate($_) }    #
      ( $latitude, $longitude );    
    
    my $url_skip = NewURL($q, -retain=>1,
        x => undef, 'y' => undef,
        latitude => $short_lat, longitude => $short_lon,
        'submit_map'=>1, skipped=>1
    );
    my $pc_h = ent($q->param('pc') || '');
    
    my $rss_url;
    if ($pc_h) {
        $rss_url = "/rss/pc/" . URI::Escape::uri_escape_utf8($pc_h);
    } else {
        $rss_url = "/rss/l/$short_lat,$short_lon";
    }
    $rss_url = Cobrand::url( $cobrand, NewURL($q, -url=> $rss_url), $q);

    my %vars = (
        'map' => FixMyStreet::Map::display_map($q,
            latitude => $short_lat, longitude => $short_lon,
            type => 1,
            pins => \@pins,
            post => $map_links
        ),
        map_end => FixMyStreet::Map::display_map_end(1),
        url_home => Cobrand::url($cobrand, '/', $q),
        url_rss => $rss_url,
        url_email => Cobrand::url($cobrand, NewURL($q, lat => $short_lat, lon => $short_lon, -url=>'/alert', feed=>"local:$short_lat:$short_lon"), $q),
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
        pc_h => $pc_h,
        errors => @errors ? '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>' : '',
        text_to_report => _('To report a problem, simply
        <strong>click on the map</strong> at the correct location.'),
        text_skip => sprintf(_("<small>If you cannot see the map, <a href='%s' rel='nofollow'>skip this
        step</a>.</small>"), $url_skip),
    );

    my %params = (
        rss => [ _('Recent local problems, FixMyStreet'), $rss_url ],
        js => FixMyStreet::Map::header_js(),
        robots => 'noindex,nofollow',
    );

    return (Page::template_include('map', $q, Page::template_root($q), %vars), %params);
}

sub display_problem {
    my ($q, $errors, $field_errors) = @_;
    my @errors = @$errors;
    my %field_errors = %{$field_errors};
    my $cobrand = Page::get_cobrand($q);
    push @errors, _('There were problems with your update. Please see below.') if (scalar keys %field_errors);

    my @vars = qw(id name rznvy update fixed add_alert upload_fileid submit_update);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
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
    return front_page($q, _('That report has been removed from FixMyStreet.'), '410 Gone') if $problem->{state} eq 'hidden';

    my $extra_data = Cobrand::extra_data($cobrand, $q);
    my $google_link = Cobrand::base_url_for_emails($cobrand, $extra_data)
        . '/report/' . $problem->{id};

    # truncate the lat,lon for nicer rss urls
    my ( $short_lat, $short_lon ) =
      map { Utils::truncate_coordinate($_) }    #
      ( $problem->{latitude}, $problem->{longitude} );

    my $map_links = '';
    $map_links = "<p id='sub_map_links'>"
      . "<a href=\"http://maps.google.co.uk/maps?output=embed&amp;z=16&amp;q="
      . URI::Escape::uri_escape_utf8( $problem->{title} . ' - ' . $google_link )
      . "\@$short_lat,$short_lon\">View on Google Maps</a></p>"
        if mySociety::Config::get('COUNTRY') eq 'GB';

    my $banner;
    if ($q->{site} ne 'emptyhomes' && $problem->{state} eq 'confirmed' && $problem->{duration} > 8*7*24*60*60) {
        $banner = $q->p({id => 'unknown'}, _('This problem is old and of unknown status.'));
    }
    if ($problem->{state} eq 'fixed') {
        $banner = $q->p({id => 'fixed'}, _('This problem has been fixed') . '.');
    }

    my $contact_url = Cobrand::url($cobrand, NewURL($q, -retain => 1, pc => undef, x => undef, 'y' => undef, -url=>'/contact?id=' . $input{id}), $q);
    my $back = Cobrand::url($cobrand, NewURL($q, -url => '/',
        lat => $short_lat, lon => $short_lon,
        -retain => 1, pc => undef, x => undef, 'y' => undef, id => undef
    ), $q);
    my $fixed = ($input{fixed}) ? ' checked' : '';

    my %vars = (
        banner => $banner,
        map_start => FixMyStreet::Map::display_map($q,
            latitude => $problem->{latitude}, longitude => $problem->{longitude},
            type => 0,
            pins => $problem->{used_map} ? [ [ $problem->{latitude}, $problem->{longitude}, 'blue' ] ] : [],
            post => $map_links
        ),
        map_end => FixMyStreet::Map::display_map_end(0),
        problem_title => ent($problem->{title}),
        problem_meta => Page::display_problem_meta_line($q, $problem),
        problem_detail => Page::display_problem_detail($problem),
        problem_photo => Page::display_problem_photo($q, $problem),
        problem_updates => Page::display_problem_updates($input{id}, $q),
        unsuitable => $q->a({rel => 'nofollow', href => $contact_url}, _('Offensive? Unsuitable? Tell us')),
        more_problems => '<a href="' . $back . '">' . _('More problems nearby') . '</a>',
        url_home => Cobrand::url($cobrand, '/', $q),
        alert_link => Cobrand::url($cobrand, NewURL($q, -url => '/alert?type=updates;id='.$input_h{id}, -retain => 1, pc => undef, x => undef, 'y' => undef ), $q),
        alert_text => _('Email me updates'),
        email_label => _('Email:'),
        subscribe => _('Subscribe'),
        blurb => _('Receive email when updates are left on this problem'),
        cobrand_form_elements1 => Cobrand::form_elements($cobrand, 'alerts', $q),
        form_alert_action => Cobrand::url($cobrand, '/alert', $q),
        rss_url => Cobrand::url($cobrand,  NewURL($q, -retain=>1, -url => '/rss/'.$input_h{id}, pc => undef, x => undef, 'y' => undef, id => undef), $q),
        rss_title => _('RSS feed'),
        rss_alt => _('RSS feed of updates to this problem'),
        update_heading => $q->h2(_('Provide an update')),
        field_errors => \%field_errors,
        add_alert_checked => ($input{add_alert} || !$input{submit_update}) ? ' checked' : '',
        fixedline_box => $problem->{state} eq 'fixed' ? '' : qq{<input type="checkbox" name="fixed" id="form_fixed" value="1"$fixed>},
        fixedline_label => $problem->{state} eq 'fixed' ? '' : qq{<label for="form_fixed">} . _('This problem has been fixed') . qq{</label>},
        name_label => _('Name:'),
        update_label => _('Update:'),
        alert_label => _('Alert me to future updates'),
        post_label => _('Post'),
        cobrand_form_elements => Cobrand::form_elements($cobrand, 'updateForm', $q),
        form_action => Cobrand::url($cobrand, '/', $q),
        input_h => \%input_h,
        optional => _('(optional)'),
    );

    $vars{update_blurb} = $q->p($q->small(_('Please note that updates are not sent to the council. If you leave your name it will be public. Your information will only be used in accordance with our <a href="/faq#privacy">privacy policy</a>')))
        unless $q->{site} eq 'emptyhomes'; # No council blurb

    if (@errors) {
        $vars{errors} = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    
    my $allow_photo_upload = Cobrand::allow_photo_upload($cobrand);
    if ($allow_photo_upload) {
        my $photo_label = _('Photo:');
        $vars{enctype} = ' enctype="multipart/form-data"';
        $vars{photo_element} = <<EOF;
<div id="fileupload_normalUI">
<label for="form_photo">$photo_label</label>
<input type="file" name="photo" id="form_photo">
</div>
EOF
    }
 
    my %params = (
        rss => [ _('Updates to this problem, FixMyStreet'), "/rss/$input_h{id}" ],
        robots => 'index, nofollow',
        js => FixMyStreet::Map::header_js(),
        title => $problem->{title}
    );

    my $page = Page::template_include('problem', $q, Page::template_root($q), %vars);
    return ($page, %params);
}

