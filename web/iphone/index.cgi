#!/usr/bin/perl -w -I../../perllib -I../../../perllib

# iphone/index.cgi:
# Screenshots of the iPhone FixMyStreet application, showing the flow
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.1 2008-10-29 15:30:15 matthew Exp $

use strict;
use Standard -db;
use mySociety::Config;
use mySociety::Web qw(ent);

# XXX: Ugh, as we're in a subdirectory
BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../../conf/general");
}

my @screens = (
"iphone-1start.png", 'Click the image to progress through the flow of using the iPhone FixMyStreet application.
<br>When launched, the user&rsquo;s location automatically gets fetched&hellip;',
"iphone-2locfound.png", 'They want to take a photo.',
"iphone-pickpicture1.png", 'The simulator doesn&rsquo;t have a camera, so we&rsquo;re taken to the photo albums. Let&rsquo;s pick Hawaii.',
"iphone-pickpicture2.png", 'That red clouds photo looks nice.',
"iphone-pickpicture3.png", 'After any moving or scaling we want, we select the photo.',
"iphone-3picture.png", 'Okay, now we need to edit the summary of the report.',
"iphone-editsummary.png", 'Enter some text.',
"iphone-editsummary2.png", 'And done.',
"iphone-4subject.png", 'I haven&rsquo;t entered all my details yet, so that&rsquo;s next.',
"iphone-5details.png", 'Your details are remembered so you only have to enter them once.',
"iphone-6emailkeyboard.png", 'The iPhone has different keyboards, this is the email one.',
"iphone-5details.png", 'Right, we need to enter a name.',
"iphone-editname.png", 'Slightly different keyboard to the email one.',
"iphone-detailsdone.png", 'Okay, details entered.',
"iphone-allready.png", 'That&rsquo;s everything, hit Report!',
"iphone-7uploading.png", 'Uploading&hellip;',
"iphone-8response.png", 'The simulator always thinks it&rsquo;s in the US, which FixMyStreet won&rsquo;t like very much.',
"iphone-allready.png", 'Ah well, let&rsquo;s read the About page instead',
"iphone-9about.png", 'Donate? :)',
);

sub main {
    my $q = shift;
    print Page::header($q, title=>'FixMyStreet for iPhone screenshots');
    print '<h1>iPhone simulator simulator</h1>';
    my $screens = scalar @screens / 2;
    print <<EOF;
<script type="text/javascript">
document.write('<style type="text/css">.vv { display: none; }</style>');
function show(a) {
    if (a==$screens) b = 1;
    else b = a+1;
    document.getElementById('d' + a).style.display='none';
    document.getElementById('d' + b).style.display='block';
}
</script>
EOF
    for (my $i=0; $i<@screens; $i+=2) {
        my $t = $i/2 + 1;
	my $next = $t + 1;
        print "<div id='d$t'";
        print " class='vv'" if $i>1;
        print ">";
        print "<p>$screens[$i+1]</p>";
        print "<p align='center'><a onclick='show($t);return false' href='#d$next'><img src='$screens[$i]' width=414 border=0 height=770></a></p>";
        print '</div>';
    }
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

