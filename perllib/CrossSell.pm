#!/usr/bin/perl -w
#
# CrossSell.pm:
# Adverts from FixMyStreet to another site.
#
# Unlike the PHP crosssell script, returns strings rather than prints them;
# and currently displays the same advert if e.g. there's a connection problem.
# 
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: CrossSell.pm,v 1.2 2007-09-25 13:30:21 matthew Exp $

# Config parameters site needs set to call these functions:
# OPTION_AUTH_SHARED_SECRET
# OPTION_HEARFROMYOURMP_BASE_URL

package CrossSell;

use strict;
use LWP::Simple qw($ua get);
$ua->timeout(5);
use URI::Escape;
use mySociety::AuthToken;

# Force site means always display this advert 
sub display_hfymp_advert ($;$$) {
    my ($user_email, $user_name, $postcode) = @_;
    my $auth_signature = mySociety::AuthToken::sign_with_shared_secret($user_email, mySociety::Config::get('AUTH_SHARED_SECRET'));

    # See if already signed up
    my $url = mySociety::Config::get('HEARFROMYOURMP_BASE_URL');
    my $already_signed = get($url . '/authed?email=' . uri_escape($user_email) . "&sign=" . uri_escape($auth_signature));
    # Different from PHP version; display this advert if e.g. connection problem
    return '' if $already_signed && $already_signed eq 'already signed';

    # If not, display advert
    $url .= '/?email=' . uri_escape($user_email) . '&sign=' . uri_escape($auth_signature);
    $url .= '&name=' . uri_escape($user_name) if $user_name;
    $url .= '&pc=' . uri_escape($postcode) if $postcode;
    return <<EOF;
<h2 style="padding: 1em; font-size: 200%" align="center">
Since you're interested in your local area, why not
start a <a href="$url">long term relationship</a> with your MP?
</h2>
EOF
    return 1;
}

# Choose appropriate advert and display it.
# $this_site is to stop a site advertising itself.
sub display_advert ($;$$) {
    my ($user_email, $user_name, $postcode) = @_;
    my $out = display_hfymp_advert($user_email, $user_name, $postcode);
    # $out ||= display_twfy_alerts_advert($user_email, $postcode);
    $out ||= <<EOF;
<h2 style="padding: 1em; font-size: 200%" align="center">
If you're interested in improving your local area,
<a href="http://www.pledgebank.com/">use PledgeBank</a> to
do so with other people!</h2>
EOF
    return $out;
}

1;
