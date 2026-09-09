### A local copy of PDF::Builder::Content::Text to add a line (search
### for# mySociety) to strip text when hyphenating to prevent failure
### to hyphenate over more than two lines.

package PDF::Builder::Content::Text;

use base 'PDF::Builder::Content';

use strict;
use warnings;
use Carp;
use List::Util qw(min max);
use version;
#use Data::Dumper;  # for debugging
# $Data::Dumper::Sortkeys = 1;  # hash keys in sorted order
    # print Dumper(var);  usage of Dumper
 
# >>>>>>>>>>>>>>>>>> CRITICAL !!!! <<<<<<<<<<<<<<<<<<<<<<
# when update column() tags and CSS with new/changed support, also update 
# Column_docs.pm (immediately) and perhaps #195 list (AT release).
# any examples/ changes update Examples on website (AT release)

our $VERSION = '3.028'; # VERSION
our $LAST_UPDATE = '3.028'; # manually update whenever code is changed

my $TextMarkdown = '1.000031'; # minimum version of Text::Markdown;
#my $TextMultiMarkdown = '1.005'; # TBD minimum version of Text::MultiMarkdown;
my $HTMLTreeBldr = '5.07';     # minimum version of HTML::TreeBuilder

=head1 NAME

PDF::Builder::Content::Text - Additional specialized text-related formatting methods

Inherits from L<PDF::Builder::Content>

B<Note:> If you have used some of these methods in PDF::Builder with a 
I<graphics> 
type object (e.g., $page->gfx()->method()), you may have to change to a I<text> 
type object (e.g., $page->text()->method()).

=head1 METHODS

=cut

sub new {
    my ($class) = @_;
    my $self = $class->SUPER::new(@_);
    $self->textstart();
    return $self;
}

=head2 Single Lines from a String

=head3 text_left

    $width = $content->text_left($text, %opts)

=over

Alias for C<text>. Implemented for symmetry, for those who use a lot of
C<text_center> and C<text_right>, and desire a matching C<text_left>.

Adds text to the page (left justified), at the current position. 
Note that there is no maximum width, and nothing to keep you from overflowing
the physical page on the right!
The width used (in points) is B<returned>.

=back

=cut

sub text_left {
    my ($self, $text, @opts) = @_;

    # override any stray 'align' that got through to here
    return $self->text($text, @opts, 'align'=>'l');
}

=head3 text_center

    $width = $content->text_center($text, %opts)

=over

As C<text>, but I<centered> on the current point.

Adds text to the page (centered). 
The width used (in points) is B<returned>.

=back

=cut

sub text_center {
    my ($self, $text, @opts) = @_;

    # override any stray 'align' that got through to here
    return $self->text($text, @opts, 'align'=>'c');
}

=head3 text_right

    $width = $content->text_right($text, %opts)

=over

As C<text>, but right-aligned to the current point.

Adds text to the page (right justified). 
Note that there is no maximum width, and nothing to keep you from overflowing
the physical page on the left!
The width used (in points) is B<returned>.

=back

=cut

sub text_right {
    my ($self, $text, @opts) = @_;

    # override any stray 'align' that got through to here
    return $self->text($text, @opts, 'align'=>'r');
}

=head3 text_justified

    $width = $content->text_justified($text, $width, %opts)

=over
 
As C<text>, but stretches text using C<wordspace>, C<charspace>, and (as a  
last resort) C<hscale>, to fill the desired
(available) C<$width>. Note that if the desired width is I<less> than the
natural width taken by the text, it will be I<condensed> to fit, using the
same three routines.

The unchanged C<$width> is B<returned>, unless there was some reason to
change it (e.g., overflow).

B<Options:>

=over

=item 'nocs' => value

If this option value is 1 (default 0), do B<not> use any intercharacter
spacing. This is useful for connected characters, such as fonts for Arabic,
Devanagari, Latin cursive handwriting, etc. You don't want to add additional
space between characters during justification, which would disconnect them.

I<Word> (interword) spacing values (explicit or default) are doubled if
nocs is 1. This is to make up for the lack of added/subtracted intercharacter
spacing.

=item 'wordsp' => value

The percentage of one space character (default 100) that is the maximum amount
to add to (each) interword spacing to expand the line.
If C<nocs> is 1, double C<value>.

=item 'charsp' => value

If adding interword space didn't do enough, the percentage of one em (default 
100) that is the maximum amount to add to (each) intercharacter spacing to 
further expand the line.
If C<nocs> is 1, force C<value> to 0.

=item 'wordspa' => value

If adding intercharacter space didn't do enough, the percentage of one space
character (default 100) that is the maximum I<additional> amount to add to 
(each) interword spacing to further expand the line.
If C<nocs> is 1, double C<value>.

=item 'charspa' => value

If adding more interword space didn't do enough, the percentage of one em 
(default 100) that is the maximum I<additional> amount to add to (each) 
intercharacter spacing to further expand the line.
If C<nocs> is 1, force C<value> to 0.

=item 'condw' => value

The percentage of one space character (default 25) that is the maximum amount
to subtract from (each) interword spacing to condense the line.
If C<nocs> is 1, double C<value>.

=item 'condc' => value

If removing interword space didn't do enough, the percentage of one em
(default 10) that is the maximum amount to subtract from (each) intercharacter
spacing to further condense the line.
If C<nocs> is 1, force C<value> to 0.

=back

If expansion (or reduction) wordspace and charspace changes didn't do enough 
to make the line fit the desired width, use C<hscale()> to finish expanding or 
condensing the line to fit.

=back

=cut

sub text_justified {
    my ($self, $text, $width, %opts) = @_;
    # copy dashed option names to the preferred undashed names
    if (defined $opts{'-wordsp'} && !defined $opts{'wordsp'}) { $opts{'wordsp'} = delete($opts{'-wordsp'}); }
    if (defined $opts{'-charsp'} && !defined $opts{'charsp'}) { $opts{'charsp'} = delete($opts{'-charsp'}); }
    if (defined $opts{'-wordspa'} && !defined $opts{'wordspa'}) { $opts{'wordspa'} = delete($opts{'-wordspa'}); }
    if (defined $opts{'-charspa'} && !defined $opts{'charspa'}) { $opts{'charspa'} = delete($opts{'-charspa'}); }
    if (defined $opts{'-condw'} && !defined $opts{'condw'}) { $opts{'condw'} = delete($opts{'-condw'}); }
    if (defined $opts{'-condc'} && !defined $opts{'condc'}) { $opts{'condc'} = delete($opts{'-condc'}); }
    if (defined $opts{'-nocs'} && !defined $opts{'nocs'}) { $opts{'nocs'} = delete($opts{'-nocs'}); }

    # optional parameters to control how expansion or condensation are done
    # 1. expand interword space up to 100% of 1 space
    my $wordsp = defined($opts{'wordsp'})? $opts{'wordsp'}: 100;
    # 2. expand intercharacter space up to 100% of 1em
    my $charsp = defined($opts{'charsp'})? $opts{'charsp'}: 100;
    # 3. expand interword space up to another 100% of 1 space
    my $wordspa = defined($opts{'wordspa'})? $opts{'wordspa'}: 100;
    # 4. expand intercharacter space up to another 100% of 1em
    my $charspa = defined($opts{'charspa'})? $opts{'charspa'}: 100;
    # 5. condense interword space up to 25% of 1 space
    my $condw = defined($opts{'condw'})? $opts{'condw'}: 25;
    # 6. condense intercharacter space up to 10% of 1em
    my $condc = defined($opts{'condc'})? $opts{'condc'}: 10;
    # 7. if still short or long, hscale()

    my $nocs = defined($opts{'nocs'})? $opts{'nocs'}: 0;
    if ($nocs) {
        $charsp = $charspa = $condc = 0;
	$wordsp *= 2;
	$wordspa *= 2;
	$condw *= 2;
    }

    # with original wordspace, charspace, and hscale settings
    # note that we do NOT change any existing charspace here
    my $length = $self->advancewidth($text, %opts);
    my $overage = $length - $width; # > 0, raw text is too wide, < 0, narrow

    my ($i, @chars, $val, $limit);
    my $hs = $self->hscale();   # save old settings and reset to 0
    my $ws = $self->wordspace();
    my $cs = $self->charspace();
    $self->hscale(100); $self->wordspace(0); $self->charspace(0);

    # not near perfect fit? not within .1 pt of fitting
    if (abs($overage) > 0.1) { 

    # how many interword spaces can we change with wordspace?
    my $num_spaces = 0;
    # how many intercharacter spaces can be added to or removed?
    my $num_chars = -1;
    @chars = split //, $text;
    for ($i=0; $i<scalar @chars; $i++) {
	if ($chars[$i] eq ' ') { $num_spaces++; } # TBD other whitespace?
	$num_chars++;  # count spaces as characters, too
    }
    my $em = $self->advancewidth('M');
    my $sp = $self->advancewidth(' ');

    if ($overage > 0) {
	# too wide: need to condense it
	# 1. subtract from interword space, up to -$condw/100 $sp
	if ($overage > 0 && $num_spaces > 0 && $condw > 0) {
	    $val = $overage/$num_spaces;
	    $limit = $condw/100*$sp;
	    if ($val > $limit) { $val = $limit; }
	    $self->wordspace(-$val);
	    $overage -= $val*$num_spaces;
	}
	# 2. subtract from intercharacter space, up to -$condc/100 $em
	if ($overage > 0 && $num_chars > 0 && $condc > 0) {
	    $val = $overage/$num_chars;
	    $limit = $condc/100*$em;
	    if ($val > $limit) { $val = $limit; }
	    $self->charspace(-$val);
	    $overage -= $val*$num_chars;
	}
	# 3. nothing more to do than scale down with hscale()
    } else {
	# too narrow: need to expand it (usual case)
	$overage = -$overage; # working with positive value is easier
	# 1. add to interword space, up to $wordsp/100 $sp
	if ($overage > 0 && $num_spaces > 0 && $wordsp > 0) {
	    $val = $overage/$num_spaces;
	    $limit = $wordsp/100*$sp;
	    if ($val > $limit) { $val = $limit; }
	    $self->wordspace($val);
	    $overage -= $val*$num_spaces;
	}
	# 2. add to intercharacter space, up to $charsp/100 $em
	if ($overage > 0 && $num_chars > 0 && $charsp > 0) {
	    $val = $overage/$num_chars;
	    $limit = $charsp/100*$em;
	    if ($val > $limit) { $val = $limit; }
	    $self->charspace($val);
	    $overage -= $val*$num_chars;
	}
	# 3. add to interword space, up to $wordspa/100 $sp additional
	if ($overage > 0 && $num_spaces > 0 && $wordspa > 0) {
	    $val = $overage/$num_spaces;
	    $limit = $wordspa/100*$sp;
	    if ($val > $limit) { $val = $limit; }
	    $self->wordspace($val+$self->wordspace());
	    $overage -= $val*$num_spaces;
	}
	# 4. add to intercharacter space, up to $charspa/100 $em additional
	if ($overage > 0 && $num_chars > 0 && $charspa > 0) {
	    $val = $overage/$num_chars;
	    $limit = $charspa/100*$em;
	    if ($val > $limit) { $val = $limit; }
	    $self->charspace($val+$self->charspace());
	    $overage -= $val*$num_chars;
	}
	# 5. nothing more to do than scale up with hscale()
    }

    # last ditch effort to fill the line: use hscale()
    # temporarily resets hscale to expand width of line to match $width
    # wordspace and charspace are already (temporarily) at max/min
    if ($overage > 0.1) {
        $self->hscale(100*($width/$self->advancewidth($text, %opts)));
    }

    } # original $overage was not near 0
    # do the output, with wordspace, charspace, and possibly hscale changed
    # override any stray 'align' that got through to here
    $self->text($text, %opts, 'align'=>'l');

    # restore settings
    $self->hscale($hs); $self->wordspace($ws); $self->charspace($cs);

    return $width;
} # end of text_justified()

=head2 Multiple Lines from a String

The string is split at regular blanks (spaces), x20, to find the longest 
substring that will fit the C<$width>. 
If a single word is longer than C<$width>, it will overflow. 
To stay strictly within the desired bounds, set the option
C<spillover>=E<gt>0 to disallow spillover.

=head3 Hyphenation

If hyphenation is enabled, those methods which split up a string into multiple
lines (the "text fill", paragraph, and section methods) will attempt to split
up the word that overflows the line, in order to pack the text even more
tightly ("greedy" line splitting). There are a number of controls over where a
word may be split, but note that there is nothing language-specific (i.e.,
following a given language's rules for where a word may be split). This is left
to other packages.

There are hard coded minimums of 2 letters before the split, and 2 letters after
the split. See C<Hyphenate_basic.pm>. Note that neither hyphenation nor simple
line splitting makes any attempt to prevent widows and orphans, prevent 
splitting of the last word in a column or page, or otherwise engage in 
more desirable I<paragraph shaping>.

=over

=item 'hyphenate' => value

0: no hyphenation (B<default>), 1: do basic hyphenation. Always allows
splitting at a soft hyphen (\xAD). Unicode hyphen (U+2010) and non-splitting
hyphen (U+2011) are ignored as split points.

=item 'spHH' => value

0: do I<not> split at a hard hyphen (x\2D), 1: I<OK to split> (B<default>)

=item 'spOP' => value

0: do I<not> split after most punctuation, 1: I<OK to split> (B<default>)

=item 'spDR' => value

0: do I<not> split after a run of one or more digits, 1: I<OK to split> (B<default>)

=item 'spLR' => value

0: do I<not> split after a run of one or more ASCII letters, 1: I<OK to split> (B<default>)

=item 'spCC' => value

0: do I<not> split in camelCase between a lowercase letter and an
uppercase letter, 1: I<OK to split> (B<default>)

=item 'spRB' => value

0: do I<not> split on a Required Blank (&nbsp;), is B<default>.
1: I<OK to split on Required Blank.> Try to avoid this; it is a desperation 
move!

=item 'spFS' => value

0: do I<not> split where it will I<just> fit (middle of word!), is B<default>.
1: I<OK to split to just fit the available space.> Try to avoid this; it is a 
super desperation move, and the split will probably make no linguistic sense!

=item 'min_prefix' => value

Minimum number of letters I<before> word split point (hyphenation point).
The B<default> is 2.

=item 'min_suffix' => value

Minimum number of letters I<after> word split point (hyphenation point).
The B<default> is 3.

=back

=head3 Methods

=cut

# splits input text (on spaces) into words, glues them back together until 
# have filled desired (available) width. return the new line and remaining 
# text. runs of spaces should be preserved. if the first word of a line does
# not fit within the alloted space, and cannot be split short enough, just 
# accept the overflow.
sub _text_fill_line {
    my ($self, $text, $width, $over, %opts) = @_;
    # copy dashed option names to the preferred undashed names
    if (defined $opts{'-hyphenate'} && !defined $opts{'hyphenate'}) { $opts{'hyphenate'} = delete($opts{'-hyphenate'}); }
    if (defined $opts{'-lang'} && !defined $opts{'lang'}) { $opts{'lang'} = delete($opts{'-lang'}); }
    if (defined $opts{'-nosplit'} && !defined $opts{'nosplit'}) { $opts{'nosplit'} = delete($opts{'-nosplit'}); }

    # options of interest
    my $hyphenate = defined($opts{'hyphenate'})? $opts{'hyphenate'}: 0; # default off
   #my $lang = defined($opts{'lang'})? $opts{'lang'}: 'en';  # English rules by default
    my $lang = 'basic';
   #my $nosplit = defined($opts{'nosplit'})? $opts{'nosplit'}: '';  # indexes NOT to split at, given
                                            # as string of integers
   #       my @noSplit = split /[,\s]+/, $nosplit;  # normally empty array
	# 1. indexes start at 0 (split after character N not permitted)
	# 2. SHYs (soft hyphens) should be skipped
	# 3. need to map entire string's indexes to each word under
	#    consideration for splitting (hyphenation)

    # TBD should we consider any non-ASCII spaces?
    # don't split on non-breaking space (required blank).
    my @txt = split(/\x20/, $text);
    my @line = ();
    local $";  # intent is that reset of separator ($") is local to block
    $"=' ';   ## no critic
    my $lastWord = '';  # the one that didn't quite fit
    my $overflowed = 0;

    while (@txt) {
	 # build up @line from @txt array until overfills line.
	 # need to remove SHYs (soft hyphens) at this point.
	 $lastWord = shift @txt;  # preserve any SHYs in the word
         push @line, (_removeSHY($lastWord));
	 # one space between each element of line, like join(' ', @line)
         $overflowed = $self->advancewidth("@line", %opts) > $width;
	 last if $overflowed;
    }
    # if overflowed, and overflow not allowed, remove the last word added, 
    # unless single word in line and we're not going to attempt word splitting.
    if ($overflowed && !$over) {
	if ($hyphenate && @line == 1 || @line > 1) {
	    pop @line;  # discard last (or only) word
            unshift @txt,$lastWord; # restore with SHYs intact
        }
	# if not hyphenating (splitting words), just leave oversized 
	# single-word line. if hyphenating, could have empty @line.
    }

    my $Txt = "@txt";   # remaining text to put on next line
    my $Line = "@line"; # line that fits, but not yet with any split word
                        # may be empty if first word in line overflows

    # if we try to hyphenate, try splitting up that last word that
    # broke the camel's back. otherwise, will return $Line and $Txt as is.
    if ($hyphenate && $overflowed) {
	my $space;
	# @line is current whole word list of line, does NOT overflow because
	# $lastWord was removed. it may be empty if the first word tried was
	# too long. @txt is whole word list of the remaining words to be output 
	# (includes $lastWord as its first word).
	#
	# we want to try splitting $lastWord into short enough left fragment
	# (with right fragment remainder as first word of next line). if we
	# fail to do so, just leave whole word as first word of next line, IF
	# @line was not empty. if @line was empty, accept the overflow and
	# output $lastWord as @line and remove it from @txt.
	if (@line) {
	    # line not empty. $space is width for word fragment, not
	    # including blank after previous last word of @line.
	    $space = $width - $self->advancewidth("@line ", %opts);
	} else {
	    # line empty (first word too long, and we can try hyphenating).
	    # $space is entire $width available for left fragment.
	    $space = $width;
	}

	if ($space > 0) {
	    my ($wordLeft, $wordRight);
	    # @line is word(s) (if any) currently fitting within $width.
	    # @txt is remaining words unused in this line. $lastWord is first
	    # word of @txt. $space is width remaining to fill in line.
            $wordLeft = ''; $wordRight = $lastWord; # fallbacks

	    # if there is an error in Hyphenate_$lang, the message may be
	    # that the splitWord() function can't be found. debug errors by
	    # hard coding the require and splitWord() calls.

           ## test that Hyphenate_$lang exists. if not, use Hyphenate_en
	   ## TBD: if Hyphenate_$lang is not found, should we fall back to
	   ##      English (en) rules, or turn off hyphenation, or do limited
	   ##      hyphenation (nothing language-specific)?
	    # only Hyphenate_basic. leave language support to other packages
            require PDF::Builder::Content::Hyphenate_basic;
 	   #eval "require PDF::Builder::Content::Hyphenate_$lang";
           #if ($@) { 
	       #print "something went wrong with require eval: $@\n"; 
	       #$lang = 'en';  # perlmonks 27443   fall back to English
               #require PDF::Builder::Content::Hyphenate_en;
	   #}
            ($wordLeft,$wordRight) = PDF::Builder::Content::Hyphenate_basic::splitWord($self, $lastWord, $space, %opts);
           #eval '($wordLeft,$wordRight) = PDF::Builder::Content::Hyphenate_'.$lang.'::splitWord($self, "$lastWord", $space, %opts)';
	    if ($@) { print "something went wrong with eval: $@\n"; }

	    # $wordLeft is left fragment of $lastWord that fits in $space.
	    # it might be empty '' if couldn't get a small enough piece. it
	    # includes a hyphen, but no leading space, and can be added to
	    # @line.
	    # $wordRight is the remainder of $lastWord (right fragment) that
	    # didn't fit. it might be the entire $lastWord. it shouldn't be
	    # empty, since the whole point of the exercise is that $lastWord
	    # didn't fit in the remaining space. it will replace the first
	    # element of @txt (there should be at least one).
	    
	    # see if have a small enough left fragment of $lastWord to append
	    # to @line. neither left nor right Word should have full $lastWord,
	    # and both cannot be empty. it is highly unlikely that $wordLeft
	    # will be the full $lastWord, but quite possible that it is empty
	    # and $wordRight is $lastWord.

	    if (!@line) {
		# special case of empty line. if $wordLeft is empty and 
		# $wordRight is presumably the entire $lastWord, use $wordRight 
		# for the line and remove it ($lastWord) from @txt.
		if ($wordLeft eq '') {
		    @line = ($wordRight);  # probably overflows $width.
		    shift @txt;  # remove $lastWord from @txt.
		} else {
		    # $wordLeft fragment fits $width.
		    @line = ($wordLeft);  # should fit $width.
		    shift @txt; # replace first element of @txt ($lastWord)
		    unshift @txt, $wordRight;
		}
	    } else {
		# usual case of some words already in @line. if $wordLeft is 
		# empty and $wordRight is entire $lastWord, we're done here.
		# if $wordLeft has something, append it to line and replace
		# first element of @txt with $wordRight (unless empty, which
		# shouldn't happen).
	        if ($wordLeft eq '') {
	            # was unable to split $lastWord into short enough fragment.
		    # leave @line (already has words) and @txt alone.
	        } else {
                    push @line, ($wordLeft);  # should fit $space.
		    shift @txt; # replace first element of @txt (was $lastWord)
		    unshift @txt, $wordRight if $wordRight ne '';
	        }
	    }

	    # rebuild $Line and $Txt, in case they were altered.
            $Txt = "@txt";
            $Line = "@line";
	}  # there was $space available to try to fit a word fragment
    }  # we had an overflow to clean up, and hyphenation (word splitting) OK
    return ($Line, $Txt);
}

# remove soft hyphens (SHYs) from a word. assume is always #173 (good for
# Latin-1, CP-1252, UTF-8; might not work for some encodings)  TBD
sub _removeSHY {
    my ($word) = @_;

    my @chars = split //, $word;
    my $out = '';
    foreach (@chars) {
        next if ord($_) == 173;
	$out .= $_;
    }
    return $out;
}

=head4 text_fill_left, text_fill

    ($width, $leftover) = $content->text_fill_left($string, $width, %opts)

=over

