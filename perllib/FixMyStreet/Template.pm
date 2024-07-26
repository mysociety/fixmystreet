package FixMyStreet::Template;
use parent Template;

use strict;
use warnings;
use FixMyStreet;
use mySociety::Locale;
use Attribute::Handlers;
use HTML::Scrubber;
use HTML::TreeBuilder;
use FixMyStreet::Template::SafeString;
use FixMyStreet::Template::Context;
use FixMyStreet::Template::Stash;

use JSON::MaybeXS;
use IO::String;

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

sub FilterFactory : ATTR(CODE,BEGIN) {
    add_attr(\%FILTERS, $_[1], [ $_[2], 1 ], $_[4]);
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

sub html_paragraph_email_factory : FilterFactory('html_para_email') {
    my ($c, $style) = @_;
    return sub {
        my $text = shift;
        $text = html_paragraph($text);
        $text =~ s/<p>/<p style="$style">/g;
        return FixMyStreet::Template::SafeString->new($text);
    }
}

sub sanitize {
    my ($text, $admin) = @_;

    return '' unless defined $text;

    # In case of markdown variant style of <https://www.google.com>
    $text =~ s/<\s*(https?[^\s>]+)\s*>/$1/g;

    $text = $$text if UNIVERSAL::isa($text, 'FixMyStreet::Template::SafeString');

    my %allowed_tags = map { $_ => 1 } qw( p ul ol li br b i strong em );
    my %admin_tags = (
        p => { class => 1, id => 1, style => 1 },
        h1 => 1,
        h2 => 1,
        h3 => 1,
    );
    my $scrubber = HTML::Scrubber->new(
        rules => [
            %allowed_tags,
            $admin ? %admin_tags : (),
            a => { href => qr{^(http|/|tel|mailto)}i, style => 1, target => qr/^_blank$/, title => 1, class => qr/^js-/ },
            img => { src => 1, alt => 1, width => 1, height => 1, hspace => 1, vspace => 1, align => 1, sizes => 1, srcset => 1 },
            font => { color => 1 },
            span => { style => 1 },
        ]
    );
    $text = $scrubber->scrub($text);
    return $text;
}

=head2 email_sanitize_text

Intended for use in the _email_comment_list.txt template to allow HTML
in updates from staff/superusers. Sanitizes the HTML and then converts
it all to text.

=cut

sub email_sanitize_text : Fn('email_sanitize_text') {
    my $update = shift;
    my $column = shift;

    my $text = $column ? $update->{$column} : $update->{item_text};
    my $extra = $update->{item_extra};
    $extra = $extra ? JSON->new->decode($extra) : {};

    my $staff = $extra->{is_superuser} || $extra->{is_body_user} || $column;

    return $text unless $staff;

    $text = FixMyStreet::Template::sanitize($text);

    my $tree = HTML::TreeBuilder->new_from_content($text);
    _sanitize_elt($tree);

    return $tree->as_text;
}

my $list_type;
my $list_num;
my $sanitize_text_subs = {
    b => [ '*', '*' ],
    strong => [ '*', '*' ],
    i => [ '_', '_' ],
    em => [ '_', '_' ],
    p => [ '', "\n\n" ],
    li => [ '', "\n\n" ],
};
sub _sanitize_elt {
    my $elt = shift;
    foreach ($elt->content_list) {
        next unless ref $_;
        $list_type = $_->tag, $list_num = 1 if $_->tag eq 'ol' || $_->tag eq 'ul';
        _sanitize_elt($_);
        $_->replace_with("\n") if $_->tag eq 'br';
        $_->replace_with('[image: ', $_->attr('alt') || '', ']') if $_->tag eq 'img';
        $_->replace_with($_->as_text, ' [', $_->attr('href') || '', ']') if $_->tag eq 'a';
        $_->replace_with_content if $_->tag eq 'span' || $_->tag eq 'font';
        $_->replace_with_content if $_->tag eq 'ul' || $_->tag eq 'ol';
        if ($_->tag eq 'li') {
            $sanitize_text_subs->{li}[0] = $list_type eq 'ol' ? "$list_num. " : '* ';
            $list_num++;
        }
        if (my $sub = $sanitize_text_subs->{$_->tag}) {
            $_->preinsert($sub->[0]);
            $_->postinsert($sub->[1]);
            $_->replace_with_content;
        }
    }
}

=head2 email_sanitize_html

Intended for use in the _email_comment_list.html template to allow HTML
in updates from staff/superusers.

=cut

sub email_sanitize_html : Fn('email_sanitize_html') {
    my $update = shift;
    my $column = shift;

    my $text = $column ? $update->{$column} : $update->{item_text};
    my $extra = $update->{item_extra};
    $extra = $extra ? JSON->new->decode($extra) : {};

    my $staff = $extra->{is_superuser} || $extra->{is_body_user} || $column;

    return _staff_html_markup($text, $staff);
}

sub _staff_html_markup {
    my ( $text, $staff ) = @_;
    unless ($staff) {
        return html_paragraph(add_links($text));
    }

    $text = sanitize($text);

    # Apply Markdown-style italics
    $text =~ s{\*(\S.*?\S)\*}{<i>$1</i>};

    # Mark safe so add_links doesn't escape everything.
    $text = FixMyStreet::Template::SafeString->new($text);

    $text = add_links($text);

    # If the update already has block-level elements then don't wrap
    # individual lines in <p> elements, as we assume the user knows what
    # they're doing.
    unless ($text =~ /<(p|ol|ul)>/) {
        $text = html_paragraph($text);
    }

    return $text;
}

=head2 add_links

    [% text | add_links | html_para %]

Add some links to some text (and thus HTML-escapes the other text).

=cut

sub add_links {
    my $text = shift;
    $text = conditional_escape($text);
    $text =~ s/\r//g;
    $text =~ s{(?<!["'])(https?://)([^\s]+)}{"<a rel=\"nofollow\" href=\"$1$2\">$1" . _space_slash($2) . '</a>'}ge;
    return FixMyStreet::Template::SafeString->new($text);
}

sub _space_slash {
    my $t = shift;
    $t =~ s{/(?!$)}{/ }g;
    return $t;
}

sub title : Filter {
    my $text = shift;
    $text =~ s{(\w[\w']*)}{\u\L$1}g;
    # Postcode special handling
    $text =~ s{(\w?\w\d[\d\w]?\s*\d\w\w)}{\U$1}g;
    return $text;
}

1;
