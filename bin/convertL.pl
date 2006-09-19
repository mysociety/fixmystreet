#!/usr/bin/perl -w

# convertL.pl:
# Out of date tile conversion
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

use strict;

my @squares = (
    '', '', '', '', 'HP', '', '',
    '', '', '', 'HT', 'HU', '', '',
    '', 'HW', 'HX', 'HY', 'HZ', '', '',
    'NA', 'NB', 'NC', 'ND', '', '', '',
    'NF', 'NG', 'NH', 'NJ', 'NK', '', '',
    'NL', 'NM', 'NN', 'NO', '', '', '', 
    '', 'NR', 'NS', 'NT', 'NU', '', '',
    '', 'NW', 'NX', 'NY', 'NZ', 'OV', '',
    '', '', 'SC', 'SD', 'SE', 'TA', '',
    '', '', 'SH', 'SJ', 'SK', 'TF', 'TG',
    '', 'SM', 'SN', 'SO', 'SP', 'TL', 'TM',
    '', 'SR', 'SS', 'ST', 'SU', 'TQ', 'TR',
    'SV', 'SW', 'SX', 'SY', 'SZ', 'TV', '');

my %squares;
my $i = 0;
foreach my $square (@squares) {
    $squares{$square} = $i if $square;
    $i++;
}

print "Converting TIF to PNGs...\n";
for (</home/tom/25k/BaseMap/*.TIF>) {
    /(S[Q-Z]\d+).TIF$/ or next;
    my $name = $1;
    unless (-e "$name-0.png") {
        print "  $_\n";
        `convert $_ -crop 250x250 tl/$name.png`;
    }
}
print "Renaming PNGs...\n";
for (<tl/*.png>) {
    /^tl\/(..)(\d+)-(\d+)\.png$/ or next;
    print "  $_\n";
    my $square = $1;
    $square = $squares{$square};
    my $square_row = int($square/7);
    my $square_col = $square%7;
    my $parta = $2;
    my $parta_col = int($parta/10);
    my $parta_row = 9 - $parta%10;
    my $partb = $3;
    my $partb_row = int($partb/16);
    my $partb_col = $partb%16;
    
    my $out_col = ($square_col*10+$parta_col)*16+$partb_col;
    my $out_row = ($square_row*10+$parta_row)*16+$partb_row;
#    print "$_ $out_col x $out_row\n";
    system("mv $_ tl/$out_col.$out_row.png");
}
print "Done.\n";
