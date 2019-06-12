package FixMyStreet::App::Form::Role;

use HTML::FormHandler::Moose;
use FixMyStreet::App::Form::I18N;
extends 'HTML::FormHandler::Model::DBIC';
use namespace::autoclean;

has 'body_id' => ( isa => 'Int', is => 'ro' );

has '+widget_name_space' => ( default => sub { ['FixMyStreet::App::Form::Widget'] } );
has '+widget_tags' => ( default => sub { { wrapper_tag => 'p' } } );
has '+item_class' => ( default => 'Role' );
has_field 'name' => ( required => 1 );
has_field 'body' => ( type => 'Select', empty_select => 'Select a body', required => 1 );
has_field 'permissions' => (
    type => 'Multiple',
    widget => 'CheckboxGroup',
    ul_class => 'permissions-checkboxes',
    tags => { inline => 1, wrapper_tag => 'fieldset', },
);

before 'update_model' => sub {
    my $self = shift;
    $self->item->body_id($self->body_id) if $self->body_id;
};

sub _build_language_handle { FixMyStreet::App::Form::I18N->new }

has '+unique_messages' => (
   default => sub {
      { roles_body_id_name_key => "Role names must be unique" };
   }
);

sub validate {
    my $self = shift;

    my $rs = $self->resultset;
    my $value = $self->value;

    return 0 if $self->body_id; # The core validation catches this, because body_id is set on $self->item
    return 0 if $self->item_id && $self->item->body_id == $value->{body}; # Correctly caught by core validation

    # Okay, due to a bug we need to check this ourselves
    # https://github.com/gshank/html-formhandler-model-dbic/issues/20
    my @id_clause = ();
    @id_clause = HTML::FormHandler::Model::DBIC::_id_clause( $rs, $self->item_id ) if defined $self->item;

    my %form_columns = (body => 'body_id', name => 'name');
    my %where = map { $form_columns{$_} =>
        exists( $value->{$_} ) ? $value->{$_} : undef ||
            ( $self->item ? $self->item->get_column($form_columns{$_}) : undef )
    } keys %form_columns;

    my $count = $rs->search( \%where )->search( {@id_clause} )->count;
    return 0 if $count < 1;

    my $field = $self->field('name');
    my $constraint = 'roles_body_id_name_key';
    my $field_error = $self->unique_message_for_constraint($constraint);
    $field->add_error( $field_error, $constraint );
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
