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
    } elsif ($c->cobrand->moniker eq 'greenwich' || $c->cobrand->moniker eq 'bexley') {
        my $features = FixMyStreet->config('COBRAND_FEATURES') || {};
        my $cobrands = $features->{asset_layers} || {};
        my $layers = $c->stash->{asset_layers} = [];
        for my $moniker ($c->cobrand->moniker, 'thamesmead') {
            my @layers = @{ $cobrands->{$moniker} || [] };
            push @$layers, _add_layer($moniker, @layers) if @layers;
        }
    } else {
        my @layers = @{ $c->cobrand->feature('asset_layers') || [] };
        return unless @layers;
        $c->stash->{asset_layers} = [ _add_layer($c->cobrand->moniker, @layers) ];
    }
}

sub _encode_json_with_js_classes {
    my $data = shift;
    my $json = JSON::MaybeXS->new->encode($data);
    $json =~ s/"([^"]*)":"((?:fixmystreet|OpenLayers)\..*?)"/"$1":$2/g;
    return $json;
}

sub _add_layer {
    my ($moniker, @layers) = @_;
    my $default = shift @layers;
    unless (ref $default eq 'ARRAY') {
        $default = [ $default ];
    }
    $default = { map {
        ($_->{name} || 'default') => $_
    } @$default };
    return {
        moniker => $moniker,
        default => _encode_json_with_js_classes($default),
        layers => [ map {
            my $default = $_->{template} || 'default';
            my $json = _encode_json_with_js_classes($_);
            { default => $default, data => $json };
        } @layers ],
    };
}

__PACKAGE__->meta->make_immutable;

1;

