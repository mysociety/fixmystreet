#!/usr/bin/perl -w

# faq.cgi:
# FAQ page for Neighbourhood Fix-It
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: faq.cgi,v 1.4 2006-09-27 13:51:23 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use Page;

# Main code for index.cgi
sub main {
    my $q = shift;
    print Page::header($q, 'FAQ');
    print faq();
    print Page::footer();
}
Page::do_fastcgi(\&main);

sub faq {
    my $out = <<EOF;
<h1>Frequently Asked Questions</h1>

<dl>

<dt>What is Neighbourhood Fix-It for?</dt>
<dd>Neighbourhood Fix-It is a site to help people report, view, or discuss local problems
they've found to their local council by simply locating them on a map.</dd>

<dt>Can you give me some examples?</dt>
<dd>Sure. Graffiti, unlit lampposts, abandoned beds, broken glass on a cycle
path; anything like that that could be usefully reported to your council
to be fixed.</dd>

<dt>How does it work?</dt>
<dd>After entering a postcode, users are presented with a map of that
area. They can view problems already reported in that area, or report
ones of their own simply by clicking on the map at the location of the
problem.</dd>

<dt>Is it free?</dt>
<dd>The site is free to use, yes. Neighbourhood Fix-It
is run by a charitable organisation, though, so if you want to make
a contribution, please contact us.</dd>
</dl>

<dt>Do you remove silly or illegal content?</dt>
<dd>We reserve the right to remove any problems or comments which we
consider to be inappropriate.</dd>

<h2>Privacy Questions</h2>
<dl>

<dt>Who gets to see my email address?</dt>
<dd>If you submit a problem, we (do we?) pass on your name, email address, and details
of the problem to the council contact responsible for the area where you
located the problem. Your name is displayed upon the site, but not your email address;
similarly with comments.

We will never give or sell your
email address to anyone else, unless we are obliged to by law.

</dd>

<dt>Will you send nasty, brutish spam to my email address?</dt>
<dd>Never.  If you opt to when adding a problem or comment, you will receive emails 
about updates to that problem, but that's it.
</dd>


</dl>

<h2>Organisation Questions</h2>

<dl>

<dt>Who built Neighbourhood Fix-It?</dt>
<dd>This site was built by <a href="http://www.mysociety.org">mySociety</a>. 
mySociety is a charitable organisation which has grown out of this community of
volunteers who built sites like <a href="http://www.theyworkforyou.com/">TheyWorkForYou.com</a>. 
mySociety's primary
mission is to build Internet projects which give people simple, tangible
benefits in the civic and community aspects of their lives. Our first project
was <a href="http://www.writetothem.com/">WriteToThem.com</a>, where you can write to any of your
elected representatives, for free.</dd>

<dt>Who pays for it?</dt>
<dd>Neighbourhood Fix-It for Newham and Lewisham was paid for via the
Department for Constitutional Affairs Innovations Fund. mySociety itself
has put in some spare resources to cover wider parts of the UK.
</dd>

<dt>Do you need any help with the project?</dt>
<dd>Yes, we can use help in all sorts of ways, technical or non-technical.
Please see our <a href="http://www.mysociety.org/volunteertasks">volunteers page</a>.</dd>

<dt>Where's the "source code" to this site?</dt>
<dd>The software behind this site is open source, and available to you
mainly under the Affero GPL software license. You can <a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety">download the source
code</a> (look under 'bci') and help us develop it. You're welcome to use it
in your own projects, although you must also make available the source code to
any such projects.
</dd>

<dt>People build things, not organisations. Who <em>actually</em> built it?</dt>
<dd>OK, we are
Francis Irving,
Chris Lightfoot,
Richard Pope,
Matthew Somerville,
and
Tom Steinberg.

Thanks also to
<a href="http://www.ordnancesurvey.co.uk">Ordnance Survey</a> (for the maps and UK postcodes),
the entire free software community (FreeBSD, Linux, PHP, Perl, Python, Apache,
MySQL, PostgreSQL, we love and use you all!) and
<a href="http://www.easynet.net/publicsector/">Easynet</a> (who kindly host all
our servers).

Let us know if we've missed anyone.
</dd>

</dl>

EOF
    return $out;
}

