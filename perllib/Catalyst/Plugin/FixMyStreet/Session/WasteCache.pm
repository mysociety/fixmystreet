package Catalyst::Plugin::FixMyStreet::Session::WasteCache;
use Moose::Role;
use namespace::autoclean;

sub waste_cache_set {
    my ($c, $key, $data) = @_;
    $c->session->{waste}{$key} = [ time, $data ];
    return $data;
}

sub waste_cache_get {
    my ($c, $key) = @_;
    $c->session->{waste}{$key} && $c->session->{waste}{$key}[1];
}

sub waste_cache_delete {
    my ($c, $key) = @_;
    delete $c->session->{waste}{$key};
}

__PACKAGE__;
