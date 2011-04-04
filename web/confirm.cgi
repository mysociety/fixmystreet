#!/usr/bin/perl -w -I../perllib

# confirm.cgi:
# Confirmation code for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: confirm.cgi,v 1.66 2009-12-15 18:26:11 louise Exp $

use strict;
use Standard;
use Digest::SHA1 qw(sha1_hex);
use CrossSell;
use FixMyStreet::Alert;
use mySociety::AuthToken;
use mySociety::Random qw(random_bytes);

sub main {
    my $q = shift;
    my $cobrand = Page::get_cobrand($q);
    my $out = '';
    my $token = $q->param('token');
    my $type = $q->param('type') || '';
    my $tokentype = $type eq 'questionnaire' ? 'update' : $type;
    my $data = mySociety::AuthToken::retrieve($tokentype, $token);
    if ($data) {
        if ($type eq 'update') {
            $out = confirm_update($q, $data);
        } elsif ($type eq 'questionnaire') {
            $out = add_questionnaire($q, $data, $token);
        }
        dbh()->commit();
    } else {
        my $contact_url = Cobrand::url($cobrand, '/contact', $q);
        $out = $q->p(sprintf(_(<<EOF), $contact_url));
Thank you for trying to confirm your update or problem. We seem to have an
error ourselves though, so <a href="%s">please let us know what went on</a>
and we'll look into it.
EOF

        my %vars = (error => $out);
        my $cobrand_page = Page::template_include('error', $q, Page::template_root($q), %vars);
        $out = $cobrand_page if $cobrand_page;
    }
    
    print Page::header($q, title=>_('Confirmation'));
    print $out;
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub confirm_update {
    my ($q, $data) = @_;
    my $cobrand = Page::get_cobrand($q);
    my $id = $data;
    my $add_alert = 0;
    if (ref($data)) {
        $id = $data->{id};
        $add_alert = $data->{add_alert};
    }

    my ($problem_id, $fixed, $email, $name, $cobrand_data) = dbh()->selectrow_array(
        "select problem_id, mark_fixed, email, name, cobrand_data from comment where id=?", {}, $id);
    $email = lc($email);

    (my $domain = $email) =~ s/^.*\@//;
    if (dbh()->selectrow_array('select email from abuse where lower(email)=? or lower(email)=?', {}, $email, $domain)) {
        dbh()->do("update comment set state='hidden' where id=?", {}, $id);
        return $q->p('Sorry, there has been an error confirming your update.');
    } else {
        dbh()->do("update comment set state='confirmed', confirmed=ms_current_timestamp() where id=? and state='unconfirmed'", {}, $id);
    }

    my $creator_fixed = 0;
    if ($fixed) {
        dbh()->do("update problem set state='fixed', lastupdate = ms_current_timestamp()
            where id=? and state='confirmed'", {}, $problem_id);
        # If a problem reporter is marking their own problem as fixed, turn off questionnaire sending
        $creator_fixed = dbh()->do("update problem set send_questionnaire='f' where id=? and lower(email)=?
            and send_questionnaire='t'", {}, $problem_id, $email);
    } else { 
        # Only want to refresh problem if not already fixed
        dbh()->do("update problem set lastupdate = ms_current_timestamp()
            where id=? and state='confirmed'", {}, $problem_id);
    }

    my $out = '';
    if ($creator_fixed > 0 && $q->{site} ne 'emptyhomes') {
        my $answered_ever_reported = dbh()->selectrow_array(
            'select id from questionnaire where problem_id in (select id from problem where lower(email)=?) and ever_reported is not null', {}, $email);
        if (!$answered_ever_reported) {
            $out = ask_questionnaire($q->param('token'), $q);
        }
    }

    my $report_url = Cobrand::url($cobrand, "/report/$problem_id#update_$id", $q);
    if (!$out) {
        $out = $q->p({class => 'confirmed'}, sprintf(_('You have successfully confirmed your update and you can now <a href="%s">view it on the site</a>.'), $report_url));
        my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
        if ($display_advert) {
            $out .= CrossSell::display_advert($q, $email, $name);
        }
        my %vars = (
            url_report => $report_url,
            url_home => Cobrand::url($cobrand, '/', $q),
        );
        my $cobrand_page = Page::template_include('confirmed-update', $q, Page::template_root($q), %vars);
        $out = $cobrand_page if $cobrand_page;
    }

    # Subscribe updater to email updates if requested
    if ($add_alert) {
        my $alert_id = FixMyStreet::Alert::create($email, 'new_updates', $cobrand, $cobrand_data, $problem_id);
        FixMyStreet::Alert::confirm($alert_id);
    }

    return $out;
}

sub ask_questionnaire {
    my ($token, $q) = @_;
    my $cobrand = Page::get_cobrand($q);
    my $qn_thanks = _("Thanks, glad to hear it's been fixed! Could we just ask if you have ever reported a problem to a council before?");
    my $yes = _('Yes');
    my $no = _('No');
    my $go = _('Submit');
    my $form_action = Cobrand::url($cobrand, "/confirm", $q);
    my $form_extra_elements = Cobrand::form_elements($cobrand, 'questionnaire', $q);
    my $out = <<EOF;
<form action="$form_action" method="post" id="questionnaire">
<input type="hidden" name="type" value="questionnaire">
<input type="hidden" name="token" value="$token">
<p>$qn_thanks</p>
<p align="center">
<input type="radio" name="reported" id="reported_yes" value="Yes">
<label for="reported_yes">$yes</label>
<input type="radio" name="reported" id="reported_no" value="No">
<label for="reported_no">$no</label>
$form_extra_elements
<input type="submit" value="$go">
</p>
</form>
EOF
    my %vars = (form => $out,
		url_home => Cobrand::url($cobrand, '/', $q));
    my $cobrand_template = Page::template_include('update-questionnaire', $q, Page::template_root($q), %vars);
    $out = $cobrand_template if $cobrand_template;
    return $out;
}

sub add_questionnaire {
    my ($q, $data, $token) = @_;

    my $id = $data;
    if (ref($data)) {
        $id = $data->{id};
    }
    my $cobrand = Page::get_cobrand($q);
    my ($problem_id, $email, $name) = dbh()->selectrow_array("select problem_id, email, name from comment where id=?", {}, $id);
    my $reported = $q->param('reported') || '';
    $reported = $reported eq 'Yes' ? 't' : ($reported eq 'No' ? 'f' : undef);
    return ask_questionnaire($token, $q) unless $reported;
    my $already = dbh()->selectrow_array("select id from questionnaire
        where problem_id=? and old_state='confirmed' and new_state='fixed'",
        {}, $problem_id);
    dbh()->do("insert into questionnaire (problem_id, whensent, whenanswered,
        ever_reported, old_state, new_state) values (?, ms_current_timestamp(),
        ms_current_timestamp(), ?, 'confirmed', 'fixed');", {}, $problem_id, $reported)
        unless $already;
    my $report_url = Cobrand::url($cobrand, "/report/$problem_id", $q);
    my $out = $q->p({class => 'confirmed'}, sprintf(_('Thank you &mdash; you can <a href="%s">view your updated problem</a> on the site.'), $report_url));
    my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
    if ($display_advert) { 
         $out .= CrossSell::display_advert($q, $email, $name);
    }
    return $out;
}

