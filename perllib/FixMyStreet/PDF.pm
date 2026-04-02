=head1 NAME

FixMyStreet::PDF - boilerplate for PDF generation

=head1 SYNOPSIS

Currently used for TfL licence forms.

=head1 DESCRIPTION

    my $pdf = FixMyStreet::PDF->new(
        title => "Document title",
        font => "Font face",
    );

    my $next_y;
    ($rc, $next_y) = $pdf->plot_line($next_y, "black", "Hello");

This could be done as a simple while loop, passing in the full HTML
and continuing with each piece of unused text returned, but that does
not let us then do colours or heading orphan handling.

=cut

package FixMyStreet::PDF;

use Moo;
use PDF::Builder;

has title => ( is => 'ro' );

has font => ( is => 'ro' );

has pdf => ( is => 'lazy', default => sub {
    my $pdf = PDF::Builder->new;
    $pdf->title($_[0]->title);
    $pdf->creator('FixMyStreet');
    $pdf->default_page_size('A4');

    # TfL specific
    $pdf->author('TfL');
    $pdf->add_font(
        face => $_[0]->font,
        type => 'ttf',
        style => 'sans-serif',
        width => 'proportional',
        settings => { encode => 'utf8' },
        file => {
            roman => FixMyStreet->path_to('web/cobrands/tfl/fonts/Johnston100-Light.ttf')->stringify,
            bold => FixMyStreet->path_to('web/cobrands/tfl/fonts/Johnston100-Medium.ttf')->stringify,
        }
    );
    return $pdf;
} );

# Current page - auto creates first one on first use
has page => ( is => 'rwp', lazy => 1, default => sub { $_[0]->pdf->page() } );

# Current page's text layer - ditto
has text => ( is => 'rwp', lazy => 1, default => sub { $_[0]->page->text() } );

=head2 plot_line START_Y COLOUR HTML [RECURSE]

This adds a block of HTML to the PDF document in colour COLOUR, starting at
START_Y down the page (or undef to start at the top). If the text does not fit
in the remaining space, it adds a new page and carries on on the new page (and
passes in the RECURSE flag then for that to work).

Returns a boolean, true if some text did not fit (will be false unless white
text is used for prediction, because then it will recurse until it all fits)
plus the next Y value to use for the next piece of text.

=cut

# Measurements in points (1/72in)
my $a4_w = 595;
my $a4_h = 842;
my $margin_h = 15/25.4*72;
my $margin_w = 30/25.4*72;
my $logo_scale = 0.48;
my $logo_w = 1241 * $logo_scale;
my $logo_h = 173 * $logo_scale;
my $box = [
    $margin_w,
    $a4_h - $margin_h,
    $a4_w - $margin_w * 2,
    $a4_h - $margin_h * 2 - $logo_h
];

sub plot_line {
    my ($self, $y, $colour, $line, $recurse) = @_;
    my ($rc, $next_y, $unused) = $self->text->column(
        $self->page, $self->text, undef, $recurse ? 'pre' : 'html', $line,
        rect => $box,
        para => [0,0],
        font_info => $self->font . ":normal:normal:$colour",
        start_y => $y,
    );
    if ($rc) {
        # On pages after the first, start under the logo
        $self->add_page();
        $next_y = undef;
        if ($colour ne 'white') {
            ($rc, $next_y) = $self->plot_line($next_y, $colour, $unused, 'pre');
        }
    }
    return ($rc, $next_y);
}

=head2 to_string

Returns the binary of the PDF.
Note the object is unusable after this point.

=cut

sub to_string {
    $_[0]->add_footer;
    $_[0]->pdf->to_string
}

=head2 add_page

Creates a new page and stores it for use when adding more text.

=cut

sub add_page {
    my $self = shift;
    $self->_set_page($self->pdf->page());
    $self->_set_text($self->page->text());
}

sub add_footer {
    my $self = shift;
    my $pdf = $self->pdf;
    my $image = $pdf->image(
        FixMyStreet->path_to('web/cobrands/tfl/images/pdf-footer.png')->stringify);
    my $font = $pdf->get_font(face => $self->font, bold => 0, italic => 0);
    my $num = $pdf->page_count;

    for (1..$num) {
        my $page = $pdf->open_page($_);
        $page->graphics->image($image, $a4_w/2 - $logo_w/2, 0, $logo_scale);
        my $line = sprintf("%d of %d", $_, $num);
        $page->text->textlabel($a4_w/2, $logo_h+6, $font, 12, $line, center => 1, color => 'black');
    }
}

1;
