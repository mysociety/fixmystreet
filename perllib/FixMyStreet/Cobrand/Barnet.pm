package FixMyStreet::Cobrand::Barnet;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2489; }
sub council_area { return 'Barnet'; }
sub council_name { return 'Barnet Council'; }
sub council_url { return 'barnet'; }
sub all_reports_style { return 'detailed'; }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Barnet',
        centre => '51.612832,-0.218169',
        span   => '0.0563,0.09',
        bounds => [ '51.584682,-0.263169', '51.640982,-0.173169' ],
    };
}

sub generate_problem_banner {
    my ( $self, $problem ) = @_;

    my $banner = {};
    if ( $problem->is_open && time() - $problem->lastupdate_local->epoch > 8 * 7 * 24 * 60 * 60 )
    {
        $banner->{id}   = 'unknown';
        $banner->{text} = _('Unknown');
    }
    if ($problem->is_fixed) {
        $banner->{id} = 'fixed';
        $banner->{text} = _('Fixed');
    }
    if ($problem->is_closed) {
        $banner->{id} = 'closed';
        $banner->{text} = _('Closed');
    }

    if ( grep { $problem->state eq $_ } ( 'investigating', 'in progress', 'planned' ) ) {
        $banner->{id} = 'progress';
        $banner->{text} = _('In progress');
    }

    return $banner;
}

sub council_rss_alert_options {
  my $self = shift;
  my $all_councils = shift;
  my $c            = shift;

  my %councils = map { $_ => 1 } $self->area_types();

  my $num_councils = scalar keys %$all_councils;

  my ( @options, @reported_to_options );
  if ( $num_councils == 1 or $num_councils == 2 ) {
    my ($council, $ward);
    foreach (values %$all_councils) {
        if ($councils{$_->{type}}) {
            $council = $_;
            $council->{short_name} = $self->short_name( $council );
            ( $council->{id_name} = $council->{short_name} ) =~ tr/+/_/;
        } else {
            $ward = $_;
            $ward->{short_name} = $self->short_name( $ward );
            ( $ward->{id_name} = $ward->{short_name} ) =~ tr/+/_/;
        }
    }

    push @options,
      {
        type      => 'council',
        id        => sprintf( 'council:%s:%s', $council->{id}, $council->{id_name} ),
        text      => 'All problems within the council.',
        rss_text  => sprintf( _('RSS feed of problems within %s'), $council->{name}),
        uri       => $c->uri_for( '/rss/reports/' . $council->{short_name} ),
      };
    push @options,
      {
        type     => 'ward',
        id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
        rss_text => sprintf( _('RSS feed of problems within %s ward'), $ward->{name}),
        text     => sprintf( _('Problems within %s ward'), $ward->{name}),
        uri      => $c->uri_for( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
      } if $ward;
    }

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

sub example_places {
    return [ 'N11 1NP', 'Wood St' ];
}
1;

