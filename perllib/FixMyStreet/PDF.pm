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
            roman => 'web/cobrands/tfl/fonts/Johnston100-Light.ttf',
            bold => 'web/cobrands/tfl/fonts/Johnston100-Medium.ttf',
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

sub plot_line {
    my ($self, $y, $colour, $line, $recurse) = @_;
    my ($rc, $next_y, $unused) = $self->text->column(
        $self->page, $self->text, undef, $recurse ? 'pre' : 'html', $line,
        rect => [0+50,842-50,595-100,842-100], # A4 in pt with 50pt margin
        para => [0,0],
        font_info => $self->font . ":normal:normal:$colour",
        start_y => $y,
    );
    if ($rc) {
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
}

1;
