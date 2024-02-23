=head1 NAME

FixMyStreet::Template:JS

=head1 SYNOPSIS

Helper functions for dynamic JavaScript generation.

=head1 DESCRIPTION

=cut

package FixMyStreet::Template::JS;
use FixMyStreet;
use JSON::MaybeXS;

sub pick_asset_layers {
    my $cobrand = shift;
    my $features = FixMyStreet->config('COBRAND_FEATURES') || {};
    my $cobrands = $features->{asset_layers} || {};
    my @cobrands;
    if ($cobrand eq 'fixmystreet') {
        # Combine all the layers together for .com
        %cobrands = %$cobrands;
    } elsif ($cobrand eq 'greenwich' || $cobrand eq 'bexley') {
        # Special case for Thamesmead crossing the border
        %cobrands = map { $_ => $cobrands->{$_} } ($cobrand, 'thamesmead');
    } else {
        # Only the cobrand's assets itself
        %cobrands = map { $_ => $cobrands->{$_} } ($cobrand);
    }

    my $layers = [];
    for my $moniker (sort keys %cobrands) {
        my @layers = @{ $cobrands{$moniker} || [] };
        push @$layers, _add_layer($moniker, @layers) if @layers;
    }
    return $layers;
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

sub _encode_json_with_js_classes {
    my $data = shift;
    my $json = JSON::MaybeXS->new->encode($data);
    $json =~ s/"([^"]*)":"((?:fixmystreet|OpenLayers)\..*?)"/"$1":$2/g;
    return $json;
}

1;
