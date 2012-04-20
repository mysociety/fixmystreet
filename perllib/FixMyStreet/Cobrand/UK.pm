package FixMyStreet::Cobrand::UK;
use base 'FixMyStreet::Cobrand::Default';

use mySociety::VotingArea;

sub country             { return 'GB'; }
sub area_types          { return qw(DIS LBO MTD UTA CTY COI); }
sub area_types_children { return @$mySociety::VotingArea::council_child_types }
sub area_min_generation { 10 }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _("Enter a nearby GB postcode, or street name and area");
}

sub disambiguate_location {
    return {
        country => 'gb',
        google_country => 'uk',
        bing_culture => 'en-GB',
        bing_country => 'United Kingdom'
    };
}

sub get_council_sender {
    my ( $self, $area_id, $area_info ) = @_;

    my $send_method;

    my $council_config = FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $area_id } )->first;
    $send_method = $council_config->send_method if $council_config;

    return $send_method if $send_method;

    return 'London' if $area_info->{type} eq 'LBO';

    return 'Email';
}

sub process_extras {
    my $self    = shift;
    my $ctx     = shift;
    my $area_id = shift;
    my $extra   = shift;
    my $fields  = shift || [];

    if ( $area_id == 2482 ) {
        my @fields = ( 'fms_extra_title', @$fields );
        for my $field ( @fields ) {
            my $value = $ctx->request->param( $field );

            if ( !$value ) {
                $ctx->stash->{field_errors}->{ $field } = _('This information is required');
            }
            push @$extra, {
                name => $field,
                description => uc( $field),
                value => $value || '',
            };
        }

        if ( $ctx->request->param('fms_extra_title') ) {
            $ctx->stash->{fms_extra_title} = $ctx->request->param('fms_extra_title');
            $ctx->stash->{extra_name_info} = 1;
        }
    }
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if ($s =~ /^\d+$/) {
        return {
            error => 'FixMyStreet is a UK-based website that currently works in England, Scotland, and Wales. Please enter either a postcode, or a Great British street name and area.'
        };
    } elsif (mySociety::PostcodeUtil::is_valid_postcode($s)) {
        my $location = mySociety::MaPit::call('postcode', $s);
        if ($location->{error}) {
            return {
                error => $location->{code} =~ /^4/
                    ? _('That postcode was not recognised, sorry.')
                    : $location->{error}
            };
        }
        my $island = $location->{coordsyst};
        if (!$island) {
            return {
                error => _("Sorry, that appears to be a Crown dependency postcode, which we don't cover.")
            };
        } elsif ($island eq 'I') {
            return {
                error => _("We do not currently cover Northern Ireland, I'm afraid.")
            };
        }
        return {
            latitude  => $location->{wgs84_lat},
            longitude => $location->{wgs84_lon},
        };
    }
    return {};
}

sub remove_redundant_councils {
  my $self = shift;
  my $all_councils = shift;

  # Ipswich & St Edmundsbury are responsible for everything in their
  # areas, not Suffolk
  delete $all_councils->{2241}
    if $all_councils->{2446}    #
        || $all_councils->{2443};

  # Norwich is responsible for everything in its areas, not Norfolk
  delete $all_councils->{2233}    #
    if $all_councils->{2391};
}

sub short_name {
  my $self = shift;
  my ($area, $info) = @_;
  # Special case Durham as it's the only place with two councils of the same name
  return 'Durham+County' if $area->{name} eq 'Durham County Council';
  return 'Durham+City' if $area->{name} eq 'Durham City Council';

  my $name = $area->{name};
  $name =~ s/ (Borough|City|District|County) Council$//;
  $name =~ s/ Council$//;
  $name =~ s/ & / and /;
  $name =~ s{/}{_}g;
  $name = URI::Escape::uri_escape_utf8($name);
  $name =~ s/%20/+/g;
  return $name;

}

1;

