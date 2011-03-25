package FixMyStreet::TestMech;
use base qw(Test::WWW::Mechanize::Catalyst);

use strict;
use warnings;

use Test::WWW::Mechanize::Catalyst 'FixMyStreet::App';

use Test::More;
use Web::Scraper;

=head1 NAME

FixMyStreet::TestMech - T::WWW::M:C but with FMS specific smarts

=head1 DESCRIPTION

This module subclasses L<Test::WWW::Mechanize::Catalyst> and adds some
FixMyStreet specific smarts - such as the ability to scrape the resulting page
for form error messages.

=head1 METHODS

=head2 form_errors

    my $arrayref = $mech->form_errors;

Find all the form errors on the current page and return them in page order as an
arrayref of TEXTs. If none found return empty arrayref.

=cut

sub form_errors {
    my $mech   = shift;
    my $result = scraper {
        process 'div.form-error', 'errors[]', 'TEXT';
    }
    ->scrape( $mech->response );
    return $result->{errors} || [];
}

=head2 pc_alternatives

    my $arrayref = $mech->pc_alternatives;

Find all the suggestions for near matches for a location. Return text presented to user as arrayref, empty arrayref if none found.

=cut

sub pc_alternatives {
    my $mech   = shift;
    my $result = scraper {
        process 'ul.pc_alternatives li', 'pc_alternatives[]', 'TEXT';
    }
    ->scrape( $mech->response );
    return $result->{pc_alternatives} || [];
}

=head2 extract_location

    $hashref = $mech->extract_location(  );

Extracts the location from the current page. Looks for inputs with the names
C<pc>, C<latitude> and C<longitude> and returns their values in a hashref with
those keys. If no values found then the values in hashrof are C<undef>.

=cut

sub extract_location {
    my $mech = shift;

    my $result = scraper {
        process 'input[name="pc"]',        pc        => '@value';
        process 'input[name="latitude"]',  latitude  => '@value';
        process 'input[name="longitude"]', longitude => '@value';
    }
    ->scrape( $mech->response );

    return {
        pc        => undef,
        latitude  => undef,
        longitude => undef,
        %$result
    };
}

1;
