#!/usr/bin/perl -w -I../perllib

# alert.cgi:
# Alert code for FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: alert.cgi,v 1.20 2007-09-25 11:55:05 matthew Exp $

use strict;
use Standard;
use Digest::SHA1 qw(sha1_hex);
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

sub main {
    my $q = shift;
    my $out = '';
    my $title = 'Confirmation';
    if ($q->param('signed_email')) {
        $out = alert_signed_input($q);
    } elsif (my $token = $q->param('token')) {
        my $data = mySociety::AuthToken::retrieve('alert', $token);
        if ($data->{id}) {
            $out = alert_token($q, $data);
        } else {
            $out = $q->p(_(<<EOF));
Thank you for trying to confirm your alert. We seem to have a problem ourselves
though, so <a href="/contact">please let us know what went on</a> and we'll look into it.
EOF
        }
    } elsif ($q->param('rss')) {
        $out = alert_rss($q);
        return unless $out;
    } elsif ($q->param('email')) {
        $out = alert_do_subscribe($q, $q->param('email'));
    } elsif ($q->param('id')) {
        $out = alert_updates_form($q);
    } elsif ($q->param('pc')) {
        $title = 'Local RSS feeds and email alerts';
        $out = alert_list($q);
    } else {
        $title = 'Local RSS feeds and email alerts';
        $out = alert_front_page($q);
    }

    print Page::header($q, title => $title);
    print $out;
    print Page::footer();
}
Page::do_fastcgi(\&main);

sub alert_list {
    my ($q, @errors) = @_;
    my %input = map { $_ => scalar $q->param($_) } qw(pc email);
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } qw(pc email);
    my ($x, $y, $e, $n, $error) = Page::geocode($input{pc});
    return Page::geocode_choice($error, '/alert') if ref($error) eq 'ARRAY';
    return alert_front_page($q, $error) if $error;

    my $errors = '';
    $errors = '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>' if @errors;

    my @types = (@$mySociety::VotingArea::council_parent_types, @$mySociety::VotingArea::council_child_types);
    my %councils = map { $_ => 1 } @$mySociety::VotingArea::council_parent_types;

    my $areas = mySociety::MaPit::get_voting_areas_by_location({easting=>$e, northing=>$n}, 'polygon', \@types);
    $areas = mySociety::MaPit::get_voting_areas_info([ keys %$areas ]);

    my ($options);
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
            "Problems within $council->{name}" ];
        push @options, [ 'ward', $council->{area_id}.':'.$ward->{area_id}, Page::short_name($council->{name}) . '/'
            . Page::short_name($ward->{name}), "Problems within $ward->{name} ward" ];

        $options = '<div>' . $q->ul({id=>'rss_feed'},
            alert_list_options($q, @options)
        );

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
        $options = '<div id="rss_list">';
        $options .= $q->p($q->strong('Problems within the boundary of:')) .
            $q->ul(alert_list_options($q, @options));
        @options = ();
        push @options,
            [ 'council', $district->{area_id}, Page::short_name($district->{name}), $district->{name} ],
            [ 'ward', $district->{area_id}.':'.$d_ward->{area_id}, Page::short_name($district->{name}) . '/' . Page::short_name($d_ward->{name}),
              "$district->{name}, within $d_ward->{name} ward" ],
            [ 'council', $county->{area_id}, Page::short_name($county->{name}), $county->{name} ],
            [ 'ward', $county->{area_id}.':'.$c_ward->{area_id}, Page::short_name($county->{name}) . '/'
              . Page::short_name($c_ward->{name}), "$county->{name}, within $c_ward->{name} ward" ];
        $options .= $q->p($q->strong('Or problems reported to:')) .
            $q->ul(alert_list_options($q, @options));
        $options .= $q->p($q->small('FixMyStreet sends different categories of problem
to the appropriate council, so problems within the boundary of a particular council
might not match the problems sent to that council. For example, a graffiti report
will be sent to the district council, so will appear in both that council\'s alerts,
but will only appear in the "Within the boundary" alert for the county council.'));
        $options .= '</div>
<div id="rss_buttons">
';

    } else {
        # Hopefully impossible in the UK!
        throw Error::Simple('An area with three tiers of council? Impossible!');
    }

    my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($e, $n, 'G');
    my $dist = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
    $dist = int($dist*10+0.5)/10;

    my $checked = '';
    $checked = ' checked' if $q->param('feed') && $q->param('feed') eq "local:$x:$y";

    my $pics = Page::recent_photos(5, $e, $n, $dist);
    $pics = '<div id="alert_photos"><h2>Photos of recent nearby reports</h2>' . $pics . '</div>' if $pics;

    <<EOF;
<h1>Local RSS feeds and email alerts for &lsquo;$input_h{pc}&rsquo;</h1>

<form id="alerts" method="post" action="/alert">
<input type="hidden" name="type" value="local">
<input type="hidden" name="pc" value="$input_h{pc}">

$pics

<p>Here are the types of local problem alerts for &lsquo;$input_h{pc}&rsquo;.
Select which type of alert you&rsquo;d like and click the button for an RSS
feed, or enter your email address to subscribe to an email alert.</p>

$errors

<p>The simplest alert is our geographic one:</p>

<p id="rss_local">
<input type="radio" name="feed" id="local:$x:$y" value="local:$x:$y"$checked>
<label for="local:$x:$y">Problems within ${dist}km of this location</label> (a default
distance which covers roughly 200,000 people)
<a href="/rss/$x,$y"><img src="/i/feed.png" width="16" height="16" title="RSS feed of nearby problems" alt="RSS feed" border="0"></a>
</p>
<p id="rss_local_alt">
(alternatively the RSS feed can be customised, within <a href="/rss/$x,$y/2">2km</a> / <a href="/rss/$x,$y/5">5km</a>
/ <a href="/rss/$x,$y/10">10km</a> / <a href="/rss/$x,$y/20">20km</a>)
</p>

<p>Or you can subscribe to an alert based upon what ward or council you&rsquo;re in:</p>

$options

<p><input type="submit" name="rss" value="Give me an RSS feed"></p>

<p id="alert_or">or</p>

<p>Your email: <input type="text" id="email" name="email" value="$input_h{email}" size="30"></p>
<p><input type="submit" name="alert" value="Subscribe me to an email alert"></p>

</div>
</form>
EOF
}

