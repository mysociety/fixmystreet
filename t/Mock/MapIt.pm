package t::Mock::MapIt;

use JSON::MaybeXS;
use Web::Simple;
use LWP::Protocol::PSGI;

use mySociety::Locale;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /postcode/*) {
        my ($self, $postcode) = @_;
        my $response = $self->postcode($postcode);
        # We must make sure we output correctly for testing purposes, we might
        # be within a different locale here...
        my $json = mySociety::Locale::in_gb_locale {
            $self->json->encode($response) };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /point/**) {
        my ($self, $point) = @_;
        my $response = {
            "63999" => {"parent_area" => 2245, "generation_high" => 25, "all_names" => {}, "id" => 63999, "codes" => {"ons" => "00HYNS", "gss" => "E05008366", "unit_id" => "44025"}, "name" => "Kington", "country" => "E", "type_name" => "Unitary Authority electoral division (UTE)", "generation_low" => 12, "country_name" => "England", "type" => "UTE"},
            "65822" => {"parent_area" => undef, "generation_high" => 25, "all_names" => {}, "id" => 65822, "codes" => {"gss" => "E14000860", "unit_id" => "24903"}, "name" => "North Wiltshire", "country" => "E", "type_name" => "UK Parliament constituency", "generation_low" => 13, "country_name" => "England", "type" => "WMC"},
            "11814" => {"parent_area" => undef, "generation_high" => 25, "all_names" => {}, "id" => 11814, "codes" => {"ons" => "09", "gss" => "E15000009", "unit_id" => "41427"}, "name" => "South West", "country" => "E", "type_name" => "European region", "generation_low" => 1, "country_name" => "England", "type" => "EUR"},
            "2245" => {"parent_area" => undef, "generation_high" => 25, "all_names" => {}, "id" => 2245, "codes" => {"ons" => "00HY", "gss" => "E06000054", "unit_id" => "43925"}, "name" => "Wiltshire Council", "country" => "E", "type_name" => "Unitary Authority", "generation_low" => 11, "country_name" => "England", "type" => "UTA"}
        };
        # We must make sure we output correctly for testing purposes, we might
        # be within a different locale here...
        my $json = mySociety::Locale::in_gb_locale {
            $self->json->encode($response) };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /area/*) {
        my ($self, $area) = @_;
        my $response = {"parent_area" => undef, "generation_high" => 25, "all_names" => {}, "id" => 2245, "codes" => {"ons" => "00HY", "gss" => "E06000054", "unit_id" => "43925"}, "name" => "Wiltshire Council", "country" => "E", "type_name" => "Unitary Authority", "generation_low" => 11, "country_name" => "England", "type" => "UTA"};
        # We must make sure we output correctly for testing purposes, we might
        # be within a different locale here...
        my $json = mySociety::Locale::in_gb_locale {
            $self->json->encode($response) };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

    sub (GET + /area/*/children) {
        my ($self, $area) = @_;
        my $response = {
            "60705" => { "parent_area" => 2245, "generation_high" => 25, "all_names" => { }, "id" => 60705, "codes" => { "ons" => "00HY226", "gss" => "E04011842", "unit_id" => "17101" }, "name" => "Trowbridge", "country" => "E", "type_name" => "Civil parish/community", "generation_low" => 12, "country_name" => "England", "type" => "CPC" },
            "62883" => { "parent_area" => 2245, "generation_high" => 25, "all_names" => { }, "id" => 62883, "codes" => { "ons" => "00HY026", "gss" => "E04011642", "unit_id" => "17205" }, "name" => "Bradford-on-Avon", "country" => "E", "type_name" => "Civil parish/community", "generation_low" => 12, "country_name" => "England", "type" => "CPC" },
        };
        # We must make sure we output correctly for testing purposes, we might
        # be within a different locale here...
        my $json = mySociety::Locale::in_gb_locale {
            $self->json->encode($response) };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

sub postcode {
    my ($self, $postcode) = @_;
    return {
        wgs84_lat => 51.5, wgs84_lon => -2.1, postcode => $postcode, coordsyst => 'G',
    };
}

LWP::Protocol::PSGI->register(t::Mock::MapIt->to_psgi_app, host => 'mapit.uk');

__PACKAGE__->run_if_script;
