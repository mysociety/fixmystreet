package FixMyStreet::App::Controller::JS;
use Moose;
use namespace::autoclean;
use FixMyStreet::Template::JS;

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
    $c->stash->{asset_layers} = FixMyStreet::Template::JS::pick_asset_layers($c->cobrand->moniker);
}

__PACKAGE__->meta->make_immutable;

1;