sub alert_list_options {
    my $q = shift;
    my $out = '';
    my $feed = $q->param('feed') || '';
    foreach (@_) {
        my ($type, $vals, $rss, $text) = @$_;
        (my $vals2 = $rss) =~ tr{/+}{:_};
        my $id = $type . ':' . $vals . ':' . $vals2;
        $out .= '<li><input type="radio" name="feed" id="' . $id . '" ';
        $out .= 'checked ' if $feed eq $id;
        $out .= 'value="' . $id . '"> <label for="' . $id . '">' . $text
            . '</label> <a href="/rss/';
        $out .= $type eq 'area' ? 'area' : 'reports';
        $out .= '/' . $rss . '"><img src="/i/feed.png" width="16" height="16"
title="RSS feed of local problems at ' . $text . '" alt="RSS feed" border="0"></a>';
    }
    return $out;
}

sub alert_front_page {
    my $q = shift;
    my $error = shift;
    my $errors = '';
    $errors = '<ul id="error"><li>' . $error . '</li></ul>' if $error;

    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } qw(pc);
    my $out = <<EOF;
<h1>Local RSS feeds and email alerts</h1>
<p>FixMyStreet has a variety of RSS feeds and email alerts for local problems, including
alerts for all problems within a particular ward or council, or all problems
within a certain distance of a particular location.</p>

$errors
<form method="get" action="/alert">
<p>To find out what local alerts we have for you, please enter your UK
postcode or street name and area:
<input type="text" name="pc" value="$input_h{pc}">
<input type="submit" value="Look up">
</form>
EOF

    return $out if $q->referer() =~ /fixmystreet\.com/;

    my $recent_photos = Page::recent_photos(10);
    $out .= "<div id='alert_recent'><h2>Some photos of recent reports</h2>$recent_photos</div>" if $recent_photos;
    return $out;
}

