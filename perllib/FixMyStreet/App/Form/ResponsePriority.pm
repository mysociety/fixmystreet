package FixMyStreet::App::Form::ResponsePriority;

use HTML::FormHandler::Moose;
use FixMyStreet::App::Form::I18N;
extends 'HTML::FormHandler::Model::DBIC';
use namespace::autoclean;

has 'body_id' => ( isa => 'Int', is => 'ro' );

has '+widget_name_space' => ( default => sub { ['FixMyStreet::App::Form::Widget'] } );
has '+widget_tags' => ( default => sub { { wrapper_tag => 'p' } } );
has '+item_class' => ( default => 'ResponsePriority' );
has_field 'name' => ( required => 1 );
has_field 'description';
has_field 'external_id' => ( label => 'External ID' );
has_field 'is_default' => (
    type => 'Checkbox',
    option_label => 'Default priority',
    do_label => 0,
);
has_field 'deleted' => (
    type => 'Checkbox',
    option_label => 'Flag as deleted',
    do_label => 0,
);
has_field 'contacts' => (
    type => 'Multiple',
    widget => 'CheckboxGroup',
    ul_class => 'no-bullets no-margin',
    do_label => 0,
    do_wrapper => 0,
    tags => { inline => 1 },
);

before 'update_model' => sub {
    my $self = shift;
    $self->item->body_id($self->body_id);
};

sub _build_language_handle { FixMyStreet::App::Form::I18N->new }

has '+unique_messages' => (
   default => sub {
      { response_priorities_body_id_name_key => "Names must be unique" };
   }
);

__PACKAGE__->meta->make_immutable;

1;
