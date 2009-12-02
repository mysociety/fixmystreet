#!/usr/bin/perl -w -I../perllib

# alert.cgi:
# Alert code for FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: alert.cgi,v 1.65 2009-12-02 16:33:56 louise Exp $

use strict;
use Standard;
use Digest::SHA1 qw(sha1_hex);
use Error qw(:try);
use CrossSell;
use mySociety::Alert;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(select_all);
use mySociety::EmailUtil qw(is_valid_email);
use mySociety::Gaze;
use mySociety::MaPit;
use mySociety::VotingArea;
use mySociety::Web qw(ent);
use Cobrand;

sub main {
    my $q = shift;
    my $out = '';
    my $title = _('Confirmation');
    if ($q->param('signed_email')) {
        $out = alert_signed_input($q);
    } elsif (my $token = $q->param('token')) {
        my $data = mySociety::AuthToken::retrieve('alert', $token);
        if ($data->{id}) {
            $out = alert_token($q, $data);
        } else {
            my $contact_url = Cobrand::url(Page::get_cobrand($q), '/contact', $q);
            $out = $q->p(sprintf(_(<<EOF), $contact_url));
Thank you for trying to confirm your alert. We seem to have an error ourselves
though, so <a href="%s">please let us know what went on</a> and we'll look into it.
EOF
        }
    } elsif ($q->param('rss')) {
        $out = alert_rss($q);
        return unless $out;
    } elsif ($q->param('rznvy')) {
        $out = alert_do_subscribe($q, $q->param('rznvy'));
    } elsif ($q->param('id')) {
        $out = alert_updates_form($q);
    } elsif ($q->param('type') && $q->param('feed')) {
        $title = _('Local RSS feeds and email alerts');
        $out = alert_local_form($q);
    } elsif ($q->param('pc') || ($q->param('x') && $q->param('y'))) {
        $title = _('Local RSS feeds and email alerts');
        $out = alert_list($q);
    } else {
        $title = _('Local RSS feeds and email alerts');
        $out = alert_front_page($q);
    }

    print Page::header($q, title => $title);
    print $out;
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub alert_list {
    my ($q, @errors) = @_;
    my @vars = qw(pc rznvy x y);
    my %input = map { $_ => scalar $q->param($_) } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;

    my($error, $e, $n);
    my $x = $input{x}; my $y = $input{y};
    $x ||= 0; $x += 0;
    $y ||= 0; $y += 0;
    if ($x || $y) {
        $e = Page::tile_to_os($input{x});
        $n = Page::tile_to_os($input{y});
    } else {
        try {
            ($x, $y, $e, $n, $error) = Page::geocode($input{pc}, $q);
        } catch Error::Simple with {
            $error = shift;
        };
    }
    return Page::geocode_choice($error, '/alert', $q) if ref($error) eq 'ARRAY';
    return alert_front_page($q, $error) if $error;

    my $pretty_pc = $input_h{pc};
    if (mySociety::PostcodeUtil::is_valid_postcode($input{pc})) {
        $pretty_pc = mySociety::PostcodeUtil::canonicalise_postcode($input{pc});
        $pretty_pc =~ s/ /&nbsp;/;
    }

    my $errors = '';
    $errors = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>' if @errors;

    my @types = (@$mySociety::VotingArea::council_parent_types, @$mySociety::VotingArea::council_child_types);
    my %councils = map { $_ => 1 } @$mySociety::VotingArea::council_parent_types;

    my $areas = mySociety::MaPit::get_voting_areas_by_location({easting=>$e, northing=>$n}, 'polygon', \@types);
    my $cobrand = Page::get_cobrand($q);
    my ($success, $error_msg) = Cobrand::council_check($cobrand, $areas, $q, 'alert');    
    if (!$success){
        return alert_front_page($q, $error_msg);
    }
    $areas = mySociety::MaPit::get_voting_areas_info([ keys %$areas ]);

    return alert_front_page($q, _('That location does not appear to be covered by a council, perhaps it is offshore - please try somewhere more specific.')) if keys %$areas == 0;

    my ($options, $options_start, $options_end);
    if (keys %$areas == 2) {

        # One-tier council
        my (@options, $council, $ward);
        foreach (values %$areas) {
            if ($councils{$_->{type}}) {
                $council = $_;
            } else {
                $ward = $_;
            }
        }
        push @options, [ 'council', $council->{area_id}, Page::short_name($council->{name}),
            sprintf(_("Problems within %s"), $council->{name}) ];
        push @options, [ 'ward', $council->{area_id}.':'.$ward->{area_id}, Page::short_name($council->{name}) . '/'
            . Page::short_name($ward->{name}), sprintf(_("Problems within %s ward"), $ward->{name}) ];
        
        $options_start = "<div><ul id='rss_feed'>";
        $options = alert_list_options($q, @options);
        $options_end = "</ul>";

    } elsif (keys %$areas == 1) {

        # One-tier council, no ward
        my (@options, $council);
        foreach (values %$areas) {
            $council = $_;
        }
        push @options, [ 'council', $council->{area_id}, Page::short_name($council->{name}),
            sprintf(_("Problems within %s"), $council->{name}) ];
        
        $options_start = "<div><ul id='rss_feed'>"; 
        $options = alert_list_options($q, @options);
        $options_end = "</ul>";

    } elsif (keys %$areas == 4) {

        # Two-tier council
        my (@options, $county, $district, $c_ward, $d_ward);
        foreach (values %$areas) {
            if ($_->{type} eq 'CTY') {
                $county = $_;
            } elsif ($_->{type} eq 'DIS') {
                $district = $_;
            } elsif ($_->{type} eq 'CED') {
                $c_ward = $_;
            } elsif ($_->{type} eq 'DIW') {
                $d_ward = $_;
            }
        }
        push @options,
            [ 'area', $district->{area_id}, Page::short_name($district->{name}), $district->{name} ],
            [ 'area', $district->{area_id}.':'.$d_ward->{area_id}, Page::short_name($district->{name}) . '/'
              . Page::short_name($d_ward->{name}), "$d_ward->{name} ward, $district->{name}" ],
            [ 'area', $county->{area_id}, Page::short_name($county->{name}), $county->{name} ],
            [ 'area', $county->{area_id}.':'.$c_ward->{area_id}, Page::short_name($county->{name}) . '/'
              . Page::short_name($c_ward->{name}), "$c_ward->{name} ward, $county->{name}" ];
        $options_start = '<div id="rss_list">';
        $options = $q->p($q->strong(_('Problems within the boundary of:'))) .
            $q->ul(alert_list_options($q, @options));
        @options = ();
        push @options,
            [ 'council', $district->{area_id}, Page::short_name($district->{name}), $district->{name} ],
            [ 'ward', $district->{area_id}.':'.$d_ward->{area_id}, Page::short_name($district->{name}) . '/' . Page::short_name($d_ward->{name}),
              "$district->{name}, within $d_ward->{name} ward" ];
        if ($q->{site} ne 'emptyhomes') {
            push @options,
                [ 'council', $county->{area_id}, Page::short_name($county->{name}), $county->{name} ],
                [ 'ward', $county->{area_id}.':'.$c_ward->{area_id}, Page::short_name($county->{name}) . '/'
                  . Page::short_name($c_ward->{name}), "$county->{name}, within $c_ward->{name} ward" ];
            $options .= $q->p($q->strong(_('Or problems reported to:'))) .
                $q->ul(alert_list_options($q, @options));
            $options_end = $q->p($q->small(_('FixMyStreet sends different categories of problem
to the appropriate council, so problems within the boundary of a particular council
might not match the problems sent to that council. For example, a graffiti report
will be sent to the district council, so will appear in both of the district
council&rsquo;s alerts, but will only appear in the "Within the boundary" alert
for the county council.'))) . '</div><div id="rss_buttons">';
        }
    } else {
        # Hopefully impossible in the UK!
        throw Error::Simple('An area with three tiers of council? Impossible! '. $e . ' ' . $n . ' ' . join('|',keys %$areas));
    }

    my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($e, $n, 'G');
    my $dist = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
    $dist = int($dist * 10 + 0.5);
    $dist = $dist / 10.0;

    my $checked = '';
    $checked = ' checked' if $q->param('feed') && $q->param('feed') eq "local:$x:$y";
    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'alerts', $q);
    my $pics = Cobrand::recent_photos($cobrand, 5, $e, $n, $dist);
    $pics = '<div id="alert_photos">' . $q->h2(_('Photos of recent nearby reports')) . $pics . '</div>' if $pics;
    my $header;
    if ($pretty_pc) {
        $header = sprintf(_('Local RSS feeds and email alerts for &lsquo;%s&rsquo;'), $pretty_pc); 
    } else {
        $header = _('Local RSS feeds and email alerts');
    }
    my $out = $q->h1($header);
    my $form_action = Cobrand::url($cobrand, '/alert', $q);
    $out .= <<EOF;
<form id="alerts" name="alerts" method="post" action="$form_action">
<input type="hidden" name="type" value="local">
<input type="hidden" name="pc" value="$input_h{pc}">
$cobrand_form_elements
$pics

EOF
    $out .= $q->p(($pretty_pc ? sprintf(_('Here are the types of local problem alerts for &lsquo;%s&rsquo;.'), $pretty_pc)
    : '') . ' ' . _('Select which type of alert you&rsquo;d like and click the button for an RSS
feed, or enter your email address to subscribe to an email alert.'));
    $out .= $errors;
    $out .= $q->p(_('The simplest alert is our geographic one:'));
    my $rss_label = sprintf(_('Problems within %skm of this location'), $dist);
    $out .= <<EOF;
<p id="rss_local">
<input type="radio" name="feed" id="local:$x:$y" value="local:$x:$y"$checked>
<label for="local:$x:$y">$rss_label</label>
EOF
    my $rss_feed = Cobrand::url($cobrand, "/rss/$x,$y", $q);
    my $default_link = Cobrand::url($cobrand, "/alert?type=local;feed=local:$x:$y", $q);
    my $rss_details = _('(a default distance which covers roughly 200,000 people)');
    $out .= $rss_details;
    $out .= " <a href='$rss_feed'><img src='/i/feed.png' width='16' height='16' title='"
        . _('RSS feed of nearby problems') . "' alt='" . _('RSS feed') . "' border='0'></a>";
    $out .= '</p> <p id="rss_local_alt">' . _('(alternatively the RSS feed can be customised, within');
    my $rss_feed_2k  = Cobrand::url($cobrand, "/rss/$x,$y/2", $q);
    my $rss_feed_5k  = Cobrand::url($cobrand, "/rss/$x,$y/5", $q);
    my $rss_feed_10k = Cobrand::url($cobrand, "/rss/$x,$y/10", $q);
    my $rss_feed_20k = Cobrand::url($cobrand, "/rss/$x,$y/20", $q);
    $out .= <<EOF;
 <a href="$rss_feed_2k">2km</a> / <a href="$rss_feed_5k">5km</a>
/ <a href="$rss_feed_10k">10km</a> / <a href="$rss_feed_20k">20km</a>)
</p>
EOF
    $out .= $q->p(_('Or you can subscribe to an alert based upon what ward or council you&rsquo;re in:'));
    $out .= $options_start;
    $out .= $options;
    $out .= $options_end;
    $out .= $q->p('<input type="submit" name="rss" value="' . _('Give me an RSS feed') . '">');
    $out .= $q->p({-id=>'alert_or'}, _('or'));
    $out .= '<p>' . _('Your email:') . ' <input type="text" id="rznvy" name="rznvy" value="' . $input_h{rznvy} . '" size="30"></p>
<p><input type="submit" name="alert" value="' . _('Subscribe me to an email alert') . '"></p>
</div>
</form>';
    my %vars = (header => $header, 
                cobrand_form_elements => $cobrand_form_elements, 
                rss_label => $rss_label,
                rss_feed => $rss_feed,
                default_link => $default_link, 
                rss_details => $rss_details, 
                rss_feed_2k => $rss_feed_2k, 
                rss_feed_5k => $rss_feed_5k,   
                rss_feed_10k => $rss_feed_10k,   
                rss_feed_20k => $rss_feed_20k, 
                x => $x, 
                y => $y, 
                options => $options   );
    my $cobrand_page = Page::template_include('alert-options', $q, Page::template_root($q), %vars);
    $out = $cobrand_page if ($cobrand_page);
    return $out;
}

sub alert_list_options {
    my $q = shift;
    my $out = '';
    my $feed = $q->param('feed') || '';
    my $cobrand = Page::get_cobrand($q);
    my $cobrand_list  = Cobrand::alert_list_options($cobrand, $q, @_);
    return $cobrand_list if ($cobrand_list);
    foreach (@_) {
        my ($type, $vals, $rss, $text) = @$_;
        (my $vals2 = $rss) =~ tr{/+}{:_};
        my $id = $type . ':' . $vals . ':' . $vals2;
        $out .= '<li><input type="radio" name="feed" id="' . $id . '" ';
        $out .= 'checked ' if $feed eq $id;
        my $url = "/rss/";
        $url .= $type eq 'area' ? 'area' : 'reports'; 
        $url .= '/' . $rss ;
        my $rss_url = Cobrand::url($cobrand, $url, $q);
        $out .= 'value="' . $id . '"> <label for="' . $id . '">' . $text
            . '</label> <a href="' . $rss_url . '"><img src="/i/feed.png" width="16" height="16"
title="' . sprintf(_('RSS feed of %s'), $text) . '" alt="' . _('RSS feed') . '" border="0"></a>';
    }
    return $out;
}

sub alert_front_page {
    my $q = shift;
    my $cobrand = Page::get_cobrand($q);
    my $error = shift;
    my $errors = '';
    $errors = '<ul class="error"><li>' . $error . '</li></ul>' if $error;

    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } qw(pc);
    my $header = _('Local RSS feeds and email alerts');
    my $intro = _('FixMyStreet has a variety of RSS feeds and email alerts for local problems, including
alerts for all problems within a particular ward or council, or all problems
within a certain distance of a particular location.');
    my $pc_label = _('To find out what local alerts we have for you, please enter your GB
postcode or street name and area:');
    my $form_action = Cobrand::url(Page::get_cobrand($q), '/alert', $q);
    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'alerts', $q);
    my $cobrand_extra_data = Cobrand::extra_data($cobrand, $q);
    my $submit_text = _('Go');

    my $out = $q->h1($header);
    $out .= $q->p($intro);
    $out .= $errors . qq(<form method="get" action="$form_action">);
    $out .= $q->p($pc_label, '<input type="text" name="pc" value="' . $input_h{pc} . '">
<input type="submit" value="' . $submit_text . '">');
    $out .= $cobrand_form_elements;
    $out .= '</form>';

    my %vars = (error => $error, 
                header => $header, 
                intro => $intro, 
                pc_label => $pc_label, 
                form_action => $form_action, 
                input_h => \%input_h, 
                submit_text => $submit_text, 
                cobrand_form_elements => $cobrand_form_elements, 
                cobrand_extra_data => $cobrand_extra_data, 
                url_home => Cobrand::url($cobrand, '/', $q));

    my $cobrand_page = Page::template_include('alert-front-page', $q, Page::template_root($q), %vars);
    $out = $cobrand_page if ($cobrand_page);

    return $out if $q->referer() && $q->referer() =~ /fixmystreet\.com/;
    my $recent_photos = Cobrand::recent_photos($cobrand, 10);
    $out .= '<div id="alert_recent">' . $q->h2(_('Some photos of recent reports')) . $recent_photos . '</div>' if $recent_photos;
    
    return $out;
}

sub alert_rss {
    my $q = shift;
    my $feed = $q->param('feed');
    return alert_list($q, _('Please select the feed you want')) unless $feed;
    my $cobrand = Page::get_cobrand($q);
    my $base_url = Cobrand::base_url($cobrand);
    my $extra_params = Cobrand::extra_params($cobrand, $q);
    my $url;
    if ($feed =~ /^area:(?:\d+:)+(.*)$/) {
        (my $id = $1) =~ tr{:_}{/+};
        $url = $base_url . '/rss/area/' . $id;
        $url .= "?" . $extra_params if ($extra_params);
        print $q->redirect($url);
        return;
    } elsif ($feed =~ /^(?:council|ward):(?:\d+:)+(.*)$/) {
        (my $id = $1) =~ tr{:_}{/+};
        $url = $base_url . '/rss/reports/' . $id;
        $url .= "?" . $extra_params if ($extra_params);
        print $q->redirect($url);
        return;
    } elsif ($feed =~ /^local:(\d+):(\d+)$/) {
        $url = $base_url . '/rss/' . $1 . ',' . $2;
        $url .= "?" . $extra_params if ($extra_params);
        print $q->redirect($url);
        return;
    } else {
        return alert_list($q, _('Illegal feed selection'));
    }
}

sub alert_updates_form {
    my ($q, @errors) = @_;
    my @vars = qw(id rznvy);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    my $cobrand_form_elements = Cobrand::form_elements(Page::get_cobrand($q), 'alerts', $q);
    my $out = '';
    if (@errors) {
        $out .= '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    $out .= $q->p(_('Receive email when updates are left on this problem.'));
    my $label = _('Email:');
    my $subscribe = _('Subscribe');
    my $form_action = Cobrand::url(Page::get_cobrand($q), 'alert', $q);
    $out .= <<EOF;
<form action="$form_action" method="post">
<label class="n" for="alert_rznvy">$label</label>
<input type="text" name="rznvy" id="alert_rznvy" value="$input_h{rznvy}" size="30">
<input type="hidden" name="id" value="$input_h{id}">
<input type="hidden" name="type" value="updates">
<input type="submit" value="$subscribe">
$cobrand_form_elements
</form>
EOF
    return $out;
}

sub alert_local_form {
    my ($q, @errors) = @_;
    my @vars = qw(id rznvy feed);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    my $cobrand_form_elements = Cobrand::form_elements(Page::get_cobrand($q), 'alerts', $q);
    my $out = '';
    if (@errors) {
        $out .= '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    $out .= $q->p(_('Receive alerts on new local problems'));
    my $label = _('Email:');
    my $subscribe = _('Subscribe');
    my $form_action = Cobrand::url(Page::get_cobrand($q), 'alert', $q);
    $out .= <<EOF;
<form action="$form_action" method="post">
<label class="n" for="alert_rznvy">$label</label>
<input type="text" name="rznvy" id="alert_rznvy" value="$input_h{rznvy}" size="30">
<input type="hidden" name="feed" value="$input_h{feed}">
<input type="hidden" name="type" value="local">
<input type="submit" value="$subscribe">
$cobrand_form_elements
</form>
EOF
    return $out;
}

sub alert_signed_input {
    my $q = shift;
    my ($salt, $signed_email) = split /,/, $q->param('signed_email');
    my $email = $q->param('rznvy');
    my $id = $q->param('id');
    my $secret = scalar(dbh()->selectrow_array('select secret from secret'));
    my $out;
    my $cobrand = Page::get_cobrand($q);
    if ($signed_email eq sha1_hex("$id-$email-$salt-$secret")) {
        my $alert_id = mySociety::Alert::create($email, 'new_updates', $cobrand, '', $id);
        mySociety::Alert::confirm($alert_id);
        $out = $q->p(_('You have successfully subscribed to that alert.'));
        my $cobrand = Page::get_cobrand($q);
        my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
        if ($display_advert) {
            $out .= CrossSell::display_advert($q, $email);
        }
    } else {
        $out = $q->p(_('We could not validate that alert.'));
    }
    return $out;
}

sub alert_token {
    my ($q, $data) = @_;
    my $id = $data->{id};
    my $type = $data->{type};
    my $email = $data->{email};

    (my $domain = $email) =~ s/^.*\@//;
    if (dbh()->selectrow_array('select email from abuse where lower(email)=? or lower(email)=?', {}, lc($email), lc($domain))) {
        return $q->p('Sorry, there has been an error confirming your alert.');
    }

    my $out;
    my $cobrand = Page::get_cobrand($q);
    my $message; 
    my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
    if ($type eq 'subscribe') {
        mySociety::Alert::confirm($id);
        $message = _('You have successfully confirmed your alert.');
        $out = $q->p($message);
        if ($display_advert) {
            $out .= CrossSell::display_advert($q, $email);
        }
    } elsif ($type eq 'unsubscribe') {
        mySociety::Alert::delete($id);
        $message = _('You have successfully deleted your alert.');
        $out = $q->p($message);
        if ($display_advert) {
            $out .= CrossSell::display_advert($q, $email);
        }
    }
 
    my %vars = (message => $message, 
                url_home => Cobrand::url($cobrand, '/', $q));
    my $confirmation = Page::template_include('confirmed-alert', $q, Page::template_root($q), %vars);
    return $confirmation if $confirmation;
    return $out;
}

sub alert_do_subscribe {
    my ($q, $email) = @_;

    my $type = $q->param('type');

    my @errors;
    push @errors, _('Please enter a valid email address') unless is_valid_email($email);
    push @errors, _('Please select the type of alert you want') if $type && $type eq 'local' && !$q->param('feed');
    if (@errors) {
        return alert_updates_form($q, @errors) if $type && $type eq 'updates';
        return alert_list($q, @errors) if $type && $type eq 'local';
        return alert_front_page($q, @errors);
    }

    my $alert_id;
    my $cobrand = Page::get_cobrand($q);
    my $cobrand_data = Cobrand::extra_alert_data($cobrand, $q);
    if ($type eq 'updates') {
        my $id = $q->param('id');
        $alert_id = mySociety::Alert::create($email, 'new_updates', $cobrand, $cobrand_data, $id);
    } elsif ($type eq 'problems') {
        $alert_id = mySociety::Alert::create($email, 'new_problems', $cobrand, $cobrand_data);
    } elsif ($type eq 'local') {
        my $feed = $q->param('feed');
        if ($feed =~ /^area:(?:\d+:)?(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'area_problems', $cobrand, $cobrand_data, $1);
        } elsif ($feed =~ /^council:(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'council_problems', $cobrand, $cobrand_data, $1, $1);
        } elsif ($feed =~ /^ward:(\d+):(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'ward_problems', $cobrand, $cobrand_data, $1, $2);
        } elsif ($feed =~ /^local:(\d+):(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'local_problems', $cobrand, $cobrand_data, $1, $2);
        }
    } else {
        throw mySociety::Alert::Error('Invalid type');
    }

    my %h = ();
    $h{url} = Page::base_url_with_lang($q, undef, 1) . '/A/'
        . mySociety::AuthToken::store('alert', { id => $alert_id, type => 'subscribe', email => $email } );
    dbh()->commit();
    return Page::send_email($q, $email, undef, 'alert', %h);
}

