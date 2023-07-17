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

    my $features = FixMyStreet->config('COBRAND_FEATURES') || {};
    my $cobrands = $features->{asset_layers} || {};
    my @cobrands;
    if ($c->cobrand->moniker eq 'fixmystreet') {
        # Combine all the layers together for .com
        @cobrands = keys %$cobrands;
    } elsif ($c->cobrand->moniker eq 'greenwich' || $c->cobrand->moniker eq 'bexley') {
        # Special case for Thamesmead crossing the border
        @cobrands = ($c->cobrand->moniker, 'thamesmead');
    } else {
        # Only the cobrand's assets itself
        @cobrands = ($c->cobrand->moniker);
    }

    my $layers = $c->stash->{asset_layers} = [];
    for my $moniker (@cobrands) {
        my @layers = @{ $cobrands->{$moniker} || [] };
        push @$layers, _add_layer($moniker, @layers) if @layers;
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
    my $default_lookup = { map {
        ($_->{name} || 'default') => $_
    } @$default };
    foreach (@$default) {
        if ($_->{template}) {
            my %d = %$_;
            my $template = delete $d{template};
            $default_lookup->{$d{name}} = { %{$default_lookup->{$template}}, %d };
        }
    }
    return {
        moniker => $moniker,
        default => _encode_json_with_js_classes($default_lookup),
        layers => [ map {
            my $default = $_->{template} || 'default';
            my $json = _encode_json_with_js_classes($_->{layers} || $_);
            { default => $default, data => $json };
        } @layers ],
    };
}

__PACKAGE__->meta->make_immutable;

1;

