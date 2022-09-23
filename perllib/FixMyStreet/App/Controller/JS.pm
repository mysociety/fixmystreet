package FixMyStreet::App::Controller::JS;
use Moose;
use JSON::MaybeXS;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::JS - Catalyst Controller

=head1 DESCRIPTION

JS Catalyst Controller. To return a language-dependent list
of translation strings.

=head1 METHODS

=cut

sub translation_strings : LocalRegex('^translation_strings\.(.*?)\.js$') : Args(0) {
    my ( $self, $c ) = @_;
    my $lang = $c->req->captures->[0];
    $c->cobrand->set_lang_and_domain( $lang, 1,
        FixMyStreet->path_to('locale')->stringify
    );
    $c->res->content_type( 'application/javascript' );
}

sub asset_layers : Path('asset_layers.js') : Args(0) {
    my ( $self, $c ) = @_;

    $c->res->content_type( 'application/javascript' );

    if ($c->cobrand->moniker eq 'fixmystreet') {
        # Combine all the layers together for .com
        my $features = FixMyStreet->config('COBRAND_FEATURES') || {};
        my $cobrands = $features->{asset_layers} || {};
        my $layers = $c->stash->{asset_layers} = [];
        for my $moniker ( keys %$cobrands ) {
            my @layers = @{ $cobrands->{$moniker} };
            push @$layers, _add_layer($moniker, @layers);
        }
    } else {
        my @layers = @{ $c->cobrand->feature('asset_layers') || [] };
        return unless @layers;
        $c->stash->{asset_layers} = [ _add_layer($c->cobrand->moniker, @layers) ];
    }
}

sub _add_layer {
    my ($moniker, @layers) = @_;
    my $default = shift @layers;
    return {
        moniker => $moniker,
        default => encode_json($default),
        layers => [ map {
            my $json = encode_json($_);
            $json =~ s/("stylemap":)"(.*?)"/$1$2/;
            $json;
        } @layers ],
    };
}

__PACKAGE__->meta->make_immutable;

1;

