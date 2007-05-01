#!/usr/bin/perl -w

# faq.cgi:
# FAQ page for Neighbourhood Fix-It
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: faq.cgi,v 1.16 2007-05-01 16:24:40 matthew Exp $

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
    print Page::header($q, _('FAQ'));
    print faq($q);
    print Page::footer();
}
Page::do_fastcgi(\&main);

sub faq {
    my $q = shift;
    my $out = $q->h1(_('Frequently Asked Questions'));
    $out .= $q->dl(
        $q->dt(_('What is Neighbourhood Fix-It for?')),
        $q->dd(_('Neighbourhood Fix-It is a site to help people report, view,
or discuss local problems they&rsquo;ve found to their local council by
simply locating them on a map. It launched in beta early February
2007.')),
        $q->dt(_('Can you give me some examples?')),
        $q->dd(_('Sure. Graffiti, unlit lampposts, abandoned beds, broken
glass on a cycle path; anything like that that could be usefully reported to
your council to be fixed.')),
        $q->dt(_('How do I use the site?')),
        $q->dd(_('After entering a postcode or location, you are presented
with a map of that area. You can view problems already reported in that area,
or report ones of your own simply by clicking on the map at the location of
the problem.')),
        $q->dt(_('How are the problems solved?')),
        $q->dd(_('They are reported to the relevant council by email. The
council can then resolve the problem the way they normally would.
Alternatively, you can discuss the problem on the website with others, and
then together lobby the council to fix it, or fix it directly yourselves.')),
        $q->dt(_('Is it free?')),
        $q->dd(_('The site is free to use, yes. Neighbourhood Fix-It is run
by a registered charity, though, so if you want to make a contribution, <a
href="https://secure.mysociety.org/donate/">please do</a>.')),
    );
    $out .= $q->h2(_('Practical Questions'));
    $out .= $q->dl(
        $q->dt(_("I'm from a council, where do you send the reports?")),
        $q->dd(_('You can either leave a test report or <a href="/contact">contact us</a>
to find out where reports go at the moment. Also <a href="/contact">contact us</a>
to update the address or addresses we use.')),
        $q->dt(_('Do you remove silly or illegal content?')),
        $q->dd(_('We reserve the right to remove any problems or updates
which we consider to be inappropriate.')),
        $q->dt(_("Why doesn't dragging the map work on reporting-a-problem pages in Safari?")),
        $q->dd(_("There's a bug in Safari to do with setting images on form
submits, which the map is when reporting a problem. It's fixed in the
latest nightly build of Safari, so will presumably be fixed in the next
release. Until then, I've sadly had to disable dragging to avoid people
dragging an empty square."))
    );
    $out .= $q->h2(_('Privacy Questions'));
    $out .= $q->dl(
        $q->dt(_('Who gets to see my email address?')),
        $q->dd(_('If you submit a problem, we pass on your details, and details
of the problem, to the council contact or contacts responsible for the
area where you located the problem. Your name is displayed upon the
site, but not your email address; similarly with updates.  We will
never give or sell your email address to anyone else, unless we are
obliged to by law.')),
        $q->dt(_('Will you send nasty, brutish spam to my email address?')),
        $q->dd(_('Never. We will email you a month after you submit a
problem, asking for a status update. You can also opt in to receive emails
about updates to a particular problem.'))
    );
    $out .= $q->h2(_('Organisation Questions'));
    $out .= $q->dl(
        $q->dt(_('Who built Neighbourhood Fix-It?')),
        $q->dd(_('This site was built by <a href="http://www.mysociety.org">mySociety</a>. 
mySociety is the project of a registered charity which has grown out of the community of
volunteers who built sites like <a href="http://www.theyworkforyou.com/">TheyWorkForYou.com</a>. 
mySociety&rsquo;s primary mission is to build Internet projects which give people simple, tangible
benefits in the civic and community aspects of their lives. Our first project
was <a href="http://www.writetothem.com/">WriteToThem.com</a>, where you can write to any of your
elected representatives, for free.')),
        $q->dt(_('Who pays for it?')),
        $q->dd(_('Neighbourhood Fix-It was paid for via the Department for
Constitutional Affairs Innovations Fund.')),
        $q->dt(_('Do you need any help with the project?')),
        $q->dd(_('Yes, we can use help in all sorts of ways, technical or
non-technical.  Please see our <a
href="http://www.mysociety.org/volunteertasks">volunteers page</a>.')),
        $q->dt(_('Where&rsquo;s the "source code" to this site?')),
        $q->dd(_('The software behind this site is open source, and available
to you mainly under the Affero GPL software license. You can <a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety">download the
source code</a> (look under &lsquo;bci&rsquo;) and help us develop it.
You&rsquo;re welcome to use it in your own projects, although you must also
make available the source code to any such projects.')),
        $q->dt(_('People build things, not organisations. Who <em>actually</em> built it?')),
        $q->dd(_('OK, we are Francis Irving, Chris Lightfoot, Richard Pope,
Matthew Somerville, and Tom Steinberg.

Thanks also to
<a href="http://www.ordnancesurvey.co.uk">Ordnance Survey</a> (for the maps,
UK postcodes, and UK addresses &ndash; data &copy; Crown copyright, all
rights reserved, Department for Constitutional Affairs 100037819&nbsp;2007),
Yahoo! for their BSD-licensed JavaScript libraries, the entire free software
community (this particular project was brought to you by Perl, PostgreSQL,
and the number 161.290) and <a
href="http://www.easynet.net/publicsector/">Easynet</a> (who kindly host all
our servers).

Let us know if we&rsquo;ve missed anyone.'))
    );
    return $out;
}

