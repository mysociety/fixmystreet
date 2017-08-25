package t::Mock::MapItZurich;

use JSON::MaybeXS;
use Web::Simple;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /areas/**) {
        my ($self, $areas) = @_;
        my $response = {
            "423017" => {"parent_area" => undef, "generation_high" => 4, "all_names" => {}, "id" => 423017, "codes" => {}, "name" => "Zurich", "country" => "G", "type_name" => "OpenStreetMap Layer 8", "generation_low" => 4, "country_name" => "Global", "type" => "O08"}
        };
        my $json = $self->json->encode($response);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /point/**) {
        my ($self, $point) = @_;
        my $response = {
            "423017" => {"parent_area" => undef, "generation_high" => 4, "all_names" => {}, "id" => 423017, "codes" => {}, "name" => "Zurich", "country" => "G", "type_name" => "OpenStreetMap Layer 8", "generation_low" => 4, "country_name" => "Global", "type" => "O08"}
        };
        my $json = $self->json->encode($response);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /area/*/example_postcode) {
        my ($self, $area) = @_;
        my $json = $self->json->encode({});
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /area/*/children) {
        my ($self, $area) = @_;
        my $json = $self->json->encode({});
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

LWP::Protocol::PSGI->register(t::Mock::MapItZurich->to_psgi_app, host => 'mapit.zurich');

__PACKAGE__->run_if_script;
