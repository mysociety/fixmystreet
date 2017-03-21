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

sub output {
    my ($self, $response) = @_;
    # We must make sure we output correctly for testing purposes, we might
    # be within a different locale here...
    my $json = mySociety::Locale::in_gb_locale {
        $self->json->encode($response) };
    return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
}

my @PLACES = (
    [ 'EH1 1BB', 55.952055, -3.189579, 2651, 'Edinburgh City Council', 'UTA', 20728, 'City Centre', 'UTE' ],
    [ 'SW1A 1AA', 51.501009, -0.141588, 2504, 'Westminster City Council', 'LBO' ],
    [ 'GL50 2PR', 51.896268, -2.093063, 2226, 'Gloucestershire County Council', 'CTY', 2326, 'Cheltenham Borough Council', 'DIS', 4544, 'Lansdown', 'DIW', 143641, 'Lansdown and Park', 'CED' ],
    [ '?', 51.754926, -1.256179, 2237, 'Oxfordshire County Council', 'CTY', 2421, 'Oxford City Council', 'DIS' ],
    [ 'BR1 3UH', 51.4021, 0.01578, 2482, 'Bromley Council', 'LBO' ],
    [ '?', 50.78301, -0.646929 ],
    [ 'GU51 4AE', 51.279456, -0.846216, 2333, 'Hart District Council', 'DIS', 2227, 'Hampshire County Council', 'CTY' ],
    [ 'WS1 4NH', 52.563074, -1.991032, 2535, 'Sandwell Borough Council', 'MTD' ],
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /postcode/*) {
        my ($self, $postcode) = @_;
        foreach (@PLACES) {
            if ($postcode eq $_->[0] || $postcode eq $_->[0] =~ s/ //gr) {
                return $self->output({wgs84_lat => $_->[1], wgs84_lon => $_->[2], postcode => $postcode, coordsyst => 'G'});
            }
        }
        my $response = {
            wgs84_lat => 51.5, wgs84_lon => -2.1, postcode => $postcode, coordsyst => 'G',
        };
        return $self->output($response);
    },

    sub (GET + /point/**.*) {
        my ($self, $point) = @_;
        foreach (@PLACES) {
            if ($point eq "4326/$_->[2],$_->[1]") {
                my %out;
                for (my $i=3; $i<@$_; $i+=3) {
                    $out{"$_->[$i]"} = { id => $_->[$i], name => $_->[$i+1], type => $_->[$i+2] };
                }
                return $self->output(\%out);
            }
        }
        my $response = {
            "63999" => {"parent_area" => 2245, "generation_high" => 25, "all_names" => {}, "id" => 63999, "codes" => {"ons" => "00HYNS", "gss" => "E05008366", "unit_id" => "44025"}, "name" => "Kington", "country" => "E", "type_name" => "Unitary Authority electoral division (UTE)", "generation_low" => 12, "country_name" => "England", "type" => "UTE"},
            "2245" => {"parent_area" => undef, "generation_high" => 25, "all_names" => {}, "id" => 2245, "codes" => {"ons" => "00HY", "gss" => "E06000054", "unit_id" => "43925"}, "name" => "Wiltshire Council", "country" => "E", "type_name" => "Unitary Authority", "generation_low" => 11, "country_name" => "England", "type" => "UTA"}
        };
        return $self->output($response);
    },

    sub (GET + /areas/*) {
        my ($self, $areas) = @_;
        if ($areas eq 'Hart') {
            $self->output({2333 => {parent_area => undef, id => 2333, name => "Hart District Council", type => "DIS"}});
        } elsif ($areas eq 'Birmingham') {
            $self->output({2514 => {parent_area => undef, id => 2514, name => "Birmingham City Council", type => "MTD"}});
        } elsif ($areas eq 'Gloucestershire') {
            $self->output({2226 => {parent_area => undef, id => 2226, name => "Gloucestershire County Council", type => "CTY"}});
        } elsif ($areas eq 'Cheltenham') {
            $self->output({2326 => {parent_area => undef, id => 2326, name => "Cheltenham Borough Council", type => "DIS"}});
        } elsif ($areas eq 'Lansdown and Park') {
            $self->output({22261 => {parent_area => 2226, id => 22261, name => "Lansdown and Park", type => "CED"}});
        } elsif ($areas eq 'Lansdown') {
            $self->output({23261 => {parent_area => 2326, id => 23261, name => "Lansdown", type => "DIW"}});
        } elsif ($areas eq 'UTA') {
            $self->output({2650 => {parent_area => undef, id => 2650, name => "Aberdeen Council", type => "UTA"}});
        }
    },

    sub (GET + /area/*) {
        my ($self, $area) = @_;
        my $response = { "id" => $area, "name" => "Area $area", "type" => "UTA" };
        return $self->output($response);
    },

    sub (GET + /area/*/children) {
        my ($self, $area) = @_;
        my $response = {
            "60705" => { "parent_area" => 2245, "generation_high" => 25, "all_names" => { }, "id" => 60705, "codes" => { "ons" => "00HY226", "gss" => "E04011842", "unit_id" => "17101" }, "name" => "Trowbridge", "country" => "E", "type_name" => "Civil parish/community", "generation_low" => 12, "country_name" => "England", "type" => "CPC" },
            "62883" => { "parent_area" => 2245, "generation_high" => 25, "all_names" => { }, "id" => 62883, "codes" => { "ons" => "00HY026", "gss" => "E04011642", "unit_id" => "17205" }, "name" => "Bradford-on-Avon", "country" => "E", "type_name" => "Civil parish/community", "generation_low" => 12, "country_name" => "England", "type" => "CPC" },
        };
        return $self->output($response);
    },

    sub (GET + /area/*/example_postcode) {
        my ($self, $area) = @_;
        return [ 200, [ 'Content-Type' => 'application/json' ], [ '"AB12 1AA"' ] ];
    },
}

LWP::Protocol::PSGI->register(t::Mock::MapIt->to_psgi_app, host => 'mapit.uk');

__PACKAGE__->run_if_script;