sub alert_rss {
    my $q = shift;
    my $feed = $q->param('feed');
    return alert_list($q, 'Please select the feed you want') unless $feed;
    if ($feed =~ /^area:(?:\d+:)+(.*)$/) {
        (my $id = $1) =~ tr{:_}{/+};
        print $q->redirect('/rss/area/' . $id);
        return;
    } elsif ($feed =~ /^(?:council|ward):(?:\d+:)+(.*)$/) {
        (my $id = $1) =~ tr{:_}{/+};
        print $q->redirect('/rss/reports/' . $id);
        return;
    } elsif ($feed =~ /^local:(\d+):(\d+)$/) {
        print $q->redirect('/rss/' . $1 . ',' . $2);
        return;
    } else {
        return alert_list($q, 'Illegal feed selection');
    }
}

sub alert_updates_form {
    my ($q, @errors) = @_;
    my @vars = qw(id email);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    my $out = '';
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    $out .= $q->p(_('Receive email when updates are left on this problem.'));
    my $label = _('Email:');
    my $subscribe = _('Subscribe');
    $out .= <<EOF;
<form action="alert" method="post">
<label class="n" for="alert_email">$label</label>
<input type="text" name="email" id="alert_email" value="$input_h{email}" size="30">
<input type="hidden" name="id" value="$input_h{id}">
<input type="hidden" name="type" value="updates">
<input type="submit" value="$subscribe">
</form>
EOF
    return $out;
}

sub alert_signed_input {
    my $q = shift;
    my ($salt, $signed_email) = split /,/, $q->param('signed_email');
    my $email = $q->param('email');
    my $id = $q->param('id');
    my $secret = scalar(dbh()->selectrow_array('select secret from secret'));
    my $out;
    if ($signed_email eq sha1_hex("$id-$email-$salt-$secret")) {
        my $alert_id = mySociety::Alert::create($email, 'new_updates', $id);
        mySociety::Alert::confirm($alert_id);
        $out = $q->p(_('You have successfully subscribed to that alert.'));
        $out .= CrossSell::display_advert($email);
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
    my $out;
    if ($type eq 'subscribe') {
        mySociety::Alert::confirm($id);
        $out = $q->p(_('You have successfully confirmed your alert.'));
        $out .= CrossSell::display_advert($email);
    } elsif ($type eq 'unsubscribe') {
        mySociety::Alert::delete($id);
        $out = $q->p(_('You have successfully deleted your alert.'));
        $out .= CrossSell::display_advert($email);
    }
    return $out;
}

sub alert_do_subscribe {
    my ($q, $email) = @_;

    my $type = $q->param('type');

    my @errors;
    push @errors, _('Please enter a valid email address') unless is_valid_email($email);
    push @errors, _('Please select the type of alert you want') if $type eq 'local' && !$q->param('feed');
    if (@errors) {
        return alert_updates_form($q, @errors) if $type eq 'updates';
        return alert_list($q, @errors) if $type eq 'local';
        return 'argh';
    }

    my $alert_id;
    if ($type eq 'updates') {
        my $id = $q->param('id');
        $alert_id = mySociety::Alert::create($email, 'new_updates', $id);
    } elsif ($type eq 'problems') {
        $alert_id = mySociety::Alert::create($email, 'new_problems');
    } elsif ($type eq 'local') {
        my $feed = $q->param('feed');
        if ($feed =~ /^area:(?:\d+:)?(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'area_problems', $1);
        } elsif ($feed =~ /^council:(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'council_problems', $1, $1);
        } elsif ($feed =~ /^ward:(\d+):(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'ward_problems', $1, $2);
        } elsif ($feed =~ /^local:(\d+):(\d+)/) {
            $alert_id = mySociety::Alert::create($email, 'local_problems', $1, $2);
        }
    } else {
        throw mySociety::Alert::Error('Invalid type');
    }

    my %h = ();
    $h{url} = mySociety::Config::get('BASE_URL') . '/A/'
        . mySociety::AuthToken::store('alert', { id => $alert_id, type => 'subscribe', email => $email } );
    dbh()->commit();
    return Page::send_email($email, undef, 'alert', %h);
}

