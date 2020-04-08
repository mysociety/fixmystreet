package t::Mock::Tilma;

use JSON::MaybeXS;
use Web::Simple;

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

    sub (GET + /mapserver/tfl + ?*) {
        my ($self, $args) = @_;
        my $features = [];
        if ($args->{Filter} =~ /540512,169141/) {
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

}

__PACKAGE__->run_if_script;
