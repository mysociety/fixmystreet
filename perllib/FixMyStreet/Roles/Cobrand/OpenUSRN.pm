package FixMyStreet::Roles::Cobrand::OpenUSRN;

use Moo::Role;

sub lookup_site_code {
    my $self = shift;
    my $row = shift;
    my $field = shift;

    my ($x, $y) = $row->local_coords;
    my $buffer = 50;
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $filter = "
    <ogc:Filter xmlns:ogc=\"http://www.opengis.net/ogc\">
        <ogc:And>
            <ogc:PropertyIsNotEqualTo>
                <ogc:PropertyName>street_type</ogc:PropertyName>
                <ogc:Literal>Numbered Street</ogc:Literal>
            </ogc:PropertyIsNotEqualTo>
            <ogc:BBOX>
                <ogc:PropertyName>geometry</ogc:PropertyName>
                <gml:Envelope xmlns:gml='http://www.opengis.net/gml' srsName='EPSG:27700'>
                    <gml:lowerCorner>$w $s</gml:lowerCorner>
                    <gml:upperCorner>$e $n</gml:upperCorner>
                </gml:Envelope>
                <Distance units='m'>50</Distance>
            </ogc:BBOX>
        </ogc:And>
    </ogc:Filter>";
    $filter =~ s/\n\s+//g;

    my $cfg = {
        url => FixMyStreet->config('STAGING_SITE') ? "https://tilma.staging.mysociety.org/mapserver/openusrn" : "https://tilma.mysociety.org/mapserver/openusrn",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => 'usrn',
        property => "usrn",
        filter => $filter,
        accept_feature => sub { 1 },
    };

    my $features = $self->_fetch_features($cfg);
    return $self->_nearest_feature($cfg, $x, $y, $features);
}

1;
