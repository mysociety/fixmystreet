package Devel::Cover::Report::Codecov;
use strict;
use warnings;
use utf8;
our $VERSION = '0.25';

use JSON::XS;

sub report {
    my ($pkg, $db, $options) = @_;

    my $json  = get_codecov_json($options->{file}, $db);

    open(FP, '>coverage.json') or warn $!;
    print FP $json;
    close FP;
}

sub get_file_lines {
    my ($file) = @_;

    my $lines = 0;

    open my $fp, '<', $file;
    $lines++ while <$fp>;
    close $fp;

    return $lines;
}

sub get_file_coverage {
    my ($filepath, $db) = @_;

    my $realpath   = get_file_realpath($filepath);
    my $lines      = get_file_lines($realpath);
    my $file       = $db->cover->file($filepath);
    my $statements = $file->statement;
    my $branches   = $file->branch;
    my @coverage   = (undef);

    for (my $i = 1; $i <= $lines; $i++) {
        my $statement = $statements->location($i);
        my $branch    = defined $branches ? $branches->location($i) : undef;
        push @coverage, get_line_coverage($statement, $branch);
    }

    return $realpath => \@coverage;
}

sub get_line_coverage {
    my ($statement, $branch) = @_;

    # If all branches covered or uncoverable, report as all covered
    return $branch->[0]->total.'/'.$branch->[0]->total if $branch && !$branch->[0]->error;
    return $branch->[0]->covered.'/'.$branch->[0]->total if $branch;
    return $statement unless $statement;
    return if $statement->[0]->uncoverable;
    return $statement->[0]->covered;
}

sub get_file_realpath {
    my $file = shift;

    if (-d 'blib') {
        my $realpath = $file;
        $realpath =~ s/blib\/lib/lib/;

        return $realpath if -f $realpath;
    }

    return $file;
}

sub get_codecov_json {
    my ($files, $db) = @_;

    my %coverages = map { get_file_coverage($_, $db) } @$files;
    my $request   = { coverage => \%coverages, messages => {} };

    return encode_json($request);
}

1;
__END__

=encoding utf-8

=head1 NAME

Devel::Cover::Report::Codecov - Backend for Codecov reporting of coverage statistics

=head1 SYNOPSIS

    $ cover -report codecov

=head1 DESCRIPTION

Devel::Cover::Report::Codecov is coverage reporter for L<Codecov|https://codecov.io>.

=head1 SEE ALSO

=over 4

=item * L<Devel::Cover>

=back

=head1 LICENSE

The MIT License (MIT)

Copyright (c) 2015-2019 Pine Mizune

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=head1 AUTHOR

Pine Mizune E<lt>pinemz@gmail.comE<gt>

=cut

