=head1 NAME

FixMyStreet::App::Form::Page::Simple

=head1 SYNOPSIS

A subclass of HTML::FormHandler's Page, to provide various glue for the wizard.

=cut

package FixMyStreet::App::Form::Page::Simple;
use Moose;
extends 'HTML::FormHandler::Page';

=over 4

=item * C<next> - either a string, or a sub that returns a string, of the next
page of the wizard after successful submission of this page

=cut

has next => ( is => 'ro', isa => 'Str|CodeRef' );

=item * C<intro> - an optional template that is displayed at the top of this
page

=cut

has intro => ( is => 'ro', isa => 'Str' );

=item * C<update_field_list> - a function that will be called to generate
an update_field_list parameter for the page (in order to change defaults
or what is included)

=cut

has update_field_list => (
    is => 'ro',
    isa => 'CodeRef',
    predicate => 'has_update_field_list',
);

=item * C<post_process> - a function called after all form processing, just
before template display (to e.g. set up the map)

=cut

has post_process => (
    is => 'ro',
    isa => 'CodeRef',
);

has check_unique_id => ( is => 'ro', default => 1 );

=item * C<pre_finished> and C<finished> - functions to call once this page has
been reached and submitted, generally used at the end of the wizard.
pre_finished is called first to allow a page to prevent actual finishing (e.g.
a final check for bulky slot availability fails).

=cut

has pre_finished => ( is => 'ro', isa => 'CodeRef' );
has finished => ( is => 'ro', isa => 'CodeRef' );

=item * C<field_ignore_list> - a function that returns a list of fields to be
ignored on this page (generally due to something cobrand specific)

=cut

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

=item * C<has_file_upload> returns true if any field on this page is an upload

=back

=cut

sub has_file_upload {
    my $self = shift;
    foreach (@{$self->fields}) {
        return 1 if $self->field($_)->type =~ /FileId/;
    }
    return 0;
}

1;
