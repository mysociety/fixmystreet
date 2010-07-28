#!/usr/bin/perl -w -I../perllib

# questionnaire.cgi:
# Questionnaire for problem creators
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: questionnaire.cgi,v 1.53 2009-12-08 17:43:13 louise Exp $

use strict;
use Standard;
use Error qw(:try);
use CrossSell;
use mySociety::AuthToken;
use mySociety::Locale;
use mySociety::Web qw(ent);

sub main {
    my $q = shift;
    my $out = '';
    if ($q->param('submit')) {
        $out = submit_questionnaire($q);
    } else {
        $out = display_questionnaire($q);
    }
    print Page::header($q, title=>_('Questionnaire'));
    print $out;
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub check_stuff {
    my $q = shift;
    my $cobrand = Page::get_cobrand($q);
    my $id = mySociety::AuthToken::retrieve('questionnaire', $q->param('token'));
    throw Error::Simple(_("I'm afraid we couldn't validate that token. If you've copied the URL from an email, please check that you copied it exactly.\n")) unless $id;

    my $questionnaire = dbh()->selectrow_hashref(
        'select id, problem_id, whenanswered from questionnaire where id=?', {}, $id);
    my $problem_id = $questionnaire->{problem_id};
    my $problem_url = Cobrand::url($cobrand, "/report/$problem_id", $q);
    my $contact_url = Cobrand::url($cobrand, "/contact", $q);
    throw Error::Simple(sprintf(_("You have already answered this questionnaire. If you have a question, please <a href='%s'>get in touch</a>, or <a href='%s'>view your problem</a>.\n"), $contact_url, $problem_url)) if $questionnaire->{whenanswered};

    my $problem = dbh()->selectrow_hashref(
        "select *, extract(epoch from confirmed) as time, extract(epoch from whensent-confirmed) as whensent
            from problem where id=? and state in ('confirmed','fixed')", {}, $problem_id);
    throw Error::Simple(_("I'm afraid we couldn't locate your problem in the database.\n")) unless $problem;

    my $num_questionnaire = dbh()->selectrow_array(
        'select count(*) from questionnaire where problem_id=?', {}, $problem_id);
    my $answered_ever_reported = dbh()->selectrow_array(
        'select id from questionnaire where problem_id in (select id from problem where email=?) and ever_reported is not null', {}, $problem->{email});

    return ($questionnaire, $problem, $num_questionnaire, $answered_ever_reported);
}

sub submit_questionnaire {
    my $q = shift;
    my $cobrand = Page::get_cobrand($q);
    my $cobrand_data = Cobrand::extra_data($cobrand, $q);
    my @vars = qw(token id been_fixed reported update another);
    my %input = map { $_ => scalar $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
 
    my ($error, $questionnaire, $num_questionnaire, $problem, $answered_ever_reported);
    try {
        ($questionnaire, $problem, $num_questionnaire, $answered_ever_reported) = check_stuff($q);
    } catch Error::Simple with {
        my $e = shift;
        $error = $e;
    };

    if ($error) {
        my %vars = (heading => _('Questionnaire'), 
                    error => $error->stringify());
        my $template_error = Page::template_include('error', $q, Page::template_root($q), %vars);
        return $template_error if $template_error;
        return $error;
    }
    # EHA questionnaires done for you
    if ($q->{site} eq 'emptyhomes') {
        $input{another} = $num_questionnaire==1 ? 'Yes' : 'No';
    }

    my @errors;
    push @errors, _('Please state whether or not the problem has been fixed') unless $input{been_fixed};
    my $ask_ever_reported = Cobrand::ask_ever_reported($cobrand);
    if ($ask_ever_reported) {
        push @errors, _('Please say whether you\'ve ever reported a problem to your council before') unless $input{reported} || $answered_ever_reported;
    }
    push @errors, _('Please indicate whether you\'d like to receive another questionnaire')
        if ($input{been_fixed} eq 'No' || $input{been_fixed} eq 'Unknown') && !$input{another};
    push @errors, _('Please provide some explanation as to why you\'re reopening this report')
        if $input{been_fixed} eq 'No' && $problem->{state} eq 'fixed' && !$input{update};
    return display_questionnaire($q, @errors) if @errors;

    my $fh = $q->upload('photo');
    my $image;
    if ($fh) {
        my $err = Page::check_photo($q, $fh);
        push @errors, $err if $err;
        try {
            $image = Page::process_photo($fh) unless $err;
        } catch Error::Simple with {
            my $e = shift;
            push(@errors, "That image doesn't appear to have uploaded correctly ($e), please try again.");
        };
    }
    push @errors, _('Please provide some text as well as a photo')
        if $image && !$input{update};
    return display_questionnaire($q, @errors) if @errors;

    my $new_state = '';
    $new_state = 'fixed' if $input{been_fixed} eq 'Yes' && $problem->{state} eq 'confirmed';
    $new_state = 'confirmed' if $input{been_fixed} eq 'No' && $problem->{state} eq 'fixed';

    # Record state change, if there was one
    dbh()->do("update problem set state=?, lastupdate=ms_current_timestamp()
        where id=?", {}, $new_state, $problem->{id})
        if $new_state;

    # If it's not fixed and they say it's still not been fixed, record time update
    dbh()->do("update problem set lastupdate=ms_current_timestamp()
        where id=?", {}, $problem->{id})
        if $input{been_fixed} eq 'No' && $problem->{state} eq 'confirmed';

    # Record questionnaire response
    my $reported = $input{reported}
        ? ($input{reported} eq 'Yes' ? 't' : ($input{reported} eq 'No' ? 'f' : undef))
        : undef;
    dbh()->do('update questionnaire set whenanswered=ms_current_timestamp(),
        ever_reported=?, old_state=?, new_state=? where id=?', {},
        $reported, $problem->{state}, $input{been_fixed} eq 'Unknown'
            ? 'unknown'
            : ($new_state ? $new_state : $problem->{state}),
        $questionnaire->{id});

    # Record an update if they've given one, or if there's a state change
    my $name = $problem->{anonymous} ? undef : $problem->{name};
    my $update = $input{update} ? $input{update} : _('Questionnaire filled in by problem reporter');
    Utils::workaround_pg_bytea("insert into comment
        (problem_id, name, email, website, text, state, mark_fixed, mark_open, photo, lang, cobrand, cobrand_data, confirmed)
        values (?, ?, ?, '', ?, 'confirmed', ?, ?, ?, ?, ?, ?, ms_current_timestamp())", 7,
        $problem->{id}, $name, $problem->{email}, $update,
        $new_state eq 'fixed' ? 't' : 'f', $new_state eq 'confirmed' ? 't' : 'f',
        $image, $mySociety::Locale::lang, $cobrand, $cobrand_data
    )
        if $new_state || $input{update};

    # If they've said they want another questionnaire, mark as such
    dbh()->do("update problem set send_questionnaire = 't' where id=?", {}, $problem->{id})
        if ($input{been_fixed} eq 'No' || $input{been_fixed} eq 'Unknown') && $input{another} eq 'Yes';
    dbh()->commit();

    my $out;
    my $message;
    my $advert_outcome = 1;
    if ($input{been_fixed} eq 'Unknown') {
        $message = _(<<EOF);
<p>Thank you very much for filling in our questionnaire; if you
get some more information about the status of your problem, please come back to the
site and leave an update.</p>
EOF
    } elsif ($new_state eq 'confirmed' || (!$new_state && $problem->{state} eq 'confirmed')) {
        my $wtt_url = Cobrand::writetothem_url($cobrand, $cobrand_data);
        $wtt_url = "http://www.writetothem.com" if (! $wtt_url);
        $message = sprintf(_(<<EOF), $wtt_url);
<p style="font-size:150%%">We're sorry to hear that. We have two suggestions: why not try
<a href="%s">writing direct to your councillor(s)</a>
or, if it's a problem that could be fixed by local people working together,
why not <a href="http://www.pledgebank.com/new">make and publicise a pledge</a>?
</p>
EOF
        $advert_outcome = 0;
    } else {
        $message = _(<<EOF);
<p style="font-size:150%">Thank you very much for filling in our questionnaire; glad to hear it's been fixed.</p>
EOF
    }
    $out = $message;
    my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
    if ($display_advert && $advert_outcome) {
        $out .= CrossSell::display_advert($q, $problem->{email}, $problem->{name},
            council => $problem->{council});
    }
    my %vars = (message => $message);
    my $template_page = Page::template_include('questionnaire-completed', $q, Page::template_root($q), %vars);
    return $template_page if ($template_page);
    return $out;
}

sub display_questionnaire {
    my ($q, @errors) = @_;
    my @vars = qw(token id been_fixed reported update another);
    my $cobrand = Page::get_cobrand($q);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;

    my ($error, $questionnaire, $num_questionnaire, $problem, $answered_ever_reported);
    try {
        ($questionnaire, $problem, $num_questionnaire, $answered_ever_reported) = check_stuff($q);
    } catch Error::Simple with {
        my $e = shift;
        $error = $e;
    };
    if ($error) {
        my %vars = (heading => _('Questionnaire'),
                    error => $error->stringify());
        my $template_error = Page::template_include('error', $q, Page::template_root($q), %vars);
        return $template_error if $template_error;
        return $error;
    }
    my $reported_date_time = Page::prettify_epoch($q, $problem->{time});
    my ($x, $y, $x_tile, $y_tile, $px, $py) = Page::os_to_px_with_adjust($q, $problem->{easting}, $problem->{northing}, undef, undef);

    my $pins = Page::display_pin($q, $px, $py, $problem->{state} eq 'fixed'?'green':'red');
    my $problem_text = Page::display_problem_text($q, $problem);
    my $updates = Page::display_problem_updates($problem->{id}, $q);

    my %vars = (
        input_h => \%input_h,
        map_start => Page::display_map($q, x => $x_tile, y => $y_tile, pins => $pins,
            px => $px, py => $py, pre => $problem_text, post => $updates ),
        map_end => Page::display_map_end(0),
        heading => _('Questionnaire'),
        yes => _('Yes'),
        no => _('No'),
        dontknow => _('Don&rsquo;t know'),
        submit => _('Submit questionnaire'),
        cobrand_form_elements => Cobrand::form_elements($cobrand, 'questionnaireForm', $q),
        form_action => Cobrand::url($cobrand, "/questionnaire", $q),
        reported_date_time => $reported_date_time
    );
    $vars{been_fixed} = {
        yes => $input{been_fixed} eq 'Yes' ? ' checked' : '',
        no => $input{been_fixed} eq 'No' ? ' checked' : '',
        unknown => $input{been_fixed} eq 'Unknown' ? ' checked' : '',
    };
    my $allow_photo_upload = Cobrand::allow_photo_upload($cobrand);
    if ($allow_photo_upload) {
         $vars{enctype} = 'enctype="multipart/form-data"';
    }
    if ($q->{site} eq 'emptyhomes') {
        if ($num_questionnaire==1) {
            $vars{blurb_eh} = _(<<EOF);
<p>Getting empty homes back into use can be difficult. You shouldn't expect
the property to be back into use yet. But a good council will have started work
and should have reported what they have done on the website. If you are not
satisfied with progress or information from the council, now is the right time
to say. You may also want to try contacting some other people who may be able
to help.  For advice on how to do this and other useful information please
go to <a href="http://www.emptyhomes.com/getinvolved/campaign.html">http://www.emptyhomes.com/getinvolved/campaign.html</a>.</p>
EOF
        } else {
            $vars{blurb_eh} = _(<<EOF);
<p>Getting empty homes back into use can be difficult, but by now a good council
will have made a lot of progress and reported what they have done on the
website. Even so properties can remain empty for many months if the owner is
unwilling or the property is in very poor repair.  If nothing has happened or
you are not satisfied with the progress the council is making, now is the right
time to say so. We think it's a good idea to contact some other people who
may be able to help or put pressure on the council  For advice on how to do
this and other useful information please go to <a
href="http://www.emptyhomes.com/getinvolved/campaign.html">http://www.emptyhomes.com/getinvolved/campaign.html</a>.</p>
EOF
        }
    }

    $vars{blurb_report} = _('The details of your problem are available on the right hand side of this page.');
    $vars{blurb_report2} = _('Please take a look at the updates that have been left.') if $updates;

    if (@errors) {
        $vars{errors} = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    $vars{fixed_question} = '';
    $vars{fixed_question} .= _('An update marked this problem as fixed.') . ' ' if $problem->{state} eq 'fixed';
    $vars{fixed_question} .= _('Has this problem been fixed?') . '</p>';

    unless ($answered_ever_reported) {
        my %reported = (
            yes => $input{reported} eq 'Yes' ? ' checked' : '',
            no => $input{reported} eq 'No' ? ' checked' : '', 
        );
        my $before = _('Reported before');
        my $first = _('First time');
        $vars{ever_reported} = $q->p(_('Have you ever reported a problem to a council before, or is this your first time?'));
        $vars{ever_reported} .= <<EOF;
<p>
<input type="radio" name="reported" id="reported_yes" value="Yes"$reported{yes}>
<label for="reported_yes">$before</label>
<input type="radio" name="reported" id="reported_no" value="No"$reported{no}>
<label for="reported_no">$first</label>
</p>
EOF
    }
    $vars{blurb_update} = $q->p(_('If you wish to leave a public update on the problem, please enter it here
(please note it will not be sent to the council). For example, what was
your experience of getting the problem fixed?'));
    if ($allow_photo_upload) {
         $vars{photo_input} = <<EOF;
<div id="fileupload_normalUI">
<label for="form_photo">Photo:</label>
<input type="file" name="photo" id="form_photo">
</div>
EOF
    }
    my %another = (
        yes => $input{another} eq 'Yes' ? ' checked' : '',
        no => $input{another} eq 'No' ? ' checked' : '', 
    );
    $vars{another_yes} = $another{yes};
    $vars{another_no} = $another{no};
    $vars{another_questionnaire} = <<EOF if $q->{site} ne 'emptyhomes';
<div id="another_qn">
<p>Would you like to receive another questionnaire in 4 weeks, reminding you to check the status?</p>
<p>
<input type="radio" name="another" id="another_yes" value="Yes"$another{yes}>
<label for="another_yes">Yes</label>
<input type="radio" name="another" id="another_no" value="No"$another{no}>
<label for="another_no">No</label>
</p>
</div>
EOF

    return Page::template_include('questionnaire', $q, Page::template_root($q), %vars);
}
