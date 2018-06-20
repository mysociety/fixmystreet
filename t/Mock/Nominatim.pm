package t::Mock::Nominatim;

use JSON::MaybeXS;
use Web::Simple;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->utf8->pretty->allow_blessed->convert_blessed;
    },
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /reverse + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'text/xml' ], [ '<result></result>' ] ];
    },

    sub (GET + /search + ?q=) {
        my ($self, $q) = @_;
        my $response = $self->query($q);
        my $json = mySociety::Locale::in_gb_locale {
            $self->json->encode($response);
        };
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

sub query {
    my ($self, $q) = @_;
    if ($q eq 'high street') {
        return [
            {"osm_type"=>"way","osm_id"=>"4684282","lat"=>"55.9504009","lon"=>"-3.1858425","display_name"=>"High Street, Old Town, City of Ed\x{ed}nburgh, Scotland, EH1 1SP, United Kingdom","class"=>"highway","type"=>"tertiary","importance"=>0.55892577838734},
            {"osm_type"=>"node","osm_id"=>"27424410","lat"=>"55.8596449","lon"=>"-4.240377","display_name"=>"High Street, Collegelands, Merchant City, Glasgow, Glasgow City, Scotland, G, United Kingdom","class"=>"railway","type"=>"station","importance"=>0.53074299592768}
        ];
    }
    return [];
}

LWP::Protocol::PSGI->register(t::Mock::Nominatim->to_psgi_app, host => 'nominatim.openstreetmap.org');

__PACKAGE__->run_if_script;
