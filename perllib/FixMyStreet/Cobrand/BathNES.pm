package FixMyStreet::Cobrand::BathNES;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub council_area_id { return 2551; }
sub council_area { return 'Bath and North East Somerset'; }
sub council_name { return 'Bath and North East Somerset Council'; }
sub council_url { return 'bathnes'; }

sub contact_email {
    my $self = shift;
    return join( '@', 'fixmystreet', 'bathnes.gov.uk' );
}
sub map_type { 'BathNES' }

sub example_places {
    return ( 'BA1 1JQ', "Lansdown Grove" );
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bath and North East Somerset';

    # The council have provided a list of common typos which we should correct:
    my %replacements = (
        "broom" => "brougham",
        "carnarvon" => "caernarvon",
        "cornation" => "coronation",
        "beafort" => "beaufort",
        "beechan" => "beechen",
        "malreword" => "malreward",
        "canyerberry"=> "canterbury",
        "clairemont"=> "claremont",
        "salsbury"=> "salisbury",
        "solsberry"=> "solsbury",
        "lawn road" => "lorne",
        "new road high littleton" => "danis house",
    );

    foreach my $original (keys %replacements) {
        my $replacement = $replacements{$original};
        $string =~ s/$original/$replacement/ig;
    }

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.3559192103294,-2.47522827137605',
        span   => '0.166437921041471,0.429359043406088',
        bounds => [ 51.2730478766607, -2.70792015294201, 51.4394857977022, -2.27856110953593 ],
        string => $string,
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires { 0 }

sub enable_category_groups { 1 }

sub default_show_name { 0 }

sub default_map_zoom { 3 }

sub map_js_extra {
    my ($self, $c) = @_;

    return unless $c->user_exists;

    my $banes_user = $c->user->from_body && $c->user->from_body->areas->{$self->council_area_id};
    if ( $banes_user || $c->user->is_superuser ) {
        return ['/cobrands/bathnes/staff.js'];
    }
}

sub category_extra_hidden {
    my ($self, $meta) = @_;
    $meta = $meta->{code};
    return 1 if $meta eq 'unitid' || $meta eq 'asset_details' || $meta eq 'site_code' || $meta eq 'central_asset_id';
    return 0;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    # Reports made via FMS.com or the app probably won't have a USRN
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $usrn = $self->lookup_usrn($row)) {
            push @$extra,
                { name => 'site_code',
                value => $usrn };
        }
    }

    $row->set_extra_fields(@$extra);
}

sub available_permissions {
    my $self = shift;

    my $permissions = $self->SUPER::available_permissions();

    $permissions->{Problems}->{report_reject} = "Reject reports";

    return $permissions;
}

sub report_sent_confirmation_email { 1 }

sub lookup_usrn {
    my $self = shift;
    my $row = shift;

    my $buffer = 5; # metres
    my ($x, $y) = $row->local_coords;
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $uri = URI->new("https://isharemaps.bathnes.gov.uk/getows.ashx");
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::27700",
        TYPENAME => "AdoptedHighways",
        VERSION => "1.1.0",
        mapsource => "BathNES/WFS",
        outputformat => "application/json",
        BBOX => "$w,$s,$e,$n"
    );

    my $response = get($uri);

    my $j = JSON->new->utf8->allow_nonref;
    try {
        $j = $j->decode($response);
        return $j->{features}->[0]->{properties}->{usrn};
    } catch {
        # There was either no asset found, or an error with the WFS
        # call - in either case let's just proceed without the USRN.
        return;
    }

}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a location in ' . $self->council_area;
}


1;
