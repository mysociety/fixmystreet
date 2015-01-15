#!/usr/bin/env perl

BEGIN {
    use File::Basename qw(dirname);
    use File::Spec;
    my $d = dirname(File::Spec->rel2abs($0));
    require "$d/../setenv.pl";
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('FixMyStreet::App', 'Test');

1;

=head1 NAME

fixmystreet_app_test.pl - Catalyst Test

=head1 SYNOPSIS

fixmystreet_app_test.pl [options] uri

 Options:
   --help    display this help and exits

 Examples:
   fixmystreet_app_test.pl http://localhost/some_action
   fixmystreet_app_test.pl /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the command line.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
