package FixMyStreet::App::Controller::Static;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Static - Catalyst Controller

=head1 DESCRIPTION

Static pages Catalyst Controller. FAQ does some smarts to choose the correct
template depending on language, will need extending at some point.

=head1 METHODS

=cut

sub about : Global : Args(0) {
    my ( $self, $c ) = @_;

    my $lang_code = $c->stash->{lang_code};
    my $template  = "static/about-$lang_code.html";
    $c->stash->{template} = $template;
}

sub privacy : Global : Args(0) {
    my ( $self, $c ) = @_;
}

sub faq : Global : Args(0) {
    my ( $self, $c ) = @_;

    # There should be a faq template for each language in a cobrand or default.
    # This is because putting the FAQ translations into the PO files is
    # overkill.
    
    # We rely on the list of languages for the site being restricted so that there
    # will be a faq template for that language/cobrand combo.
        
    my $lang_code = $c->stash->{lang_code};
    my $template  = "faq/faq-$lang_code.html";
    $c->stash->{template} = $template;
}

sub fun : Global : Args(0) {
    my ( $self, $c ) = @_;
    # don't need to do anything here - should just pass through.
}

sub posters : Global : Args(0) {
    my ( $self, $c ) = @_;
}

sub iphone : Global : Args(0) {
    my ( $self, $c ) = @_;
}

sub council : Global : Args(0) {
    my ( $self, $c ) = @_;
}

__PACKAGE__->meta->make_immutable;

1;

