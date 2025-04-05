package FixMyStreet::App::Form::Page::Simple;
use Moose;
extends 'HTML::FormHandler::Page';

# What page to go to after successful submission of this page
has next => ( is => 'ro', isa => 'Str|CodeRef' );

# Optional template to display at the top of this page
has intro => ( is => 'ro', isa => 'Str' );

# A function that will be called to generate an update_field_list parameter
has update_field_list => (
    is => 'ro',
    isa => 'CodeRef',
    predicate => 'has_update_field_list',
);

# A function called after all form processing, just before template display
# (to e.g. set up the map)
has post_process => (
    is => 'ro',
    isa => 'CodeRef',
);

has check_unique_id => ( is => 'ro', default => 1 );

# Catalyst action to forward to once this page has been reached
has pre_finished => ( is => 'ro', isa => 'CodeRef' );
has finished => ( is => 'ro', isa => 'CodeRef' );

has field_ignore_list => (
    is => 'ro',
    isa => 'CodeRef',
    predicate => 'has_field_ignore_list'
);
has fields_copy => (
    traits => ['Array'],
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        all_fields_copy => 'elements',
    },
);

sub BUILD {
    my $self = shift;
    my $fields = $self->fields;
    $self->fields_copy($fields);
    if ($self->has_field_ignore_list) {
        my %ignore = map { $_ => 1 } @{$self->field_ignore_list->($self) || []};
        my $kept_fields = [ grep { !$ignore{$_} } @$fields ];
        $self->fields($kept_fields);
    }
}

sub has_file_upload {
    my $self = shift;
    foreach (@{$self->fields}) {
        return 1 if $self->field($_)->type =~ /FileId/;
    }
    return 0;
}

1;
