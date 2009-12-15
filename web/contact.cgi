#!/usr/bin/perl -w -I../perllib

# contact.cgi:
# Contact page for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: contact.cgi,v 1.54 2009-12-15 15:07:01 matthew Exp $

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
    print Page::header($q, title=>_('Contact Us'), context=>'contact');
    my $out = '';
    if ($q->param('submit_form')) {
        $out = contact_submit($q);
    } else {
        $out = contact_page($q, [], {});
    }
    print $out;
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub contact_submit {
    my $q = shift;
    my @vars = qw(name em subject message id update_id);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my $cobrand = Page::get_cobrand($q);
    my @errors;
    my %field_errors;
    $field_errors{name} = _('Please give your name') unless $input{name} =~ /\S/;
    if ($input{em} !~ /\S/) {
        $field_errors{email} = _('Please give your email');
    } elsif (!mySociety::EmailUtil::is_valid_email($input{em})) {
        $field_errors{email} = _('Please give a valid email address');
    }
    $field_errors{subject} = _('Please give a subject') unless $input{subject} =~ /\S/;
    $field_errors{message} = _('Please write a message') unless $input{message} =~ /\S/;
    push(@errors, _('Illegal ID')) if (($input{id} && $input{id} !~ /^[1-9]\d*$/) || ($input{update_id} && $input{update_id} !~ /^[1-9]\d*$/));
    return contact_page($q, \@errors, \%field_errors) if (@errors || scalar keys %field_errors);

    (my $message = $input{message}) =~ s/\r\n/\n/g;
    (my $subject = $input{subject}) =~ s/\r|\n/ /g;
    my $extra_data = Cobrand::extra_data($cobrand, $q);
    my $base_url = Cobrand::base_url_for_emails($cobrand, $extra_data); 
    my $admin_base_url = Cobrand::admin_base_url($cobrand);
    if (!$admin_base_url) {
        $admin_base_url = "https://secure.mysociety.org/admin/bci/";
    }
    if ($input{id} && $input{update_id}) {
         $message .= "\n\n[ Complaint about update $input{update_id} on report $input{id} - "
        . $base_url . "/report/$input{id}#update_$input{update_id} - "
        . "$admin_base_url?page=update_edit;id=$input{update_id} ]";
    } elsif ($input{id}) {
         $message .= "\n\n[ Complaint about report $input{id} - "
        . $base_url . "/report/$input{id} - "
        . "$admin_base_url?page=report_edit;id=$input{id} ]";
    }
    my $postfix = '[ Sent by contact.cgi on ' .
        $ENV{'HTTP_HOST'} . '. ' .
        "IP address " . $ENV{'REMOTE_ADDR'} .
        ($ENV{'HTTP_X_FORWARDED_FOR'} ? ' (forwarded from '.$ENV{'HTTP_X_FORWARDED_FOR'}.')' : '') . '. ' .
        ' ]';

    my $recipient = Cobrand::contact_email($cobrand);
    my $recipient_name = Cobrand::contact_name($cobrand);
    my $email = mySociety::Email::construct_email({
        _body_ => "$message\n\n$postfix",
        From => [$input{em}, $input{name}],
        To => [[$recipient, _($recipient_name)]],
        Subject => 'FMS message: ' . $subject,
        'Message-ID' => sprintf('<contact-%s-%s@mysociety.org>', time(), unpack('h*', random_bytes(5, 1))),
    });
    my $result = mySociety::EmailUtil::send_email($email, $input{em}, $recipient);
    if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
        my $out = $q->p(_("Thanks for your feedback.  We'll get back to you as soon as we can!"));
        my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
        if ($display_advert) {
            $out .= CrossSell::display_advert($q, $input{em}, $input{name}, emailunvalidated=>1 );
        }
        return $out;
    } else {
        return $q->p('Failed to send message.  Please try again, or <a href="mailto:' . $recipient . '">email us</a>.');
    }
}

