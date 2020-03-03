package FixMyStreet::Template;
use parent Template;

use strict;
use warnings;
use FixMyStreet;
use mySociety::Locale;
use Attribute::Handlers;
use HTML::Scrubber;
use FixMyStreet::Template::SafeString;
use FixMyStreet::Template::Context;
use FixMyStreet::Template::Stash;

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
    my $disable_autoescape = delete $config->{disable_autoescape};
    $config->{FILTERS}->{$_} = $FILTERS{$_} foreach keys %FILTERS;
    $config->{ENCODING} = 'utf8';
    if (!$disable_autoescape) {
        $config->{STASH} = FixMyStreet::Template::Stash->new($config);
        $config->{CONTEXT} = FixMyStreet::Template::Context->new($config);
    }
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
Pass in "JS" as the optional comment to escape single quotes (for use in JavaScript).

=cut

sub loc : Fn {
    my $s = _(@_);
    $s =~ s/'/\\'/g if $_[1] && $_[1] eq 'JS';
    return FixMyStreet::Template::SafeString->new($s);
}

=head2 nget

    [% nget( 'singular', 'plural', $number ) %]

Use first or second string depending on the number.

=cut

sub nget : Fn {
    return FixMyStreet::Template::SafeString->new(mySociety::Locale::nget(@_));
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

sub conditional_escape {
    my $text = shift;
    $text = html_filter($text) unless UNIVERSAL::isa($text, 'FixMyStreet::Template::SafeString');
    return $text;
}

=head2 html_paragraph

Same as Template Toolkit's html_paragraph, but converts single newlines
into <br>s too.

=cut

sub html_paragraph : Filter('html_para') {
    my $text = shift;
    $text = conditional_escape($text);
    my @paras = grep { $_ } split(/(?:\r?\n){2,}/, $text);
    s/\r?\n/<br>\n/g for @paras;
    $text = "<p>\n" . join("\n</p>\n\n<p>\n", @paras) . "</p>\n";
    return FixMyStreet::Template::SafeString->new($text);
}

sub sanitize {
    my $text = shift;

    my %allowed_tags = map { $_ => 1 } qw( p ul ol li br b i strong em );
    my $scrubber = HTML::Scrubber->new(
        rules => [
            %allowed_tags,
            a => { href => qr{^(http|/|tel)}i, style => 1, target => qr/^_blank$/, title => 1, class => qr/^js-/ },
            img => { src => 1, alt => 1, width => 1, height => 1, hspace => 1, vspace => 1, align => 1, sizes => 1, srcset => 1 },
            font => { color => 1 },
            span => { style => 1 },
        ]
    );
    $text = $scrubber->scrub($text);
    return $text;
}

1;
