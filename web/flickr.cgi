#!/usr/bin/perl -w -I../perllib

# flickr.cgi:
# Register for Flickr usage, and update photos
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: flickr.cgi,v 1.6 2007-10-22 18:00:04 matthew Exp $

use strict;
use Standard;
use LWP::Simple;
use mySociety::AuthToken;
use mySociety::Email;
use mySociety::EmailUtil;
use mySociety::Random qw(random_bytes);

sub main {
    my $q = shift;
    print Page::header($q, title=>'Flickr photo upload');
    my $out = '';
    if (my $token = $q->param('token')) {
        my $email = mySociety::AuthToken::retrieve('flickr', $token);
        if ($email) {
            my $key = mySociety::Config::get('FLICKR_API');
            my $url = 'http://api.flickr.com/services/rest/?method=flickr.people.findByEmail&api_key='.$key.'&find_email='.$email;
            my $result = get($url);
            my ($nsid) = $result =~ /nsid="([^"]*)"/;
            $url = 'http://api.flickr.com/services/rest/?method=flickr.people.getInfo&api_key='.$key.'&user_id='.$nsid;
            $result = get($url);
            my ($name) = $result =~ /<realname>(.*?)<\/realname>/;
            $name ||= '';

            my $id = dbh()->selectrow_array("select nextval('flickr_id_seq');");
            dbh()->do("insert into flickr (id, nsid, name, email) values (?, ?, ?, ?)", {},
                $id, $nsid, $name, $email);
            dbh()->commit();
            $out .= $q->p('Thanks for confirming your email address. Please now tag
your photos with FixMyStreet (and geo-tag them if you want/can, automatically if possible!)
for us to pick them up.');
        } else {
            $out = $q->p(_(<<EOF));
Thank you for trying to register for your Flickr photos. We seem to have a
problem ourselves though, so <a href="/contact">please let us know what went on</a>
and we'll look into it.
EOF
        }
    } elsif (my $email = $q->param('email')) {
        my $template = File::Slurp::read_file("$FindBin::Bin/../templates/emails/flickr-confirm");
        my %h = ();
        my $token = mySociety::AuthToken::store('flickr', $email);
        $h{url} = mySociety::Config::get('BASE_URL') . '/F/' . $token;

        my $body = mySociety::Email::construct_email({
            _template_ => $template,
            _parameters_ => \%h,
            To => $email,
            From => [ mySociety::Config::get('CONTACT_EMAIL'), 'FixMyStreet' ],
            'Message-ID' => sprintf('<flickr-%s-%s@mysociety.org>', time(), unpack('h*', random_bytes(5))),
        });

        my $result;
        $result = mySociety::EmailUtil::send_email($body, mySociety::Config::get('CONTACT_EMAIL'), $email);
        if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
            $out = 'Thanks, we\'ve sent you a confirmation email!';
            dbh()->commit();
        } else {
            $out = 'Sorry, something went wrong - very alpha!';
            dbh()->rollback();
        }
    } else {
        $out .= <<EOF;
<p><strong>This feature was added for HackDay London 2007, and might not be of production quality.</strong>
Please <a href="/contact">send bug reports to us</a>.</p>
<p>Using the Flickr API, FixMyStreet can utilise all the methods of uploading photos to Flickr
to report problems to your council:</p>
<ol>
<li>Register that you're going to be using Flickr here, so we know to check your photos.
<li>Upload your photo to Flickr, for example via camera phone on location
<li>Tag the photo with FixMyStreet when uploading, or afterwards
<li>Locate the problem on Flickr's map (if you have GPS, this might be done automatically :) )
<li>FixMyStreet will find the photo, and ask you to add/ check the details;
<li>The report is then sent to the council.
</ol>

<form method="post">
<p>To begin, please enter your Flickr email address, both so we know the account to watch and
so we can email you when you upload FixMyStreet photos with a link to check and confirm
the details: <input type="text" name="email" value="" size="30">
<input type="submit" value="Go">
</p></form>
EOF
    }

    print $out;
    print Page::footer();
}
Page::do_fastcgi(\&main);

