package FixMyStreet::Cobrand::EmptyHomes;
use base 'FixMyStreet::Cobrand::UK';

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
    [ 'DIS', 'LBO', 'MTD', 'UTA', 'LGD', 'COI' ]; # No CTY
}


sub base_url_with_lang {
    my $self = shift;

    my $base = $self->base_url;

    my $lang = $mySociety::Locale::lang;
    if ($lang eq 'cy') {
        $base =~ s{http://}{$&cy.};
    } else {
        $base =~ s{http://}{$&en.};
    }
    return $base;
}

sub languages { [ 'en-gb,English,en_GB', 'cy,Cymraeg,cy_GB' ] }
sub language_domain { 'FixMyStreet-EmptyHomes' }

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
    my $c            = shift;

    my %councils = map { $_ => 1 } @{$self->area_types};

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
        uri       => $c->uri_for( '/rss/reports/' . $council->{short_name} ),
    };
    push @options, {
        type     => 'ward',
        id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
        rss_text => sprintf( _('RSS feed of problems within %s ward'), $ward->{name}),
        text     => sprintf( _('Problems within %s ward'), $ward->{name}),
        uri      => $c->uri_for( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
    };

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

1;

