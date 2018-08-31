package FixMyStreet::Template;
use parent Template;

use strict;
use warnings;
use FixMyStreet;
use mySociety::Locale;
use Attribute::Handlers;

my %FILTERS;
my %SUBS;

# HASH is where we want to store the thing, either FILTERS or SUBS. SYMBOL is a
# symbol table ref, where NAME then returns its name (perlref has the gory
# details). FN is a ref to the function. DATA is an arrayref of any passed in
# arguments.

sub add_attr {
    my ($hash, $symbol, $fn, $data) = @_;
    my $name = $data ? $data->[0] : *{$symbol}{NAME};
    $hash->{$name} = $fn;
}

# Create two attributes, Filter and Fn, which you apply to a function to turn
# them into a template filter or function. You can optionally provide an argument
# name for what to call the thing in the template if it's not the same as the
# function name. They're called at the BEGIN stage rather than the default CHECK
# as this code might be imported by an eval.

sub Filter : ATTR(CODE,BEGIN) {
    add_attr(\%FILTERS, $_[1], $_[2], $_[4]);
}

sub Fn : ATTR(CODE,BEGIN) {
    add_attr(\%SUBS, $_[1], $_[2], $_[4]);
}

sub new {
    my ($class, $config) = @_;
    $config->{FILTERS}->{$_} = $FILTERS{$_} foreach keys %FILTERS;
    $config->{ENCODING} = 'utf8';
    $class->SUPER::new($config);
}

sub process {
    my ($class, $template, $vars, $output, %options) = @_;
    $vars->{$_} = $SUBS{$_} foreach keys %SUBS;
    $class->SUPER::process($template, $vars, $output, %options);
}

=head2 loc

    [% loc('Some text to localize', 'Optional comment for translator') %]

Passes the text to the localisation engine for translations.

=cut

sub loc : Fn {
    return _(@_);
}

=head2 nget

    [% nget( 'singular', 'plural', $number ) %]

Use first or second string depending on the number.

=cut

sub nget : Fn {
    return mySociety::Locale::nget(@_);
}

=head2 file_exists

    [% file_exists("web/cobrands/$cobrand/image.png") %]

Checks to see if a file exists, relative to the codebase root.

=cut

sub file_exists : Fn {
    -e FixMyStreet->path_to(@_);
}

=head2 html_filter

Same as Template Toolkit's html_filter, but escapes ' too, as we don't (and
shouldn't have to) know whether we'll be used inbetween single or double
quotes.

=cut

sub html_filter : Filter('html') {
    my $text = shift;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/"/&quot;/g;
        s/'/&#39;/g;
    }
    return $text;
}

=head2 html_paragraph

Same as Template Toolkit's html_paragraph, but converts single newlines
into <br>s too.

=cut

sub html_paragraph : Filter('html_para') {
    my $text = shift;
    my @paras = split(/(?:\r?\n){2,}/, $text);
    s/\r?\n/<br>\n/g for @paras;
    $text = "<p>\n" . join("\n</p>\n\n<p>\n", @paras) . "</p>\n";
    return $text;
}

1;