Fill a line of 'width' with as much text as will fit, 
and outputs it left justified.
The width actually used, and the leftover text (that didn't fit), 
are B<returned>.

=back

    ($width, $leftover) = $content->text_fill($string, $width, %opts)

=over

Alias for text_fill_left().

=back

=cut

sub text_fill_left {
    my ($self, $text, $width, %opts) = @_;
    # copy dashed option names to preferred undashed names
    if (defined $opts{'-spillover'} && !defined $opts{'spillover'}) { $opts{'spillover'} = delete($opts{'-spillover'}); }

    # 0 = overflow past right margin NOT allowed; 1 = allowed
    my $over = defined($opts{'spillover'}) && $opts{'spillover'} == 1;
    $over = 0 if $over eq '';
    my ($line, $ret) = $self->_text_fill_line($text, $width, $over, %opts);
    # override any stray 'align' that got through to here
    $width = $self->text($line, %opts, 'align'=>'l');
    return ($width, $ret);
}

sub text_fill { 
    my $self = shift;
    return $self->text_fill_left(@_); 
}

=head4 text_fill_center

    ($width, $leftover) = $content->text_fill_center($string, $width, %opts)

=over

Fill a line of 'width' with as much text as will fit, 
and outputs it centered.
The width actually used, and the leftover text (that didn't fit), 
are B<returned>.

=back

=cut

sub text_fill_center {
    my ($self, $text, $width, %opts) = @_;
    # copy dashed option names to preferred undashed names
    if (defined $opts{'-spillover'} && !defined $opts{'spillover'}) { $opts{'spillover'} = delete($opts{'-spillover'}); }

    # 0 = overflow past right margin NOT allowed; 1 = allowed
    my $over = defined($opts{'spillover'}) && $opts{'spillover'} == 1;
    $over = 0 if $over eq '';
    my ($line, $ret) = $self->_text_fill_line($text, $width, $over, %opts);
    $width = $self->text_center($line, %opts);
    return ($width, $ret);
}

=head4 text_fill_right

    ($width, $leftover) = $content->text_fill_right($string, $width, %opts)

=over

Fill a line of 'width' with as much text as will fit, 
and outputs it right justified.
The width actually used, and the leftover text (that didn't fit), 
are B<returned>.

=back

=cut

sub text_fill_right {
    my ($self, $text, $width, %opts) = @_;
    # copy dashed option names to preferred undashed names
    if (defined $opts{'-spillover'} && !defined $opts{'spillover'}) { $opts{'spillover'} = delete($opts{'-spillover'}); }

    # 0 = overflow past right margin NOT allowed; 1 = allowed
    my $over = defined($opts{'spillover'}) && $opts{'spillover'} == 1;
    $over = 0 if $over eq '';
    my ($line, $ret) = $self->_text_fill_line($text, $width, $over, %opts);
    $width = $self->text_right($line, %opts);
    return ($width, $ret);
}

=head4 text_fill_justified

    ($width, $leftover) = $content->text_fill_justified($string, $width, %opts)

=over

Fill a line of 'width' with as much text as will fit, 
and outputs it fully justified (stretched or condensed).
The width actually used, and the leftover text (that didn't fit), 
are B<returned>.

Note that the entire line is fit to the available 
width via a call to C<text_justified>. 
See C<text_justified> for options to control stretch and condense.
The last line is unjustified (normal size) and left aligned by default, 
although the option

B<Options:>

=over

=item 'last_align' => place

where place is 'left' (default), 'center', or 'right' (may be shortened to
first letter) allows you to specify the alignment of the last line output.

=back

=back

=cut

sub text_fill_justified {
    my ($self, $text, $width, %opts) = @_;
    # copy dashed option names to preferred undashed names
    if (defined $opts{'-last_align'} && !defined $opts{'last_align'}) { $opts{'last_align'} = delete($opts{'-last_align'}); }
    if (defined $opts{'-spillover'} && !defined $opts{'spillover'}) { $opts{'spillover'} = delete($opts{'-spillover'}); }

    my $align = 'l'; # default left align last line
    if (defined($opts{'last_align'})) {
	if    ($opts{'last_align'} =~ m/^l/i) { $align = 'l'; }
	elsif ($opts{'last_align'} =~ m/^c/i) { $align = 'c'; }
	elsif ($opts{'last_align'} =~ m/^r/i) { $align = 'r'; }
	else { warn "Unknown last_align for justified fill, 'left' used\n"; }
    }

    # 0 = overflow past right margin NOT allowed; 1 = allowed
    my $over = defined($opts{'spillover'}) && $opts{'spillover'} == 1;
    $over = 0 if $over eq '';
    my ($line, $ret) = $self->_text_fill_line($text, $width, $over, %opts);
    # if last line, use $align (don't justify)
    if ($ret eq '') {
	my $lw = $self->advancewidth($line, %opts);
        # override any stray 'align' that got through to here
	if      ($align eq 'l') {
	    $width = $self->text($line, %opts, 'align'=>'l');
	} elsif ($align eq 'c') {
	    $width = $self->text($line, 'indent' => ($width-$lw)/2, %opts, 'align'=>'l');
	} else {  # 'r'
	    $width = $self->text($line, 'indent' => ($width-$lw), %opts, 'align'=>'l');
	}
    } else {
        $width = $self->text_justified($line, $width, %opts);
    }
    return ($width, $ret);
}

=head2 Larger Text Segments

=head3 paragraph

    ($overflow_text, $unused_height) = $txt->paragraph($text, $width,$height, $continue, %opts)

    ($overflow_text, $unused_height) = $txt->paragraph($text, $width,$height, %opts)

    $overflow_text = $txt->paragraph($text, $width,$height, $continue, %opts)

    $overflow_text = $txt->paragraph($text, $width,$height, %opts)

=over

Print a single string into a rectangular area on the page, of given width and
maximum height. The baseline of the first (top) line is at the current text
position.

Apply the text within the rectangle and B<return> any leftover text (if could 
not fit all of it within the rectangle). If called in an array context, the 
unused height is also B<returned> (may be 0 or negative if it just filled the 
rectangle).

C<$continue> is optional, with a default value of 0. An C<%opts> list may be
given after the fixed parameters, whether or not C<$continue> is explicitly
given.

If C<$continue> is 1, the first line does B<not> get special treatment for
indenting or outdenting, because we're printing the continuation of the 
paragraph that was interrupted earlier. If it's 0, the first line may be 
indented or outdented.

B<Options:>

=over

=item 'pndnt' => $indent

Give the amount of indent (positive) or outdent (negative, for "hanging")
for paragraph first lines. The unit is I<ems>. 
This setting is ignored for centered text.

=item 'align' => $choice

C<$choice> is 'justified', 'right', 'center', 'left'; the default is 'left'.
See C<text_justified> call for options to control how a line is expanded or
condensed if C<$choice> is 'justified'. C<$choice> may be shortened to the
first letter.

=item 'last_align' => place

where place is 'left' (default), 'center', or 'right' (may be shortened to
first letter) allows you to specify the alignment of the last line output,
but applies only when C<align> is 'justified'.

=item 'underline' => $distance

=item 'underline' => [ $distance, $thickness, ... ]

If a scalar, distance below baseline,
else array reference with pairs of distance and line thickness.

=item 'spillover' => $over

Controls if words in a line which exceed the given width should be 
"spilled over" the bounds, or if a new line should be used for this word.

C<$over> is 1 or 0, with the default 1 (spills over the width).

=back

B<Example:>

    $txt->font($font,$fontsize);
    $txt->leading($leading);
    $txt->translate($x,$y);
    $overflow = $txt->paragraph( 'long paragraph here ...',
                                 $width,
                                 $y+$leading-$bottom_margin );

B<Note:> if you need to change any text treatment I<within> a paragraph 
(B<bold> or I<italicized> text, for instance), this can not handle it. Only 
plain text (all the same font, size, etc.) can be typeset with C<paragraph()>.
Also, there is currently very limited line splitting (hyphenation) to better 
fit to a given width, and nothing is done for "widows and orphans".

=back

=cut

# TBD for LTR languages, does indenting on left make sense for right justified?
# TBD for bidi/RTL languages, should indenting be on right?

sub paragraph {
    my ($self, $text, $width,$height, @optsA) = @_;
    # if odd number of elements in optsA, it contains $continue flag and
    #   remainder is %opts. if even, paragraph is being called PDF::API2 style
    #   with no $continue (default to 0).
    my $continue = 0;
    if (@optsA % 2) {
	$continue = splice(@optsA, 0, 1);
    }
    my %opts = @optsA;

    # copy dashed option names to preferred undashed names
    if (defined $opts{'-align'} && !defined $opts{'align'}) { $opts{'align'} = delete($opts{'-align'}); }
    if (defined $opts{'-pndnt'} && !defined $opts{'pndnt'}) { $opts{'pndnt'} = delete($opts{'-pndnt'}); }

    my @line = ();
    my $nwidth = 0;
    my $leading = $self->leading();
    my $align = 'l'; # default left
    if (defined($opts{'align'})) {
	if    ($opts{'align'} =~ /^l/i) { $align = 'l'; }
	elsif ($opts{'align'} =~ /^c/i) { $align = 'c'; }
	elsif ($opts{'align'} =~ /^r/i) { $align = 'r'; }
	elsif ($opts{'align'} =~ /^j/i) { $align = 'j'; }
	else { warn "Unknown align value for paragraph(), 'left' used\n"; }
    } # default stays at 'l'
    my $indent = defined($opts{'pndnt'})? $opts{'pndnt'}: 0;
    if ($align eq 'c') { $indent = 0; } # indent/outdent makes no sense centered
    my $first_line = !$continue;
    my $lw;
    my $em = $self->advancewidth('M');

    while (length($text) > 0) { # more text to go...
	# indent == 0 (flush) all lines normal width
	# indent (>0) first line moved in on left, subsequent normal width
	# outdent (<0) first line is normal width, subsequent moved in on left
	$lw = $width;
	if ($indent > 0 && $first_line) { $lw -= $indent*$em; }
	if ($indent < 0 && !$first_line) { $lw += $indent*$em; }
	# now, need to indent (move line start) right for 'l' and 'j'
	if ($lw < $width && ($align eq 'l' || $align eq 'j')) {
        $self->cr($leading); # go UP one line
	    # 88*10 text space units per em, negative to right for TJ
	    $self->nl(88*abs($indent)); # come down to right line and move right
	}

        if      ($align eq 'j') {
            ($nwidth,$text) = $self->text_fill_justified($text, $lw, %opts);
        } elsif ($align eq 'r') {
            ($nwidth,$text) = $self->text_fill_right($text, $lw, %opts);
        } elsif ($align eq 'c') {
            ($nwidth,$text) = $self->text_fill_center($text, $lw, %opts);
        } else {  # 'l'
            ($nwidth,$text) = $self->text_fill_left($text, $lw, %opts);
        }

        $self->nl();
	$first_line = 0;

	# bail out and just return remaining $text if run out of vertical space
        last if ($height -= $leading) < 0;
    }

    if (wantarray) {
	# paragraph() called in the context of returning an array
        return ($text, $height);
    }
    return $text;
}

=head3 section, paragraphs

    ($overflow_text, $continue, $unused_height) = $txt->section($text, $width,$height, $continue, %opts)

    $overflow_text = $txt->section($text, $width,$height, $continue, %opts)

=over

The C<$text> contains a string with one or more paragraphs C<$width> wide, 
starting at the current text position, with a newline \n between each 
paragraph. Each paragraph is output (see C<paragraph>) until the C<$height> 
limit is met (a partial paragraph may be at the bottom). Whatever wasn't 
output, will be B<returned>.
If called in an array context, the 
unused height and the paragraph "continue" flag are also B<returned>.

C<$continue> is 0 for the first call of section(), and then use the value 
returned from the previous call (1 if a paragraph was cut in the middle) to 
prevent unwanted indenting or outdenting of the first line being printed.

B<Options:>

=over

=item 'pvgap' => $vertical

Additional vertical space (unit: pt) between paragraphs (default 0). 
Note that this space will also be added after the last paragraph printed,
B<unless> you give a negative value. The |pvgap| is the value used (positive);
negative tells C<section> I<not> to add the gap (space) after the last
paragraph in the section.

=back

See C<paragraph> for other C<%opts> you can use, such as C<align> and C<pndnt>.

B<Alternate name:> paragraphs

This is for compatibility with PDF::API2, which renamed C<section>.

=back

=cut

# alias for compatibility
sub paragraphs {
    return section(@_);
}

sub section {
    my ($self, $text, $width,$height, $continue, %opts) = @_;
    # copy dashed option names to preferred undashed names
    if (defined $opts{'-pvgap'} && !defined $opts{'pvgap'}) { $opts{'pvgap'} = delete($opts{'-pvgap'}); }

    my $overflow = ''; # text to return if height fills up
    my $pvgap = defined($opts{'pvgap'})? $opts{'pvgap'}: 0;
    my $pvgapFlag = ($pvgap >= 0)?1 :0; 
    $pvgap = abs($pvgap);
    # $continue =0 if fresh paragraph, or =1 if continuing one cut in middle

    my @paras = split(/\n/, $text);
    for (my $i=0; $i<@paras; $i++) {
	my $para = $paras[$i];
	# regardless of whether we've run out of space vertically, we will
	# loop through all the paragraphs requested
	
	# already seen inability to output more text?
	# just put unused text back together into the string
	# $continue should stay 1
        if (length($overflow) > 0) {
            $overflow .= "\n" . $para;
            next;
        }
        ($para, $height) = $self->paragraph($para, $width,$height, $continue, %opts);
	$continue = 0;
	if (length($para) > 0) {
	    # we cut a paragraph in half. set flag that continuation doesn't
	    # get indented/outdented (continue current left margin)
            $overflow .= $para;
	    $continue = 1;
	}

	# inter-paragraph vertical space? (0 length $para means that the 
	# entire paragraph was consumed)
	# note that the last paragraph will also get the extra space after it
	# and first paragraph did not
	# if this is the last paragraph in the section, still want a gap to
	# the next section's starting paragraph, so can't simply omit gap.
	# however, want to avoid a pending gap (Td) if that's the last of all.
	if (length($para) == 0 && $pvgap != 0 && 
	    ($i < scalar(@paras)-1 || $pvgapFlag)) { 
            # move DOWN page by pvgap amount (is > 0)
	    $self->cr(-$pvgap); # creates pending Td command
	    $height -= $pvgap;
        }
    }

    if (wantarray) {
	# section() called in the context of returning an array
        return ($overflow, $continue, $height);
    }
    return $overflow;
}

=head3 textlabel

    $width = $txt->textlabel($x,$y, $font, $size, $text, %opts)

=over

Place a line of text at an arbitrary C<[$x,$y]> on the page, with various text 
settings (treatments) specified in the call.

=over

=item $font

A previously created font.

=item $size

The font size (points).

=item $text

The text to be printed (a single line).

=back

B<Options:>

=over

=item 'rotate' => $deg

Rotate C<$deg> degrees counterclockwise from due East.

=item 'color' => $cspec

A color name or permitted spec, such as C<#CCE840>, for the character I<fill>.

=item 'strokecolor' => $cspec

A color name or permitted spec, such as C<#CCE840>, for the character I<outline>.

=item 'charspace' => $cdist

Additional distance between characters.

=item 'wordspace' => $wdist

Additional distance between words.

=item 'hscale' => $hfactor

Horizontal scaling mode (percentage of normal, default is 100).

=item 'render' => $mode

Character rendering mode (outline only, fill only, etc.). See C<render> call.

=item 'left' => 1

Left align on the given point. This is the default.

=item 'center' => 1

Center the text on the given point.

=item 'right' => 1

Right align on the given point.

=item 'align' => $placement

Alternate to left, center, and right. C<$placement> is 'left' (default),
'center', or 'right'.

=back

Other options available to C<text>, such as underlining, can be used here.

The width used (in points) is B<returned>.

=back

B<Please note> that C<textlabel()> was not designed to interoperate with other
text operations. It is a standalone operation, and does I<not> leave a "next 
write" position (or any other setting) for another C<text> mode operation. A 
following write will likely be at C<(0,0)>, and not at the expected location.

C<textlabel()> is intended as an "all in one" convenience function for single 
lines of text, such as a label on some
graphics, and not as part of putting down multiple pieces of text. It I<is>
possible to figure out the position of a following write (either C<textlabel>
or C<text>) by adding the returned width to the original position's I<x> value
(assuming left-justified positioning).

=cut

sub textlabel {
    my ($self, $x,$y, $font, $size, $text, %opts) = @_;
    # copy dashed option names to preferred undashed names
    if (defined $opts{'-rotate'} && !defined $opts{'rotate'}) { $opts{'rotate'} = delete($opts{'-rotate'}); }
    if (defined $opts{'-color'} && !defined $opts{'color'}) { $opts{'color'} = delete($opts{'-color'}); }
    if (defined $opts{'-strokecolor'} && !defined $opts{'strokecolor'}) { $opts{'strokecolor'} = delete($opts{'-strokecolor'}); }
    if (defined $opts{'-charspace'} && !defined $opts{'charspace'}) { $opts{'charspace'} = delete($opts{'-charspace'}); }
    if (defined $opts{'-hscale'} && !defined $opts{'hscale'}) { $opts{'hscale'} = delete($opts{'-hscale'}); }
    if (defined $opts{'-wordspace'} && !defined $opts{'wordspace'}) { $opts{'wordspace'} = delete($opts{'-wordspace'}); }
    if (defined $opts{'-render'} && !defined $opts{'render'}) { $opts{'render'} = delete($opts{'-render'}); }
    if (defined $opts{'-right'} && !defined $opts{'right'}) { $opts{'right'} = delete($opts{'-right'}); }
    if (defined $opts{'-center'} && !defined $opts{'center'}) { $opts{'center'} = delete($opts{'-center'}); }
    if (defined $opts{'-left'} && !defined $opts{'left'}) { $opts{'left'} = delete($opts{'-left'}); }
    if (defined $opts{'-align'} && !defined $opts{'align'}) { $opts{'align'} = delete($opts{'-align'}); }
    my $wht;

    my %trans_opts = ( 'translate' => [$x,$y] );
    my %text_state = ();
    $trans_opts{'rotate'} = $opts{'rotate'} if defined($opts{'rotate'});

    my $wastext = $self->_in_text_object();
    if ($wastext) {
        %text_state = $self->textstate();
        $self->textend();
    }
    $self->save();
    $self->textstart();

    $self->transform(%trans_opts);

    $self->fillcolor(ref($opts{'color'}) ? @{$opts{'color'}} : $opts{'color'}) if defined($opts{'color'});
    $self->strokecolor(ref($opts{'strokecolor'}) ? @{$opts{'strokecolor'}} : $opts{'strokecolor'}) if defined($opts{'strokecolor'});

    $self->font($font, $size);

    $self->charspace($opts{'charspace'}) if defined($opts{'charspace'});
    $self->hscale($opts{'hscale'})       if defined($opts{'hscale'});
    $self->wordspace($opts{'wordspace'}) if defined($opts{'wordspace'});
    $self->render($opts{'render'})       if defined($opts{'render'});

    if      (defined($opts{'right'}) && $opts{'right'} ||
	     defined($opts{'align'}) && $opts{'align'} =~ /^r/i) {
        $wht = $self->text_right($text, %opts);
    } elsif (defined($opts{'center'}) && $opts{'center'} ||
	     defined($opts{'align'}) && $opts{'align'} =~ /^c/i) {
        $wht = $self->text_center($text, %opts);
    } elsif (defined($opts{'left'}) && $opts{'left'} ||
	     defined($opts{'align'}) && $opts{'align'} =~ /^l/i) {
        # override any stray 'align' that got through to here
        $wht = $self->text($text, %opts, 'align'=>'l');  # explicitly left aligned
    } else {
        # override any stray 'align' that got through to here
        $wht = $self->text($text, %opts, 'align'=>'l');  # left aligned by default
    }

    $self->textend();
    $self->restore();

    if ($wastext) {
        $self->textstart();
        $self->textstate(%text_state);
    }
    return $wht;
}
 
# --------------------- start of column() section ---------------------------
# WARNING: be sure to keep in synch with changes to POD elsewhere, especially
# Column_docs.pm

=head3 column

See L<PDF::Builder::Content::Column_docs> for documentation.

=cut

# TBD, future:
#  * = not official HTML5 or CSS (i.e., an extension)
# perhaps 3.029?  
#   arbitrary paragraph shapes (path)
#   at a minimum, hyphenate-basic usage including &SHY;
#   <img>, <sup>, <sub>, <pre>, <nobr>, <br>, <dl>/<dt>/<dd>, <center>*
#   <big>*, <bigger>*, <smaller>*, <small> 
#   <cite>, <q>, <code>, <kbd>, <samp>, <var>
#   CSS _expand* to call hscale() and/or condensed/expanded type in get_font()
#        (if not doing synfont() call)
#   CSS text transform, such as uppercase and lowercase flavors
#   CSS em and ex sizes relative to current font size (like %), 
#        other absolute sizes such as in, cm, mm, px (?)
#
#  TBD link page numbers: currently nothing shown ($page_numbers = 0)
#    add <_link_page> text</_link_page> inserted BEFORE </_ref>
#    page_numbers=1 " on page $fpn" (internal) " on [page $fpn]" (external)
#                =2 " on this page" " on previous page" "on following page" etc
#    permits user to choose formatting CSS that often will be a bit different
#      from rest of link text, such as Roman while link text is italic
#    consider $extname of some sort for external links not just [ ] e.g.,
#      " on page [$extname $fpn]" extname not necessarily same as file name
#    link to id already knows ppn and fpn. link to #p could use an additional
#      pass for forward references to get the $fpn. link to ##ND ? might be
#      able to determine physical and forrmatted page numbers
#    local override (attribute, {&...}) of page_numbers to repair problem areas
#
#  possibly...
#   <abbr>, <base>, <wbr>
#   <article>, <aside>, <section>  as predefined page areas?
#
#  extensions to HTML and CSS...
#   <_sc>* preprocess: around runs of lowercase put <span style="font-size: 80%;
#        expand: 110%"> and fold to UPPER CASE. this is post-mytext creation!
#   <_pc>* (Petite case) like <sc> but 1ex font-size, expand 120%
#   <_dc>* drop caps
#   <_ovl>* overline (similar to underline) using CSS text-decoration: overline
#   <_k>* kern text (shift left or right) with CSS _kern, or general 
#     positioning: ability to form (La)TeX logo through character positioning
#        what to do at HTML level? x+/- %fs, y+/- %fs
#     also useful for <sup>4</sup><sub>2</sub>He notation
#   <_vfrac>* vulgar fraction, using sup, sup, kern
#   HTML attributes to tune (force end) of something, such as early </sc> 
#        after X words and/or end of line. flag to ignore next </sc> coming up,
#        or just make self-closing with children?
#   <_endc>* force end of column here (at this y, while still filling line)
#        e.g., to prevent an orphan. optional conditional (e.g., less than 1"
#        of vertical space left in column)
#   <_keep>* material to keep together, such as headings and paragraph text
#   leading (line-height) as a dimension instead of a ratio, convert to ratio
#
# 3.030 or later?
#  left/right auto margins? <center> may need this
#  Text::KnuthLiang hyphenation
#  <hyp>*, <nohyp>* control hypenation in a word (and remember
#        rules when see this word again)
#  <lang>* define language of a span of text, for hyphenation/audio purposes
#  Knuth-Plass paragraph shaping (with proper hyphenation) 
#  HarfBuzz::Shaper for ligatures, callout of specific glyphs (not entities), 
#        RTL and non-Western language support. <bdi>, <bdo>
#  <nolig></nolig>* forbid ligatures in this range
#  <lig gid='nnn'> </lig>* replace character(s) by a ligature
#  <alt gid='nnn'> </alt>* replace character(s) by alternate glyph
#        such as a swash. font-dependent
#  <eqn>* (needs image support, SVG processing)

sub column {
    my ($self, $page, $text, $grfx, $markup, $txt, %opts) = @_;
    my $pdf = $self->{' api'}->{' FM'}->{' pdf'};

    my $rc = 0; # so far, a normal call with input completely consumed
    my $unused = undef;
    # array[1] will be consolidated CSS from any <style> tags
    my ($x, $y);

    my $font_size = 12; # basic default, override with font-size
   #if ($text->{' fontsize'} > 0) { $font_size = $text->{' fontsize'}; } # already defined font size?
    if (defined $opts{'font_size'}) { $font_size = $opts{'font_size'}; }
    
    my $leading = 1.125; # basic default, override with line-height
    if (defined $opts{'leading'}) { $leading=$opts{'leading'}; }
    my $marker_width = 1*$font_size;  # 2em space for list markers
    my $marker_gap = $font_size;   # 1em space between list marker and item
    if (defined $opts{'marker_width'}) { $marker_width=$opts{'marker_width'}; }
    if (defined $opts{'marker_gap'}) { $marker_gap=$opts{'marker_gap'}; }
    my $page_numbers = 0; # default: formatted pgno not used in links (TBD)
   #if (defined $opts{'page_numbers'}) { $page_numbers=$opts{'page_numbers'}; }

    my $restore = 0; # restore text state and color at end
    if (defined $opts{'restore'}) { $restore = $opts{'restore'}; }
    my @entry_state = (); # font state, color and graphics color
    push @entry_state, $text->{' font'};  # initially may be undef, then hashref
    push @entry_state, $text->{' fontsize'};  # initially 0
    push @entry_state, $text->{' fillcolor'};  # an arrayref, often single number or string
    push @entry_state, $text->{' strokecolor'};  # an arrayref, often single number or string
    if (defined $grfx && ref($grfx) =~ m/^PDF::Builder::Content=HASH/){
	# we have a valid grfx, so can use its values
        push @entry_state, $grfx->{' fillcolor'};  # an array, often single number or string
        push @entry_state, $grfx->{' strokecolor'};  # an array, often single number or string
    } else {
        # no grfx, so use undef for values
	push @entry_state, undef;
	push @entry_state, undef;
    }

    # fallback CSS properties, inserted at array[0]
    my $default_css = _default_css($pdf, $text, $font_size, $leading, %opts); # per-tag properties
    # dump @mytext list within designated column @outline
    # for now, the outline is a simple rectangle
    my $outline_color = 'none';  # optional outline of the column
    $outline_color = $opts{'outline'} if defined $opts{'outline'};

    # define coordinates of column, currently just 'rect' rectangle, but
    # in future could be very elaborate
    my @outline = _get_column_outline($grfx, $outline_color, %opts);
    my ($col_min_x, $col_min_y, $col_max_x, $col_max_y) = 
        _get_col_extents(@outline);
    my $start_y = $col_max_y; # default is at top of column
    my $topCol = 1; # paragraph is at top of column, don't use margin-top
    $start_y = $opts{'start_y'} if defined $opts{'start_y'};
    if ($start_y != $col_max_y) { 
	# topCol reset to 0 b/c not at top of column
	$topCol = 0; # go ahead with any extra top margin
    }

    # 'page' parameters
    my ($pass_count, $max_passes, $ppn, $extfilepath, $fpn, $LR, $bind);
    $ppn = $extfilepath = $fpn = undef;
      # physical page number 1,2,..., filepath/name/ext for THIS output,
      # formatted page number string (all for link creation)
    $LR = 'R';  # for now, just right-hand page
    $bind = 0;  # for now, offset column by 0 points to "outside" of page
    if (defined $opts{'page'}) {
	if (!( ref($opts{'page'}) eq 'ARRAY' &&
	       7 == @{$opts{'page'}} )) {
	    carp "page not anonymous array of length 7, ignored.";
	} else {
	    $pass_count  = $opts{'page'}->[0];
	    $max_passes  = $opts{'page'}->[1];
	    $ppn         = $opts{'page'}->[2];
	    if (defined $ppn && $ppn !~ /^[1-9]\d*$/) {
		carp "physical page number must be integer > 0";
		$ppn = 1;
	    }
	    $extfilepath = $opts{'page'}->[3];
	    # external name for THIS output (other docs can link to it)
	    # undef OK, if will never link to this from outside. this name
	    # is the path and name of this output file in its FINAL home,
	    # not necessarily where it is created!
	    $fpn         = $opts{'page'}->[4];
	    # formatted page string (THIS page)
	    $LR          = $opts{'page'}->[5];
	    if (!defined $LR) { $LR = 'R'; }
	    if (defined $LR && $LR ne 'L' && $LR ne 'R') {
		carp "LR setting should be L or R. force to R";
		$LR = 'R';
	    }
	    # TBD handle 'L' and 'R', for now ignore $LR
	    $bind        = $opts{'page'}->[6];
	    # TBD for now, ignore $bind
        }
    } else {
	# for situations where $opts{'page'} is not passed in because 
	# we're not doing links and similar. some will be used.
	$pass_count = 1;
	$max_passes = 1;
	$ppn = 1;
	$extfilepath = '';
	$fpn = '1';
	$LR = 'R';
	$bind = 0;
    }

    # what is the state of %state parameter (hashref $state)
    my $state = undef;  # OK, but xrefs and other links disallowed!
    # TBD everywhere $state used, check if defined!
    #      disable all the _ref and _reft stuff if no state
    if (defined $opts{'state'} && ref($opts{'state'}) eq 'HASH') {
	$state = $opts{'state'};
        # TBD {source} {target} {params} to read in, write out
	#     before first pass of first PDF (if multiple), external initialize
    }

    # what is the content of $text: string, array, or array of hashes?
    # (or already set up, per 'pre' markup)
    # break up text into array of hashes so we have one common input
    my @mytext = _break_text($txt, $markup, %opts,'page_numbers'=>$page_numbers);
    unshift @mytext, $default_css;

    # each element of mytext is an anonymous hash, with members text=>text
    # content, font_size, color, font, variants, etc.
    #
    # if markup=pre, it's already in final form (array of hashes)
    # if none, separate out paragraphs into array of hashes
    # if md1 or md2, convert to HTML (error if no converter)
    # if html, need to interpret (error if no converter)
    # finally, resulting array of hashes is interpreted and fit in column
    # process style attributes, tag attributes, style tags, column() options,
    # and fixed default attributes in that order to fill in each tag's
    # attribute list. on exit from tag, set attributes to restore settings
    @mytext = _tag_attributes($markup, @mytext);
    _check_CSS_properties(@mytext);

    ($rc, $start_y, $unused) = _output_text($start_y, $col_min_y, \@outline, $pdf, $page, $text, $grfx, $restore, $topCol, $font_size, $markup, $marker_width, $marker_gap, $leading, $opts{'page'}, $page_numbers, $pass_count, $max_passes, $state, @mytext);

    if ($rc > 1) {
	# restore = 2 request restore to @entry_state for rc=0, 3 for 1
        $text->{' font'} = $entry_state[0]; 
        $text->{' fontsize'} = $entry_state[1]; 
        $text->{' fillcolor'} = $entry_state[2];
        $text->{' strokecolor'} = $entry_state[3];
        if (defined $grfx && ref($grfx) =~ m/^PDF::Builder::Content=HASH/){
	    # we have a valid grfx, so can use its values
            $grfx->{' fillcolor'} = $entry_state[4];
            $grfx->{' strokecolor'} = $entry_state[5];
        } else {
            # no grfx, so do nothing
        }
	$rc -= 2;
    }

    return ($rc, $start_y, $unused);
} # end of column()

# set up an element containing all the default settings, as well as those
# passed in by column() parameters and options. this is generated once for
# each call to column, in case any parameters or options change.
sub _default_css {
    my ($pdf, $text, $font_size, $leading, %opts) = @_;

    # font size is known
    # if user wishes to set font OUTSIDE of column
    # if FontManager called outside column() and wish to inherit settings for
    #  face, style, weight, color (fill), 'font_info'=>'-fm-'
    # if FontManager NOT used to set font externally, can just inherit font
    #  (don't know what it is), current font = -external-. all styles and 
    #  weights are this one font
    # otherwise, 'font_info'=>'face:style:weight:color' where style = italic
    #  or normal, weight = bold or normal, color = a color name e.g., black.
    #  this face must be known to FontManager
    # as last resort, if font not set outside of column, FontManager default
    my (@cur_font, @cur_color, $current_color);
    if (!defined $opts{'font_info'}) {
	# default action: -fm-
	$opts{'font_info'} = '-fm-';
    }
    # override any predefined font
    if      ($opts{'font_info'} eq '-fm-') {
	# use whatever FontManager thinks is the default font
        $pdf->get_font('face'=>'default'); # set current font to default
        @cur_font = $pdf->get_font(); 
	$cur_font[1] = $cur_font[2] = 0; # no italic or bold
        # use [0..2] of returned array
    } elsif ($opts{'font_info'} eq '-ext-') {
	# requesting preloaded font, as '-external-'
        # there IS a predefined font, from somewhere, to use?
        if ($pdf->get_external_font($text)) {
	    # failed to find a predefined font. use default
            $pdf->get_font('face'=>'default'); # set current font to default
        }
        @cur_font = $pdf->get_font(); # use [0..2] of returned array,
	                 # either predefined -external- font, or default font
    } else {
	# explicitly given font must be KNOWN to FontManager
	# family:style:weight:color (normal/0/italic/1, normal/0/bold/1)
	@cur_font = split /:/, $opts{'font_info'};
	# add normal style and weight if not given
	if (@cur_font == 2) { push @cur_font, 0; }
	if (@cur_font == 1) { push @cur_font, 0,0; }
	if ("$cur_font[1]" eq 'normal') { $cur_font[1] = 0; }
	if ("$cur_font[1]" eq 'italic') { $cur_font[1] = 1; }
	if ("$cur_font[2]" eq 'normal') { $cur_font[2] = 0; }
	if ("$cur_font[2]" eq 'bold'  ) { $cur_font[2] = 1; }
	# set the current font
	if (@cur_font == 4) { $text->fillcolor($cur_font[3]); } # color
	$pdf->get_font('face'=>$cur_font[0],
		       'italic'=>$cur_font[1],
		       'bold'=>$cur_font[2]);
	@cur_font = $pdf->get_font();
    }
    # @cur_font should have (at least) face, italic 0/1, bold 0/1
    #  to load into 'body' properties later

    @cur_color = $text->fillcolor();
#   if (defined $opts{'font_color'}) {
#	# request override of current text color on entry
#	@cur_color = ($opts{'font_color'});
#   }
    if (@cur_color == 1) { 
   	# 'name', '#rrggbb' etc. suitable for CSS usage
	# TBD: single gray scale value s/b changed to '#rrggbb'
	#       (might be 0..1, 0..100, 0..ff)? 0 = black
    	$current_color = $cur_color[0];
    } else {
	# returned an array of values, unsuitable for CSS
	# TBD: 3 values 0..1 turn into #rrggbb
	# TBD: 3 values 0..100 turn into #rrggbb
	# TBD: 3 values 0..ff turn into #rrggbb
	# TBD: 4 values like 3, but CMYK
	# for now, default to 'black'
    	$current_color = 'black';
    }

    my %style;
    $style{'tag'} = 'defaults';
    $style{'text'} = '';

    $style{'body'} = {};
    $style{'p'} = {};
    $style{'ol'} = {};
    $style{'ul'} = {};
    $style{'_sl'} = {};
    $style{'h1'} = {};
    $style{'h2'} = {};
    $style{'h3'} = {};
    $style{'h4'} = {};
    $style{'h5'} = {};
    $style{'h6'} = {};
    $style{'i'} = {};
    $style{'em'} = {};
    $style{'b'} = {};
    $style{'strong'} = {};
    $style{'code'} = {};
    $style{'hr'} = {};
    $style{'a'} = {};
    $style{'_ref'} = {};
    $style{'_reft'} = {};  # no visible content
    $style{'_nameddest'} = {};  # no visible content

    $style{'body'}->{'font-size'} = $font_size; # must be in points
    $style{'body'}->{'_parent-fs'} = $font_size; # carry current value
    $style{'body'}->{'line-height'} = $leading;

    # HARD-CODED default for paragraph indent, top margin
    my $para = [ 1, 1*$font_size, 0 ]; 
    # if font_size changes, change indentation
    # REVISED default if 'para' option given
    if (defined $opts{'para'}) {
       #$para->[0]  # flag: 0 = <p> is normal top of paragraph (with indent
       #    and margin), 1 = at top of column, so suppress extra top margin
       #    (and reset once past this first line)
        $para->[1] = $opts{'para'}->[0]; # indentation
        $para->[2] = $opts{'para'}->[1]; # extra top margin
    }
    # $para flag determines whether these settings are used or ignored (=1, 
    # we are at the top of a column, ignore text-indent and margin-top)
    # set paragraph CSS defaults, may be overridden below
    $style{'p'}->{'text-indent'} = $para->[1];
    $style{'p'}->{'margin-top'} = $para->[2];

    my $color = $current_color;  # text default color
    $color = $opts{'color'} if defined $opts{'color'};
    $style{'body'}->{'color'} = $color;

    # now for fixed settings
    $style{'body'}->{'font-family'} = $cur_font[0]; # face
    $style{'body'}->{'font-style'} = $cur_font[1]? 'italic': 'normal';
    # TBD future: multiple gradations of weight, numeric and named
    $style{'body'}->{'font-weight'} = $cur_font[2]? 'bold': 'normal';
   #$style{'body'}->{'font-variant'} = 'normal'; # small-caps, petite caps
    # TBD future: optical size select subfont, slant separate from italic flagm,
    #             stretch amount (expand/condense)
    # TBD future: 'margin' consolidated entry
    $style{'body'}->{'margin-top'} = '0'; 
    $style{'body'}->{'margin-right'} = '0'; 
    $style{'body'}->{'margin-bottom'} = '0'; 
    $style{'body'}->{'margin-left'} = '0'; 
    $style{'body'}->{'_left'} = '0'; 
    $style{'body'}->{'_left_nest'} = '0'; 
    $style{'body'}->{'_right'} = '0'; 
    $style{'body'}->{'text-indent'} = '0'; 
    $style{'body'}->{'text-align'} = 'left';
   #$style{'body'}->{'text-transform'} = 'none'; # capitalize, uppercase, lowercase
   #$style{'body'}->{'border-style'} = 'none'; # solid, dotted, dashed... TBD
   #$style{'body'}->{'border-width'} = '1pt'; 
   #$style{'body'}->{'border-color'} = 'inherit'; 
    # TBD border-* individually specify for top/right/bottom/left
    #     also 'border' consolidated entry
    $style{'body'}->{'text-decoration'} = 'none';
    $style{'body'}->{'display'} = 'block'; 
    $style{'body'}->{'width'} = '-1';  # used for <hr> length in pts, -1 is full column
    $style{'body'}->{'height'} = '-1';  # used for <hr> size (thickness) in pts
    $style{'body'}->{'_href'} = ''; 
    $style{'body'}->{'_marker-before'} = ''; 
    $style{'body'}->{'_marker-after'} = '.'; 
    $style{'body'}->{'_marker-color'} = ''; 
    $style{'body'}->{'_marker-font'} = ''; 
    $style{'body'}->{'_marker-size'} = $font_size; 
    $style{'body'}->{'_marker-style'} = ''; 
    $style{'body'}->{'_marker-text'} = ''; 
    $style{'body'}->{'_marker-weight'} = ''; 
    $style{'body'}->{'_marker-align'} = 'right'; 

    $style{'p'}->{'display'} = 'block';
    $style{'font'}->{'display'} = 'inline';
    $style{'span'}->{'display'} = 'inline';

    $style{'ul'}->{'list-style-type'} = '.u';
      # disc, circle, square, box, none
    $style{'ul'}->{'list-style-position'} = 'outside'; # or inside or numeric
    $style{'ul'}->{'display'} = 'block'; 
    # TBD future: padding and padding-*
    $style{'ul'}->{'margin-top'} = '50%';  # relative to text's font-size
    $style{'ul'}->{'margin-bottom'} = '50%'; 
    $style{'ul'}->{'_marker-font'} = 'ZapfDingbats';
    $style{'ul'}->{'_marker-style'} = 'normal';
    $style{'ul'}->{'_marker-weight'} = 'bold';
    $style{'ul'}->{'_marker-size'} = "50%";
    $style{'ul'}->{'_marker-align'} = "right";
    $style{'_sl'}->{'list-style-type'} = 'none'; 
    $style{'_sl'}->{'list-style-position'} = 'outside'; # or inside or numeric
    $style{'_sl'}->{'display'} = 'block'; 
    $style{'_sl'}->{'margin-top'} = '50%';  # relative to text's font-size
    $style{'_sl'}->{'margin-bottom'} = '50%'; 
    $style{'ol'}->{'list-style-type'} = '.o';
      # decimal, lower-roman, upper-roman, lower-alpha, upper-alpha, none
      # arabic is synonym for decimal
    $style{'ol'}->{'list-style-position'} = 'outside'; # or inside or numeric
    $style{'ol'}->{'display'} = 'block'; 
    $style{'ol'}->{'margin-top'} = '50%';  # relative to text's font-size
    $style{'ol'}->{'margin-bottom'} = '50%'; 
    $style{'ol'}->{'_marker-before'} = ''; # content to add before marker
    $style{'ol'}->{'_marker-after'} = '.'; # content to add after marker
    $style{'ol'}->{'_marker-font'} = '';  # unchanged
    $style{'ol'}->{'_marker-style'} = 'normal';
    $style{'ol'}->{'_marker-weight'} = 'bold';
    $style{'ol'}->{'_marker-size'} = '100%';
    $style{'ol'}->{'_marker-align'} = "right";
    $style{'li'}->{'display'} = 'inline';  # should inherit from ul or ol
               # marker is block, forcing new line, and li immediately follows

   #$style{'h6'}->{'text-transform'} = 'uppercase'; # heading this level CAPS
    $style{'h6'}->{'font-weight'} = 'bold'; # all headings bold
    $style{'h6'}->{'font-size'} = '75%'; # % of original font-size
    $style{'h6'}->{'margin-top'} = '106%'; # relative to the font-size
    $style{'h6'}->{'margin-bottom'} = '80%'; # relative to the font-size
    $style{'h6'}->{'display'} = 'block'; # block (start on new line)

    $style{'h5'}->{'font-weight'} = 'bold';
    $style{'h5'}->{'font-size'} = '85%';
    $style{'h5'}->{'margin-top'} = '95%';
    $style{'h5'}->{'margin-bottom'} = '71%';
    $style{'h5'}->{'display'} = 'block';

    $style{'h4'}->{'font-weight'} = 'bold';
    $style{'h4'}->{'font-size'} = '95%';
    $style{'h4'}->{'margin-top'} = '82%';
    $style{'h4'}->{'margin-bottom'} = '61%';
    $style{'h4'}->{'display'} = 'block';

    $style{'h3'}->{'font-weight'} = 'bold';
    $style{'h3'}->{'font-size'} = '115%';
    $style{'h3'}->{'margin-top'} = '68%';
    $style{'h3'}->{'margin-bottom'} = '51%';
    $style{'h3'}->{'display'} = 'block';

    $style{'h2'}->{'font-weight'} = 'bold';
    $style{'h2'}->{'font-size'} = '150%';
    $style{'h2'}->{'margin-top'} = '54%';
    $style{'h2'}->{'margin-bottom'} = '40%';
    $style{'h2'}->{'display'} = 'block';

    $style{'h1'}->{'font-weight'} = 'bold';
    $style{'h1'}->{'font-size'} = '200%';
    $style{'h1'}->{'margin-top'} = '40%';
    $style{'h1'}->{'margin-bottom'} = '30%';
    $style{'h1'}->{'display'} = 'block';

    $style{'i'}->{'font-style'} = 'italic';
    $style{'i'}->{'display'} = 'inline';
    $style{'b'}->{'font-weight'} = 'bold';
    $style{'b'}->{'display'} = 'inline';
    $style{'em'}->{'font-style'} = 'italic';
    $style{'em'}->{'display'} = 'inline';
    $style{'strong'}->{'font-weight'} = 'bold';
    $style{'strong'}->{'display'} = 'inline';
    $style{'code'}->{'display'} = 'inline';
    $style{'code'}->{'font-family'} = 'Courier'; # TBD why does ' default-constant' fail?
    $style{'code'}->{'font-size'} = '85%';

    $style{'u'}->{'display'} = 'inline';
    $style{'u'}->{'text-decoration'} = 'underline';
    $style{'ins'}->{'display'} = 'inline';
    $style{'ins'}->{'text-decoration'} = 'underline';

    $style{'s'}->{'display'} = 'inline';
    $style{'s'}->{'text-decoration'} = 'line-through';
    $style{'strike'}->{'display'} = 'inline';
    $style{'strike'}->{'text-decoration'} = 'line-through';
    $style{'del'}->{'display'} = 'inline';
    $style{'del'}->{'text-decoration'} = 'line-through';

    # non-standard tag for overline TBD
   #$style{'_ovl'}->{'display'} = 'inline';
   #$style{'_ovl'}->{'text-decoration'} = 'overline';
    
    # non-standard tag for kerning (+ font-size fraction to move left, - right)
    # e.g., for vulgar fraction adjust / and denominator <sub> TBD
   #$style{'_k'}->{'display'} = 'inline';
   #$style{'_k'}->{'_kern'} = '0.2';

    $style{'hr'}->{'display'} = 'block';
    $style{'hr'}->{'height'} = '0.5'; # 1/2 pt default thickness
    $style{'hr'}->{'width'} = '-1'; # default width is full column
    $style{'hr'}->{'margin-top'} = '100%'; 
    $style{'hr'}->{'margin-bottom'} = '100%'; 

    $style{'blockquote'}->{'display'} = 'block';
    $style{'blockquote'}->{'margin-top'} = '56%';
    $style{'blockquote'}->{'margin-bottom'} = '56%';
    $style{'blockquote'}->{'margin-left'} = '300%';  # want 3em TBD
    $style{'blockquote'}->{'margin-right'} = '300%';
    $style{'blockquote'}->{'line-height'} = '1.00'; # close spacing
    $style{'blockquote'}->{'font-size'} = '80%'; # smaller type

    # only browser (URL) applies here, so leave browser style
    # other links changed to '_ref', with its own style
    $style{'a'}->{'text-decoration'} = 'underline'; # browser style
          # none, underline, overline, line-through or a combination
	  # separated by spaces
    $style{'a'}->{'color'} = 'blue'; 
    $style{'a'}->{'display'} = 'inline'; 
    $style{'a'}->{'_href'} = ''; 

    $style{'_ref'}->{'color'} = '#660066';  # default link for xrefs
    $style{'_ref'}->{'font-style'} = 'italic'; 
    $style{'_ref'}->{'display'} = 'inline'; 
    # <_reft> and <_nameddest> no visible content, so no styling

   #$style{'sc'}->{'font-size'} = '80%'; # smaller type TBD
   #$style{'sc'}->{'_expand'} = '110%'; # wider type   TBD _expand
   #likewise for pc (petite caps) TBD

    $style{'_marker'}->{'display'} = 'block'; 
    $style{'_marker'}->{'text-align'} = 'right'; # overwrite with _marker-align
    # _marker-align defaulted 'right' in 'ul' and 'ol', N/A in '_sl'
    #  can set properties in <ol> or <ul> to apply to entire list (inherited)
    #  this is why unique CSS names _marker-* is needed rather than std names
    
    return \%style;
} # end of _default_css()

# make sure each tag's attributes are proper property names 
# consolidate attributes and style attribute (if any)
# mark empty tags (no explicit end tag will be found)
#
# also insert <_marker> tag before every <li> lacking an explicit one
sub _tag_attributes {
    my ($markup, @mytext) = @_;
    
    # start at [2], so defaults and styles skipped
    for (my $el=2; $el < @mytext; $el++) {
	if (ref($mytext[$el]) ne 'HASH') { next; }
	if ($mytext[$el]->{'tag'} eq '') { next; }

        my $tag = lc($mytext[$el]->{'tag'});
	if (!defined $tag) { next; }
	if ($tag =~ m#^/#) { next; }

	# we have a tag that might have one or more attributes that may
	# need to be renamed as a CSS property
	if      ($tag eq 'font') {
	    if (defined $mytext[$el]->{'face'}) {
		$mytext[$el]->{'font-family'} = delete($mytext[$el]->{'face'});
	    }
	    if (defined $mytext[$el]->{'size'}) {
		$mytext[$el]->{'font-size'} = delete($mytext[$el]->{'size'});
		# TBD some sizes may need to be converted to points. for now,
		#   assume is a bare number (pt), pt, or % like font-size CSS
	    }
	} elsif ($tag eq 'ol') {
	    if (defined $mytext[$el]->{'type'}) {
	        $mytext[$el]->{'list-style-type'} = delete($mytext[$el]->{'type'});
	    }
	    # note that list-style-type would be aAiI1
	    # 'start' left unchanged
	} elsif ($tag eq 'ul') {
	    if (defined $mytext[$el]->{'type'}) {
	        $mytext[$el]->{'list-style-type'} = delete($mytext[$el]->{'type'});
	    }
	} elsif ($tag eq 'li') {
	   #if (defined $mytext[$el]->{'type'}) {
	   #    $mytext[$el]->{'list-style-type'} = delete($mytext[$el]->{'type'});
	   #}
	    # 'value' left unchanged, to be used by <_marker> before this <li>
	    # 'type' to be used by <_marker> (both, under <ol> only)
	} elsif ($tag eq 'a') {
	    if (defined $mytext[$el]->{'href'}) {
	        $mytext[$el]->{'_href'} = delete($mytext[$el]->{'href'});
	    }
	} elsif ($tag eq 'hr') {
	    if (defined $mytext[$el]->{'size'}) {
	        $mytext[$el]->{'height'} = delete($mytext[$el]->{'size'});
	    }
	}
	# add any additional tag attributes -> CSS property here
	 
	# process any style attribute and override attribute values
	if (defined $mytext[$el]->{'style'}) {
	    my $style_attr = _process_style_string({}, $mytext[$el]->{'style'});
	    # hash of property_name => value pairs
	    foreach (keys %$style_attr) {
		# create or override any existing property by this name
		$mytext[$el]->{$_} = $style_attr->{$_};
	    }
	}

	# list-style-type for ol/ul/li needs fleshing out
	if (defined $mytext[$el]->{'list-style-type'}) {
	    if      ($mytext[$el]->{'list-style-type'} eq '1') {
	        $mytext[$el]->{'list-style-type'} = 'decimal';
	    } elsif ($mytext[$el]->{'list-style-type'} eq 'A') {
	        $mytext[$el]->{'list-style-type'} = 'upper-alpha';
	    } elsif ($mytext[$el]->{'list-style-type'} eq 'a') {
	        $mytext[$el]->{'list-style-type'} = 'lower-alpha';
	    } elsif ($mytext[$el]->{'list-style-type'} eq 'I') {
	        $mytext[$el]->{'list-style-type'} = 'upper-roman';
	    } elsif ($mytext[$el]->{'list-style-type'} eq 'i') {
	        $mytext[$el]->{'list-style-type'} = 'lower-roman';
	    } elsif ($mytext[$el]->{'list-style-type'} eq 'upper-latin') {
	        $mytext[$el]->{'list-style-type'} = 'upper-alpha';
	    } elsif ($mytext[$el]->{'list-style-type'} eq 'lower-latin') {
	        $mytext[$el]->{'list-style-type'} = 'lower-alpha';
	    }
	    # note that there are dozens more valid order list formats that
	    # are NOT currenty supported (TBD). also, although upper/lower-
	    # latin is valid, the code is expecting alpha
	}

	# VOID elements (br, hr, img, area, base, col, embed, input,
	# link, meta, source, track, wbr) do not have a separate end
	# tag (no children). also incude style and defaults in this list in 
	# case a stray one shows up (does not have an end tag). this is NOT 
	# really "self-closing", although the terms are often used 
	# interchangeably.
	if ($tag eq 'br' || $tag eq 'hr' || $tag eq 'img' || $tag eq 'area' ||
	    $tag eq 'base' || $tag eq 'col' || $tag eq 'embed' || 
	    $tag eq 'input' || $tag eq 'link' || $tag eq 'meta' ||
	    $tag eq 'source' || $tag eq 'track' || $tag eq 'wbr' ||
            $tag eq 'defaults' || $tag eq 'style') {
	    $mytext[$el]->{'empty_element'} = 1;
        }

	# 'next' to here
    } # for loop through all user-defined elements
    return @mytext;
} # end of _tag_attributes()

# go through <style> tags (element 1) and all element style tags (elements 2+)
# and find any bogus CSS property names. assume anything built into the code
# (defaults, etc.) is legitimate -- this is only for user-supplied CSS.
sub _check_CSS_properties {
    my @mytext = @_;

    my ($tag, $style, $stylehash);
    my @supported_properties = qw(
      color font-size line-height margin-top margin-right margin-bottom 
      margin-left text-indent text-align font-family font-weight font-style 
      display height width text-decoration _marker-before _marker-after 
      _marker-color _marker-font _marker-size _marker-style _marker-text 
      _marker-weight _marker-align list-style-type list-style-position
    );

    # 1. element 0 is default CSS, no need to check. 
    #    element 1 is user-supplied <style> tags and style=> column() option.
    #   should be tag=>'style' and 'text'=>''
    foreach my $tagname (keys %{ $mytext[1] }) {
        if ($tagname eq 'tag') { next; }
        if ($tagname eq 'text') { next; }
       #print "tagname <$tagname> check\n";
        foreach my $propname (keys %{ $mytext[1]->{$tagname} }) {
           #print "checking <$tagname> property '$propname'\n";
	    my $found = 0;
	    for (my $sup=0; $sup < @supported_properties; $sup++) {
                if ($propname eq $supported_properties[$sup]) {
	   	    $found = 1;
		    last;
                }
	    }
	    if (!$found) {
	        print STDERR "Warning: CSS property name '$propname' found in style option or <style>\n is either invalid, or is unsupported by PDF::Builder.\n";
	    }
           #my $style_string = $mytext[1]->{$sel};  TBD check value
       }
    }
     
    # 2. elements 2 and up are tags and text. check tags for style attribute
    #    and check property names there
    for (my $el = 2; $el < @mytext; $el++) {
	$tag = $mytext[$el]->{'tag'};
	if ($tag eq '' || substr($tag, 0, 1) eq '/') { next; }
        $style = $mytext[$el]->{'style'};
	if (!defined $style) { next; }

        $stylehash = _process_style_string({}, $style);
        # look at each defined property. do we support it?
	foreach (keys %$stylehash) {
	    my $propname = $_;
	    my $found = 0;
	    for (my $sup=0; $sup < @supported_properties; $sup++) {
                if ($propname eq $supported_properties[$sup]) {
		    $found = 1;
		    last;
		}
	    }
	    if (!$found) {
	        print STDERR "Warning: CSS property name '$propname' found in element $el (tag <$tag>)\n";
                print STDERR " style is either invalid, or is unsupported by PDF::Builder.\n";
	    }
	}
	# TBD stylehash->$_ check values here
    }
     
    return;
} # end of _check_CSS_properties

# the workhorse of the library: output text (modified by tags) in @mytext
sub _output_text {
    my ($start_y, $min_y, $outl, $pdf, $page, $text, $grfx, $restore, $topCol, 
	$font_size, $markup, $marker_width, $marker_gap, $leading, $optpage,
	$page_numbers, $pass_count, $max_passes, $state, @mytext)
        = @_;
    my @outline = @$outl;

    # 'page' in opts, for cross references and left-right paging
    my $pc = 1;
    my $mp = 1;
    my $ppn = 1;
    my $filename = '';
    my $fpn = '1';
    my $LR = 'R';
    my $bind = 0; # global item
    if (defined $optpage) {
	($pc, $mp, $ppn, $filename, $fpn, $LR, $bind) = @$optpage;
    }

    # start_y is the lowest extent of the previous line, or the highest point
    #   of the column outline, and is where we start the next one. 
    # min_y is the lowest y available within the column outline, outl.
    # pdf is the pdf top-level object. 
    # text is the text context. 
    # para is a flag that we are at the top of a column (no margin-top added).
    # font_size is the default font size to use.
    # markup is 'html', 'pre' etc. in case you need to do something different
    # marker_width is width (pt) of list markers (right justify within)
    # marker_gap is space (pt) between list marker and item text
    # leading is the default leading ratio to use.
    # mytext is the array of hashes containing tags, attributes, and text.
      
    my ($start_x, $x,$y, $width, $endx); # current position of text
    my ($asc, $desc, $desc_leading); 
    my $next_y = $start_y;
    # we loop to fill next line, starting with a y position baseline set when
    #   encounter the next text, and know the font, font_size, and thus the
    #   ascender/descender extents (which may grow). from that we can find
    #   the next baseline (which could be moved downwards).
    # we loop until we either run out of input text, or run out of column
    my $need_line = 1; # need to start a new line? always 'yes' (1) on
                       # call to column(). set to 'yes' if tag is for a block
		       # level display (treat like a paragraph)
    my $add_x = 0; # amount to add for indent
    my $add_y = 0; # amount to drop for first line's top margin
    my @line_extents = (); # for dealing with changes to vertical extents
                           # changes mid-line

    my $start = 1; # counter for ordered lists
    my $list_depth_u = 0; # nesting level of ul
    my $list_depth_s = 0; # nesting level of _sl
    my $list_depth_o = 0; # nesting level of ol
    my $list_marker = ''; # li marker text
    my $reversed_ol = 0; # count down from start

    my $phrase='';
    my $remainder='';
    my $desired_x;  # leave undef, is correction for need_line reset of x
    my @vmargin = (0, 0); # build up largest vertical margin (most negative and most positive)
    my $current_prop = _init_current_prop(); # determine if a property has 
    #           changed and PDF::Builder routines need calling. see
    #           _init_current_prop() for list of properties
    my @properties = ({}); # stack of properties from tags
    _update_properties($properties[0], $mytext[0], 'body');
    _update_properties($properties[0], $mytext[1], 'body');
    my $call_get_font = 0;
    my %bad_tags; # keep track of invalid HTML tags
    my $x_adj = 0;  # ul, ol list marker move left from right-align position
    my $y_adj = 0;  # ul list marker elevation

    # mytext[0] should be default css values
    # mytext[1] should be any <style> tags (consolidated) plus opts 'style'
    # user input tags/text start at mytext[2]

    # starting available space, will be updated as new line needed
    ($start_x,$y, $width) = _get_baseline($start_y, @outline);

    for (my $el = 2; $el < scalar @mytext; $el++) {
	# discard any empty elements
	if (ref($mytext[$el]) ne 'HASH') { next; }
	if (!keys %{$mytext[$el]}) { next; }
	
	if ($mytext[$el]->{'tag'} ne '') {
            # tags/end-tags
	    # should be a tag or end-tag element defined
	    # for the most part, just set properties at stack top. sometimes
	    # special actions need to be taken, with actual output (e.g.,
	    # <hr> or <img>). remember that the properties stack includes
	    # any units (%, pt, etc.), while current_prop has been converted
	    # to points.
	    my $tag = lc($mytext[$el]->{'tag'});

	    # ================ <tag> tags ==========================
	    if (substr($tag, 0, 1) ne '/') {
	        # take care of 'beginning' tags. dup the top of the properties
		# stack, update properties in the stack top element. note that
		# current_prop usually isn't updated until the text is being
		# processed. some tags need some special processing if they 
		# do something that isn't just a property change

		# watch for INK HERE where PDF needs to be told to change

		# properties stack new element ---------------------------------
	        # 1. dup the top of the properties stack for a new set of
	        #   properties to be modified by attributes and CSS
                push @properties, {};
	        foreach (keys %{$properties[-2]}) {
	            $properties[-1]->{$_} = $properties[-2]->{$_};
	        }
	        # current_prop is still previous text's properties
		# 1a. "drop" any property which should not be inherited
		#    unless value is 'inherit' (explicit inheritance, TBD)
		#    width (used by <hr>), margin-*, TBD: border-*,
		#    background-*, perhaps others. if list gets long enough,
		#    put in separate routine.
		$properties[-1]->{'width'} = 0; # used for <hr>
                $properties[-1]->{'height'} = 0; # used for <hr>
		$properties[-1]->{'margin-top'} = 0;
		$properties[-1]->{'margin-bottom'} = 0;
		$properties[-1]->{'margin-left'} = 0;
		$properties[-1]->{'margin-right'} = 0;
                # 1b. unless first entry, save parent's font-size (points)
                if (@properties > 1) {
                    $properties[-1]->{'_parent-fs'} = $properties[-2]->{'font-size'};
                } else {
                    # very first tag in list, no parent (use body.font-size) should be points
                    $properties[-1]->{'_parent-fs'} = $mytext[0]->{'body'}->{'font-size'};
                    $properties[-1]->{'_parent-fs'} = $mytext[1]->{'body'}->{'font-size'}
                        if defined $mytext[1]->{'body'}->{'font-size'};
                    # strip off any 'pt' unit and leave as bare number
                    $properties[-1]->{'_parent-fs'} =~ s/pt$//;
                }

	        # 2. update properties top with element [0] (default CSS) 
		#   per $tag
	        _update_properties($properties[-1], $mytext[0], $tag);

	        # 3. update properties top with element [1] (styles CSS)
		#   per $tag
	        _update_properties($properties[-1], $mytext[1], $tag);

	        # 4. update properties top with element [1] per any .class
		#   (styles CSS, which is only one with .class selectors)
	        if (defined $mytext[$el]->{'class'}) {
	            _update_properties($properties[-1], $mytext[1], 
		                       '.'.$mytext[$el]->{'class'});
	        }
	    
	        # 5. update properties top with element [1] per any #id
		#   (styles CSS, which is only one with #id selectors)
	        if (defined $mytext[$el]->{'id'}) {
	            _update_properties($properties[-1], $mytext[1], 
		                       '#'.$mytext[$el]->{'id'});
	        }
	    
	        # 6. update properties top with any tag/style attributes.
		#   these come from the tag itself: its attributes, 
		#   overridden by any style attribute. these are the
		#   highest priority properties. everything copied over to
		#   the stack top, but anything not a real property will end
		#   up not being used.
	        _update_properties($properties[-1], $mytext[$el]);
                # 6a. 3.028 and 3.029 releases, allow text-height as alias
		#    for line-height (currently only multiplier of font size)
		if (defined $properties[-1]->{'text-height'}) {
		    $properties[-1]->{'line-height'} = 
		      delete $properties[-1]->{'text-height'}; }
	        
                # 7. update size properties to be simply bare points, rather than e.g., 75%
                # remember that $current_prop->{'font-size'} init -1, is what was last written to PDF
		# current font size (pt) before properties applied
                my $fs = $properties[-1]->{'_parent-fs'}; # old font size (should always be one, in points > 0)
                $fs = $properties[-1]->{'font-size'} = _size2pt($properties[-1]->{'font-size'}, $fs, 'usage'=>'font-size');
                $fs = $font_size if $fs == -1; # just in case a -1 sneaks through, $font_size 
                                               # should default to 12, override with 'font_size'=>value

                $properties[-1]->{'margin-top'} = _size2pt($properties[-1]->{'margin-top'}, $fs, 'usage'=>'margin-top');
                $properties[-1]->{'margin-right'} = _size2pt($properties[-1]->{'margin-right'}, $fs, 'usage'=>'margin-right');
                $properties[-1]->{'margin-bottom'} = _size2pt($properties[-1]->{'margin-bottom'}, $fs, 'usage'=>'margin-bottom');
                $properties[-1]->{'margin-left'} = _size2pt($properties[-1]->{'margin-left'}, $fs, 'usage'=>'margin-left');
               #   border-* width (TBD, with border to set all four)
               #   padding-* (TBD, with padding to set all four)
               # width = length of <hr> in pts
                $properties[-1]->{'width'} = _size2pt($properties[-1]->{'width'}, $fs, 'usage'=>'width');
               #   height (thickness/size of <hr>) in pts
                $properties[-1]->{'height'} = _size2pt($properties[-1]->{'height'}, $fs, 'usage'=>'height');
                $properties[-1]->{'text-indent'} = _size2pt($properties[-1]->{'text-indent'}, $fs, 'usage'=>'text-indent');
                $properties[-1]->{'_marker-size'} = _size2pt($properties[-1]->{'_marker-size'}, $fs, 'usage'=>'_marker-size');
                # TBD should inside and outside be set to point values here?
                if (defined $properties[-1]->{'list-style-position'} &&
                    $properties[-1]->{'list-style-position'} ne 'inside' &&
                    $properties[-1]->{'list-style-position'} ne 'outside') {
                    $properties[-1]->{'list-style-position'} = _size2pt($properties[-1]->{'list-style-position'}, $fs,
                      'parent_size'=>$marker_width + $marker_gap, 'usage'=>'list-style-position');
                }

		# update current_prop hash -------------------------------------
		# properties stack already updated 
		# some current_prop must be updated here, such as stroke
		#   color for <hr>, font-size for top and bottom margins

		# block level elements -----------------------------------------
	        if ($properties[-1]->{'display'} eq 'block') {
		    $need_line = 1; 
		    $start_y = $next_y;
		    $add_x = $add_y = 0;
	            # block display with a non-zero top margin and/or bottom
		    # margin... set skip to larger of the two.
		    # when text is ready to be output, figure both any new
		    # top margin (for that text) and compare to the existing
		    # bottom margin (in points) saved at the end of the previous
		    # text.
                    # if paragraph and is marked as a continuation (i.e., spanned two columns),
                    # suppress indent (below) and suppress top margin by setting topCol flag
	            my $pcont = ($tag eq 'p' && defined $mytext[$el]->{'cont'} && $mytext[$el]->{'cont'})? 1: 0;
                    $topCol = 1 if $pcont;
                    $vmargin[0] = min($vmargin[0], $properties[-1]->{'margin-top'});
                    $vmargin[1] = max($vmargin[1], $properties[-1]->{'margin-top'});
		    # now that need_line etc. has been set due to block display,
		    # change stack top into 'inline'
		    $properties[-1]->{'display'} = 'inline';
	        }

		# handle specific kinds of tags' special processing
		# if no code for a tag, yet uncommented, it's supported
		#   (just no special processing at this point)
		# in many cases, all that was needed was to set properties,
		#   and normal text output takes care of the rest
		#
	        if      ($tag eq 'p') {
                    # indent for start of paragraph
		    $add_x = $properties[-1]->{'text-indent'}; # indent by para indent amount
                    $add_y = 0;
	            # p with cont=>1 is continuation of paragraph in new column 
	            # no indent and no top margin... just start a new line
	            if (defined $mytext[$el]->{'cont'} && $mytext[$el]->{'cont'}) {
                        $add_x = $add_y = 0;
                    }
	        } elsif ($tag eq 'i') {
	        } elsif ($tag eq 'em') {
		} elsif ($tag eq 'b') {
	        } elsif ($tag eq 'strong') {
	        } elsif ($tag eq 'font') { # face already renamed to
	            # font-family, size already renamed to font-size, color
	        } elsif ($tag eq 'span') { 
		    # needs style= or <style> to be useful
	        } elsif ($tag eq 'ul') { 
		    $list_depth_u++; # for selecting default marker text
		    # indent each list level by same amount (initially 0)
	            $properties[-1]->{'_left'} = $properties[-1]->{'_left_nest'};
		    # next list to be nested will start here
	            $properties[-1]->{'_left_nest'} += $marker_width+$marker_gap;
	        } elsif ($tag eq '_sl') { 
		    $list_depth_s++; # for indent level
		    # indent each list level by same amount (initially 0)
	            $properties[-1]->{'_left'} = $properties[-1]->{'_left_nest'};
		    # next list to be nested will start here
	            $properties[-1]->{'_left_nest'} += $marker_width+$marker_gap;
		} elsif ($tag eq 'ol') { 
		    # save any existing start and reversed_ol values
		    $properties[-2]->{'_start'} = $start; # current start
		    $properties[-2]->{'_reversed_ol'} = $reversed_ol; # cur flag

	            $start = 1;
	            if (defined $mytext[$el]->{'start'}) {
	                $start = $mytext[$el]->{'start'};
		    }
		    if (defined $mytext[$el]->{'reversed'}) {
			$reversed_ol = 1;
		    } else {
			$reversed_ol = 0;
		    }
                    $list_depth_o++; # for selecting default marker format
		    # indent each list level by same amount (initially 0)
	            $properties[-1]->{'_left'} = $properties[-1]->{'_left_nest'};
		    $properties[-1]->{'_left_nest'} += $marker_width+$marker_gap;
	       #} elsif ($tag eq 'img') { # hspace and vspace already 
		    # margins, width, height
		    # TBD for 3.029 currently ignored
	        } elsif ($tag eq 'a') {
		    # no special treatment at this point
	       #} elsif ($tag eq 'pre') { 
	            # white-space etc. no consolidating whitespace
                    # TBD for 3.029 currently ignored
	        } elsif ($tag eq 'code') { # font-family sans-serif + constant width 75% font-size
	        } elsif ($tag eq 'blockquote') {
		} elsif ($tag eq 'li') {
		    # where to start <li> text
		    # after /marker, $x is in desired place
                    # set its new _left for subsequent lines
		    if ($properties[-1]->{'list-style-position'} eq 'inside') {
			# _left unchanged
		    } elsif ($properties[-1]->{'list-style-position'} eq 'outside') {
			# li's copy of _left, should be reset at /li
			$properties[-1]->{'_left'} += $marker_width+$marker_gap;
	            } else {
			# extension to CSS (should already be in pts)
                        $properties[-1]->{'_left'} += $properties[-1]->{'list-style-position'};
		    }
                } elsif ($tag eq 'h1') { # TBD align
                    # treat headings as paragraphs
	        } elsif ($tag eq 'h2') {
	        } elsif ($tag eq 'h3') {
	        } elsif ($tag eq 'h4') {
	        } elsif ($tag eq 'h5') {
	        } elsif ($tag eq 'h6') {
	        } elsif ($tag eq 'hr') { 
		    # actually draw a horizontal line  INK HERE
		    $start_y = $next_y;
            
                    # drop down page by any pending vertical margin spacing
                    if ($vmargin[0] != 0 || $vmargin[1] != 0) {
                        if (!$topCol) {
                            $start_y -= ($vmargin[0]+$vmargin[1]);
                        }
                        @vmargin = (0, 0); # reset counters
                    }
                    $topCol = 0; # for rest of column do not suppress vertical margin

		    my $oldcolor = $grfx->strokecolor();
		    $grfx->strokecolor($properties[-1]->{'color'});
		    my $oldlinewidth = $grfx->linewidth();
		    my $thickness = $properties[-1]->{'height'} || 1; # HTML size attribute
		    $grfx->linewidth($thickness);
		    my $y = $start_y - $thickness/2;
                    ($start_x,$y, $width) = _get_baseline($y, @outline);
		    $x = $start_x + $properties[-1]->{'_left'};
		    $width -= $properties[-1]->{'_left'} + $properties[-1]->{'_right'}; # default full width
                    my $available = $width;  # full width amount
		    # if there is a requested width, use the smaller of the two
		    # TBD future, width as % of possible baseline, 
		    #     center or right aligned, explicit units (pt default)
		    if ($properties[-1]->{'width'} > 0 &&  # default to use full width is -1
			$properties[-1]->{'width'} < $width) {
			$width = $properties[-1]->{'width'}; # reduced width amount
		    }
                    my $align = 'center';
                    if (defined $mytext[$el]->{'align'}) {
                        $align = lc($mytext[$el]->{'align'});
                    }
                    if ($align eq 'left') {
                        # no change to x
                    } elsif ($align eq 'right') {
                        $x += ($available-$width);
                    } else {
                        if ($align ne 'center') {
                            carp "<hr> align not 'left', 'center', or 'right'. Ignored.";
                            $align = 'center';
                        }
                        $x += ($available-$width)/2;
                    }
                    $endx = $x + $width;

		    $grfx->move($x, $y);
		    $grfx->hline($endx);
		    $grfx->stroke();
		    $y -= $thickness/2;
		    $next_y = $y;
            # empty (self closing) tag, so won't go through a /hr to set bottom margin.
            # is in empty tag list, so will get proper treatment
            
		    # restore changed values
		    $grfx->linewidth($oldlinewidth);
		    $grfx->strokecolor($oldcolor);
	       #} elsif ($tag eq 'br') { # TBD force new line
	       #} elsif ($tag eq 'sup') { # TBD
	       #} elsif ($tag eq 'sub') { # TBD
	        } elsif ($tag eq 'u') {
	        } elsif ($tag eq 'ins') {
	        } elsif ($tag eq 's') {
	        } elsif ($tag eq 'strike') {
	        } elsif ($tag eq 'del') {
	        
	       # tags maybe some time in the future TBD
	       #} elsif ($tag eq 'address') { # inline formatting
	       #} elsif ($tag eq 'article') { # discrete section
	       #} elsif ($tag eq 'aside') { # discrete section 
	       #} elsif ($tag eq 'base') {
	       #} elsif ($tag eq 'basefont') {
	       #} elsif ($tag eq 'big') { #  font-size 125%
	       # already taken care of head, body
	       #} elsif ($tag eq 'canvas') {
	       #} elsif ($tag eq 'caption') {
	       #} elsif ($tag eq 'center') { #  margin-left/right auto
	       #} elsif ($tag eq 'cite') { # quotes, face?
	       #} elsif ($tag eq 'dl') { #  similar to ul/li
	       #} elsif ($tag eq 'dt') {
	       #} elsif ($tag eq 'dd') {
	       #} elsif ($tag eq 'div') {  # requires width, height, left, etc.
	       #} elsif ($tag eq 'figure') {
	       #} elsif ($tag eq 'figcap') {
	       #} elsif ($tag eq 'footer') { # discrete section
	       #} elsif ($tag eq 'header') { # discrete section
	       #} elsif ($tag eq 'kbd') { # font-family sans-serif +
	       #    constant width 75% font-size
	       #} elsif ($tag eq 'mark') {
	       #} elsif ($tag eq 'nav') { # discrete section
	       #} elsif ($tag eq 'nobr') { # treat all spaces within as NBSPs?
	       #} elsif ($tag eq 'q') { # ldquo/rdquo quotes around
	       #} elsif ($tag eq 'samp') { # font-family sans-serif + 
	       #    constant width 75% font-size
	       #} elsif ($tag eq 'section') { # discrete section
	       #} elsif ($tag eq 'small') { # font-size 75%
	       #} elsif ($tag eq 'summary') { # discrete section
                } elsif ($tag eq 'style') {
		    # sometimes some stray empty style tags seem to come 
		    # through...  can be ignored
	        } elsif ($tag eq '_marker') {
		    # at this point, all properties are set in usual way. only
		    # tasks remaining are to 1) determine the text,
		    # 2) set CSS properties to default marker conventions.
		    # 3) override text, color, etc. from _marker-* properties.
		    # 4) if not left justified, set reference x location
		    #
		    # paragraph, but label depends on parent (list-style-type)
		    # type and value attributes can override parent 
		    # list-style-type and start
		    if (defined $properties[-1]->{'_marker-text'} &&
		        $properties[-1]->{'_marker-text'} ne '') {
			# explicitly-defined _marker-text overrides all else
			$list_marker = $properties[-1]->{'_marker-text'};
		    } else {
			# li's 'value', if any. li is at el+3.
			# TBD check if parent is ol? (current_list top == o)
		        if (defined $mytext[$el+3]->{'value'}) {
		            $start =  $mytext[$el+3]->{'value'};
		        }
			# li's 'list-style-type', if any (was 'type'). li is at el+3.
			# TBD does this only apply to <ol>? check?
			if (defined $mytext[$el+3]->{'type'}) {
			    $properties[-1]->{'list-style-type'} =
			    $mytext[$el+3]->{'type'};
			}
		        # determine li marker
		        $list_marker = _marker(
			    $properties[-1]->{'list-style-type'},
			    $list_depth_u, $list_depth_o, $list_depth_s, 
			    $start, 
			    $properties[-1]->{'_marker-before'}, 
			    $properties[-1]->{'_marker-after'});
		        if (substr($list_marker, 0, 1) eq '.') {
			    # it's a bullet character (or '')
		        } else {
			    # fully formatted ordered list item
			    if ($reversed_ol) {
		                $start--;
			    } else {
		                $start++;
			    }
		        }
                        # starting at _left, position x for marker LJ, CJ, or RJ
			# WITHIN _left to _left+marker_width
			$desired_x = $start_x + $properties[-1]->{'_left'};
			if      ($properties[-1]->{'_marker-align'} eq 'left') {
			    # should already be at _left
		            $properties[-1]->{'text-align'} = 'left';
			} elsif ($properties[-1]->{'_marker-align'} eq 'center') {
			    $desired_x += $marker_width/2;
			    $properties[-1]->{'text-align'} = 'center';
			} else { # right (default)
			    $desired_x += $marker_width;
			    $properties[-1]->{'text-align'} = 'right';
			}

		        # dl: variable length marker width, minimum size given,
		        #     which is where dd left margin is
			#   handle dl/dt/dd separately from ul/ol/_sl
		    }

		    # list_marker is set
		    if ($list_marker eq '.none' || $list_marker =~ /^ *$/) {
		        # list_marker '' or ' ' or '.none': don't reset 
			# properties as it generates redundant color, font, 
			# size, etc. changes because no ink laid down
                    } else {
			# issue property changes when necessary
                        my $fs = $properties[-1]->{'font-size'};
		        # override any other property with corresponding _marker-*
		        # properties-to-PDF-calls have NOT yet been done
		        if (defined $properties[-1]->{'_marker-color'} &&
		            $properties[-1]->{'_marker-color'} ne '') {
                            $properties[-1]->{'color'} = 
			        $properties[-1]->{'_marker-color'};
		        }
		        if (defined $properties[-1]->{'_marker-font'} &&
		            $properties[-1]->{'_marker-font'} ne '') {
                            $properties[-1]->{'font-family'} = 
			        $properties[-1]->{'_marker-font'};
		        }
		        if (defined $properties[-1]->{'_marker-style'} &&
		            $properties[-1]->{'_marker-style'} ne '') {
                            $properties[-1]->{'font-style'} = 
			        $properties[-1]->{'_marker-style'};
		        }
		        if (defined $properties[-1]->{'_marker-size'} &&
		            $properties[-1]->{'_marker-size'} ne '') {
                            $properties[-1]->{'font-size'} = 
			        $properties[-1]->{'_marker-size'};
		        }
		        if (defined $properties[-1]->{'_marker-weight'} &&
		            $properties[-1]->{'_marker-weight'} ne '') {
                            $properties[-1]->{'font-weight'} = 
			        $properties[-1]->{'_marker-weight'};
		        }
			# _marker-align is not a standard CSS property
		
		        # finally, update the text within the _marker
		        if ($list_marker ne '') {
		            # list marker should be nonblank for <ol> and <ul>,
		            # empty for <_sl> (just leave marker text alone)
    
		            # output the marker. x,y is the upper left baseline of
		            #   the <li> text, so text_right() the marker
		            if ($list_marker =~ m/^\./) {
			        # it's a symbol for <ul>. 50% size, +y by 33% size
			        # TBD url image and other character symbols 
			        #     (possibly in other than Zapf Dingbats). 
			        if      ($list_marker eq '.disc') {
			            $list_marker = chr(108); # 'l'
			        } elsif ($list_marker eq '.circle') {
			            $list_marker = chr(109); # 'm'
			        } elsif ($list_marker eq '.square') {
			            $list_marker = chr(110); # 'n'
			        } elsif ($list_marker eq '.box') {
			            $list_marker = chr(111); # non-standard 'o'
			        } elsif ($list_marker eq '.none') {
			            $list_marker = '';
			        }
			     
			        # ul defaults
				$x_adj = $y_adj = 0;
			        if ($list_marker ne '') {
			            # x_adj (- to left) .3em+2pt for gap marker to text
                                   #$x_adj = -(0.3 * $fs + 2);
		                    # figure y_adj for ul marker (raise, since smaller)
				    # TBD: new CSS to set adjustments
			            $y_adj = -0.33*_size2pt($properties[-1]->{'font-size'}, $fs, 'usage'=>'list marker raise')/$fs + 0.33;
			            $y_adj *= $fs;
			        } else {
				    # empty text
			        }
		            } else {
			        # it's a formatted count for <ol>
			        # ol defaults
			        # x_adj (- to left) .3em for gap marker to text
			       #$x_adj = -(0.3 * $fs);
		            }

		        } else {
			    # '' list-marker for _sl, leave as is so no output
			    # no change to font attributes
		        }
		        # insert list_marker into text field at $el+1 and end
		        # of marker at $el+2. no need to change $el.
			# IF existing text not empty or blank, leave alone!
			if ($mytext[$el+1]->{'text'} =~ /^ *$/) {
		            $mytext[$el+1]->{'text'} = $list_marker;
			}
		    } # list marker NOT to be skipped
		    $list_marker = '';

	       #} elsif ($tag eq '_ovl') { # TBD
	       #} elsif ($tag eq '_k') { # TBD
	        } elsif ($tag eq '_move') {
		    # move left or right on current baseline, per 'x' and/or
		    # 'dx' attribute values
		    # TBD: consider y/dy positioning too, would need to adjust
		    #   baseline to new y before getting fresh start_x and x
		    # first, we need valid $x and $y. if left by the previous
		    # write, use them. otherwise need to start at the left edge
		    # of the column (start_x) and y on the baseline
                    if (!defined $y) { 
                        $y = $start_y - 8.196;
	            }
                    ($start_x,$y, $width) = _get_baseline($y, @outline);
                    if (!defined $x) { 
		        $x = $start_x;
	            }
                    # need to increase x and decrease width by any 
		    # left margin amount
		    $x = $start_x + $properties[-1]->{'_left'};
		    $width -= $properties[-1]->{'_left'} + $properties[-1]->{'_right'};
		    $endx = $start_x + $width;
		    my ($attr, $attrv, $attru);
                    # handle "x" attribute first (absolute positioning),
		    # leaving $x at the new position. no check on going beyond
		    # either end of the line.
		    if (defined $mytext[$el]->{'x'}) {
			# 'x' attribute given, treat as move relative to start_x
			$attr = $mytext[$el]->{'x'};
			# TBD: a more rigorous number check
			if ($attr =~ m/^(-?[\d.]+)(pt$|%$|$)/i) {
			    $attrv = $1;
			    $attru = $2;
			    if ($attru eq '%') {
				$x = $start_x + $attrv/100*$width; # % of width
			    } else {
				$x = $start_x + $attrv;  # pts
			    }
			} # if can't match pattern, x remains unchanged
		    }
		    # now handle "dx" attribute (relative positioning),
		    # leaving $x at the new position. no check on going beyond
		    # either end of the line.
		    if (defined $mytext[$el]->{'dx'}) {
			# 'dx' attribute given, treat as move relative to where
			# 'x' left it (if given), else relative to current x
			$attr = $mytext[$el]->{'dx'};
			# TBD: a more rigorous number check
			if ($attr =~ m/^(-?[\d.]+)(pt$|%$|$)/i) {
			    $attrv = $1;
			    $attru = $2;
			    if ($attru eq '%') {
				$x += $attrv/100*$width; # % of width
			    } else {
				$x += $attrv;  # pts
			    }
			} # if can't match pattern, x remains unchanged
		    }
		    # allow <0 or >width to go beyond baseline at user's risk
		    # (likely to be cut off if exceed line end on right, who
		    # knows what will happen on the left)
		    $text->translate($x, $y);
		    # any pending need_line will reset x to start_x, so save
		    # desired x (otherwise is undef)
		    $desired_x = $x;
		    # HTML::TreeBuilder may have left a /_move tag. problem?

		} elsif ($tag eq '_ref') {
		    # cross reference tag   tgtid= fit=
		    # $mytext[$el] is this tag, $el+1 is link text (update
		    #  from target if empty or undefined), so there IS a
		    #  child text and end tag for _ref
		    # add 'annot' info to link text field. output only current 
		    #  text of link, save link data for very end.
		    my ($tgtid, $fit, $title);
                    $tgtid = $mytext[$el]->{'tgtid'};  # required!
		    if (!defined $tgtid) { croak "<_ref> missing tgtid=."; }
                    $fit   = $mytext[$el]->{'fit'};  # optional
		    $fit //= ''; # use default fit
                    $title = $mytext[$el]->{'title'};  # optional
		    $title //= '';
		    $title = "[no title given]" if $title eq '';
                    # if no title, try to get from target 
		    # TBD override of page_numbers

                    my ($tfn, $tppn, $tid);
		    # first, #id convert to just id (only at beginning), or
		    # #p-x-y[-z] split into #p and fit
		    if ($tgtid =~ /^#[^#]/) {
			# starts with single #
			my @fields = split /-/, $tgtid;
			# if size 1, is just #id or #p
			if      (@fields == 1) {
			    # if just #p, see if p is integer 1+
			    if ($tgtid =~ /^#[1-9]\d*$/) {
				# is #p so leave $tgtid as is
			    } else {
				# is #id -- strip off leading #
				$tgtid = substr($tgtid, 1);
			    }
			} elsif (@fields == 3 || @fields == 4) {
			    # possibly #p-x-y-z default z = null
			    # only checking if p is integer 1+
			    # TBD check if x and y are numbers >= 0
			    # TBD check if z is number > 0 or 'null' or 'undef'
			    if ($fields[0] =~ /^#[1-9]\d*$/) {
				# is #p so build $fit
				$tgtid = $fields[0];
				if (@fields == 3) { push @fields, 'null'; }
				if ($fields[3] eq 'undef') { $fields[3] = 'null'; }
				$fit = "xyz,$fields[1],$fields[2],$fields[3]";
			    } else {
				# is #id -- strip off leading #
				$tgtid = substr($tgtid, 1);
			    }
		        } else {
			    # wrong number of fields, is just #id
			    # so strip off leading #
			    $tgtid = substr($tgtid, 1);
			}
		    }

                    # split up tgtid into various fields
		    if      ($tgtid =~ /##/) {
			 # external link's file, and ppn of target
			 ($tfn, $tppn) = split /##/, $tgtid;
			 $tfn //= '';
			 $tid = "##$tppn";
		    } elsif ($tgtid =~ /#/) {
			 # external link's file, and Named Destination
			 ($tfn, $tppn) = split /#/, $tgtid; 
			 $tfn //= '';
			 $tid = "#$tppn";
		    } else {
			 # an id= 
			 $tfn = ''; # internal link only
			 $tppn = -1; # unknown at this time
			 $tid = $tgtid;
		    }

		    # add a new array entry to xrefs, or update existing one
		    # knowing title, fit, tid, tfn, tppn from <_ref>
		    # sptr = pointer (ref) to this entry in xrefs
		    # tptr = pointer (ref) to matching target in xreft
		    my $sindex = $state->{'sindex'};
		    my ($sptr, $tfpn, $tptr);
		    if ($pass_count == 1 && defined $sindex) {
			# add new entry at $sindex
			$state->{'xrefs'}->[$sindex] = {};
			# ptr to hash {id} and its siblings (see Builder.pm)
		        $sptr = $state->{'xrefs'}->[$sindex]; 
			# the following items should never change after the
			#  first pass
			# it's possible that this _ref is totally self-contained
			#  and does not refer to any target id
			$sptr->{'id'}    = $tid;
			$sptr->{'fit'}   = $fit;
			$sptr->{'tfn'}   = $tfn;
			# items that CAN change between passes
			$sptr->{'title'} = $title;
                        $sptr->{'tx'}    = 0;
                        $sptr->{'ty'}    = 0;
                        $sptr->{'tfpn'}  = '';
		    } else {
			# entry already exists, at $sindex
			# update anything that might change pass-to-pass
			# set 'changed' flag only if updated AFTER this pass's
			#  title text and other_pg have been laid down. 
			#  if $page_numbers == 2, a change in ppn's either 
			#  source or target is of concern TBD
		        $sptr = $state->{'xrefs'}->[$sindex] if defined $sindex;
			# nothing in this section to warrant changed flag
			#  and we're about to output a fresh copy of link text
			#  and 'other_pg' text
		    }

		    # whether pass 1 initialization or pass 2+ update
		    # the following can change without forcing another pass
		    #
                    $sptr->{'tppn'} = $tppn;
                    $sptr->{'sppn'} = $ppn;

		    # have we found this target id already?
		    if (defined $state->{'xreft'}{'_reft'}{$tid}) {
			$tptr = $state->{'xreft'}{'_reft'}{$tid};
		    } else {
			$tptr = undef; # just to be certain
		    }

		    if (defined $tptr) {
		        # does the title need an update from target?
			if ($sptr->{'title'} eq '[no title given]' &&
			    $tptr->{'title'} ne '[no title given]') {
			    $sptr->{'title'} = $tptr->{'title'};
			    # no need to mark as changed, as about to output 
			    # the link text (title, other_pg)
			   #$state->{'changed_target'}->{$tid} = 1;
			    # update child text
			    $mytext[$el+1]{'text'} = $sptr->{'title'};
		        }

			# other fields that may change
                        $sptr->{'tx'} = $tptr->{'tx'};
                        $sptr->{'ty'} = $tptr->{'ty'}; 
                        $sptr->{'tfpn'} = $tptr->{'tfpn'}; # affects other_pg
			# other fields that may be overridden by target
                        $sptr->{'tppn'} = $tptr->{'tppn'} 
			    if ($sptr->{'tppn'} == -1); # affects other_pg
                        $sptr->{'tag'} = $tptr->{'tag'};
		    }
		    # TBD figure 'other_pg' text when actually output it,
		    #      and update field and set flag if changed (pass > 1)
			    # once know sppn and tppn (in same PDF) and
			    # $page_numbers > 0. note that a _ref can override
			    # the global page_numbers with its own (e.g., to
			    # force = 1 'on page N' when global == 2)
		    $sptr->{'other_pg'} = $sptr->{'prev_other_pg'} = ''; # TBD
		    #
		    # Note that Named Destinations do not get a page 
		    #  designation output (no "on page $" etc.) regardless 
		    #  of $page_numbers setting. TBD what about internal jumps?
		    # may not know page of an external jump.

		    # via 'annot' flag tell title text to grab rectangle corners
		    # and stick in {'click'} area array. may be multiple such
		    # rectangles (click areas) if text wraps. also determine
		    # 'other_pg' string and update entry (TBD)
		    $sptr->{'click'} = [];
		    # TBD title that includes embedded tags to support
		    $mytext[$el+1]->{'annot'} = $sindex;

		    $state->{'sindex'} = ++$sindex;

		} elsif ($tag eq '_reft') {
		    # cross reference target tag  id=
		    # for markdown, only target available
		    my $id = $mytext[$el]->{'id'};  # required!
		    if (!defined $id) { croak "<_reft> missing id=."; }
                    my $title = $mytext[$el]->{'title'};  # optional
		    # code handling id= and checking tag_lists from here on out
		    # to deal with <_reft>

		} elsif ($tag eq '_nameddest') {
		    # define a Named Destination at this point
		    # possibly a fit attribute is defined
		    my $name = $mytext[$el]->{'name'};  # required!
		    if (!defined $name) { croak "<_nameddest> missing name=."; }
		    my $fit  = $mytext[$el]->{'fit'};  #optional
		    $fit //= '';

		    my $ptr = $state->{'nameddest'};
		    $ptr->{$name} = {};
		    $ptr->{$name}{'fit'} = $fit;
		    $ptr->{$name}{'ppn'} = $ppn; # this and following can change
		    $ptr->{$name}{'x'}   = $x;   # on subsequent passes
		    $ptr->{$name}{'y'}   = $y;

                # special directives such as (TBD)
		# <_endc> force end of column here (while still filling line)
		#   e.g., to prevent an orphan
		# <_nolig></_nolig> forbid ligatures in this range
		# <_lig gid='nnn'>c</_lig> replace character(s) by a ligature
		# <_alt gid='nnn'>c</_alt> replace character(s) by alternate
		#   glyph such as a swash. font-dependent
		# <_hyp>, <_nohyp> control hypenation in a word (and remember
		#   rules when see this word again)

		} else {
		    # unsupported or invalid tag found
		    # keep list of those found, error message once per tag
		    #         per column() call
		    if (!defined $bad_tags{$tag}) {
		        print STDERR "Warning: tag <$tag> either invalid or currently unsupported by PDF::Builder.\n";
			$bad_tags{$tag} = 1;
		    }
		    # treat as <span>
	            $tag = $mytext[$el]->{'tag'} = 'span';
		}

		# any common post-tag work -------------------------------------
		# does this tag have an id attribute, and is it in one or
		# more of the watch lists to add to references?
                # _reft tags already checked that id= given
		if (defined $state && exists $mytext[$el]->{'id'}) {
		    my $id = $mytext[$el]->{'id'};
		    # might have a title, too
                    my $title = $mytext[$el]->{'title'};  # optional (_reft)
		    $title = '' if !defined $title; 
		    # if no title in source or target tags, will have to
		    # look at child text of various tags
		     
		    # yes, it has an id. now check against lists
		    # this tag will produce an entry in xreft for each list 
		    #  that it is in TBD find way to consolidate into one?
		    my %tag_lists = %{$state->{'tag_lists'}};
		    # will contain at least _reft list with _reft tag
		    # goes into xreft/listname/id structure
		    foreach my $list (keys %tag_lists) { # _reft, TOC, etc
			my @tags = @{$tag_lists{$list}}; # tags to check
			foreach my $xtag (@tags) {
			    if ($tag eq $xtag) {
				# this tag (with id=) is being used by target 
				#  list $list (e.g., '_reft')
				# add (or update) this tag's data into the $list
				my $tptr;

		                $tptr = $state->{'xreft'}->{$list}->{$id};
		                if (!defined $tptr) {
                                    $state->{'xreft'}->{$list}->{$id} = {};
		                    $tptr = $state->{'xreft'}->{$list}->{$id};
			            # add new entry or overwrites old one
			            # perhaps pass > 1 see if $id already exists
			            # these three should never change on update
			            $tptr->{'tfn'} = $filename;
			            $tptr->{'title'} = $title;
			            $tptr->{'tag'} = $tag;
				    # if title empty, look for child text
				    # use this title if no title= on <_ref>
				    if ($title eq '') {
					# heading has child text, add others
					# as useful
					if ($tag =~ /^h\d$/ ||
				            $tag eq '_part' || 
					    $tag eq '_chap') {
					    $title = _get_child_text(
						         \@mytext, $el );
					    # might still be ''
				        }
					$tptr->{'title'} = $title;
				    }
                                } # add a new id= to xreft, or update existing
				# these may change from pass to pass
		                $tptr->{'tppn'} = $ppn;
		                $tptr->{'tfpn'} = $fpn;
		                $tptr->{'tx'} = $x//0; # sometimes undef
		                $tptr->{'ty'} = $y;
				# done creating or updating an entry

				# every link source using this id gets update
				# and "changed" flag set for visible text change
				for (my $sindex=0; 
				     $sindex < scalar(@{$state->{'xrefs'}});
				     $sindex++) {
				    if ($state->{'xrefs'}->[$sindex]->{'id'} eq $id) {
			                # yes, link source exists. update it and
				        # set flag if need another pass
				        my $another_pass = 0;
					my $sptr = $state->{'xrefs'}->[$sindex];
				        if ($sptr->{'title'} eq '[no title given]' &&
				            $tptr->{'title'} ne '[no title given]') {
				            $sptr->{'title'} = $tptr->{'title'};
					    $another_pass = 1;
				        }
					# 'other_pg' determined elsewhere
				        $state->{'changed_target'}{$id} = 1
				            if $another_pass;

                                        # other fields in xrefs to update
					#  from xreft entry
					$sptr->{'tx'} = $tptr->{'tx'};
					$sptr->{'ty'} = $tptr->{'ty'};
					$sptr->{'tag'} = $tptr->{'tag'};
					$sptr->{'tfn'} = $tptr->{'tfn'}
					  if $sptr->{'tfn'} eq '';
					$sptr->{'tfpn'} = $tptr->{'tfpn'}
					  if $sptr->{'tfpn'} eq '';
					$sptr->{'tppn'} = $tptr->{'tppn'}
					  if $sptr->{'tppn'} < 1;

				    } # link source targeting this id
				} # loop sindex through all link sources
			    } # found a tag of interest in a list
			} # check against list of tags
		    } # search through target tag lists
		} # tag with id=  see if wanted for target lists
		
	        if (defined $mytext[$el]->{'empty_element'}) {
	            # empty/void tag, no end tag, pop property stack
		    # as this tag's actions have already been taken
            # update bottom margin. display already reset to 'inline'
            $vmargin[0] = min($vmargin[0], $properties[-1]->{'margin-bottom'});
            $vmargin[1] = max($vmargin[1], $properties[-1]->{'margin-bottom'});

		    pop @properties;
                    # should revert any changed font-size
		    splice(@mytext, $el, 1);
		    $el--; # end of loop will advance $el
		    # no text as child of this tag, whatever it does, it has
		    # to be completely handled in this section
	        }

		# end of handling starting tags <tag>

	    # ================ </tags> end tags ======================
	    } else {
		# take care of 'end' tags. some end tags need some special 
		# processing if they do something that isn't just a 
		# property change. current_prop should be up to date.
		$tag = lc(substr($tag, 1)); # discard /

		# note that current_prop should be all up to date by the
		# time you hit the end tag
		# this tag post-processing is BEFORE vertical margins and
		#   popping of properties stack for this and nested tags
		# processing specific to specific end tags ---------------------
		if      ($tag eq 'ul') { 
		    $list_depth_u--; 
	        } elsif ($tag eq '_sl') {
		    $list_depth_s--;
	        } elsif ($tag eq 'ol') {
		    $list_depth_o--;
		    # restore any saved start and reversed_ol values
		    $start = $properties[-2]->{'_start'}; # current start
		    $reversed_ol = $properties[-2]->{'_reversed_ol'}; # cur flag
                } elsif ($tag eq '_marker') {
		    # bump x position past gap to li start (li is inline)
		    $x = $start_x + $properties[-1]->{'_left'} + 
			 $marker_width + $marker_gap;
		    $text->translate($x, $y);
		    $desired_x = $x;
	        }

		# ready to pick larger of top and bottom margins (block display)
		# block display element end (including paragraphs)
	        # start next material on new line
	        if ($current_prop->{'display'} eq 'block') {
		    $need_line = 1; 
		    $start_y = $next_y;
		    $add_x = $add_y = 0;
		    # now that need_line, etc. are set, make inline
		    $current_prop->{'display'} = 'inline';
                    $vmargin[0] = min($vmargin[0], $properties[-1]->{'margin-bottom'});
                    $vmargin[1] = max($vmargin[1], $properties[-1]->{'margin-bottom'});
	        }

		# pop properties stack and remove element ----------------------
		# last step is to pop the properties stack and remove this
		# element, its start tag, and everything in-between. adjust 
		# $el and loop again.
		for (my $first = $el-1; $first>1; $first--) {
		    # looking for a tag matching $tag
		    if ($mytext[$first]->{'text'} eq '' &&
			$mytext[$first]->{'tag'} eq $tag) {
			# found it at $first
			my $len = $el - $first + 1;
			splice(@mytext, $first, $len);
			$el -= $len; # end of loop will advance $el
			pop @properties;
                        # restore current font size
			last;
		    }
                }
		# this tag post-processing is AFTER vertical margins and
		#   popping of properties stack for this and nested tags
		#   (currently none)
		if (@mytext == 2) { last; } # have used up all input text!
		# only default values and style element are left
		next; # next mytext element s/b one after batch just removed
               
		# end of handling end tags </tag>
	    }

	    # end of tag processing

	# ========================== text to output =================
	} else {
            # normally text is not empty '', but sometimes such may come
	    # through. a blank text is still valid
            if ($mytext[$el]->{'text'} eq "\n") { next; } # EOL too
	    if ($mytext[$el]->{'text'} eq '') { next; }

	    # we should be at a new text entry ("phrase")  INK HERE
	    # we have text to output on the page, using properties at the
	    # properties stack top. compare against current properties to
	    # see if need to make any calls (font, color, etc.) to make.

            # drop down page by any pending vertical margin spacing
            if ($vmargin[0] != 0 || $vmargin[1] != 0) {
                if (!$topCol) {
                    $start_y -= ($vmargin[0]+$vmargin[1]);
                }
                @vmargin = (0, 0); # reset counters
            }
            $topCol = 0; # for rest of column do not suppress vertical margin

	    # after tags processed, and property list (properties[-1]) updated,
	    # typically at start of a text string (phrase) we will call PDF
	    # updates such as fillcolor, get_font, etc. and at the same time
	    # update current_prop to match.

	    # what properties have changed and need PDF calls to update?
	    # TBD future: separate slant and italic, optical size
	    $call_get_font = 0;
	    if ($properties[-1]->{'font-family'} ne $current_prop->{'font-family'}) {
		 $call_get_font = 1;
		 # a font label known to FontManager
		 $current_prop->{'font-family'} = $properties[-1]->{'font-family'};
            }
	    if ($properties[-1]->{'font-style'} ne $current_prop->{'font-style'}) {
		 $call_get_font = 1;
		 # normal or italic (TBD separate slant)
		 $current_prop->{'font-style'} = $properties[-1]->{'font-style'};
            }
	    if ($properties[-1]->{'font-weight'} ne $current_prop->{'font-weight'}) {
		 $call_get_font = 1;
		 # normal or bold (TBD multiple steps, numeric and named)
		 $current_prop->{'font-weight'} = $properties[-1]->{'font-weight'};
            }
	    # font size
	    # don't want to trigger font call unless numeric value changed
	    # current_prop's s/b in points, newval will be in points. if
	    # properties (latest request) is a relative size (e.g., %),
	    # what it is relative to is NOT the last font size used
	    # (current_prop), but carried-along current font size.
	    my $newval = _size2pt($properties[-1]->{'font-size'}, 
	                        $properties[-1]->{'_parent-fs'}, 'usage'=>'font-size');
	    # newval is the latest requested size (in points), while
	    # current_prop is last one used for output (in points)
	    if ($newval != $current_prop->{'font-size'}) {
	        $call_get_font = 1;
		$current_prop->{'font-size'} = $newval;
	    }
	    # any size as a percentage of font-size will use the current fs
            # should be in points by now, might not equal current_prop{font-size}
	    my $fs = $properties[-1]->{'font-size'};

	    # uncommon to only change font size without also changing something
	    # else, so make font selection call at the same time, besides,
	    # there is very little involved in just returning current font.
	    if ($call_get_font) {
		# TBD future additional options, expanded weight
                $text->font($pdf->get_font(
		    'face' => $current_prop->{'font-family'}, 
		    'italic' => ($current_prop->{'font-style'} eq 'normal')? 0: 1, 
		    'bold' => ($current_prop->{'font-weight'} eq 'normal')? 0: 1, 
		                          ), $fs);
                $current_prop->{'font-size'} = $fs; 
	    }
	    # font-size should be set in current_prop for use by margins, etc.

	    # don't know if color will be used for text or for graphics draw,
	    # so set both
	    if ($properties[-1]->{'color'} ne $current_prop->{'color'}) {
		$current_prop->{'color'} = $properties[-1]->{'color'};
		$text->fillcolor($current_prop->{'color'});
		$text->strokecolor($current_prop->{'color'}); 
		if (defined $grfx && ref($grfx) =~ m/^PDF::Builder::Content/) {
		    $grfx->fillcolor($current_prop->{'color'});
		    $grfx->strokecolor($current_prop->{'color'});
                }
            }

	    # these properties don't get a PDF::Builder call
	    # update text-indent, etc. of current_prop, even if we don't
	    # call a Builder routine to set them in PDF, so we can always use
	    # current_prop instead of switching between the two. current_prop
	    # property lengths should always be in pts (no labeled dimensions).
	    $current_prop->{'text-indent'} = $properties[-1]->{'text-indent'}; # should already be pts
	    $current_prop->{'text-decoration'} = $properties[-1]->{'text-decoration'};
	    $current_prop->{'text-align'} = $properties[-1]->{'text-align'};
	    $current_prop->{'margin-top'} = _size2pt($properties[-1]->{'margin-top'}, $fs, 'usage'=>'margin-top');
	    # the incremental right margin, and the running total
	    $current_prop->{'margin-right'} = _size2pt($properties[-1]->{'margin-right'}, $fs, 'usage'=>'margin-right');
	    $properties[-1]->{'_right'} += $current_prop->{'margin-right'};
	    $current_prop->{'margin-bottom'} = _size2pt($properties[-1]->{'margin-bottom'}, $fs, 'usage'=>'margin-bottom');
	    # the incremental left margin, and the running total
	    $current_prop->{'margin-left'} = _size2pt($properties[-1]->{'margin-left'}, $fs, 'usage'=>'margin-left');
	    $properties[-1]->{'_left'} += $current_prop->{'margin-left'};
	    # line-height is expected to be a multiplier to font-size, so
	    # % or pts value would have to be converted back to ratio TBD
	    $current_prop->{'line-height'} = $properties[-1]->{'line-height'}; # numeric ratio
	    $current_prop->{'display'} = $properties[-1]->{'display'};
	    $current_prop->{'list-style-type'} = $properties[-1]->{'list-style-type'};
	    $current_prop->{'list-style-position'} = $properties[-1]->{'list-style-position'}
                if defined $properties[-1]->{'list-style-position'};
	    $current_prop->{'_href'} = $properties[-1]->{'_href'};
	    # current_prop should now be up to date with properties[-1], and
	    # any Builder calls have been made

	    # we're ready to roll, and output the actual text itself
	    #
	    # fill line from element $el at current x,y until will exceed endx
	    # then get next baseline
	    # if this phrase doesn't finish out the line, will start next
	    # mytext element at the x,y it left off. otherwise, unused portion
	    # of phrase (remainder) becomes the next element to process.
	    $phrase = $mytext[$el]->{'text'}; # there should always be a text
	    #
	    # $list_marker was set in li tag processing
	    #   note that ol is bold, ul is Symbol (replace macros .disc, etc.).
	    #   content of li is with new left margin. first line ($list_marker
	    #   ne '') text_right of $list_marker at left margin of li text.
	    #   then set $list_marker to '' to cancel out until next li.
	    $remainder = '';

	    # for now, all whitespace convert to single blanks 
	    # TBD blank preserve for <code> or <pre> (CSS white-space)
	    $phrase =~ s/\s+/ /g;

	    # click areas ------------------------------------------------------
	    # if 'annot' field (attribute) exists for a text, we want to define
	    # a rectangle around it for an annotation click area (several
	    # rectangles, even across multiple columns, are possible if the
	    # phrase is long enough to split in the middle).
	    # value = element number in state->xrefs array to update rect
	    # with [ UL, LR ] values being assembled
	    # at end (when LR done), push to state->xrefs->[elno]{click}
	    #  (could already have one or more subarrays)
	    my $click_ele;
	    if (defined $mytext[$el]->{'annot'}) {
		$click_ele = $mytext[$el]->{'annot'};
		$click_ele = $state->{'xrefs'}->[$click_ele]{'click'};
		# for every chunk of text the phrase gets split into, push
		# an element on the 'click' anonymous array, consisting of
		# the [sppn, [ULx,ULy, LRx,LRy]]
	    }

	    # output text itself -----------------------------------------------
	    # a phrase may have multiple words. see if entire thing fits, and if
	    # not, start trimming off right end (split into a new element)
    
            while ($phrase ne '') {
	        # one of four things to handle:
	        # 1. entire phrase fits at x -- just write it out
	        # 2. none of phrase fits at x (all went into remainder) --
	        #    go to next line to check and write (not all may fit)
	        # 3. phrase split into (shortened) phrase (that fits) and a
	        #    remainder -- write out phrase, remainder to next line to
	        #    check and write (not all may fit)
		# 4. phrase consists of just one word, AND it's too long to
		#    fit on the full line. it must be split somewhere to fit 
		#    the line.

		my ($x_click, $y_click, $y_click_bot);
		my $full_line = 0;
	        # this is to force start of a new line at start_y?
		# phrase still has content, and there may be remainder.
		# don't forget to set the new start_y when need_line=1
	        if ($need_line) {
	            # first, set font (current, or something specified)
		    if ($topCol) { # at top of column, font undefined
	                $text->font($pdf->get_font('face'=>'current'), $fs);
		    }

	            # extents above and below the baseline (so far)?
	            ($asc, $desc, $desc_leading) = 
	                _get_fv_extents($pdf, $font_size, 
				        $properties[-1]->{'line-height'});
	            $next_y = $start_y - $add_y - $asc + $desc_leading;
	            # did we go too low? will return -1 (start_x) and 
		    #   remainder of input
	            # don't include leading when seeing if line dips too low
	            if ($start_y - $add_y - $asc + $desc < $min_y) { last; }
	            # start_y and next_y are vertical extent of this line 
		    #   (so far)
	            # y is the y value of the baseline (so far)
	            $y = $start_y - $add_y - $asc;

	            # how tall is the line? need to set baseline. add_y is
		    #   any paragraph top margin to drop further. note that this
		    #   is just the starting point -- the line could get taller
                    ($start_x,$y, $width) = _get_baseline($y, @outline);
		    $x = $start_x + $properties[-1]->{'_left'};
 		    $width -= $properties[-1]->{'_left'} + $properties[-1]->{'_right'};
                    $endx = $x + $width;
	            # at this point, we have established the next baseline 
		    #   (x,y start and width/end x). fill this line.
		    $x += $add_x; $add_x = 0; # indent
		    $add_y = 0; # para top margin extra
		    $need_line = 0;
		    $full_line = 1;

		    # was there already a "desired x" value, such as <_move>?
		    if (defined $desired_x) {
			$x = $desired_x;
			$desired_x = undef;
		    }

                    # stuff to remember if need to shift line down due to 
		    #   vertical extents increase
		    # TBD: may need to change LR corner of last line of an
		    #      annotation click area if content further along line
		    #      moves baseline down
		    @line_extents = ();
		    push @line_extents, $start_x; # current baseline's start
		    push @line_extents, $x; # current baseline 
		    # note that $x advances with each write
		    push @line_extents, $y;
		    push @line_extents, $width;
		    push @line_extents, $endx;
		    push @line_extents, $next_y;
		    push @line_extents, $asc; # current vertical extents
		    push @line_extents, $desc;
		    push @line_extents, $desc_leading;
		    # text and graphics contexts and
	            # where the current line starts in the streams
		    push @line_extents, $text;
		    push @line_extents, length($text->{' stream'});
		    push @line_extents, $grfx;
		    if (defined $grfx && ref($grfx) =~ m/^PDF::Builder::Content/) {
		        push @line_extents, length($grfx->{' stream'});
		    } else {
			push @line_extents, 0;
		    }
		    push @line_extents, $start_y;
		    push @line_extents, $min_y;
		    push @line_extents, \@outline;
		    push @line_extents, $properties[-1]->{'_left'};
		   #push @line_extents, $properties[-1]->{'_left_nest'};
		    push @line_extents, $properties[-1]->{'_right'};

		    # if starting a line, make sure no leading whitespace
		    # TBD if pre, don't remove whitespace
		    $phrase =~ s/^\s+//;
		} else {
		    # cancel desired_x if not used
		    $desired_x = undef;
	        }
    	
		# have a phrase to attempt to add to output, and an
		#   x,y to start it at (tentative if start of line)
		# x is current user-specified position to align at, and
		#   if not LJ, will be adjusted so write is CJ or RJ there
	        my $w = $text->advancewidth($phrase); # will use $w later
		my $align = $properties[-1]->{'text-align'};
		if ($align eq 'c' || $align eq 'center') {
                    $x -= $w/2; # back up 1/2 phrase to real starting point
		    if ($x+$x_adj < $start_x) {
			carp "Centered text of width $w: left edge ".($x+$x_adj)." is left of column start $start_x. Results unpredictable.\n";
		    }
		    if ($x+$x_adj+$w > $endx) {
			carp "Centered text of width $w: right edge ".($x+$x_adj+$w)." is right of column end $endx. Results unpredictable.\n";
		    }
		    $text->translate($x+$x_adj, $y+$y_adj);
	        } elsif ($align eq 'r' || $align eq 'right') {
                    $x -= $w; # back up by phrase to real starting point
		    if ($x+$x_adj < $start_x) {
			carp "Right-aligned text of width $w: left edge ".($x+$x_adj)." is left of column start $start_x. Results unpredictable.\n";
		    }
		    if ($x+$x_adj+$w > $endx) {
			carp "Right-aligned text of width $w: right edge ".($x+$x_adj+$w)." is right of column end $endx. Results unpredictable.\n";
		    }
		    $text->translate($x+$x_adj, $y+$y_adj);
	        } else { # align l/left
		    # no x adjustment for phrase width
		    $text->translate($x+$x_adj, $y+$y_adj);
		}
		$align = 'left'; # have set x,y to actual start point

		# $x,$y is where we will actually start writing the phrase
		# (adjusted per text-align setting)
	        if ($x + $w <= $endx) {
		    my $rc;
	            # no worry, the entire phrase fits (case 1.)
		    # y (and possibly x) might change if extents change
		    my $w = $text->advancewidth($phrase);
		    if ($current_prop->{'text-decoration'} ne 'none') {
			# output any requested line strokes, after baseline
			#   positioned and before baseline adjusted
			# supported: underline, line-through, overline
			# may be a combination separated by spaces
			# inherit current color (strokecolor) setting
			my $font = $pdf->get_font('face'=>'current');
			my $upem = $font->upem();
			my $strokethickness = $font->underlinethickness() || 1;
			$strokethickness *= $fs/$upem;
			my $stroke_ydist = $font->underlineposition() || 1;

			# don't stroke through any trailing whitespace
			my $trail = 0; # width of WS
			if ($phrase =~ m/(\s+)$/) {
			    $trail = $text->advancewidth($1);
			}

			$stroke_ydist *= $fs/$upem;
			# TBD consider whether to draw lines in graphics
			#  context instead (could end up with text under line)
			$text->add('ET'); # go into graphics mode
			$text->add("$strokethickness w");
			# baseline is x,y to x+w,y, ydist is < 0
			if ($current_prop->{'text-decoration'} =~ m#underline#) { 
			    # use ydist as-is
			    $text->add("$x ".($y+$stroke_ydist)." m");
			    $text->add(($x+$w-$trail)." ".($y+$stroke_ydist)." l");
			}
			if ($current_prop->{'text-decoration'} =~ m#line-through#) { 
			    # use new ydist at .3fs
			    $stroke_ydist = 0.3*$fs;
			    $text->add("$x ".($y+$stroke_ydist)." m");
			    $text->add(($x+$w-$trail)." ".($y+$stroke_ydist)." l");
			}
			if ($current_prop->{'text-decoration'} =~ m#overline#) {
			    # use new ydist at 0.65fs
			    $stroke_ydist = 0.70*$fs;
			    $text->add("$x ".($y+$stroke_ydist)." m");
			    $text->add(($x+$w-$trail)." ".($y+$stroke_ydist)." l");
			}
			$text->add('S'); # always stroke the line
			$text->add('BT'); # back into text mode
			# after BT, need to restore position
			$text->translate($x,$y);
		    } # handle text-decoration
		    # before writing a new phrase with possibly increased
		    # extents, see if new baseline needed
	            # extents above and below the baseline (so far)?
	            my ($n_asc, $n_desc, $n_desc_leading) = 
	                _get_fv_extents($pdf, $current_prop->{'font-size'}, 
				        $properties[-1]->{'line-height'});
		    $line_extents[1] = $x;  # current position
		    ($rc, @line_extents) = 
		        _revise_baseline(@line_extents, $n_asc, $n_desc, $n_desc_leading, $w);
		    ($start_x, $x, $y, $width, $endx, $next_y, 
			$asc, $desc, $desc_leading)
		        = @line_extents; # only parts which might have changed
		    # if rc == 0, line successfully moved down page
		    # if rc == 1, existing line moved down, but need to check if
		    #             still room for $phrase
		    # if rc == 2, current written line doesn't fit narrower line
		    # if rc == 3, revised line won't fit in column! (vertically)
		    # TBD need to check $rc once column width can vary
		    # if annotation click area, remember x and y
		    if (defined $click_ele) {
		        # UL corner, best guess for y value
		        $x_click = int($x +0.5);
		        $y_click = int($y + 0.8*$fs +0.5);
		        $y_click_bot = int($y_click - $leading*$fs +0.5);
		    }
	            $text->text($phrase);  # have already corrected start point
		    # if adjusted x and/or y, undo it and zero out
		    if ($x_adj || $y_adj) {
			$text->translate($x, $y);
			$x_adj = $y_adj = 0;
		    }

                    if ($current_prop->{'_href'} ne '') {
			# this text is a link, so need to make an annot. link
			# $x,$y is baseline left, $w is width
			# $asc, $desc are font ascenders/descenders
                        # some extra margin to make it easier to select
                        my $fs = 0.2*$current_prop->{'font-size'};
                        my $rect = [ $x-$fs, $y-$desc-3*$fs, 
				     $x+$w+$fs, $y+$asc+$fs ];
			# TBD what if link wraps around? make two or more?
			my $annotation = $page->annotation();
			my $href = $current_prop->{'_href'};
			# TBD: href=pdf:docpath.pdf#p.x.y.z jump to another PDF
			if ($href =~ m/^#/) {
			    # href starts with # so it's a jump within this doc
			    my ($pageno, $xpos, $ypos, $zoom);
			    if      ($href =~ m/^#(\d+)$/) {
				# #p format (whole page)
				$pageno = $1;
				$xpos = $ypos = $zoom = undef;
			    } elsif ($href =~ m/^#(\d+)-(\d+)-(\d+)$/) {
				# #p-x-y format (no zoom, at a specific spot)
				$pageno = $1;
				$xpos = $2;
				$ypos = $3; 
				$zoom = undef;
			    } elsif ($href =~ m/^#(\d+)-(\d+)-(\d+)-(.+)$/) {
				# #p-x-y-z format (zoom, at a specific spot)
				$pageno = $1; # integer > 0
				$xpos = $2; # number >= 0
				$ypos = $3; # number >= 0
				$zoom = $4; # number >= 0
				if ($zoom <= 0) {
				    carp "Invalid zoom value $zoom. Using 1";
				    $zoom = 1;
				}
		            } else {
			        # bad format
				carp "Invalid link format '$href'. Using page 1";
				$pageno = 1;
				$xpos = $ypos = $zoom = undef;
			    }
			    if ($pageno < 1) { 
				carp "Invalid page number $pageno. Using page 1";
				$pageno = 1; 
			    }
			    if (defined $xpos && $xpos < 0) { 
				carp "Invalid page x coordinate $xpos. Using x=100";
				$xpos = 100; 
			    }
			    if (defined $ypos && $ypos < 0) { 
				carp "Invalid page y coordinate $ypos. Using y=300";
				$ypos = 300; 
			    }

			    my $tgt_page = $pdf->open_page($pageno);
			    if (!defined $tgt_page) {
				carp "Invalid page number $pageno. Using page 1";
				$pageno = 1;
				$tgt_page = $pdf->open_page($pageno);
			    }
			    if (!defined $xpos) {
				# page only
			        $annotation->link($tgt_page,
			            'rect'=>$rect, 'border'=>[0,0,0]);
			    } else {
				# page at a location and zoom factor
			        $annotation->link($tgt_page,
			            'rect'=>$rect, 'border'=>[0,0,0],
			            'xyz'=>[ $xpos,$ypos, $zoom ]);
			    }
			} else {
			    # webpage (usually HTML) link
			    $annotation->uri($href,
			        'rect'=>$rect, 'border'=>[0,0,0]);
		        }
		    } # deal with an href
		    # need to move current x to right end of text just written
		    # TBD: revise if RTL/bidirectional
	            $x += $w;

		    # whether or not the full phrase fit, we need to create the
		    # annotation click area and the annotation for this line
		    if (defined $click_ele) {
		        my $ele = [$ppn, [$x_click,$y_click, $x,$y_click_bot]];
			# push this element 'ele' onto the list at click_ele
			my @click = @$click_ele; # initially empty
			push @click, $ele;
			$click_ele = \@click;
			$state->{'xrefs'}->[$mytext[$el]->{'annot'}]{'click'} = $click_ele;
			# TBD when last chunk of phrase has been output, if
			# 'other_pg' used, need to update that text element
			# (following </_ref>) as well as set flag that this
			# has changed (if true)
		    }

		    $full_line = 0;
		    $need_line = 0;
		    # change current property display to inline
		    $current_prop->{'display'} = 'inline';

	            # next element in mytext (try to fit on same line)
		    $phrase = $remainder; # may be empty
		    $remainder = '';
		    # since will start a new line, trim leading w/s
		    $phrase =~ s/^\s+//;  # might now be empty
		    if ($phrase ne '') {
			# phrase used up, but remainder for next line
			$need_line = 1;
			$start_y = $next_y;
		    }
 		    next; # done with phrase loop if phrase empty

		    # end of handling entire phrase fits
	        } else {
		    # existing line plus phrase is too long (overflows line)
	            # entire phrase does NOT fit (case 2 or 3). start splitting 
		    # up phrase, beginning with stripping space(s) off end

                    if ($phrase =~ s/(\s+)$//) {
		        # remove whitespace at end (line will end somewhere
		        # within phrase, anyway)
		        $remainder = $1.$remainder;
		    } else {
	                # Is line too short to fit even the first word at the
		        # beginning of the line? force split in word somewhere 
			# so that it fits.
	                my $word = $phrase;
	                $word =~ s/^\s+//; # probably not necessary, but doesn't hurt
	                $word =~ s/\s+$//;
	                if ($full_line && index($word, ' ') == -1) {
	                    my ($wordLeft, $wordRight);
                            # is a single word at the beginning of the line, 
			    # and didn't fit
                            require PDF::Builder::Content::Hyphenate_basic;
                            ($wordLeft,$wordRight) = PDF::Builder::Content::Hyphenate_basic::splitWord($text, $word, $endx-$x);
			    if ($wordLeft eq '') {
				# failed to split. try desperation move of
				# splitting at Non Splitting SPace!
                                ($wordLeft,$wordRight) = PDF::Builder::Content::Hyphenate_basic::splitWord($text, $word, $endx-$x, 'spRB'=>1);
				if ($wordLeft eq '') {
	                            # super-desperation move... split to fit 
				    # space! eventually with proper hyphenation
				    # this probably will never be needed.
                                    ($wordLeft,$wordRight) = PDF::Builder::Content::Hyphenate_basic::splitWord($text, $word, $endx-$x, 'spFS'=>1);
				}
			    }
			    $phrase = $wordLeft; 
			    $remainder = "$wordRight $remainder";
			    $remainder =~ s/\s+$//; # mySociety addition
                            next; # re-try shortened phrase
	                }
    
		        # phrase should end with non-whitespace if here. 
			# try moving last word to remainder
                        if ($phrase =~ s/(\S+)$//) {
		            # remove word at end
		            $remainder = $1.$remainder;
		        }
		    }
		    # at least part of text will end up on another line.
	            # find current <p> and add cont=>1 to it to mark 
		    # continuation in case we end up at end of column
	            for (my $ptag=$el-1; $ptag>1; $ptag--) {
		        if ($mytext[$ptag]->{'text'} ne '') { next; }
		        if ($mytext[$ptag]->{'tag'} ne 'p') { next; }
		        $mytext[$ptag]->{'cont'} = 1;
		        last;
	            }
    
		    if ($phrase eq '' && $remainder ne '') {
			# entire phrase goes to next line
			$need_line = 1;
			$start_y = $next_y;
			$add_x = $add_y = 0;
			$phrase = $remainder;
			$remainder = '';
		    }
 		    next;
	            
		} # phrase did not fit (else)

	        # 'next' to here
            } # end of while phrase has content loop
	    # remainder should be '' at this point, phrase may have content
	    # either ran out of phrase, or ran out of column

	    if ($phrase eq '') {
		# ran out of input text phrase, so process more elements
		# but first, remove this text from mytext array so won't be
		#   accidentally repeated
		splice(@mytext, $el, 1);
		$el--;
		next;
	    }
	    # could get here if exited loop due to running out of column,
	    # in which case, phrase has to be stuffed back into mytext
	    $mytext[$el]->{'text'} = $phrase;
            last;
	    
	}  # text to output

	# =================== done with this element? ==========================
	# end of processing this element in mytext, UNLESS it was text (phrase)
	# and we ran out of column space!

	if ($phrase ne '') {
	    # we left early, with incomplete text, because we ran out of
	    # column space. can't process any more elements -- done with column.
	    # mytext[el] already updated with remaining text
	    last; # exit mytext loop
	} else {
	    # more elements to go
	    next;
	}

	# 'next' to here
    } # for $el loop through mytext array over multiple lines

    # if get to here, is it because we ran out of mytext (normal loop exit), or 
    #   because we ran out of space in the column (early exit, in middle of a
    #   text element)?
    #
    # for whatever reason we're exiting, remove first array element (default
    # CSS entries). it is always re-created on entry to column(). leave next 
    # element (consolidated <style> tags, if any).
    shift @mytext;

    if ($#mytext == 0) {
	# [0] = consolidated styles (default styles was just removed)
	# we ran out of input. return next start_y and empty list ref
	
	# first, handle restore = 0, 1, or 2
	if      ($restore == 0) {
	    # carry out pending font and color changes
	    # what properties have changed and need PDF calls to update?
	    my $call_get_font = 0;
	    if ($properties[-1]->{'font-family'} ne $current_prop->{'font-family'}) {
		 $call_get_font = 1;
		 # a font label known to FontManager
		 $current_prop->{'font-family'} = $properties[-1]->{'font-family'};
            }
	    if ($properties[-1]->{'font-style'} ne $current_prop->{'font-style'}) {
		 $call_get_font = 1;
		 # normal or italic
		 $current_prop->{'font-style'} = $properties[-1]->{'font-style'};
            }
	    if ($properties[-1]->{'font-weight'} ne $current_prop->{'font-weight'}) {
		 $call_get_font = 1;
		 # normal or bold
		 $current_prop->{'font-weight'} = $properties[-1]->{'font-weight'};
            }
	    # font size
	    # don't want to trigger font call unless numeric value changed
	    # current_prop's s/b in points, newval will be in points. if
	    # properties (latest request) is a relative size (e.g., %),
	    # what it is relative to is NOT the last font size used
	    # (current_prop), but carried-along current font size.
	    my $newval = _size2pt($properties[-1]->{'font-size'}, 
	                        $properties[-1]->{'_parent-fs'}, 'usage'=>'font-size');
	    # newval is the latest requested size (in points), while
	    # current_prop is last one used for output (in points)
	    if ($newval != $current_prop->{'font-size'}) {
	        $call_get_font = 1;
		$current_prop->{'font-size'} = $newval;
	    }
	    # any size as a percentage of font-size will use the current fs
	    my $fs = $current_prop->{'font-size'};

	    if ($call_get_font) {
                $text->font($pdf->get_font(
		    'face' => $current_prop->{'font-family'}, 
		    'italic' => ($current_prop->{'font-style'} eq 'normal')? 0: 1, 
		    'bold' => ($current_prop->{'font-weight'} eq 'normal')? 0: 1, 
		                          ), $fs); 
	    }
	    # font-size should be set in current_prop for use by margins, etc.

	    # don't know if color will be used for text or for graphics draw,
	    # so set both
	    if ($properties[-1]->{'color'} ne $current_prop->{'color'}) {
		$current_prop->{'color'} = $properties[-1]->{'color'};
		$text->fillcolor($current_prop->{'color'});
		$text->strokecolor($current_prop->{'color'}); 
		if (defined $grfx && ref($grfx) =~ m/^PDF::Builder::Content/ ) {
		    $grfx->fillcolor($current_prop->{'color'});
		    $grfx->strokecolor($current_prop->{'color'});
                }
            }
	} elsif ($restore == 1) {
	    # do nothing, leave the font state/colors as-is
	} else { # 2
	    # restore to entry with @entry_state
            return (2, $next_y - ($vmargin[0]+$vmargin[1]), []);
	}

        return (0, $next_y - ($vmargin[0]+$vmargin[1]), []);
    } else {
	# we ran out of vertical space in the column. return -1 and 
	# remainder of mytext list (next_y would be inapplicable)
	
	# first, handle restore = 0, 1, or 2
	if ($restore == 0 || $restore == 1) {
	    # do nothing, leave the font state/colors as-is
	} else { # 2
	    # restore to entry with @entry_state
	    return (3, -1, \@mytext);
	}

	return (1, -1, \@mytext);
    }

} # end of _output_text()

# initialize current property settings to values that will cause updates (PDF
# calls) when the first real properties are determined, and thereafter whenever
# these properties change
sub _init_current_prop {

    my $cur_prop = {};
    
    # NOTE that all lengths must be in points (unitless), ratios are
    # pure numbers, named things are strings.
    $cur_prop->{'font-size'} = -1;
    $cur_prop->{'line-height'} = 0; # alias is text-height until release 3.030
    $cur_prop->{'text-indent'} = 0;
    $cur_prop->{'color'} = 'snork'; # PDF default is black
    $cur_prop->{'font-family'} = 'yoMama';  # force a change
    $cur_prop->{'font-weight'} = 'abnormal';
    $cur_prop->{'font-style'} = 'abnormal';
   #$cur_prop->{'font-variant'} = 'abnormal';
    $cur_prop->{'margin-top'} = '0'; 
    $cur_prop->{'margin-right'} = '0'; 
    $cur_prop->{'margin-bottom'} = '0'; 
    $cur_prop->{'margin-left'} = '0'; 
    $cur_prop->{'text-align'} = 'left';
   #$cur_prop->{'text-transform'} = 'none';
   #$cur_prop->{'border'} = 'none';   # NOT inherited
   #$cur_prop->{'border-style'} = 'none';   # NOT inherited
   #$cur_prop->{'border-width'} = '1pt';    # NOT inherited
   #$cur_prop->{'border-color'} = 'inherit';    # NOT inherited
    $cur_prop->{'text-decoration'} = 'none';
   #$cur_prop->{'text-decoration-skip-ink'}; for underline etc.
    $cur_prop->{'display'} = 'block'; # inline, TBD inline-block, none
    $cur_prop->{'height'} = '0';  # currently <hr> only, NOT inherited
    $cur_prop->{'width'} = '0';  # currently <hr> only, NOT inherited
    $cur_prop->{'list-style-type'} = '.u';
    $cur_prop->{'list-style-position'} = 'outside';
    $cur_prop->{'_marker-before'} = ''; 
    $cur_prop->{'_marker-after'} = '.'; 
    $cur_prop->{'_marker-color'} = ''; 
    $cur_prop->{'_marker-font'} = ''; 
    $cur_prop->{'_marker-size'} = '0'; 
    $cur_prop->{'_marker-style'} = ''; 
    $cur_prop->{'_marker-text'} = ''; 
    $cur_prop->{'_marker-weight'} = ''; 
    $cur_prop->{'_marker-align'} = 'right'; 
    $cur_prop->{'_href'} = '';
    
    return $cur_prop;
} # end of _init_current_prop()

# update a properties hash for a specific selector (all, if not given)
# in all but a few cases, a higher level selector overrides a lower level by
#   simply replacing the old content, but in some, property values are
#   combined
sub _update_properties {
    my ($target, $source, $selector) = @_;

    my $tag = '';
    if (defined $selector) {
        if ($selector =~ m#^tag:(.+)$#) {
	    $tag = $1;
	    $selector = undef;
	}
    }

    if (defined $selector) {
        if (defined $source->{$selector}) {
	    foreach (keys %{$source->{$selector}}) {
		# $selector e.g., 'u' for underline
		# $_ is property name, e.g., 'text-decoration'
		# special treatment for text-decoration
		if ($_ eq 'text-decoration') {
		    # 'none' is overwritten, but subsequent values appended
		    if (defined $target->{$_} && $target->{$_} ne 'none') {
			$target->{$_} .= " $source->{$selector}->{$_}";
		    } else {
                        $target->{$_} = $source->{$selector}->{$_};
		    }
		} else {
                    $target->{$_} = $source->{$selector}->{$_};
		}
            }
	}
    } else { # selector not defined (use all)
	foreach my $tag_sel (keys %$source) { # top-level selectors
	    if ($tag_sel eq 'text' || $tag_sel eq 'tag') { next; }
	    if ($tag_sel eq 'cont') { next; } # paragraph continuation flag
	    if ($tag_sel eq 'body') { next; } # do body selector last
	    if (ref($source->{$tag_sel}) ne 'HASH') { 
	        # e.g., <a href="..."> the href element is a string, not a 
		# hashref (ref != HASH), so we put it in directly
		$target->{$tag_sel} = $source->{$tag_sel};
            } else {
	        foreach (keys %{$source->{$tag_sel}}) {
                    $target->{$_} = $source->{$tag_sel}->{$_};
                }
            }
	}
	# do body selector last, after others
	if (defined $source->{'body'}) {
	    foreach (keys %{$source->{'body'}}) {
                $target->{$_} = $source->{'body'}->{$_};
            }
        }
    }

    return;
} # end of _update_properties()

# according to Text::Layout#10, HarfBuzz::Shaper *may* now have per-glyph 
# extents. should check some day when HS is supported (but not mandatory)
sub _get_fv_extents {
    my ($pdf, $font_size, $leading) = @_;

    $leading = 1.0 if $leading <= 0; # actually, a bad value
    $leading++ if $leading < 1.0;    # might have been given as fractional

    my $font = $pdf->get_font('face' => 'current');   # font object realized
    # now it's loaded, if it wasn't already
    my $ascender  = $font->ascender()/1000*$font_size; # positive
    my $descender = $font->descender()/1000*$font_size; # negative

    # ascender is positive, descender is negative (above/below baseline)
    return ($ascender, $descender, $descender-($leading-1.0)*$font_size);
} # end of _get_fv_extents()

# returns a list (array) of x,y coordinates outlining the column defined
# by various options entries. currently only 'rect' is used, to define a
# rectangular outline.
# $grfx is graphics context, non-dummy if 'outline' option given (draw outline)
#
# TBD: what to do if any line too short to use? 

sub _get_column_outline {
    my ($grfx, $draw_outline, %opts) = @_;

    my @outline = ();
    # currently only 'rect' supported. TBD: path
    if (!defined $opts{'rect'}) {
	croak "column: no outline of column area defined";
    }

    # treat coordinates as absolute, unless 'relative' option given
    my $off_x = 0;
    my $off_y = 0;
    my $scale_x = 1;
    my $scale_y = 1;
    if (defined $opts{'relative'}) {
        my @relative = @{ $opts{'relative'} };
        croak "column: invalid number of elements in 'relative' list"
            if (@relative < 2 || @relative > 4);

        $off_x = $relative[0];
        $off_y = $relative[1];
	# @relative == 2 use default 1 1 scale factors
        if (@relative == 3) { # same scale for x and y
            $scale_x = $scale_y = $relative[2];
        }
        if (@relative == 4) { # different scales for x and y
            $scale_x = $relative[2];
            $scale_y = $relative[3];
        }
    }

    my @rect = @{$opts{'rect'}};  # if using 'rect' option
    push @outline, [$rect[0], $rect[1]]; # UL corner = x,y
          # TBD: check x,y reasonable, w,h reasonable
    push @outline, [$rect[0]+$rect[2], $rect[1]]; # UR corner + width
    push @outline, [$rect[0]+$rect[2], $rect[1]-$rect[3]]; # LR corner - height
    push @outline, [$rect[0], $rect[1]-$rect[3]]; # LL corner - width
    push @outline, [$rect[0], $rect[1]]; # back to UL corner

    # TBD: 'path' option

    # treat coordinates as absolute or relative
    for (my $i = 0; $i < scalar @outline; $i++) {
	$outline[$i][0] = $outline[$i][0]*$scale_x + $off_x;
	$outline[$i][1] = $outline[$i][1]*$scale_y + $off_y;
    }

    # TBD body level background-color fill in outline  INK HERE
    # if $has_grfx can proceed
    # use _change_properties _fcolor background-color

    # requested to draw outline (color other than 'none')?   INK HERE
    if ($draw_outline ne 'none' && defined $grfx && ref($grfx) =~ m/^PDF::Builder::Content/) {
	$grfx->strokecolor($draw_outline);
	$grfx->linewidth(0.5);
	# only rect currently supported
	my @flat = ();
        for (my $i = 0; $i < scalar @outline; $i++) {
	    push @flat, $outline[$i][0];
	    push @flat, $outline[$i][1];
	}
	$grfx->poly(@flat);
	$grfx->stroke();
    }

    return @outline;
} # end of _get_column_outline()

sub _get_col_extents {
    my (@outline) = @_;
    my ($minx, $miny, $maxx, $maxy);

    # for rect, all pairs are x,y. once introduce splines/arcs, need more
    for (my $i = 0; $i < scalar @outline; $i++) {
	if ($i == 0) {
	    $minx = $maxx = $outline[$i][0];
	    $miny = $maxy = $outline[$i][1];
	} else {
	    $minx = min($minx, $outline[$i][0]);
	    $miny = min($miny, $outline[$i][1]);
	    $maxx = max($maxx, $outline[$i][0]);
	    $maxy = max($maxy, $outline[$i][1]);
	}
    }

    return ($minx, $miny, $maxx, $maxy);
} # end of _get_col_extents()

# get the next baseline from column outline @outline
# the first argument is the y value of the baseline
# we've already checked that there is room in this column, so y is good
# returns on-page x,y, and width of baseline
# currently expect outline to be UL UR LR LL UL coordinates. 
# TBD: arbitrary shape with line at start_y clipped by outline (if multiple
# lines result, pick longest or first one)
sub _get_baseline {
    my ($start_y, @outline) = @_;

    my ($x,$y, $width);
    $x = $outline[0][0];
    $y = $start_y;
    $width = $outline[1][0] - $x;

    # note that this is the baseline, so it is possible that some
    # descenders may exceed the limit, in a non-rectangular outline!

    return ($x,$y, $width);
} # end of _get_baseline()

# returns array of hashes with prepared text. input could be
#  'pre' markup: must be an array (list) of hashes, returned unchanged.
#  'none' markup: empty lines separate paragraphs, array of texts permitted,
#     paragraphs may not span array elements.
#   'md1' markup: empty lines separate paragraphs, array of texts permitted,
#     paragraphs may span array elements, content is converted to HTML
#     per Text::Markdown, one array element at a time.
#   'md2' markup: similar to md1, but using Text::MultiMarkdown TBD
#   'html' markup: single text string OR array of texts permitted (consolidated
#     into one text), containing HTML markup. 
#
# each element is a hash containing the text and all attributes (HTML or MD
# has been processed).

sub _break_text {
    my ($text, $markup, %opts) = @_;
    my $page_numbers = 0;
    $page_numbers = $opts{'page_numbers'} if defined $opts{'page_numbers'};

    my @array = ();

    if      ($markup eq 'pre') {
	# should already be in final format (such as continuing a column)
	return @$text;

    } elsif ($markup eq 'none') {
	# split up on blank lines into paragraphs and wrap with p and /p tags
        if       (ref($text) eq '') {
	    # is a single string (scalar)
            @array = _none_hash($text, %opts);

        } elsif (ref($text) eq 'ARRAY') {
	    # array ref, elements should be text
            for (my $i = 0; $i < scalar(@$text); $i++) {
                @array = (@array, _none_hash($text->[$i], %opts));
	    }
	}

        # dummy style element at array element [0]
        my $style;
        $style->{'tag'} = 'style';
        $style->{'text'} = '';
        unshift @array, $style;

    } elsif ($markup eq 'md1') {
	# process into HTML, then feed to HTML processing to make hash
	# note that blank-separated lines already turned into paragraphs
        if       (ref($text) eq '') {
	    # is a single string (scalar)
            @array = _md1_hash($text, %opts);

        } elsif (ref($text) eq 'ARRAY') {
	    # array ref, elements should be text
            @array = _md1_hash(join("\n", @$text), %opts);
	}

#       ### no MultiMarkdown until br, code, pre tags supported
#	    ### update Column.pl sample, README.md, Column_doc.pm
#	    ### update TextMultiMarkdown min version in build routines
#   } elsif ($markup eq 'md2') {
#	    # process into HTML, then feed to HTML processing to make hash
#	    # note that blank-separated lines already turned into paragraphs
#        if      (ref($text) eq '') {
# 	         # is a single string (scalar)
#            @array = _md2_hash($text, %opts);
#
#        } elsif (ref($text) eq 'ARRAY') {
# 	         # array ref, elements should be text
#            @array = _md2_hash(join("\n", @$text), %opts);
# 	     }

    } else { # should be 'html'
        if       (ref($text) eq '') {
	    # is a single string (scalar)
            @array = _html_hash($page_numbers, $text, %opts);
	    
        } elsif (ref($text) eq 'ARRAY') {
	    # array ref, elements should be text
	    # consolidate into one string. 
            @array = _html_hash($page_numbers, join("\n", @$text), %opts);
	}
    }

    return @array;
} # end of _break_text()

# convert unformatted string to array of hashes, splitting up on blank lines.
# return with only markup as paragraphs
# note that you can NOT span a paragraph across array elements
sub _none_hash {
    my ($text, %opts) = @_;

    my @array = ();
    my $in_para = 0;
    my $line = '';
    chomp($text); # don't want empty last element due to trailing \n
    foreach (split /\n/, $text) {
	# should be no \n's, but adjacent non-empty lines need to be joined
	if ($_ =~ /^\s*$/) {
	    # empty/blank line. end paragraph if one in progress
	    if ($in_para) {
	        push @array, {'tag' => '', 'text' => $line};
		push @array, {'text' => "", 'tag' => '/p'};
		$in_para = 0;
		$line = '';
	    }
	    # not in a paragraph, just ignore this entry

	} else {
	    # content in this line. start paragraph if necessary
	    if ($in_para) {
		# accumulate content into line
		$line .= " $_";
	    } else {
		# start paragraph, content starts with this text
	        push @array, {'text' => "", 'tag' => 'p'};
		$in_para = 1;
		$line = $_;
	    }
	}

    } # end of loop through line(s) in paragraph
   
    # out of input.
    # if still within a paragraph, need to properly close it
    if ($in_para) {
	push @array, {'tag' => '', 'text' => $line};
	push @array, {'text' => "", 'tag' => '/p'};
	$in_para = 0;
	$line = '';
    }
	
    return @array;
} # end of _none_hash()

# convert md1 string to html, returning array of hashes
# TBD `content` wraps in <code> (OK), but fenced ``` wraps in <p><code> ?!
#     may need to preprocess ``` to wrap in <pre> or postprocess add <pre>
#     <p><code> -> <p><pre><code>
sub _md1_hash {
    my ($text, %opts) = @_;
    my $page_numbers = 0;
    $page_numbers = $opts{'page_numbers'} if defined $opts{'page_numbers'};

    my @array;
    my ($html, $rc);
    $rc = eval {
        require Text::Markdown;
	1;
    };
    if (!defined $rc) { $rc = 0; }  # else is 1
    if ($rc) {
	# installed, but not up to date?
	if (version->parse("v$Text::Markdown::VERSION")->numify() <
	    version->parse("v$TextMarkdown")->numify()) { $rc = 0; }
    }

    if ($rc) {
	# MD converter appears to be installed, so use it
	$html = Text::Markdown::markdown($text);
    } else {
	# leave as MD, will cause a chain of problems
	warn "Text::Markdown not installed, can't process Markdown";
	$html = $text;
    }

    # need to fix something in Text::Markdown -- custom HTML tags are
    # disabled by changing < to &lt;. change them back!
    $html =~ s/&lt;_ref /<_ref /g;
    $html =~ s/&lt;_reft /<_reft /g;
    $html =~ s/&lt;_nameddest /<_nameddest /g;
    $html =~ s/&lt;_sl /<_sl /g;
    $html =~ s/&lt;_move /<_move /g;
    $html =~ s/&lt;_marker /<_marker /g;
    # probably could just do it with s/&lt;_/<_/ but the list is short
    
    # blank lines within a list tend to create paragraphs in list items
    $html =~ s/<li><p>/<li>/g;
    $html =~ s#</p></li>#</li>#g;

    # standard Markdown ~~ line-through (strike-out) not recognized
    my $did_one = 1;
    while ($did_one) {
	$did_one = 0;
	if ($html =~ s#~~([^~])#<del>$1#) {
	    # just one at a time. replace ~~ by <del>
	    $did_one = 1;
	}
	# should be another, replace ~~ by </del>
	$html =~ s#~~([^~])#</del>$1#;
    }

    # standard Markdown === by itself not recognized as a horizontal rule
    $html =~ s#<p>===</p>#<hr>#g;

    # dummy (or real) style element will be inserted at array element [0]
    #   by _html_hash()

    # blank-line separated paragraphs already wrapped in <p> </p>
    @array = _html_hash($page_numbers, $html, %opts);

    return @array;
} # end of _md1_hash()

# convert md2 string to html, returning array of hashes
#sub _md2_hash {
#    my ($text, %opts) = @_;
#    my $page_numbers = 0;
#    $page_numbers = $opts{'page_numbers'} if defined $opts{'page_numbers'};
#
#    my @array;
#    my ($html, $rc);
#    $rc = eval {
#        require Text::MultiMarkdown;
#	1;
#    };
#    if (!defined $rc) { $rc = 0; }  # else is 1
#    if ($rc) {
#	# installed, but not up to date?
#	if (version->parse("v$Text::MultiMarkdown::VERSION")->numify() <
#	    version->parse("v$TextMultiMarkdown")->numify()) { $rc = 0; }
#    }
#
#    my $heading_ids = 0; # default no automatic id generation for hX
#    if (defined $opts{'heading_ids'}) { $heading_ids = $opts{'heading_ids'}; }
#
#    if ($rc) {
#	# MD converter appears to be installed, so use it
#	$html = Text::MultiMarkdown->new(
#		'heading_ids' => $heading_ids,
#		'img_ids' => 0,
#		'empty_element_suffix' => '>',
#	)->markdown($text);
#    } else {
#	# leave as MD, will cause a chain of problems
#	warn "Text::MultiMarkdown not installed, can't process Markdown";
#	$html = $text;
#    }
#
#   # need to fix something in Text::Markdown -- custom HTML tags are
#    # disabled by changing < to &lt;. change them back!
#    $html =~ s/&lt;_ref /<_ref /g;
#    $html =~ s/&lt;_reft /<_reft /g;
#    $html =~ s/&lt;_nameddest /<_nameddest /g;
#    $html =~ s/&lt;_sl /<_sl /g;
#    $html =~ s/&lt;_move /<_move /g;
#    $html =~ s/&lt;_marker /<_marker /g;
#    # probably could just do it with s/&lt;_/<_/ but the list is short
#    
#    # blank lines within a list tend to create paragraphs in list items
#    $html =~ s/<li><p>/<li>/g;
#    $html =~ s#</p></li>#</li>#g;
#
#    # standard Markdown ~~ line-through (strike-out) not recognized
#    my $did_one = 1;
#    while ($did_one) {
#    	$did_one = 0;
#    	if ($html =~ s#~~([^~])#<del>$1#) {
#    	    # just one at a time. replace ~~ by <del>
#    	    $did_one = 1;
#    	}
#    	# should be another, replace ~~ by </del>
#    	$html =~ s#~~([^~])#</del>$1#;
#    }
#
#    # standard Markdown === by itself not recognized as a horizontal rule
#    $html =~ s#<p>===</p>#<hr>#g;
#
#    # dummy (or real) style element will be inserted at array element [0]
#    #   by _html_hash()
#
#    # blank-line separated paragraphs already wrapped in <p> </p>
#    @array = _html_hash($page_numbers, $html, %opts);
#
#    return @array;
#} # end of _md2_hash()

# convert html string to array of hashes. this is for both 'html' markup and
# the final step of 'md1' or 'md2' markup.
# returns array (list) of tags and text, and as a side effect, element [0] is
# consolidated <style> tags (may be empty hash)
sub _html_hash {
    my ($page_numbers, $text, %opts) = @_;

    my $style = {};  # <style> hashref to return
    my @array;       # array of body tags and text to return
    my ($rc);

    # process 'substitute' stuff here. %opts needs to be passed in!
    if (defined $opts{'substitute'}) {
	# array of substitutions to make 
	foreach my $macro_list (@{$opts{'substitute'}}) {
	    # 4 element array: macro name (including any delimiters, such as ||)
	    #                  HTML code to insert before the macro
	    #                  anything to replace the macro name (could be the
	    #                      macro name itself if you want it unchanged)
	    #                  HTML code to insert after the macro
	    # $text is updated, perhaps multiple times
	    # $macro_list is anonymous array [ macro, before, rep, after ]
	    my $macro = $macro_list->[0];
	    my $sub = $macro_list->[1].$macro_list->[2].$macro_list->[3];
            $text =~ s#$macro#$sub#g;
	}
    }

    $rc = eval {
	require HTML::TreeBuilder;
	1;
    };
    if (!defined $rc) { $rc = 0; }  # else is 1
    if ($rc) {
	# installed, but not up to date?
	if (version->parse("v$HTML::TreeBuilder::VERSION")->numify() <
	    version->parse("v$HTMLTreeBldr")->numify()) { $rc = 0; }
    }

    if ($rc) {
	# HTML converter appears to be installed, so use it
        $HTML::Tagset::isList{'_sl'} = 1; # add new list parent
	push @HTML::Tagset::p_closure_barriers, '_sl';
	$HTML::Tagset::emptyElement{'_reft'} = 1; # don't add closing tag
	$HTML::Tagset::emptyElement{'_nameddest'} = 1; # don't add closing tag
	$HTML::Tagset::isPhraseMarkup{'_ref'} = 1; 
	$HTML::Tagset::isPhraseMarkup{'_reft'} = 1; 
	$HTML::Tagset::isPhraseMarkup{'_nameddest'} = 1; 
	my $tree = HTML::TreeBuilder->new();
	$tree->ignore_unknown(0);  # don't discard non-HTML recognized tags
	$tree->no_space_compacting(1);  # preserve spaces
	$tree->warn(1);  # warn if syntax error found
	$tree->p_strict(1);  # auto-close paragraph on new block element
	$tree->implicit_body_p_tag(1);  # loose text gets wrapped in <p>
	$tree->parse_content($text);
	
	# see if there is a <head>, and if so, if any <style> tags within it
	my $head = $tree->{'_head'}; # a hash
	if (defined $head and defined $head->{'_content'}) {
	    my @headList = @{ $head->{'_content'} }; # array of strings and tags
	    @array = _walkTree(0, @headList);
	    # pull out one or more style tags and build $styles hash
            for (my $el = 0; $el < @array; $el++) {
		my $style_text = $array[$el]->{'text'};
		if ($style_text ne '') {
		    # possible style content. style tag immediately before?
		    if (defined $array[$el-1]->{'tag'} &&
			        $array[$el-1]->{'tag'} eq 'style') {
			$style = _process_style_tag($style, $style_text);
		    }
		}
	    }
	} # $style is either empty hash or has style content
	
	# there should always be a body of some sort
	my $body = $tree->{'_body'}; # a hash
	my @bodyList = @{ $body->{'_content'} }; # array of strings and tags
	@array = _walkTree(0, @bodyList);
	# pull out one or more style tags and add to $styles hash
        for (my $el = 0; $el < @array; $el++) {
	    my $style_text = $array[$el]->{'text'};
	    if ($style_text ne '') {
		# possible style content. style tag immediately before?
		if (defined $array[$el-1]->{'tag'} &&
			    $array[$el-1]->{'tag'} eq 'style') {
		    $style = _process_style_tag($style, $style_text);
		    # remove <style> from body (array list)
		    splice(@array, $el-1, 3);
		}
	    }
	} # $style is either empty hash or has style content
    } else {
	# leave as original HTML, will cause a chain of problems
	warn "HTML::TreeBuilder not installed, can't process HTML";
	push @array, {'tag' => '', 'text' => $text};
    }

    # does call include a style initialization (opt in column() call)?
    # merge into any consolidated <style> tags for user styling in [1]
    if (defined $opts{'style'}) {
	# $style could be empty hash ptr at this point
        $style = _process_style_tag($style, $opts{'style'});
    }

    # always first element tag=style containing the hash, even if it's empty
    # array[0] is default CSS, array[1] is consolidated <style> tags
    $style->{'tag'} = 'style';
    $style->{'text'} = '';
    unshift @array, $style; # [0] default CSS added later
     
    # HTML::TreeBuilder does some undesirable things with custom tags
    # it doesn't understand. clean them up.
    @array = _HTB_cleanup($page_numbers, $opts{'debug'}, @array);

    return @array;
} # end of _html_hash()

# clean up some things HTML::TreeBuilder does when it sees unknown tag.
# this is done at creation of the tag/content array, so no need to worry
# about 'pre' input format and the like.
sub _HTB_cleanup {
    my ($page_numbers, $debug, @mytext) = @_;

    my @current_list = ('empty');

    # loop through all elements, looking for specific patterns
    # start at [1], so defaults and styles skipped
    for (my $el=1; $el < @mytext; $el++) {
	if (ref($mytext[$el]) ne 'HASH') { next; }
	if ($mytext[$el]->{'tag'} eq '') { next; }

        my $tag = lc($mytext[$el]->{'tag'});
        $mytext[$el]->{'tag'} = $tag; # lc the tag
	if (!defined $tag) { next; }
       #if ($tag =~ m#^/#) { next; } # ignore end tags?

        if ($tag eq 'li') {
	    # dealing with <_marker> is a special case, driven by need to
	    # ensure that all <li> tags have a <_marker>[text]</_marker>
	    # just before them, and is not a shortcoming of HTML::TreeBuilder
	    #
	    # if user did not explicitly give a <_marker> just before <li>,
	    # insert one to "even up" with any in the source. 
	    # $el element ($tag) s/b at 'li' at this point
	    # MUST check if HTML::TreeBuilder (or user) added their own 
	    #    /_marker tag! and whether explicit text given!
	    #
	    # 1. <_marker><li>   add text='' and </_marker>
	    # 2. <_marker></_marker><li>  add text='' in between
	    # 3. <_marker>text</_marker><li>  no change (text may be '')
	    #    use this user-provided marker text; do not replace
	    # 4. <li>  add <_marker>text=''</_marker>
	    #
	    # Note that HTML::TreeBuilder seems to already track that a list
	    #  (ul) or (ol) is the parent of a li
	    if ($mytext[$el-1]->{'tag'} eq '/_marker') {
		# case 2 or 3, assume there is <_marker> tag
	        if ($mytext[$el-2]->{'tag'} eq '') {
		    # case 3, no change to make unless current parent is _sl
		    # AND text is not ''
		    if ($current_list[-1] eq 's') {
			$mytext[$el-2]->{'text'} = '';
		    }
		} else {
		    # case 2, add empty text tag between
	            splice(@mytext, $el-1, 0, {'tag'=>'', 'text'=>''});
		    $el++;
		}
	    } elsif ($mytext[$el-1]->{'tag'} eq '_marker') {
		# case 1
	        splice(@mytext, $el++, 0, {'tag'=>'', 'text'=>''});
	        splice(@mytext, $el++, 0, {'tag'=>'/_marker', 'text'=>''});
	    } else {
		# case 4
		# we haven't added or expanded a <_marker> here yet
		splice(@mytext, $el++, 0, {'tag'=>'_marker', 'text'=>''});
	        splice(@mytext, $el++, 0, {'tag'=>'', 'text'=>''});
	        splice(@mytext, $el++, 0, {'tag'=>'/_marker', 'text'=>''});
	    }
	    # $el should still point to <li> element, which should now have
	    # three elements in front of it: <_marker>(empty)</_marker>
	    # for ul, ol if user gives marker with explicit text, don't replace
	    # for _sl, text should be '', and marker is mostly ignored
	     
	# if user added a non-'' _marker text for _sl, need to remove
	} elsif ($tag eq 'ul') {
	    push @current_list, 'u';
	} elsif ($tag eq 'ol') {
	    push @current_list, 'o';
	} elsif ($tag eq '_sl') {
	    push @current_list, 's';
	} elsif ($tag eq '/_sl' || $tag eq '/ol' || $tag eq '/ul') {
	    pop @current_list;

        # already added _sl to list of allowed list parents

	} elsif ($tag eq '_ref') {
	    # should be followed by empty text and then /_ref tag,
	    # add if either missing. fill in text content with any title=
	    # attribute in _ref
	    # tgtid= is mandatory
	    if (!defined $mytext[$el]->{'tgtid'}) {
		carp "Warning! No 'tgtid' defined for a <_ref> tag, no link.";
		$mytext[$el]->{'tgtid'} = '';
	    }
	    # if tgtid is '#', check if following content is ^\d+-?. if
	    # not, remove # (is a regular id)
	    my $tgtid = $mytext[$el]->{'tgtid'};
	    if ($tgtid =~ m/^#[^#]/) {
		# starts with a single '#'
	        if ($tgtid =~ m/^#\d+-?/) {
		    # it's a physical page number link, leave it alone
		} else {
		    # it's #id, so strip off leading #
		    $mytext[$el]->{'tgtid'} = substr($tgtid, 1);
		}
	    }

	    my $text = $mytext[$el]->{'title'} // '[no title given]';
	    $text =~ s/\n/ /sg; # any embedded line ends turn to spaces
            # most likely, the /_ref has been put AFTER the following text,
	    # resulting in el=_ref, el+1=random text, >el+1=/_ref
	    #   >el+1 loose end tag will be deleted
            if      ($mytext[$el+1]->{'tag'} eq '/_ref') {
		# <_ref></_ref> insert child text with title
	        splice(@mytext, ++$el, 0, {'tag'=>'', 'text'=>$text});
		$el++;
	    } elsif ($mytext[$el+1]->{'tag'} eq '' &&
	             $mytext[$el+1]->{'text'} ne '') {
	   #    # <_ref><other text></_ref> insert text=$text and /_ref
	   #    # giving <_ref><title text></_ref><other text>
	   #    splice(@mytext, ++$el, 0, {'tag'=>'', 'text'=>$text});
	   #    splice(@mytext, ++$el, 0, {'tag'=>'/_ref', 'text'=>''});
	   #    # superfluous /_ref will be deleted
	        $el+=2;
	    } elsif ($mytext[$el+1]->{'tag'} eq '' &&
	             $mytext[$el+1]->{'text'} eq '') {
		# <_ref><empty text></_ref> update text with title text
		$mytext[++$el]->{'text'} = $text;
		# is following /_ref missing?
		if ($mytext[++$el]->{'tag'} ne '/_ref') {
		    splice(@mytext, $el, 0, {'tag'=>'/_ref', 'text'=>''});
		}
	    } else {
		# just <_ref>. add text and end tag
	        splice(@mytext, ++$el, 0, {'tag'=>'', 'text'=>$text});
	        splice(@mytext, ++$el, 0, {'tag'=>'/_ref', 'text'=>''});
	    }
	    # $el should be pointing to /_ref tag
	    if ($page_numbers != 0 &&
	        $mytext[$el]->{'tgtid'} !~ /#[^#]/) {
	        # insert a <text> after </_ref> to hold " on page $", 
		# " on facing page", etc. TBD page&nbsp;$
		# do NOT insert for Named Destination (single # in tgtid)
	        splice(@mytext, ++$el, 0, {'tag'=>'', 'text'=>" on page \$"});
	    }
	} elsif ($tag eq '/_ref') {
            # TreeBuilder often puts end tag after wrong text
	   #splice(@mytext, $el--, 1);

	} elsif ($tag eq '_reft') {
	    # leave title in place for <_reft>, but delete any text and </_reft>
	    if      ($mytext[$el+1]->{'tag'} eq '' && 
		     $mytext[$el+2]->{'tag'} eq '/_reft') {
		splice(@mytext, $el+1, 2);
	    } elsif ($mytext[$el+1]->{'tag'} eq '/_reft') {
	        splice(@mytext, $el+1, 1);
	    }
	} elsif ($tag eq '/_reft') {
            # TreeBuilder often puts end tag after wrong text
	    splice(@mytext, $el--, 1);

	} elsif ($tag eq '_nameddest') {
	    # delete any text and </_nameddest>
	    if      ($mytext[$el+1]->{'tag'} eq '' && 
		     $mytext[$el+2]->{'tag'} eq '/_nameddest') {
		splice(@mytext, $el+1, 2);
	    } elsif ($mytext[$el+1]->{'tag'} eq '/_nameddest') {
	        splice(@mytext, $el+1, 1);
	    }
	    if (defined $debug && $debug == 1) {
		# insert tags to write a blue | bar at beginning of text
		# $el should point to _nameddest tag itself
		splice(@mytext, $el++, 0, {'tag'=>'span', 'text'=>'',
	               'style'=>'color: #0000FF; font-weight: bold;'});
		splice(@mytext, $el++, 0, {'tag'=>'', 'text'=>'|'});
		splice(@mytext, $el++, 0, {'tag'=>'/span', 'text'=>''});
		# still pointing at _nameddest tag
	    }
	} elsif ($tag eq '/_nameddest') {
            # TreeBuilder often puts end tag after wrong text
	    splice(@mytext, $el--, 1);

	} elsif ($tag eq '/_move') {
            # TreeBuilder often puts end tag after wrong text
	    splice(@mytext, $el--, 1);

	} elsif ($tag eq 'a') {
	    # if a URL, leave as-is. otherwise convert a /a to _ref /_ref
	    if ($mytext[$el]->{'href'} =~ m#^[a-z0-9]+://#i) {
		# protocol:// likely a URL
	    } else {
		# xref link: convert tag
		# 1. a tag convert to _ref
		$mytext[$el]->{'tag'} = '_ref';
		# 1a. need to check if <a href></a> need to insert text?
		if ($mytext[$el+1]->{'tag'} ne '') {
		    # yep, missing child text
		    splice(@mytext, $el+1, 0, { 'tag'=>'', 'text'=>'' });
		}

		# 2. /a tag convert to /_ref (next /a seen, does not nest)
		for (my $i=$el+1; $i<@mytext; $i++) {
		    if ($mytext[$i]->{'tag'} eq '/a') {
			$mytext[$i]->{'tag'} = '/_ref';
			last;
		    }
		}

		# 3. href -> tgtid attribute
		$mytext[$el]->{'tgtid'} = delete $mytext[$el]->{'href'};

		# 4. child text -> title, id, fit attributes
		# NOTE: any markup tags get removed, is plain text
		my $newtitle = _get_special_info(\@mytext, $el, '{^', '}');
		my $newfit   = _get_special_info(\@mytext, $el, '{%', '}');
		my $newid    = _get_special_info(\@mytext, $el, '{#', '}');

		if ($newtitle eq '') {
		    $newtitle = _get_child_text(\@mytext, $el);
		}
		if (!defined $mytext[$el]->{'title'}) {
		    $mytext[$el]->{'title'} = $newtitle;
		}
		# is child (title) text still empty after all this?
		if ($mytext[$el+1]->{'text'} eq '') {
		    $mytext[$el+1]->{'text'} = $mytext[$el]->{'title'};
		}

		# 5. fit info -> fit attribute (if none exists)
		if (defined $mytext[$el]->{'fit'}) {
		    # already exists, so only remove inline stuff
		} else {
		    if ($newfit ne '') { 
			$mytext[$el]->{'fit'} = $newfit; 
		    }
		}

		# 6. id info -> id attribute (if none exists)
		if (defined $mytext[$el]->{'id'}) {
		    # already exists, so only remove inline stuff
		} else {
		    if ($newid ne '') { 
			$mytext[$el]->{'id'} = $newid; 
		    }
		}

		# 7. child text is empty? replace by title text
		if ($mytext[$el+1]->{'text'} eq '' &&
		    defined $mytext[$el]->{'title'}) {
		    $mytext[$el+1]->{'text'} = $mytext[$el]->{'title'};
		}
	    }
        }

	# any child text (incl. link title) with {#id}? pull out into id=
	# this is needed for Markdown (may define, for headings only). not
	# necessarily supported by Text::Markdown, or yet by Builder.
	# child text in: hX, a, span, p, li, i/em, b/strong, del, sub/sup, mark,
	#   blockquote, dd/dd, code, pre, img (alt text or title text), th,td
	if ($mytext[$el]->{'tag'} eq 'h1' ||
	    $mytext[$el]->{'tag'} eq 'h2' ||
	    $mytext[$el]->{'tag'} eq 'h3' ||
	    $mytext[$el]->{'tag'} eq 'h4' ||
	    $mytext[$el]->{'tag'} eq 'h5' ||
	    $mytext[$el]->{'tag'} eq 'h6' ||
	    $mytext[$el]->{'tag'} eq 'a' ||
	    $mytext[$el]->{'tag'} eq 'span' ||
	    $mytext[$el]->{'tag'} eq 'p' ||
	    $mytext[$el]->{'tag'} eq 'li' ||
	    $mytext[$el]->{'tag'} eq 'i' ||
	    $mytext[$el]->{'tag'} eq 'em' ||
	    $mytext[$el]->{'tag'} eq 'b' ||
	    $mytext[$el]->{'tag'} eq 'strong' ||
	    $mytext[$el]->{'tag'} eq 'del' ||
	    $mytext[$el]->{'tag'} eq 'sub' ||
	    $mytext[$el]->{'tag'} eq 'sup' ||
	    $mytext[$el]->{'tag'} eq 'mark' ||
	    $mytext[$el]->{'tag'} eq 'blockquote' ||
	    $mytext[$el]->{'tag'} eq 'dt' ||
	    $mytext[$el]->{'tag'} eq 'dd' ||
	    $mytext[$el]->{'tag'} eq 'code' ||
	    $mytext[$el]->{'tag'} eq 'pre' ||
	    $mytext[$el]->{'tag'} eq 'img' ||
	    $mytext[$el]->{'tag'} eq 'th' ||
	    $mytext[$el]->{'tag'} eq 'td') {
	    my $newid = _get_special_info(\@mytext, $el, '{#', '}');
	    if ($newid ne '' && !defined $mytext[$el]->{'id'}) {
		# do not replace existing id=
	        $mytext[$el]->{'id'} = $newid;
	    }
	}
	
	# if _get_special_info() was used to extract an id {#id}, title
	# {^title}, or fit {%fit}; it should have NOT left a blank child
	# text string, though it may be empty
	
	# if a tag has id=, assume it's a link target
	# insert tags to write a red | bar at beginning of link text
	# $el should point to tag itself
	if (defined $mytext[$el]->{'id'} && defined $debug && $debug == 1) {
	    splice(@mytext, ++$el, 0, {'tag'=>'span', 'text'=>'',
		   'style'=>'color: #FF0000; font-weight: bold;'});
	    splice(@mytext, ++$el, 0, {'tag'=>'', 'text'=>'|'});
	    splice(@mytext, ++$el, 0, {'tag'=>'/span', 'text'=>''});
	    # still pointing at original tag
	}
	# 'next' to here
    } # for loop through all tags

    return @mytext;
} # end of _HTB_cleanup()

# given the text between <style> and </style>, and an existing $style
# hashref, update $style and return it
sub _process_style_tag {
    my ($style, $text) = @_;

    # expect sets of selector { property: value; ... }
    # break up into selector => { property => value, ... }
    # replace or add to existing $style
    # note that a selector may be a tagName, a .className, or an #idName

    $text =~ s/\n/ /sg;  # replace end-of-lines with spaces
    while ($text ne '') {
	my $selector;

	if ($text =~ s/^\s+//) { # remove leading whitespace
	    if ($text eq '') { last; }
	}
	if ($text =~ s/([^\s]+)//) { # extract selector
	    $selector = $1;
        }
	if ($text =~ s/^\s*{//) { # remove whitespace up through {
	    if ($text eq '') { last; }
	}
	# one or more property-name: value; sets (; might be missing on last)
	# go into %prop_val. we don't expect to see any } within a property
	# value string.
	if ($text =~ s/([^}]+)//) {
	    $style->{$selector} = _process_style_string({}, $1);
	}
	if ($text =~ s/^}\s*//) { # remove closing } and whitespace
	    if ($text eq '') { last; }
	}
	
        # 'next' to here
    } # end while loop

    return $style;
} # end of _process_style_tag()

# decompose a style string into property-value pairs. used for both <style>
# tags and style= attributes.
sub _process_style_string {
    my ($style, $text) = @_;

    # split up at ;'s. don't expect to see any ; within value strings
    my @sets = split /;/, $text;
    # split up at :'s. don't expect to see any : within value strings
    foreach (@sets) {
	my ($property_name, $value) = split /:/, $_;
	if (!defined $property_name || !defined $value) { last; }
	# trim off leading and trailing whitespace from both
	$property_name =~ s/^\s+//;
	$property_name =~ s/\s+$//;
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
	# trim off any single or double quotes around value string
	if ($value =~ s/^['"]//) {
	    $value =~ s/['"]$//;
	}

	$style->{$property_name} = $value;
    }

    return $style;
} # end of _process_style_string()

# given a list of tags and content and attributes, return a list of hashes.
# new array element at start, at each tag, and each _content.
sub _walkTree {
    my ($depth, @bodyList) = @_;
    my ($tag, $element, $no_content);

    my $bLSize = scalar(@bodyList);
    # $depth not really used here, but might come in handy at some point
    my @array = ();

    for (my $elIdx=0; $elIdx<$bLSize; $elIdx++) {
        $element = $bodyList[$elIdx];
	# an element may be a simple text string, but most are hashes that
	# contain a _tag and _content array and any tag attributes. _tag and
	# any attributes go into an entry with text='', while any _content
	# goes into one entry with text='string' and usually no attributes. 
	# if the _tag takes an end tag , it gets its own dummy entry.
	
        if ($element =~ m/^HTML::Element=HASH/) {
            # $element should be anonymous hash
            $tag = $element->{'_tag'};
            push @array, {'tag' => $tag, 'text' => ''};

	    # look for attributes for tag, also see if no child content
	    $no_content = 0;  # has content (children) until proven otherwise
	    my @tag_attr = keys %$element;
	    # VOID elements (br, hr, img, area, base, col, embed, input,
	    # link, meta, source, track, wbr) should NOT have /> to mark
	    # as "self-closing", but it's harmless and much HTML code will
	    # have them marked as "self-closing" even though it really
	    # isn't! So be prepared to handle such dummy attributes, as
	    # per RT 143038.
	    if ($tag eq 'br' || $tag eq 'hr' ||
	        $tag eq 'img' || $tag eq 'area' || $tag eq 'base' ||
	        $tag eq 'col' || $tag eq 'embed' || $tag eq 'input' ||
	        $tag eq 'link' || $tag eq 'meta' || $tag eq 'source' ||
	        $tag eq 'track' || $tag eq 'wbr' || 
		$tag eq 'defaults' || $tag eq 'style') { 
		# self-closing or VOID with unnecessary /, there is no
		# child data/elements for this tag. and, we can ignore
		# this 'attribute' of /.
		# defaults and style are specially treated as a VOID tags
		$no_content = 1; 
	    }
	    foreach my $key (@tag_attr) {
		# has an (unnecessary) self-closing / ?
	        if ($element->{$key} eq '/') { next; }
	        
		# 'key' is more of an attribute within a tag (element)
	        if ($key =~ m/^_/) { next; } # built-in attribute
		# this tag has one or more attributes to add to it
                # add tag attribute (e.g., src= for <img>) to hash
		$array[-1]->{$key} = $element->{$key};
	    }

	    if (!$no_content && defined $element->{'_content'}) {
	        my @content = @{ $element->{'_content'} };
		# content array elements are either text segments or
		# tag subelements
	        foreach (@content) {
	            if ($_ =~ m/^HTML::Element=HASH/) {
		        # HASH child of this _content
		        # recursively handle a tag within _content
		        @array = (@array, _walkTree($depth+1, $_));
		    } else {
                        # _content text, shouldn't be any attributes
		        push @array, {'tag' => '', 'text' => $_};
		    }
	        }
	    } else {
		# no content for this tag
	    }
	    # at end of a tag ... if has content, output end tag
	    if (!$no_content) {
		push @array, {'tag' => "/$tag", 'text' => ''};
	    }

	    $no_content = 0;

       } else {
            # SCALAR (string) element
            push @array, {'tag' => '', 'text' => $element};
       }

       # 'next' to here
   } # loop through _content at this level ($elIdx)

   return @array;
} # end of _walkTree()

# convert a size (length) or font size into points
# TBD another parm to indicate how to treat 'no unit' case?
#     currently assume points (CSS considers only bare 0 to be valid)
# length = string (or pure number) of length in CSS units
#          if number, is returned as points
# font_size = current font size (points) for use with em, en, ex, % units
# option parent_size = parent dimension (points) to use for % instead of font size
# option usage = label for what is being converted to points
sub _size2pt {
    my ($length, $font_size, %opts) = @_;
    # length is requested size (or font size), possibly with a unit
    #    if undefined, use '0'
    $length = '0' if !defined $length;
    $length = ''.$length; # ensure is a string (may be unitless number of points)
    # font_size is current_prop font-size (pts), 
    #    in case relative to font size (such as %). must be number > 0
    my $parent_size = $font_size;
    if (defined $opts{'parent_size'}) {
        # must be a number (points). this way, font size still available
        # for em, en, ex, but parent container size used for other things
        $parent_size = $opts{'parent_size'};
    }
    my $usage = 'unknown';
    $usage = $opts{'usage'} if defined $opts{'usage'};

    my $number = 0;
    my $unit = '';
    # split into number and unit
    if      ($length =~ m/^(-?\d+\.?\d*)(.*)$/) {
	$number = $1; # [-] nnn.nn, nnn., or nnn format
	$unit = $2;   # may be empty
    } elsif ($length =~ m/^(-?\.\d+)(.*)$/) {
	$number = $1; # [-] .nnn format
	$unit = $2;   # may be empty
    } else {
	carp "Unable to find number in '$length', _size2pt returning 0";
	return 0;
    }

    # font_size should be in points (bare number)
    if ($unit eq '') {
        # if is already a pure number, just return it
	# except for 0, that's not legal CSS, is an extension
	return $number;
    } elsif ($unit eq 'pt') {
        # if the unit is 'pt', strip off the unit and return the number
        return $number;
    } elsif ($unit eq '%') {
        # if the unit is '%', strip off, /100, multiply by current parent/font size
	return $number/100 * $parent_size;
    } elsif ($unit eq 'em') {
	# 1 em = 100% font size
	return $font_size;
    } elsif ($unit eq 'en' || $unit eq 'ex') {
	# 1 en = 1 ex = 50% font size
	# TBD get true ex size from font information
	return $font_size/2;
    } elsif ($unit eq 'in') {
	# 1 inch = 72pt
	return 72*$number;
    } elsif ($unit eq 'cm') {
	# 1 cm = 28.35pt
	return 28.35*$number;
    } elsif ($unit eq 'mm') {
	# 1 cm = 2.835pt
	return 2.835*$number;
    } elsif ($unit eq 'px') {
	# assume 78px to the inch TBD actual value available anywhere?
	return 72/78*$number;
    } else {
	carp "Unknown unit '$unit' in '$length', _size2pt() assumes 'pt'";
	return $number;
    }

    return 0; # should not get to here
} # end of _size2pt()

# create ordered or unordered list item marker
# for ordered, returns $prefix.formatted_value.$suffix.blank
# for unordered, returns string .disc, .circle, .square, or .box
#   (.box is nonstandard marker)
#
# TBD for ol, there are many other formats: cjk-decimal, decimal-leading-zero,
#      lower-greek, upper-greek?, lower-latin = lower-alpha, upper-latin =
#      upper-alpha, arabic-indic, -moz-arabic-indic, armenian, [-moz-]bengali, 
#      cambodian (khmer), [-moz-]cjk-earthly-branch, [-moz-]cjk-heavenly-stem, 
#      cjk-ideographic, [-moz-]devanagari, ethiopi-numeric, georgian,
#      [-moz-]gujarati, [-moz-]gurmukhi, hebrew, hiragana, hiragana-iroha, 
#      japanese-formal, japanese-informal, [-moz-]kannada, katakana, 
#      katakana-iroha, korean-hangul-formal, korean-hanja-formal, 
#      korean-hanja-informal, [-moz-]lao, lower-armenian, upper-armenian, 
#      [-moz-]malayalam, mongolian, [-moz-]myanmar, [-moz-]oriya, 
#      [-moz-]persian, simp-chinese-formal, simp-chinese-informal, [-moz-]tamil,
#      [-moz-]telugu, [-moz-]thai, tibetan, trad-chinese-formal, 
#      trad-chinese-informal, disclosure-open, disclosure-closed
# TBD for ol, some browser-specific formats: -moz-ethiopic-halehame,
#      -moz-ethiopic-halehame-am, [-moz-]ethiopic-halehame-ti-et, [-moz-]hangul,
#      [-moz-]hangul-consonant, [-moz-]urdu
# TBD for ul, ability to select images and possibly other characters
sub _marker {
    my ($type, $depth_u, $depth_o, $depth_s, $value, $prefix, $suffix) = @_; 
                                     # type = list-style-type, 
                                     # depth_u = 1, 2,... ul nesting level,
                                     # depth_o = 1, 2,... ol nesting level,
                                     # depth_s = 1, 2,... _sl nesting level,
				     # (following for ordered list only):
				     #   value = counter (start)
				     #   prefix = text before formatted value
				     #    default ''
				     #   suffix = text after formatted value
				     #    default '.'
    if (!defined $suffix) { $suffix = '.'; }
    if (!defined $prefix) { $prefix = ''; }

    my $output = '';
    # CAUTION: <ol type=  and <li type = will be aAiI1, not CSS property values!
    if      ($type eq 'a') {
	$type = 'lower-alpha';
    } elsif ($type eq 'A') {
	$type = 'upper-alpha';
    } elsif ($type eq 'i') {
	$type = 'lower-roman';
    } elsif ($type eq 'I') {
	$type = 'upper-roman';
    } elsif ($type eq '1') {
	$type = 'decimal';
    }

    # ordered lists
    if      ($type eq 'decimal' || $type eq 'arabic') {
	$output = "$prefix$value$suffix";
    } elsif ($type eq 'upper-roman' || $type eq 'lower-roman') {
	# TBD support overbar (1000x) for Roman numerals. what is exact format?
	while ($value >= 1000) { $output .= 'M';  $value -= 1000; }
	if ($value >= 900)     { $output .= 'CM'; $value -= 900;  }
	if ($value >= 500)     { $output .= 'D';  $value -= 500;  }
	if ($value >= 400)     { $output .= 'CD'; $value -= 500;  }
	while ($value >= 100)  { $output .= 'C';  $value -= 100;  }
	if ($value >= 90)      { $output .= 'XC'; $value -= 90;   }
	if ($value >= 50)      { $output .= 'L';  $value -= 50;   }
	if ($value >= 40)      { $output .= 'XL'; $value -= 40;   }
	while ($value >= 10)   { $output .= 'X';  $value -= 10;   }
	if ($value == 9)       { $output .= 'IX'; $value -= 9;    }
	if ($value >= 5)       { $output .= 'V';  $value -= 5;    }
	if ($value == 4)       { $output .= 'IV'; $value -= 4;    }
	while ($value >= 1)    { $output .= 'I';  $value -= 1;    }
        if ($type eq 'lower-roman') { $output = lc($output); }
	$output = "$prefix$output$suffix";
    } elsif ($type eq 'upper-alpha' || $type eq 'lower-alpha') {
	my $n;
	while ($value) {
	    $n = ($value - 1)%26; # least significant letter digit 0..25
	    $output = chr(ord('A') + $n) . $output;
	    $value -= ($n+1);
	    $value /= 26;
	}
        if ($type eq 'lower-alpha') { $output = lc($output); }
	$output = "$prefix$output$suffix";

    # there are many more ordered list formats that could be supported here

    # unordered lists
    } elsif ($type eq 'disc') {
	$output = '.disc';
    } elsif ($type eq 'circle') {
	$output = '.circle';
    } elsif ($type eq 'square') {
	$output = '.square';
    } elsif ($type eq 'box') {  # non-standard
	$output = '.box';
    } elsif ($type eq '.u') { # default for unordered list at this depth
	# unlikely to exceed depth of 4, but be ready for it...
	# TBD what is official policy on depth exceeding 3? is it all .square
	#   or is it supposed to rotate?
	my $depth = $depth_u+$depth_o+$depth_s;
	if      ($depth%4 == 1) {
	    $output = '.disc';
	} elsif ($depth%4 == 2) {
	    $output = '.circle';
	} elsif ($depth%4 == 3) {
	    $output = '.square';
        } elsif ($depth%4 == 0) {
	    $output = '.box';
	}
    } elsif ($type eq '.o') { # default for ordered list at this depth
	$output = "$prefix$value$suffix"; # decimal

    # potentially many other unordered list marker systems, but need to find
    # out if there's anything official

    } elsif ($type eq 'none') {
	$output = '.none';
    } else {
	# unknown. use disc
	$output =  '.disc';
    }

    return $output;
} # end of _marker()

# stuff to remember if need to shift line down due to extent increase
# @line_extents array:
#   $start_x # fixed start of current baseline
#   $x # current baseline offset to write at
#        note that $x changes with each write 
#   $y
#   $width
#   $endx
#   $next_y # where next line will start (may move down)
#   $asc # current vertical extents
#   $desc
#   $desc_leading
#   $text # text context (won't change)
#   length($text->{' stream'}) # where the current line starts in the stream
#                              # (won't change)
#   $grfx # graphis content, might be undef (won't change)
#   length($grfx->{' stream'}) # where the current line starts in the stream
#                              # (won't change)
#   $start_y # very top of this line (won't change)
#   $min_y # lowest allowable inked value (won't change)
#   $outline # array ref to outline (won't change)
#   $left_margin to shorten line (won't change)
#   $left_margin_nest to shorten line on nested list (won't change)
#   $right_margin to shorten line (won't change)
# we do the asc/desc externally, as how to get them depends on whether it's
#   a font change, an image or equation, or some other kind of inline object
# $asc = new ascender (does it exceed the old one?)
# $desc = new descender (does it exceed the old one?)
# $desc_leading = new descender with leading (does it exceed the old one?)
# $text_w = width of text ($phrase) to be written
# returns $rc = 0: all OK, line fits with no change to available space
#               1: OK, but available space reduced, so need to recheck
#               2: problem -- existing line (already written) won't fit in
#                             shorter line, much less space for new text
#               3: problem -- line now runs off bottom of column
#         @line_extents, with some entries revised
sub _revise_baseline {
    my ($o_start_x, $o_x, $o_y, $o_width, $o_endx, $o_next_y, $o_asc, $o_desc,
	$o_desc_leading, $text, $line_start_offset, 
	$grfx, $line_start_offsetg, $start_y, $min_y,
	$outline, $margin_left, 
	$margin_right, $asc, $desc, $desc_leading, $text_w) = @_;

    my $rc = 0; # everything OK so far
    # items which may change (remembering initial/old values)
    my $start_x = $o_start_x; # line's original starting x
    my $x = $o_x; # current x position
    my $y = $o_y;
    my $width = $o_width;
    my $endx = $o_endx;
    my $next_y = $o_next_y;
    # may change, but supplied separately
    # $asc = $o_asc;
    # $desc = $o_desc;
    # $desc_leading = $o_desc_leading;

    my $need_revise = 0;
    # determine whether we need to revise baseline due to extent increases
    if ($asc > $o_asc) {
	$need_revise = 1;
    } else {
	$asc = $o_asc;
    }
    if ($desc < $o_desc) { # desc and desc_leading are negative values
	$need_revise = 1;
    } else {
	$desc = $o_desc;
    }
    if ($desc_leading < $o_desc_leading) {
	$need_revise = 1;
    } else {
	$desc_leading = $o_desc_leading;
    }

    if ($need_revise) {
	# in middle of line, add_x and add_y are 0
	# start_y is unchanged, but asc, desc may have increased
	$next_y = $start_y - $asc + $desc_leading;
	# did we go too low? will return -1 (start_x) and 
	#   remainder of input
	# don't include leading when seeing if line dips too low
	if ($start_y - $asc + $desc < $min_y) {
	    $rc = 3; # ran out of column (vertically) = we overflow column
	             # off bottom if we go ahead and write any of new text
	    # TBD instead just end line here (early), 
	    #     go to next column for taller text we want to print
	    #     however, could then end up with a very short line!
        } else {
	    # start_y and next_y are vertical extent of this line (revised)
	    # y is the y value of the baseline (so far). lower it a bit.
	    $y -= $asc - $o_asc;
	    # start_x is baseline start (so far), x is current write position

	    # how tall is the line? need to set baseline.
            ($start_x,$y, $width) = _get_baseline($y, @$outline);
	    # $x should be unchanged at this point (might be beyond new end)
	    $width -= $margin_left + $margin_right; # available on new line
            $endx = $start_x + $width;

	    # we don't know the nature of the new material attempting to add,
	    #   so can't resolve insufficient space issues here
	    # $x should already account for margin_left
 	    if      ($x > $endx) {
	        # if current (already written) line can't fit (due to much 
		#     shorter line), rc = 2
                $rc = 2;
	    } elsif ($x + $text_w > $endx) {
	        # if adding new text will overflow line, rc = 1
		$rc = 1;
	    } else { # should have room to write new text
		$rc = 0;
	    
		# revise (move in x,y) any existing text in this line (Tm cmd),
		# INCLUDING this text chunk's Tm if still in Tpending buffer.
		$text->_Tpending();
                my $i = $line_start_offset;
		my $delta_x = $start_x - $o_start_x;
		my $delta_y = $y - $o_y;
                while(1) {
                   $i = index($text->{' stream'}, ' Tm', $i+3);
                   if ($i == -1) { last; }
		   # $i is the position of a Tm command in the stream. the two
		   # words before it are x and y position to write at.
		   # $j is $i back up by two spaces
		   my $j = rindex($text->{' stream'}, ' ', $i-1);
		   $j = rindex($text->{' stream'}, ' ', $j-1) + 1;
		   # $j points to first char of x, $i to one after last y char
		   my $str1 = substr($text->{' stream'}, 0, $j);
		   my $str2 = substr($text->{' stream'}, $i);
		   my $old_string = substr($text->{' stream'}, $j, $i-$j);
		   $old_string =~ m/^([^ ]+) ([^ ]+)$/;
		   my $old_x = $1;
		   my $old_y = $2;
		   $old_x += $delta_x;
		   $old_y += $delta_y;
                   $text->{' stream'} = $str1."$old_x $old_y".$str2;
                   # no need to change line_start_offset, but $i has to be 
		   # adjusted to account for possible change in resulting 
		   # position of Tm
		   $i += length("$old_x $old_y") - ($i - $j);
                }  # end while(1) loop adjusting Tm's on this line

		# AFTER the Tm statement may come one or more strokes for
		# underline, strike-through, and/or overline
                $i = $line_start_offset;
		# $delta_x, $delta_y same as before
		while (1) {
                   $i = index($text->{' stream'}, ' l S', $i+4);
                   if ($i == -1) { last; }
		   # $i is the position of a lS command in the stream. the five
		   # words before it are x and y positions to write at.
		   # (x y m x' y l S is full command to modify)
		   # $j is $i back up by five spaces
		   my $j = rindex($text->{' stream'}, ' ', $i-1);
		   $j = rindex($text->{' stream'}, ' ', $j-1);
		   $j = rindex($text->{' stream'}, ' ', $j-1);
		   $j = rindex($text->{' stream'}, ' ', $j-1);
		   $j = rindex($text->{' stream'}, ' ', $j-1);
		   # $j points to first char of x, $i to one after last y char
		   my $str1 = substr($text->{' stream'}, 0, $j);
		   my $str2 = substr($text->{' stream'}, $i);
		   my $old_string = substr($text->{' stream'}, $j, $i-$j);
		   $old_string =~ m/^ ([^ ]+) ([^ ]+) m ([^ ]+) ([^ ]+)$/;
		   my $old_x1 = $1;
		   my $old_y1 = $2;
		   my $old_x2 = $3;
		   my $old_y2 = $4;
		   $old_x1 += $delta_x;
		   $old_y1 += $delta_y;
		   $old_x2 += $delta_x;
		   $old_y2 += $delta_y;
                   $text->{' stream'} = $str1." $old_x1 $old_y1 m $old_x2 $old_y2".$str2;
                   # no need to change line_start_offset, but $i has to be 
		   # adjusted to account for possible change in resulting 
		   # position of lS
		   $i += length(" $old_x1 $old_y1 m $old_x2 $old_y2") - ($i - $j);
                } # end while(1) loop adjusting line stroke positions
	    }
        }
    }

    return ($rc, $start_x, $x, $y, $width, $endx, $next_y, 
	    $asc, $desc, $desc_leading, 
            $text, $line_start_offset, $grfx, $line_start_offsetg,
	    $start_y, $min_y, $outline,
            $margin_left, $margin_right);
} # end of _revise_baseline()

# just something to pause during debugging
sub _pause {
    print STDERR "====> Press Enter key to continue...";
    my $input = <>;
    return;
}

=head4 init_state()

See L<PDF::Builder> for code and L<PDF::Builder::Content::Column_docs> 
for documentation.

=cut

=head4 pass_start_state()

See L<PDF::Builder> for code and L<PDF::Builder::Content::Column_docs>
for documentation.

=head4 pass_end_state()

See L<PDF::Builder::Content::Column_docs> for documentation.

=cut

sub pass_end_state {
    my ($self, $pass_count, $max_passes, $pdf, $state, %opts) = @_;
    # $state = ref to %state structure

    my $rc = scalar(keys %{$state->{'changed_target'}}); 
        # length of changed_target key list

    # are we either clear to finish, or at max number of passes? if so,
    # output all annotations. each page should have its complete text already,
    # as well as a record of the annotations in %state

    if (!$rc || $pass_count == $max_passes) {
	# where to put UL corner of target window relative to target text
        my $delta_x = 20; # 20pt to LEFT
	my $delta_y = 20;
	if (defined $opts{'deltas'} && ref($opts{'deltas'}) eq 'ARRAY') {
	    my @deltas = @{ $opts{'deltas'} };
	    if (@deltas == 2) {
		$delta_x = $deltas[0];
		$delta_y = $deltas[1];
	    }
	}
	my @media_size = $pdf->mediabox(); # [0] min x, [3] max y

        # go through list of annotations to create at '_ref' tag links
	my $cur_src_page = 0; # minimize openings of source page. min valid 1
	my $cur_tgt_page = 0; # minimize openings of target page. min valid 1
	my ($src_page, $tgt_page); # opened page objects
	my $link_border;
	if (defined $opts{'debug'} && $opts{'debug'} == 1) {
	    # debug: draw border around link text
	    $link_border = [ 0, 0, 1 ]; 
        } else {
            # production: no border around link text
	    $link_border = [ 0, 0, 0 ];
	}

	for (my $source=0; $source<@{$state->{'xrefs'}}; $source++) {
	    my $sptr = $state->{'xrefs'}->[$source];
	    # source filename of target link (final name and position!)
	    my $tfn  = $sptr->{'tfn'};
	    # target's physical page number
	    my $tppn = $sptr->{'tppn'};
	    # source's physical page number
	    my $sppn = $sptr->{'sppn'};
	    # target's formatted page number is not of interest here (link
	    #  text already output, if includes fpn)
	   #my $tfpn = $sptr->{'tfpn'};
	    # target's tag that produced the entry is not of interest here
	   #my $ttag = $sptr->{'tag'};
	    # title is not of interest here (link text already output)
	   #my $title = $sptr->{'title'};
	    # other_pg is not of interest here (link text already output)
	   #my $other_pg = $sptr->{'other_pg'};
	    # target's x and y coordinates (for fit entry)
	    my $tx = $sptr->{'tx'};
	    my $ty = $sptr->{'ty'};
            # target id/ND/etc. information and fit
	    my $tid = $sptr->{'id'};
	    my $fit = $sptr->{'fit'};
		# if fit includes two % fields, replace by tx and ty
		# (for xyz fit: 'xyz,%x,%y,null')
		my $val = max(int($tx-$delta_x),$media_size[0]);
		$fit =~ s/%x/$val/;
		$val = min(int($ty+$delta_y),$media_size[3]);
		$fit =~ s/%y/$val/;
	        # replace any 'undef' by 'null' in $fit
	        $fit =~ s/undef/null/g;

	    # list of pairs of source physical page number and annot rectangle
	    #  coordinates, to place link at. usually one per link, but
	    #  sometimes 2 or more due to wrapping
	    my @links = @{ $sptr->{'click'} };
	    for (my $click=0; 
		    $click<@links; # most often, 1
		    $click++) {
	        # usually only one click area to place an annotation in, but 
		#  could spread over two or more lines, and even into the
		#  next column (or page). annotation click area to be placed
		#  in page object $src_page at coordinates $rect
		my @next_click_area = @{ $links[$click] };
		my $sppn = $next_click_area[0];
                if ($sppn != $cur_src_page) {
                    $src_page = $pdf->openpage($sppn);
		    $cur_src_page = $sppn;
		}
		# click area corners [ULx,y, LRx,y]
		my $rect = $next_click_area[1];  # leave as pointer
		my $annot = $src_page->annotation();

		# three flavors of 'tid':
                if      ($tid =~ /^#[^#]/) {
	            # physical page number target, may be internal or external
		    # reuse $tppn since explicitly giving
		    $tppn = substr($tid, 1);
                    # have target file (if ext) and physical page number
		    $fit = 'fit' if $fit eq ''; # default show whole page
		    if ($tfn eq '') {
		        # internal link to page object at $tx,$ty fit
                        if ($tppn != $cur_tgt_page) {
                            $tgt_page = $pdf->openpage($tppn);
			    $cur_tgt_page = $tppn;
		        }
			$annot->goto($tgt_page, 
				     (split /,/, $fit), 
				     'rect'=>$rect, 'border'=>$link_border);
		    } else {
		        # external link to physical page
			$annot->pdf($tfn, $tppn,
				    (split /,/, $fit), 
				    'rect'=>$rect, 'border'=>$link_border);
		    }

	        } elsif ($tid =~ /^##/) {
		    # Named Destination given (ignore 'fit' if given)
		    # external if filepath not ''
		    my $nd = substr($tid, 1);
		    if ($tfn eq '') {
		        # internal link to named destination
			$annot->goto($nd,
				     'rect'=>$rect, 'border'=>$link_border);
		    } else {
		        # external link to named destination
			$annot->pdf($tfn, $nd,
				    'rect'=>$rect, 'border'=>$link_border);
		    }

	        } else {
		    # id defined elsewhere, at $tgt_page from target
		    if ($fit eq '') {
		        # default fit is xyz x-$delta_x,y+$delta_y,undef
		        # x,y from location of target on page
		        $fit = "xyz,".max(int($tx)-$delta_x,$media_size[0]).",".
		                      min(int($ty)+$delta_y,$media_size[3]).",null";
		    }
		    # internal link to page object at $tx,$ty fit
                    # skip if Named Destination instead of a phys page no
		    if ($tppn =~ m/^\d+$/ && $tppn != $cur_tgt_page) {
                        $tgt_page = $pdf->openpage($tppn);
		        $cur_tgt_page = $tppn;
		    }
		    $annot->goto($tgt_page, 
			         (split /,/, $fit), 
			         'rect'=>$rect, 'border'=>$link_border);
                }
	    } # have gone through one or more click areas to create for this
	      #  one link
	} # done looping through all the requested annotations in xrefs
	    
        # output any named destinations defined
	my $ptr = $state->{'nameddest'};
	foreach my $name (keys %$ptr) {
	    my $fit = $ptr->{$name}{'fit'};
	    my $ppn = $ptr->{$name}{'ppn'};
	    my $x   = $ptr->{$name}{'x'};
	    my $y   = $ptr->{$name}{'y'};

	    # if no fit given, set to xyz,x-$delta_x,y+$delta_y,undef
	    if ($fit eq '') {
		$fit = "xyz,".max(int($x)-$delta_x,$media_size[0]).",".
		              min(int($y)+$delta_y,$media_size[3]).",null";
	    }
	    # if $x and $y in fit, replace with integer values
	    my $val = max(int($x)-$delta_x,$media_size[0]);
	    $fit =~ s/\$x/$val/;
	    $val = min(int($y)+$delta_y,$media_size[3]);
	    $fit =~ s/\$y/$val/;
            my @fits = ();
	    @fits = split /,/, $fit;
	    for (my $i=0; $i<@fits; $i++) {
		# if the user specified a fit with 'undef' (string) parms
		if ($fits[$i] eq 'undef') { $fits[$i] = 'null'; }
	    }
            my $dest = PDF::Builder::NamedDestination->new($pdf);
	    my $page = $pdf->openpage($ppn);
	    $dest->goto($page, @fits);
	    $pdf->named_destination('Dests', $name, $dest);
	}

    } # end of outputting annotations and named destinations

    return $rc;
}

# list target ids in state holder that are still changing
=head4 unstable_state()

See L<PDF::Builder::Content::Column_docs> for documentation

=cut

sub unstable_state {
    my ($self, $state) = @_;
    # $state = ref to %state structure

    my @list = sort(keys %{$state->{'changed_target'}});
    # would prefer target ids to be returned in order encountered, but
    # since no idea what order hash keys will be in, might as well sort
    # in alphabetical order
    return @list;  # hopefully empty at some point
}

# mytext array at element $el, extract full child text of this element
# may be sub tags and their own child text, all to be returned
#
# actually, all tags have already been removed and the overall text will
# now be a series of text and tags and their children (arbitrarily deep)
# e.g. <h2 id=target>This is <i>italic</i> text</h2> would be
#   tag=>'h2'
#     id=>'target'
#   tag=>''
#     text=>'This is '
#   tag=>'i'
#   tag=>''
#     text=>'italic'
#   tag=>'/i'
#   tag=>''
#     text=>' text'
#   tag=>'/h2'
# desired output: 'This is italic text'
#
# the big problem is to know what element to stop at (the end tag to
# $el element, not necessarily the next /tag, in case there's another 'tag'
# embedded within the child text)
# TBD: consider also copying tags (markup) within child text, to appear 
#       formatted in title (per _ref, and global, flag to flatten)

sub _get_child_text {
    my ($mytext, $el) = @_;

    my $output = '';
    my @tags = ($mytext->[$el]->{'tag'});
    for (my $elx=$el+1; ; $elx++) {
	# found end of this tag we seek child text from?
	if ($mytext->[$elx]->{'tag'} eq "/$tags[0]" && 
	    scalar(@tags)==1) { last; }
        # found some text in it? add to output
        if ($mytext->[$elx]->{'tag'} eq '') {
	    $output .= $mytext->[$elx]->{'text'};
	    next;
	}
	# an end tag? pop stack (assume properly nested!)
	if ($mytext->[$elx]->{'tag'} =~ /^\//) {
	    pop @tags;
	    next;
	}
        # must be another tag. push it on tag stack
	push @tags, $mytext->[$elx]->{'tag'};
    }

    # also convert line ends to blanks
    $output =~ s/\s+/ /sg;
    return $output;
} # end _get_child_text()

# similar to _get_child_text(), but goes through looking for special section
# AND trims out removed text from where it was found
#
# open text in a paragraph shouldn't have any special text, but
# we need to look at tag attributes (title= ), heading text, link
# child text, etc.
sub _get_special_info {
    my ($mytext, $el, $pattern, $endchar) = @_;

    my $newtext = '';
    my ($start, $end);

    my @tags = ($mytext->[$el]->{'tag'});
    for (my $elx=$el+1; $elx<@$mytext; $elx++) {
	# found end of this tag we seek child text from?
	if (@tags == 1 && $mytext->[$elx]->{'tag'} eq "/$tags[0]") { last; }
        # found some desired text in it? extract to output
        if ($mytext->[$elx]->{'tag'} eq '') {
	    # assume no tags within text
	    my $text = $mytext->[$elx]->{'text'};
            $start = index($text, $pattern);
            if ($start > -1) {
                # starting pattern found within text string
		$end = index($text, $endchar, $start+length($pattern));
		if ($end > -1) {
		    # ending pattern found within text string, after starting
		    $newtext = substr($text, $start+length($pattern),
			              $end-$start-length($pattern));

                    # now remove entire thing plus up to one space
		    $end += length($endchar)-1;
		    my $space_before = 0;
		    if ($start>0 && substr($text, $start-1, 1) eq ' ') {
			$space_before = 1;
		    }
		    my $space_after = 0;
		    if ($end < length($text)-1 &&
		        substr($text, $end+1, 1) eq ' ') {
			$space_after = 1;
		    }

		    if      ($start == 0) {
			# at far left
			if ($space_after) { $end++; }
			$text = substr($text, $end+1);
		    } elsif ($end == length($text)-1) {
			# at far right
			if ($space_before) { $start--; }
			$text = substr($text, 0, $start);
		    } elsif ($space_before && $space_after) {
			# in middle with one space to delete at either end
			$text = substr($text, 0, --$start) .
			        substr($text, $end+1);
		    } else {
			# in middle with no space after or no space after,
			# so preserve adjoining space
			$text = substr($text, 0, $start) .
			        substr($text, $end+1);
		    }
                }
	    }
	    $mytext->[$elx]->{'text'} = $text; # may be now empty
	    next; # should be only occurence, but still need to clean up
	}
	# an end tag? pop stack (assume properly nested!)
	if ($mytext->[$elx]->{'tag'} =~ /^\//) {
	    pop @tags;
	    next;
	}
        # must be another tag. push it on tag stack
	push @tags, $mytext->[$elx]->{'tag'};
    }

    # trim enclosure and leading and trailing whitespace off it
    $newtext =~ s/^$pattern\s+//;
    $newtext =~ s/\s+$endchar$//;
    return $newtext;
} # end _get_special_info()

# --------------------- end of column() section -----------------------------
1;
