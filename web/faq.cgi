#!/usr/bin/perl -w -I../perllib

# faq.cgi:
# FAQ page for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: faq.cgi,v 1.39 2009-03-21 00:40:26 matthew Exp $

use strict;
use Standard -db;

my $lastmodified = (stat $0)[9];

sub main {
    my $q = shift;
    print Page::header($q, title=>_('Frequently Asked Questions'));
    if ($q->{site} eq 'emptyhomes') {
        print emptyhomes_faq($q);
    } else {
        print faq($q);
    }
    print Page::footer($q);
}
Page::do_fastcgi(\&main, $lastmodified);

sub faq {
    my $q = shift;
    my $out = $q->h1(_('Frequently Asked Questions'));
    $out .= $q->dl(
        $q->dt(_('What is FixMyStreet for?')),
        $q->dd(_('FixMyStreet is a site to help people report, view,
or discuss local problems they&rsquo;ve found to their local council by
simply locating them on a map. It launched in early February
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
        $q->dd(_('The site is free to use, yes. FixMyStreet is run
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
        $q->dd(_('FixMyStreet is not responsible for the content and accuracy
of material submitted by its users. All reports are accepted on the basis that
they contain no illegal content, and we reserve the right to remove any
problems or updates which we consider to be inappropriate upon being informed
by a user of the site.')),
        $q->dt(_("Why doesn't dragging the map work on reporting-a-problem pages in Safari or Konqueror?")),
        $q->dd(_("There's a bug in these two browsers to do with setting images on form
submit buttons, which the map uses when reporting a problem. It's fixed in the
latest nightly build of Safari, so will presumably be fixed in the next
release. Until then, I've sadly had to disable dragging to avoid people
dragging an empty square.")),
        $q->dt(_('Do you have any publicity material?')),
        $q->dd(_('Sure, we have a whole <a href="posters/">array of posters, flyers and badges</a>.')),
    );
    $out .= $q->h2(_('Privacy Questions'));
    $out .= $q->dl(
        $q->dt(_('Who gets to see my email address?')),
        $q->dd(_('If you submit a problem, we pass on your details, and details
of the problem, to the council contact or contacts responsible for the
area where you located the problem. Your name is displayed upon the
site if you let us, but not your email address; similarly with updates.  We will
never give or sell your email address to anyone else, unless we are
obliged to by law.')),
        $q->dt(_('Will you send nasty, brutish spam to my email address?')),
        $q->dd(_('Never. We will email you if someone leaves an update on a
problem you&rsquo;ve reported, and send you a questionnaire email four weeks
after you submit a problem, asking for a status update; we&rsquo;ll only ever
send you emails in relation to your problem.'))
    );
    $out .= $q->h2(_('Organisation Questions'));
    $out .= $q->dl(
        $q->dt(_('Who built FixMyStreet?')),
        $q->dd(_('This site was built by <a href="http://www.mysociety.org/">mySociety</a>, in conjunction with the <a href="http://www.youngfoundation.org.uk/">Young Foundation</a>. 
mySociety is the project of a registered charity which has grown out of the community of
volunteers who built sites like <a href="http://www.theyworkforyou.com/">TheyWorkForYou.com</a>. 
mySociety&rsquo;s primary mission is to build Internet projects which give people simple, tangible
benefits in the civic and community aspects of their lives. Our first project
was <a href="http://www.writetothem.com/">WriteToThem</a>, where you can write to any of your
elected representatives, for free.')),
        $q->dt('<img src="/i/moj.png" align="right" alt="Ministry of Justice" hspace="10">' .
            _('Who pays for it?')),
        $q->dd(_('FixMyStreet was paid for via the Department for
Constitutional Affairs Innovations Fund.')),
        $q->dt(_('<a name="nfi"></a>Wasn\'t this site called Neighbourhood Fix-It?')),
        $q->dd(_('Yes, we changed the name mid June 2007. We decided
Neighbourhood Fix-It was a bit of a mouthful, hard to spell, and hard to publicise (does the URL have a dash in it or not?). The domain FixMyStreet became available recently, and everyone liked the name.')),
        $q->dt(_('Do you need any help with the project?')),
        $q->dd(_('Yes, we can use help in all sorts of ways, technical or
non-technical.  Please see our <a
href="http://www.mysociety.org/volunteertasks">volunteers page</a>.')),
        $q->dt(_('Where&rsquo;s the "source code" to this site?')),
        $q->dd(_('The software behind this site is open source, and available
to you mainly under the GNU Affero GPL software license. You can <a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety">download the
source code</a> (look under &lsquo;bci&rsquo;) and help us develop it.
You&rsquo;re welcome to use it in your own projects, although you must also
make available the source code to any such projects.')),
        $q->dt(_('People build things, not organisations. Who <em>actually</em> built it?')),
        $q->dd(_('Matthew Somerville and Francis Irving wrote the site,
Chris Lightfoot wrote the tileserver and map cutter, Richard Pope created
our pins, Deborah Kerr keeps things up-to-date and does user support,
Ayesha Garrett designed our posters, and Tom Steinberg managed it all.

Thanks also to
<a href="http://www.ordnancesurvey.co.uk">Ordnance Survey</a> (for the maps,
UK postcodes, and UK addresses &ndash; data &copy; Crown copyright, all
rights reserved, Ministry of Justice 100037819&nbsp;2008),
Yahoo! for their BSD-licensed JavaScript libraries, the entire free software
community (this particular project was brought to you by Perl, PostgreSQL,
and the number 161.290) and <a
href="http://www.easynet.net/publicsector/">Easynet</a> (who kindly host all
our servers).

Let us know if we&rsquo;ve missed anyone.'))
    );
    return $out;
}

sub emptyhomes_faq {
    my $q = shift;
    my $out = $q->h1('Frequently Asked Questions');
    $out .= $q->dl(
        $q->dt('What is this site for?'),
        $q->dd('This site is to help make it as easy as possible for you to get
empty homes in your area put back into use. It allows you, to view empty homes
that have been reported and see what has been done about them. It makes
councils accountable for responding and dealing with the empty homes you
report.'),
        $q->dt('How do I use the site?'),
        $q->dd('Enter a postcode or address in the box on the homepage and you
are presented with a map of that area. Click where the empty property is, fill
in the details, upload a photo if you have one and press submit. That&rsquo;s
it. You can also view other empty properties that have been reported and see
what has been done about them.'),
        $q->dt('Is it free?'),
        $q->dd('Yes. The costs of developing and running this site have been
paid for by The Empty Homes Agency and through the generosity of its funders.
The Empty Homes Agency is a charity, so if you believe in our aims and would
like to make a contribution, <a href="http://www.emptyhomes.com/donate.html">please do</a>.'),
        $q->dt('Do you remove silly or illegal content?'),
        $q->dd('We reserve the right to remove any reports or updates
which we consider to be inappropriate.'),
        $q->dt('How do councils bring empty properties back into use?'),
        $q->dd($q->p('All councils in England and Wales have powers to bring empty
homes back into use. Many are very good at it, some are not. Most councils seek
to persuade and help the owner to bring their property back into use; they only
use legal powers such as Empty Dwelling Management Orders when help and
persuasion have failed.'), $q->p('  
Most empty homes are brought back into use eventually by their owner. But in
many cases this takes years. Empty homes often decline fast &ndash; they become
overrun with weeds and attacked by the weather. They are often used by
squatters, fly tippers, vandals and are sometimes subject to arson. The whole
neighbourhood suffers waiting for the owner to deal with their property.'), $q->p('
Councils help and persuade owners to bring their properties into use faster.
Even so the process can be slow, especially if the property is in very poor
repair or the owner is unwilling to do anything. In most cases it takes six
months before you can expect to see anything change, occasionally longer.  This
doesn&rsquo;t mean the council isn&rsquo;t doing anything, which is why we encourage
councils to update the website so you can see what is happening.'), $q->p('
We will contact you twice (a month and six months after you report the empty
home) so you can tell us what has happened. If the council doesn&rsquo;t do anything,
or you think their response is inadequate we will advise you what you can do
next.'), $q->p('
If the empty home is owned by the government or one its agencies, councils are
often powerless to help. However you might be able to take action directly
yourself using a PROD:
<a href="http://www.emptyhomes.com/usefulinformation/policy_docs/prods.html">http://www.emptyhomes.com/usefulinformation/policy_docs/prods.html</a>
')),
        $q->dt('Will reporting an empty home make any difference?'),
        $q->dd($q->p('Yes. Councils can make a real difference, but they have lots of
things to do. Many councils only deal with empty homes that are reported to
them. If people do not report empty homes, councils may well conclude that
other areas of work are more important.'), $q->p('
There are over 840,000 empty homes in the UK. The Empty Homes Agency estimates
that over half of these are unnecessarily empty. The effect of this is to
significantly reduce the available housing stock fuelling the UK&rsquo;s housing
crisis.  A by-product of this waste is that far greater pressure is put on
building land as more homes are built to meet the shortfall. The Empty Homes
Agency estimate that bringing just a quarter of the UK&rsquo;s empty homes into use
would provide homes for 700,000 people, save 160 square kilometres of land and
save 10 million tonnes of CO<sub>2</sub> over building the same number of new homes.
')),
    );
    $out .= $q->h2(_('Privacy Questions'));
    $out .= $q->dl(
        $q->dt('Who gets to see my email address?'),
        $q->dd('If you submit an empty property, your details are obviously provided to us.
Your name is displayed upon the site if you let us, but not your email address;
similarly with updates.  We will never give or sell your email address to
anyone else, unless we are obliged to by law.'),
        $q->dt('Will you send nasty, brutish spam to my email address?'),
        $q->dd('Never. We will email you if someone leaves an update on a
report you&rsquo;ve made, and send you questionnaire emails four weeks and six months
after you submit a problem, asking for a status update; we&rsquo;ll only ever
send you emails in relation to your problem.')
    );
    $out .= $q->h2(_('Organisation Questions'));
    $out .= $q->dl(
        $q->dt('Who built this site?'),
        $q->dd('This site was built by <a href="http://www.mysociety.org/">mySociety</a>. 
mySociety is the project of a registered charity which has grown out of the community of
volunteers who built sites like <a href="http://www.theyworkforyou.com/">TheyWorkForYou</a>. 
mySociety&rsquo;s primary mission is to build Internet projects which give people simple, tangible
benefits in the civic and community aspects of their lives. Our first project
was <a href="http://www.writetothem.com/">WriteToThem</a>, where you can write to any of your
elected representatives, for free.
<a href="https://secure.mysociety.org/donate/">Donate to mySociety</a>'),
        $q->dt(_('Where&rsquo;s the "source code" to this site?')),
        $q->dd(_('The software behind this site is open source, and available
to you mainly under the GNU Affero GPL software license. You can <a
href="https://secure.mysociety.org/cvstrac/dir?d=mysociety">download the
source code</a> (look under &lsquo;bci&rsquo;) and help us develop it.
You&rsquo;re welcome to use it in your own projects, although you must also
make available the source code to any such projects.')),
        $q->dt(_('People build things, not organisations. Who <em>actually</em> built it?')),
        $q->dd(_('This adaptation of <a href="http://www.fixmystreet.com/">Fix&shy;MyStreet</a>
was written by Matthew Somerville. Thanks go to
<a href="http://www.ordnancesurvey.co.uk">Ordnance Survey</a> (for the maps,
UK postcodes, and UK addresses &ndash; data &copy; Crown copyright, all
rights reserved, Ministry of Justice 100037819&nbsp;2008),
Yahoo! for their BSD-licensed JavaScript libraries, the entire free software
community (this particular project was brought to you by Perl, PostgreSQL,
and the number 161.290) and <a
href="http://www.easynet.net/publicsector/">Easynet</a> (who kindly host all
our servers).

Let us know if we&rsquo;ve missed anyone.'))
    );
    return $out;
}

