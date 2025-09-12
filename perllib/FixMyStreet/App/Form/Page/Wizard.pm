=head1 NAME

FixMyStreet::App::Form::Page::Wizard

=head1 SYNOPSIS

A subclass of the Simple page to provide per-page custom title and template,
whether a page requires signing in, and tags (used by claims form for whether
to show/hide things on the summary page).

=cut

package FixMyStreet::App::Form::Page::Wizard;
use Moose;
extends 'FixMyStreet::App::Form::Page::Simple';

# Title to use for this page
has title => ( is => 'ro', isa => 'Str' );

# Special template to use in preference to the default
has template => ( is => 'ro', isa => 'Str' );

# Does this page of the form require you to be signed in?
has requires_sign_in => ( is => 'ro', isa => 'Bool' );


has 'tags' => (
    traits     => ['Hash'],
    isa        => 'HashRef',
    is         => 'rw',
    default    => sub { {} },
    handles   => {
      _get_tag => 'get',
      set_tag => 'set',
      has_tag => 'exists',
      tag_exists => 'exists',
      delete_tag => 'delete',
    }
);

sub get_tag {
    my ( $self, $name ) = @_;
    return '' unless $self->tag_exists($name);
    my $tag = $self->_get_tag($name);
    return $self->$tag if ref $tag eq 'CODE';
    return $tag;
}

1;
