package FixMyStreet::App::Controller::FAQ;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::FAQ - Catalyst Controller

=head1 DESCRIPTION

Show the FAQ page - does some smarts to choose the correct template depending on
language.

=cut

sub faq : Path : Args(0) {
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

__PACKAGE__->meta->make_immutable;

1;
