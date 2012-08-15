#!/usr/bin/env perl

BEGIN {    # set all the paths to the perl code
    use File::Basename qw(dirname);
    use File::Spec;
    my $d = dirname(File::Spec->rel2abs($0));
    require "$d/../setenv.pl";
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run( 'FixMyStreet::App', 'CGI' );

1;

=head1 NAME

fixmystreet_app_cgi.pl - Catalyst CGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as a cgi script.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

