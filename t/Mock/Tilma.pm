package t::Mock::Tilma;

use JSON::MaybeXS;
use Web::Simple;
use mySociety::Locale;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->utf8->pretty->allow_blessed->convert_blessed;
    },
);

sub as_json {
    my ($self, $features) = @_;
    my $json = mySociety::Locale::in_gb_locale {
        $self->json->encode({
            type => "FeatureCollection",
            crs => { type => "name", properties => { name => "urn:ogc:def:crs:EPSG::27700" } },
            features => $features,
        });
    };
    return $json;
}

sub dispatch_request {
    my $self = shift;

    sub (GET + /alloy/layer.php + ?*) {
        my ($self, $args) = @_;
        my $features = [];
        if (
            $args->{url} eq 'https://buckinghamshire.staging'
            && $args->{layer} eq 'designs_highwaysNetworkAsset_62d68698e5a3d20155f5831d'
            && $args->{bbox} eq '-0.830314942133343,51.8104703988955,-0.824420654281584,51.8140082035939'
        ) {
            $features = [
                {
                    type => "Feature",
                    geometry => {
                        type => "MultiLineString",
                        coordinates => [
                            [
                                [
                                    -0.8271352889663803,
                                    51.81223799453361
                                ],
                                [
                                    -0.8292204779165135,
                                    51.81274102101397
                                ]
                            ]
                        ]
                    },
                    properties => {
                        itemId => "62d6e394942fae016cae1124",
                        usrn => "01401076",
                        title => " FOWLER ROAD - 01401076",
                        feature_ty => "3B"
                    }
                },
                {
                    type => "Feature",
                    geometry => {
                        type => "MultiLineString",
                        coordinates => [
                            [
                                [
                                    -0.8301593482038864,
                                    51.813671000615024
                                ],
                                [
                                    -0.8288245117326856,
                                    51.813136003982514
                                ]
                            ]
                        ]
                    },
                    properties => {
                        itemId => "62d6e394942fae016cae1246",
                        usrn => "01401222",
                        title => " MASONS COURT - 01401222",
                        feature_ty => "4B"
                    }
                }
            ];
        }
        my $json = $self->as_json($features);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /proxy/bucks_prow/wfs/ + ?*) {
        my ($self, $args) = @_;
        my $features = [];
        my $out = <<FEATURE;
<wfs:FeatureCollection
   xmlns:ms="http://mapserver.gis.umn.edu/mapserver"
   xmlns:gml="http://www.opengis.net/gml"
   xmlns:wfs="http://www.opengis.net/wfs">
FEATURE
        if ($args->{TYPENAME} eq 'RouteWFS') {
            $out .= <<FEATURE;
<gml:featureMember>
<ms:RouteWFS>
<ms:msGeometry>
<gml:LineString srsName="EPSG:27700">
<gml:posList srsDimension="2">484232.512000 220244.945000 484260.047000 220241.346000 484290.051000 220231.889000 484324.392000 220223.081000 484366.318000 220212.804000 484409.267000 220202.497000 484426.594000 220197.527000 484446.839000 220191.060000 484472.382000 220186.052000 484490.818000 220181.483000 484512.697000 220176.254000 484535.996000 220171.189000 484553.216000 220166.124000 484572.217000 220160.637000 484592.723000 220153.969000 484611.333000 220149.240000 484632.366000 220143.772000 484646.830000 220141.587000 484657.943000 220140.529000 484668.963000 220139.144000 484678.201000 220141.342000 484685.309000 220145.649000 484687.462000 220147.803000 484700.600000 220135.527000 </gml:posList>
</gml:LineString>
</ms:msGeometry>
<ms:RouteCode>AAB/1/1</ms:RouteCode>
<ms:AdminArea>AAB</ms:AdminArea>
<ms:LinkType>1</ms:LinkType>
</ms:RouteWFS>
</gml:featureMember>
FEATURE
        }
        $out .= '</wfs:FeatureCollection>';
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $out ] ];
    },

    sub (GET + /mapserver/tfl + ?*) {
        my ($self, $args) = @_;
        my $features = [];
        if ($args->{Filter} =~ /540512,169141|534371,185488/) {
            $features = [
                { type => "Feature", properties => { HA_ID => "19" }, geometry => { type => "Polygon", coordinates => [ [
                    [ 539408.94, 170607.58 ],
                    [ 539432.81, 170627.93 ],
                    [ 539437.24, 170623.48 ],
                    [ 539408.94, 170607.58 ],
                ] ] } } ];
        }
        my $json = $self->as_json($features);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /mapserver/highways + ?*) {
        my ($self, $args) = @_;
        my $json = $self->as_json([]);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /mapserver/brent + ?*) {
        my ($self, $args) = @_;
        my $header = '<?xml version="1.0" encoding="UTF-8" ?>
<wfs:FeatureCollection
   xmlns:ms="http://mapserver.gis.umn.edu/mapserver"
   xmlns:gml="http://www.opengis.net/gml"
   xmlns:wfs="http://www.opengis.net/wfs"
   xmlns:ogc="http://www.opengis.net/ogc">';

        if ($args->{Filter} =~ /519730,186383/) {
            return [ 200, [ 'Content-Type' => 'application/xml' ], [ $header .
  '<gml:featureMember>
    <ms:Housing>
      <ms:site_name>Some houses</ms:site_name>
    </ms:Housing>
  </gml:featureMember>
</wfs:FeatureCollection>'
            ] ];
        } elsif ($args->{Filter} =~ /519515,186474/) {
            return [ 200, [ 'Content-Type' => 'application/xml' ], [ $header .
  '<gml:featureMember>
    <ms:Parks_and_Open_Spaces>
      <ms:site_name>King Edward VII Park, Wembley</ms:site_name>
    </ms:Parks_and_Open_Spaces>
  </gml:featureMember>
</wfs:FeatureCollection>'
            ] ];
        } else {
            return [ 200, [ 'Content-Type' => 'application/xml' ], [ $header .
'</wfs:FeatureCollection>'
            ] ];
        }
    },

    sub (GET + /mapserver/thamesmead + ?*) {
        my ($self, $args) = @_;

        my $thamesmead_asset_found = '<?xml version=\'1.0\' encoding="UTF-8" ?>
   <wfs:FeatureCollection
   xmlns:ms="http://mapserver.gis.umn.edu/mapserver"
   xmlns:gml="http://www.opengis.net/gml"
   xmlns:wfs="http://www.opengis.net/wfs"
   xmlns:ogc="http://www.opengis.net/ogc"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://mapserver.gis.umn.edu/mapserver https://tilma.staging.mysociety.org:80/mapserver/thamesmead?SERVICE=WFS&amp;VERSION=1.1.0&amp;REQUEST=DescribeFeatureType&amp;TYPENAME=grass&amp;OUTPUTFORMAT=SFE_XMLSCHEMA  http://www.opengis.net/wfs http://schemas.opengis.net/wfs/1.1.0/wfs.xsd">
      <gml:boundedBy>
      	<gml:Envelope srsName="EPSG:27700">
      		<gml:lowerCorner>547547.098266 181365.400053</gml:lowerCorner>
      		<gml:upperCorner>548048.231804 181488.319418</gml:upperCorner>
      	</gml:Envelope>
      </gml:boundedBy>
    <gml:featureMember>
      <ms:grass gml:id="grass.1000.000000000000000">
        <gml:boundedBy>
        	<gml:Envelope srsName="EPSG:27700">
        		<gml:lowerCorner>547547.098266 181365.400053</gml:lowerCorner>
        		<gml:upperCorner>548048.231804 181488.319418</gml:upperCorner>
        	</gml:Envelope>
        </gml:boundedBy>
        <ms:msGeometry>
          <gml:Polygon srsName="EPSG:27700">
            <gml:exterior>
              <gml:LinearRing>
                <gml:posList srsDimension="2">547665.891525 181488.319418 547667.893687 181488.319418 547669.992575 181488.319418 547675.151960 181488.187126 547679.649886 181488.187126 547684.941563 181487.790251 547690.828554 181487.657959 547695.987939 181487.261083 547700.618157 181487.128791 547706.571294 181486.864207 547714.244226 181486.599623 547720.065071 181486.070456 547725.489040 181485.805872 547730.846863 181485.673580 547735.741665 181485.541288 547739.842714 181485.144412 547742.885429 181485.012120 547746.721895 181484.879828 547750.293777 181484.615244 547754.262535 181484.482952 547757.966709 181484.350660 547761.670883 181483.953785 547765.242765 181483.953785 547769.013085 181483.689201 547772.717259 181483.556909 547776.289141 181483.292325 547778.934980 181482.763157 547780.985505 181482.101698 547784.425095 181481.175654 547787.467810 181479.985027 547790.642816 181478.794399 547793.950114 181477.736064 547797.389705 181476.545436 547800.961587 181475.487101 547804.401177 181474.164182 547807.311599 181473.105846 547810.486606 181472.179803 547813.264736 181471.518343 547816.307451 181470.856883 547819.085581 181470.592300 547822.525171 181470.460008 547825.832470 181470.195424 547829.536644 181469.798548 547832.447066 181469.666256 547835.357489 181469.666256 547835.278049 181468.004858 547836.806700 181467.886672 547838.384561 181467.764681 547838.466349 181469.666256 547842.435107 181469.533964 547846.006989 181469.401672 547849.446579 181469.004796 547853.547629 181468.872504 547857.251803 181468.607921 547861.352853 181468.211045 547864.527860 181467.681877 547868.628909 181466.755834 547873.788295 181465.432914 547878.550804 181464.374579 547880.515685 181463.774199 547883.313314 181462.919368 547887.811240 181461.464156 547892.309165 181460.008945 547896.542507 181458.553734 547901.437308 181456.437063 547905.935234 181454.849560 547910.565452 181452.865181 547914.666502 181451.013094 547919.429011 181448.896423 547924.720688 181446.250584 547928.755592 181444.544018 547933.518102 181442.427347 547938.280611 181439.913801 547941.587910 181438.326298 547944.630624 181436.871086 547948.334798 181435.018999 547952.700432 181432.637744 547954.026593 181431.886253 547956.669190 181430.388782 547960.770240 181428.007527 547964.738998 181425.361688 547968.707755 181422.980433 547972.941097 181419.937719 547976.512979 181417.569694 547979.952570 181415.056147 547983.656744 181412.013432 547988.154669 181408.441550 547992.520303 181405.266544 547996.092185 181402.488413 547999.928651 181399.445699 548003.500533 181397.064444 548007.866167 181394.021730 548011.967217 181391.243599 548016.200559 181388.597761 548019.507857 181386.269423 548023.741199 181383.623584 548027.842249 181381.242329 548030.505762 181379.589114 548031.678715 181378.861074 548035.250597 181376.876695 548039.351647 181374.363149 548043.012018 181372.609959 548045.850671 181369.879086 548048.231804 181365.400053 548043.705809 181367.508706 548039.260000 181369.580000 548029.530000 181375.550000 548021.209278 181379.687303 548016.900000 181381.830000 548012.675000 181384.682500 548008.450000 181387.535000 548000.000000 181393.240000 547991.410000 181399.040000 547991.130000 181398.630000 547993.200000 181393.100000 547993.183319 181393.093686 547991.038798 181398.863883 547989.847500 181401.995315 547987.345105 181401.030755 547980.082500 181406.275000 547972.805000 181411.530000 547965.527500 181416.785000 547958.250000 181422.040000 547952.455000 181425.750000 547946.660000 181429.460000 547938.870000 181433.265000 547934.975000 181435.167500 547925.757500 181439.765000 547915.112500 181445.155000 547909.790000 181447.850000 547903.305000 181450.450000 547893.530000 181453.875000 547885.850000 181456.510000 547880.460000 181458.600000 547873.237500 181460.947500 547868.035000 181462.470000 547863.830000 181463.522500 547859.989960 181464.327536 547858.022500 181464.740000 547853.290000 181465.580000 547842.550242 181467.344324 547841.053400 181467.558343 547838.384561 181467.764681 547836.806700 181467.886672 547835.278049 181468.004858 547832.560000 181468.215000 547823.700000 181468.900000 547818.610000 181468.875000 547817.390125 181468.869008 547813.520000 181468.850000 547808.680000 181468.720000 547799.000000 181468.460000 547794.160000 181468.330000 547790.295000 181468.397500 547786.430000 181468.465000 547778.700000 181468.600000 547765.957500 181468.935000 547755.270000 181469.160000 547748.107500 181469.422500 547738.980000 181469.967500 547732.240000 181470.425000 547725.500000 181470.882500 547718.760000 181471.340000 547712.547500 181471.497500 547706.335000 181471.655000 547693.910000 181471.970000 547686.237500 181471.822500 547678.565000 181471.675000 547670.892500 181471.527500 547663.220000 181471.380000 547655.870000 181470.695000 547633.820000 181468.640000 547632.766056 181468.431217 547622.260000 181466.350000 547614.210000 181464.400000 547601.680000 181460.740000 547589.632500 181456.760000 547575.540000 181451.840000 547566.330000 181447.925000 547557.120000 181444.010000 547554.850000 181447.700000 547554.675000 181448.060000 547554.038366 181449.351566 547553.400000 181450.650000 547552.375000 181452.575000 547551.350000 181454.500000 547551.318366 181454.561566 547550.050000 181457.000000 547549.843366 181457.411566 547549.700000 181457.700000 547549.493366 181458.111566 547549.350000 181458.400000 547548.850000 181459.300000 547548.350000 181460.300000 547547.850000 181461.450000 547547.400000 181462.450000 547547.098266 181463.113814 547550.003793 181464.109995 547553.840259 181465.300622 547557.147557 181466.358958 547558.017610 181466.611554 547561.248607 181467.549585 547566.011117 181469.137088 547570.773626 181470.856883 547575.668428 181471.915219 547579.931880 181473.105019 547581.356981 181473.502722 547588.103869 181474.957933 547593.924714 181476.148561 547600.671603 181477.868356 547606.889324 181479.455859 547612.181001 181480.646486 547618.266430 181482.366281 547623.954983 181483.556909 547629.643536 181484.747536 547635.067505 181485.673580 547640.094598 181486.335039 547645.121692 181486.996499 547650.413369 181487.525667 547656.101922 181487.922543 547662.055059 181488.187126 547665.891525 181488.319418 </gml:posList>
              </gml:LinearRing>
            </gml:exterior>
          </gml:Polygon>
        </ms:msGeometry>
        <ms:fid>1000.000000000000000</ms:fid>
        <ms:owner>Tilfen Land</ms:owner>
        <ms:maintainby>Peabody</ms:maintainby>
        <ms:managedby>Thamesmead Commercial Team</ms:managedby>
      </ms:grass>
    </gml:featureMember>
</wfs:FeatureCollection>';

        my $thamesmead_asset_not_found = '<?xml version=\'1.0\' encoding="UTF-8" ?>
<wfs:FeatureCollection
   xmlns:ms="http://mapserver.gis.umn.edu/mapserver"
   xmlns:gml="http://www.opengis.net/gml"
   xmlns:wfs="http://www.opengis.net/wfs"
   xmlns:ogc="http://www.opengis.net/ogc"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xsi:schemaLocation="http://mapserver.gis.umn.edu/mapserver https://tilma.staging.mysociety.org:80/mapserver/thamesmead?SERVICE=WFS&amp;VERSION=1.1.0&amp;REQUEST=DescribeFeatureType&amp;TYPENAME=hardsurfaces&amp;OUTPUTFORMAT=SFE_XMLSCHEMA  http://www.opengis.net/wfs http://schemas.opengis.net/wfs/1.1.0/wfs.xsd">
   <gml:boundedBy>
      <gml:Null>missing</gml:Null>
   </gml:boundedBy>
</wfs:FeatureCollection>';

        if ($args->{Filter} =~ /547584,181468/) {
            return [ 200, [ 'Content-Type' => 'application/xml' ], [ $thamesmead_asset_found ] ];
        } else {
            return [ 200, [ 'Content-Type' => 'application/xml' ], [ $thamesmead_asset_not_found ] ];
        }
    }
}

__PACKAGE__->run_if_script;
