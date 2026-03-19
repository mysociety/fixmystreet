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

has header_image => ( is => 'rw' );

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
    my $image = $pdf->image(
        FixMyStreet->path_to('web/cobrands/tfl/images/roundel.png')->stringify);
    $_[0]->header_image($image);

    return $pdf;
} );

# Current page - auto creates first one on first use
has page => ( is => 'rwp', lazy => 1, default => sub { $_[0]->pdf->page() } );

has page_number => ( is => 'rw', default => 0 );

# Current page's text layer - ditto
has text => ( is => 'rwp', lazy => 1, default => sub {
    my $self = shift;
    my $text = $self->page->text();
    $self->page_setup($text);
    return $text;
} );

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
my $logo_w = 960;
my $logo_h = 781;
my $logo_scale = 0.05;
my $box_first = [
    $margin_w,
    $a4_h - $margin_h,
    $a4_w - $margin_w * 2 - $logo_w * $logo_scale - 12,
    $a4_h - $margin_h * 2 - $margin_h
];
my $box_subsequent = [
    $margin_w,
    $a4_h - $margin_h - $logo_h * $logo_scale - 12,
    $a4_w - $margin_w * 2,
    $a4_h - $margin_h * 2 - $margin_h - $logo_h * $logo_scale - 12
];
my $box = $box_first;

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
        $box = $box_subsequent;
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

sub to_string { $_[0]->pdf->to_string }

=head2 add_page

Creates a new page and stores it for use when adding more text.

=cut

sub add_page {
    my $self = shift;
    $self->_set_page($self->pdf->page());
    $self->_set_text($self->page->text());
    $self->page_setup($self->text);
}

# Passing in text because it's also used in text's build
sub page_setup {
    my ($self, $text) = @_;
    $self->page_number($self->page_number + 1);
    my $font = $self->pdf->get_font(face => $self->font, bold => 0, italic => 0);
    $text->textlabel($a4_w/2, $margin_h+6, $font, 12, $self->page_number, center => 1, color => 'black');

    my $gfx = $self->page->graphics;
    $gfx->image($self->header_image,
        $a4_w - $margin_w - $logo_w * $logo_scale,
        $a4_h - $margin_h - $logo_h * $logo_scale,
        $logo_scale);
}

1;
