#!/usr/bin/perl -w -I../perllib

# contact.cgi:
# Contact page for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: contact.cgi,v 1.33 2008-10-08 14:38:29 matthew Exp $

use strict;
use Standard;
use CrossSell;
use mySociety::Email;
use mySociety::EmailUtil;
use mySociety::Web qw(ent);
use mySociety::Random qw(random_bytes);

# Main code for index.cgi
sub main {
    my $q = shift;
    print Page::header($q, title=>_('Contact Us'));
    my $out = '';
    if ($q->param('submit_form')) {
        $out = contact_submit($q);
    } else {
        $out = contact_page($q);
    }
    print $out;
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub contact_submit {
    my $q = shift;
    my @vars = qw(name em subject message id);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my @errors;
    push(@errors, _('Please give your name')) unless $input{name} =~ /\S/;
    if ($input{em} !~ /\S/) {
        push(@errors, _('Please give your email'));
    } elsif (!mySociety::EmailUtil::is_valid_email($input{em})) {
        push(@errors, _('Please give a valid email address'));
    }
    push(@errors, _('Please give a subject')) unless $input{subject} =~ /\S/;
    push(@errors, _('Please write a message')) unless $input{message} =~ /\S/;
    push(@errors, _('Illegal ID')) if $input{id} && $input{id} !~ /^[1-9]\d*$/;
    return contact_page($q, @errors) if @errors;

    (my $message = $input{message}) =~ s/\r\n/\n/g;
    (my $subject = $input{subject}) =~ s/\r|\n/ /g;
    $message .= "\n\n[ Complaint about report $input{id} - "
        . mySociety::Config::get('BASE_URL') . "/report/$input{id} ]"
        if $input{id};
    my $postfix = '[ Sent by contact.cgi on ' .
        $ENV{'HTTP_HOST'} . '. ' .
        "IP address " . $ENV{'REMOTE_ADDR'} .
        ($ENV{'HTTP_X_FORWARDED_FOR'} ? ' (forwarded from '.$ENV{'HTTP_X_FORWARDED_FOR'}.')' : '') . '. ' .
        ' ]';
    my $email = mySociety::Email::construct_email({
        _body_ => "$message\n\n$postfix",
        From => [$input{em}, $input{name}],
        To => [[mySociety::Config::get('CONTACT_EMAIL'), _('FixMyStreet')]],
        Subject => 'FMS message: ' . $subject,
        'Message-ID' => sprintf('<contact-%s-%s@mysociety.org>', time(), unpack('h*', random_bytes(5))),
    });
    my $result = mySociety::EmailUtil::send_email($email, $input{em}, mySociety::Config::get('CONTACT_EMAIL'));
    if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
        my $out = $q->p(_("Thanks for your feedback.  We'll get back to you as soon as we can!"));
        $out .= CrossSell::display_advert($q, $input{em}, $input{name}, emailunvalidated=>1 );
        return $out;
    } else {
        return $q->p('Failed to send message.  Please try again, or <a href="mailto:' . mySociety::Config::get('CONTACT_EMAIL') . '">email us</a>.');
    }
}

sub contact_page {
    my ($q, @errors) = @_;
    my @vars = qw(name em subject message);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;

    my $out = $q->h1(_('Contact the team'));
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    $out .= '<form method="post">';

    my $id = $q->param('id');
    $id = undef unless $id && $id =~ /^[1-9]\d*$/;
    if ($id) {
        mySociety::DBHandle::configure(
            Name => mySociety::Config::get('BCI_DB_NAME'),
            User => mySociety::Config::get('BCI_DB_USER'),
            Password => mySociety::Config::get('BCI_DB_PASS'),
            Host => mySociety::Config::get('BCI_DB_HOST', undef),
            Port => mySociety::Config::get('BCI_DB_PORT', undef)
        );
        my $p = dbh()->selectrow_hashref(
            'select title,detail,name,anonymous,extract(epoch from created) as created
            from problem where id=?', {}, $id);
        $out .= $q->p(_('You are reporting the following problem report for being abusive, containing personal information, or similar:'));
        $out .= $q->blockquote(
            $q->h2(ent($p->{title})),
            $q->p($q->em(
         'Reported ',
         ($p->{anonymous}) ? 'anonymously' : "by " . ent($p->{name}),
         ' at ' . Page::prettify_epoch($p->{created}),
            )),
            $q->p(ent($p->{detail}))
        );
        $out .= '<input type="hidden" name="id" value="' . $id . '">';
    } elsif ($q->{site} eq 'emptyhomes') {
	$out .= $q->p('We&rsquo;d love to hear what you think about this
website. Just fill in the form. Please don&rsquo;t contact us about individual empty
homes; use the box accessed from <a href="/">the front page</a>.'); 
    } else {
        $out .= $q->p(_('Please do <strong>not</strong> report problems through this form; messages go to
the team behind FixMyStreet, not a council. To report a problem,
please <a href="/">go to the front page</a> and follow the instructions.'));
        $out .= $q->p(_("We'd love to hear what you think about this site. Just fill in the form:"));
    }
    my $label_name = _('Your name:');
    my $label_email = _('Your&nbsp;email:');
    my $label_subject = _('Subject:');
    my $label_message = _('Message:');
    my $label_submit = _('Post');
    $out .= <<EOF;
<fieldset>
<input type="hidden" name="submit_form" value="1">
<div><label for="form_name">$label_name</label>
<input type="text" name="name" id="form_name" value="$input_h{name}" size="30"></div>
<div><label for="form_email">$label_email</label>
<input type="text" name="em" id="form_email" value="$input_h{em}" size="30"></div>
<div><label for="form_subject">$label_subject</label>
<input type="text" name="subject" id="form_subject" value="$input_h{subject}" size="30"></div>
<div><label for="form_message">$label_message</label>
<textarea name="message" id="form_message" rows="7" cols="50">$input_h{message}</textarea></div>
<div class="checkbox"><input type="submit" value="$label_submit"></div>
</fieldset>
</form>
</div>
EOF
    return $out;
}

