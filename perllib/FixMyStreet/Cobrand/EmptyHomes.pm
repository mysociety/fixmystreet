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


sub base_url_with_lang {
    my $self = shift;
    my $email = shift;

    my $base = $self->base_url;

    if ($email) {
        $base = $self->base_url_for_emails;
    }

    my $lang = $mySociety::Locale::lang;
    if ($lang eq 'cy') {
        $base =~ s{http://}{$&cy.};
    } else {
        $base =~ s{http://}{$&en.};
    }
    return $base;
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

=head2 default_photo_resize

Size that photos are to be resized to for display. If photos aren't
to be resized then return 0;

=cut

sub default_photo_resize { return '195x'; }

=item council_rss_alert_options

Generate a set of options for council rss alerts. 

=cut

sub council_rss_alert_options {
    my $self = shift;
    my $all_councils = shift;

    my %councils = map { $_ => 1 } $self->area_types();

    my $num_councils = scalar keys %$all_councils;

    my ( @options, @reported_to_options );
    my ($council, $ward);
    foreach (values %$all_councils) {
        $_->{short_name} = $self->short_name( $_ );
        ( $_->{id_name} = $_->{short_name} ) =~ tr/+/_/;
        if ($councils{$_->{type}}) {
            $council = $_;
        } else {
            $ward = $_;
        }
    }

    push @options, {
        type      => 'council',
        id        => sprintf( 'council:%s:%s', $council->{id}, $council->{id_name} ),
        text      => sprintf( _('Problems within %s'), $council->{name}),
        rss_text  => sprintf( _('RSS feed of problems within %s'), $council->{name}),
        uri       => $self->uri( '/rss/reports/' . $council->{short_name} ),
    };
    push @options, {
        type     => 'ward',
        id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
        rss_text => sprintf( _('RSS feed of problems within %s ward'), $ward->{name}),
        text     => sprintf( _('Problems within %s ward'), $ward->{name}),
        uri      => $self->uri( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
    };

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

1;

