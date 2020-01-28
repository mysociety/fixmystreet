package FixMyStreet::App::Form::ManifestTheme;

use HTML::FormHandler::Moose;
use FixMyStreet::App::Form::I18N;
extends 'HTML::FormHandler::Model::DBIC';
use namespace::autoclean;

has 'cobrand' => ( isa => 'Str', is => 'ro' );

has '+widget_name_space' => ( default => sub { ['FixMyStreet::App::Form::Widget'] } );
has '+widget_tags' => ( default => sub { { wrapper_tag => 'p' } } );
has '+item_class' => ( default => 'ManifestTheme' );
has_field 'cobrand' => ( required => 0 );
has_field 'name' => ( required => 1 );
has_field 'short_name' => ( required => 1 );
has_field 'background_colour' => ( required => 0 );
has_field 'theme_colour' => ( required => 0 );

before 'update_model' => sub {
    my $self = shift;
    $self->item->cobrand($self->cobrand) if $self->cobrand && !$self->item->cobrand;
};

sub _build_language_handle { FixMyStreet::App::Form::I18N->new }

__PACKAGE__->meta->make_immutable;

1;
