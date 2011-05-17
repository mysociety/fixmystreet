package FixMyStreet::Cobrand::EmptyHomes;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

use FixMyStreet;
use mySociety::Locale;
use Carp;

=item

Return the base url for this cobranded site

=cut

sub base_url {
    my $base_url = FixMyStreet->config('BASE_URL');
    if ( $base_url !~ /emptyhomes/ ) {
        $base_url =~ s/http:\/\//http:\/\/emptyhomes\./g;
    }
    return $base_url;
}

sub admin_base_url {
    return 'https://secure.mysociety.org/admin/emptyhomes/';
}

sub area_types {
    return qw(DIS LBO MTD UTA LGD COI);    # No CTY
}

=item set_lang_and_domain LANG UNICODE

Set the language and text domain for the site based on the query and host. 

=cut

sub set_lang_and_domain {
    my ( $self, $lang, $unicode, $dir ) = @_;
    my $set_lang = mySociety::Locale::negotiate_language(
        'en-gb,English,en_GB|cy,Cymraeg,cy_GB', $lang );
    mySociety::Locale::gettext_domain( 'FixMyStreet-EmptyHomes', $unicode,
        $dir );
    mySociety::Locale::change();
    return $set_lang;
}

=item site_title

Return the title to be used in page heads

=cut 

sub site_title {
    my ($self) = @_;
    return _('Report Empty Homes');
}

=item feed_xsl

Return the XSL file path to be used for feeds'

=cut

sub feed_xsl {
    my ($self) = @_;
    return '/xsl.eha.xsl';
}

=item shorten_recency_if_new_greater_than_fixed

For empty homes we don't want to shorten the recency

=cut

sub shorten_recency_if_new_greater_than_fixed {
    return 0;
}

=head2 generate_problem_banner

    my $banner = $c->cobrand->generate_problem_banner;

    <p id="[% banner.id %]:>[% banner.text %]</p>

Generate id and text for banner that appears at top of problem page.

=cut

sub generate_problem_banner {
    my ( $self, $problem ) = @_;

    my $banner = {};
    if ($problem->state eq 'fixed') {
        $banner->{id} = 'fixed';
        $banner->{text} = _('This problem has been fixed') . '.';
    }

    return $banner;
}

1;