sub contact_details {
    my ($q) = @_;
    my $out = '';
    my $sitename = _('FixMyStreet');
    my $contact_info = '';
    $contact_info .= <<EOF;
<div class="contact-details">
<p>$sitename is a service provided by mySociety, which is the project of a 
registered charity. The charity is called UK Citizens Online Democracy and is charity number 1076346.</p>
<p>mySociety can be contacted by email at <a href="mailto:team\@mysociety.org">team\@mysociety.org</a>,
or by post at:</p>
<p>mySociety.org<br>
12 Duke's Road<br>
London<br>
WC1H 9AD<br>
UK</p>
</div>
EOF
    $out .= $contact_info unless $q->{site} eq 'emptyhomes'; 
    return $out;
}

sub contact_page {
    my ($q, $errors, $field_errors) = @_;
    my @errors = @$errors;
    my %field_errors = %{$field_errors};
    push @errors, _('There were problems with your report. Please see below.') if (scalar keys %field_errors);
    my @vars = qw(name em subject message);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
    my $out = '';
    my $header = _('Contact the team');
    $errors = '';

    if (@errors) {
        $errors = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    my $cobrand = Page::get_cobrand($q);
    my $form_action = Cobrand::url($cobrand, '/contact', $q);

    my $intro = '';
    my $item_title = '';
    my $item_body = '';
    my $item_meta = '';
    my $hidden_vals = '';
    my $id = $q->param('id');
    my $update_id = $q->param('update_id');
    $id = undef unless $id && $id =~ /^[1-9]\d*$/;
    $update_id = undef unless $update_id && $update_id =~ /^[1-9]\d*$/;
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
        if ($update_id) {
             my $u = dbh()->selectrow_hashref(
            'select comment.text, comment.name, problem.title, extract(epoch from comment.created) as created
            from comment, problem where comment.id=? 
            and comment.problem_id = problem.id
            and comment.problem_id=?', {}, $update_id ,$id);
            $intro .= $q->p(_('You are reporting the following update for being abusive, containing personal information, or similar:'));
            $item_title =  ent($u->{title});
            $item_meta = $q->em( 'Update below added ', ($u->{name} eq '') ? 'anonymously' : "by " . ent($u->{name}),
                                 ' at ' . Page::prettify_epoch($q, $u->{created}));
            $item_body = ent($u->{text});
            $hidden_vals .= '<input type="hidden" name="update_id" value="' . $update_id . '">';
        } else {
            $intro .= $q->p(_('You are reporting the following problem report for being abusive, containing personal information, or similar:'));
            $item_title = ent($p->{title});
            $item_meta = $q->em(
               'Reported ',
               ($p->{anonymous}) ? 'anonymously' : "by " . ent($p->{name}),
               ' at ' . Page::prettify_epoch($q, $p->{created}));
            $item_body = ent($p->{detail});
        }
	$hidden_vals .= '<input type="hidden" name="id" value="' . $id . '">';
    } elsif ($q->{site} eq 'emptyhomes') {
        $intro .= $q->p(_('We&rsquo;d love to hear what you think about this
website. Just fill in the form. Please don&rsquo;t contact us about individual empty
homes; use the box accessed from <a href="/">the front page</a>.')); 
    } else {
        my $mailto = mySociety::Config::get('CONTACT_EMAIL');
        $mailto =~ s/\@/&#64;/;
        $intro .= $q->p(_('Please do <strong>not</strong> report problems through this form; messages go to
the team behind FixMyStreet, not a council. To report a problem,
please <a href="/">go to the front page</a> and follow the instructions.'));
        $intro .= $q->p(sprintf(_("We'd love to hear what you think about this site. Just fill in the form, or send an email to <a href='mailto:%s'>%s</a>:"), $mailto, $mailto));
    }
    my $cobrand_form_elements = Cobrand::form_elements(Page::get_cobrand($q), 'contactForm', $q);
    my %vars = (
      header => $header,
      errors => $errors,
      intro => $intro,
      item_title => $item_title, 
      item_meta => $item_meta,
      item_body => $item_body,
      hidden_vals => $hidden_vals,
      form_action => $form_action, 
      input_h => \%input_h,
      field_errors => \%field_errors,
      label_name => _('Your name:'),
      label_email => _('Your&nbsp;email:'),
      label_subject => _('Subject:'),
      label_message => _('Message:'),
      label_submit => _('Post'),
      contact_details => contact_details($q),
      cobrand_form_elements => $cobrand_form_elements
    );
    $out .= Page::template_include('contact', $q, Page::template_root($q), %vars);
    return $out;
}

