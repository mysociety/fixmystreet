use FixMyStreet::Test;

use_ok 'FixMyStreet::Template';

my $tt = FixMyStreet::Template->new;

my $output = '';
$tt->process(\'[% s %] [% s | safe %] [% s | upper %] [% s | html %]', {
    s => 'sp<i>l</i>it'
}, \$output);
is $output, 'sp&lt;i&gt;l&lt;/i&gt;it sp<i>l</i>it SP&lt;I&gt;L&lt;/I&gt;IT sp&lt;i&gt;l&lt;/i&gt;it';

$output = '';
$tt->process(\'[% s | html_para %]', { s => 'sp<i>l</i>it' }, \$output);
is $output, "<p>\nsp&lt;i&gt;l&lt;/i&gt;it</p>\n";

$output = '';
$tt->process(\'[% loc("s") %] [% loc("s") | html_para %]', {}, \$output);
is $output, "s <p>\ns</p>\n";

$output = '';
$tt->process(\'[% s.upper %] [% t = s %][% t %] [% t.upper %]', {
    s => 'sp<i>l</i>it'
}, \$output);
is $output, 'SP&lt;I&gt;L&lt;/I&gt;IT sp&lt;i&gt;l&lt;/i&gt;it SP&lt;I&gt;L&lt;/I&gt;IT';

$output = '';
$tt->process(\'H: [% s.split(":").join(",") %]', {
    s => '1:sp<i>l</i>it:3'
}, \$output);
is $output, 'H: 1,sp&lt;i&gt;l&lt;/i&gt;it,3';

$output = '';
$tt->process(\'[% size %] [% 100 / size %] [% size / 100 %]', {
    size => 4
}, \$output);
is $output, '4 25 0.04';

done_testing;
