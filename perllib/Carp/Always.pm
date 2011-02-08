
package Carp::Always;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.09';

use Carp qw(verbose); # makes carp() cluck and croak() confess

sub _warn {
  if ($_[-1] =~ /\n$/s) {
    my $arg = pop @_;
    $arg =~ s/ at .*? line .*?\n$//s;
    push @_, $arg;
  }
  warn &Carp::longmess;
}

sub _die {
  if ($_[-1] =~ /\n$/s) {
    my $arg = pop @_;
    $arg =~ s/ at .*? line .*?\n$//s;
    push @_, $arg;
  }
  die &Carp::longmess;
}

my %OLD_SIG;

BEGIN {
  @OLD_SIG{qw(__DIE__ __WARN__)} = @SIG{qw(__DIE__ __WARN__)};
  $SIG{__DIE__} = \&_die;
  $SIG{__WARN__} = \&_warn;
}

END {
  @SIG{qw(__DIE__ __WARN__)} = @OLD_SIG{qw(__DIE__ __WARN__)};
}

1;
__END__

=head1 NAME

Carp::Always - Warns and dies noisily with stack backtraces

=head1 SYNOPSIS

  use Carp::Always;

makes every C<warn()> and C<die()> complains loudly in the calling package 
and elsewhere. More often used on the command line:

  perl -MCarp::Always script.pl

=head1 DESCRIPTION

This module is meant as a debugging aid. It can be 
used to make a script complain loudly with stack backtraces 
when warn()ing or die()ing.

Here are how stack backtraces produced by this module
looks:

  # it works for explicit die's and warn's
  $ perl -MCarp::Always -e 'sub f { die "arghh" }; sub g { f }; g'
  arghh at -e line 1
          main::f() called at -e line 1
          main::g() called at -e line 1

  # it works for interpreter-thrown failures
  $ perl -MCarp::Always -w -e 'sub f { $a = shift; @a = @$a };' \
                           -e 'sub g { f(undef) }; g'
  Use of uninitialized value in array dereference at -e line 1
          main::f('undef') called at -e line 2
          main::g() called at -e line 2

In the implementation, the C<Carp> module does
the heavy work, through C<longmess()>. The
actual implementation sets the signal hooks
C<$SIG{__WARN__}> and C<$SIG{__DIE__}> to
emit the stack backtraces.

Oh, by the way, C<carp> and C<croak> when requiring/using
the C<Carp> module are also made verbose, behaving
like C<cloak> and C<confess>, respectively.

=head2 EXPORT

Nothing at all is exported.

=head1 ACKNOWLEDGMENTS

This module was born as a reaction to a release
of L<Acme::JavaTrace> by Sébastien Aperghis-Tramoni.
Sébastien also has a newer module called
L<Devel::SimpleTrace> with the same code and fewer flame
comments on docs. The pruning of the uselessly long
docs of this module were prodded by Michael Schwern.

Schwern and others told me "the module name stinked" -
it was called C<Carp::Indeed>. After thinking long
and not getting nowhere, I went with nuffin's suggestion
and now it is called C<Carp::Always>. 
C<Carp::Indeed> which is now deprecate
lives in its own distribution (which won't go anywhere
but will stay there as a redirection to this module).

=head1 SEE ALSO

=over 4

=item *

L<Carp>

=item *

L<Acme::JavaTrace> and L<Devel::SimpleTrace>

=back

Please report bugs via CPAN RT 
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Carp-Always.

=head1 BUGS

Every (un)deserving module has its own pet bugs.

=over 4

=item *

This module does not play well with other modules which fusses
around with C<warn>, C<die>, C<$SIG{'__WARN__'}>,
C<$SIG{'__DIE__'}>.

=item *

Test scripts are good. I should write more of these.

=item *

I don't know if this module name is still a bug as it was
at the time of C<Carp::Indeed>.

=back

=head1 AUTHOR

Adriano Ferreira, E<lt>ferreira@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2007 by Adriano R. Ferreira

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
