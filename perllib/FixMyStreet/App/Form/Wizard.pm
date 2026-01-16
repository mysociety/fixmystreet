=head1 NAME

FixMyStreet::App::Form::Wizard

=head1 SYNOPSIS

A multi-page form, based on HTML::FormHandler::Wizard, but using pages by name,
not numbered, with the ability for each page to decide where it goes next.

=cut

package FixMyStreet::App::Form::Wizard;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with ('HTML::FormHandler::BuildPages', 'HTML::FormHandler::Pages' );

use Path::Tiny;
use File::Copy;
use Digest::SHA qw(sha1_hex);
use File::Basename;

sub is_wizard { 1 } # So build_active is called

=pod

We create our own namespace to put our own Page and Field classes in.

=cut

sub build_page_name_space { 'FixMyStreet::App::Form::Page' }
has '+field_name_space' => ( default => 'FixMyStreet::App::Form::Field' );

=head2 Attributes

=over 4

=item * page_name - the name of the current page we're on

=item * current_page - the current page we're on

=cut

has page_name => ( is => 'ro', isa => 'Str' );
has current_page => ( is => 'ro', lazy => 1,
    default => sub { $_[0]->page($_[0]->page_name) },
    predicate => 'has_current_page',
);

=item * c - the Catalyst App, so we can get anything we need out of it

=cut

has c => ( is => 'ro', weak_ref => 1 );

=item * saved_data - this stores the data from previous steps so we don't have
to keep it in the session or anywhere else.

=item * previous_form - contains the previous step, should that be needed (e.g.
ticking things on the very first page)

=item * already_submitted_error - a flag set if a form is submitted at the end
but that has already happened, due to a unique ID mismatch.

=back

=cut

has saved_data_encoded => ( is => 'ro', isa => 'Maybe[Str]' );
has saved_data => ( is => 'rw', lazy => 1, isa => 'HashRef', default => sub {
    $_[0]->field('saved_data')->inflate_json($_[0]->saved_data_encoded) || {};
});
has previous_form => ( is => 'ro', isa => 'Maybe[HTML::FormHandler]', weak_ref => 1 );
has csrf_token => ( is => 'ro', isa => 'Str' );

has already_submitted_error => ( is => 'rw', isa => 'Bool', default => 0 );

=item * upload_dir - directory for FileIdUpload files. Forms can override this
to use a different directory (e.g. claims_files/, licence_files/).

=back

=cut

has upload_dir => ( is => 'ro', lazy => 1, default => sub {
    my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
    my $dir = $cfg ? $cfg->{UPLOAD_DIR} : FixMyStreet->config('UPLOAD_DIR');
    path($dir, "uploads")->absolute(FixMyStreet->path_to())->mkdir;
});

=head2 Form fields

=over 4

=item * saved_data - this is a base64 encoded copy of the JSON of the saved_data.

=item * token - the CSRF token

=item * process - the current form name, so we know what step to be processed

=item * unique_id - a field stored in both the form and the session, so we can
try and spot duplicate submission

=back

=cut

has_field saved_data => ( type => 'JSON' );
has_field token => ( type => 'Hidden', required => 1 );
has_field process => ( type => 'Hidden', required => 1 );

has unique_id_session => ( is => 'ro', isa => 'Maybe[Str]' );
has unique_id_form => ( is => 'ro', isa => 'Maybe[Str]' );
has_field unique_id => ( type => 'Hidden', required => 0 );

sub has_page_called {
    my ($self, $page_name) = @_;

    return grep { $_->name eq $page_name } $self->all_pages;
}

# body_params does not include file uploads, which breaks validation
# and value setting, so we need to add them here.
sub get_params {
    my ($self, $c) = @_;

    my @params = $c->req->body_params;

    if ( $c->req->uploads ) {
        for my $field ( keys %{ $c->req->uploads } ) {
            next unless $self->field($field);
            if ($self->field($field)->{type} eq 'FileIdUpload') {
                $self->file_upload($field);
                $params[0]->{$field} = $self->saved_data->{$field};
            }
        }
    }

    return @params;
}

=head2 next

This is called by the form controller to know where to go next.
It looks at the current page's C<next> - either a string, or a
code reference which should return the page to go to.

=cut

sub next {
    my $self = shift;
    my $next = $self->current_page->next;
    if (ref $next eq 'CODE') {
        $next = $next->(
            $self->saved_data,
            $self->c->req->params,
            $self, # TODO This should probably be the first arg
        );
    }
    return $next;
}

=head2 build_active

This overrides the default and makes all fields mentioned by pages inactive
apart from those on the current page. Note this means if a field is defined
but not assigned to a page, it will appear on all pages.

=cut

sub build_active {
    my $self = shift;

    my %active;
    foreach my $fname ($self->current_page->all_fields) {
        $active{$fname} = 1;
    }

    foreach my $page ( $self->all_pages ) {
        foreach my $fname ( $page->all_fields_copy ) {
            my $field = $self->field($fname);
            $field->inactive(1) unless $active{$fname};
        }
    }
}

=head2 after_build

The behind the curtain that does the plumbing of setting the saved data and
related information, calls a page's C<update_field_list> (which can then return
any required changes to the field list), and updates any photo fields.

=cut

sub after_build {
    my $self = shift;
    my $page = $self->current_page;

    my $saved_data = $self->previous_form ? $self->previous_form->saved_data : $self->saved_data;

    $self->init_object($saved_data); # For filling in existing values
    $self->saved_data($saved_data);

    # Fill in internal fields
    $self->update_field(saved_data => { default => $saved_data });
    $self->update_field(token => { default => $self->csrf_token });
    $self->update_field(process => { default => $page->name });
    $self->update_field(unique_id => { default => $self->unique_id_session });

    # Update field list with any dynamic things (eg user-based, address lookup, geocoding)
    my $updates = {};
    if ($page->has_update_field_list) {
        $updates = $page->update_field_list->($self) || {};
    }
    foreach my $fname ($self->current_page->all_fields) {
        if ($self->field($fname)->type eq 'Photo') {
            $self->update_photo($fname, $updates);
        }
    }
    foreach my $field_name (keys %$updates) {
        $self->update_field($field_name, $updates->{$field_name});
    }
}

=head2 after process

A page can define a C<post_process> function which is called after that page's
processing.

=cut

after 'process' => sub {
    my $self = shift;
    my $page = $self->current_page;
    $page->post_process->($self) if $page->post_process;
};

=head2 after validate_form

This checks the unique ID for mismatch, updates saved_data for the next page,
and calls C<pre_finished> and C<finished> if defined on the page (these are
explained more in the Page::Simple class).

=cut

after 'validate_form' => sub {
    my $self = shift;

    if ($self->validated) {
        my $page = $self->current_page;

        # Mismatch of unique ID, resubmission?
        if ($self->unique_id_session && $page->check_unique_id && $self->unique_id_session ne ($self->unique_id_form || '')) {
            $self->add_form_error('You have already submitted this form.');
            $self->already_submitted_error(1);
            return;
        }

        # Update saved_data for the next page
        my $saved_data = { %{$self->saved_data}, %{$self->value} };
        delete $saved_data->{process};
        delete $saved_data->{token};
        delete $saved_data->{saved_data};
        delete $saved_data->{unique_id};
        $self->saved_data($saved_data);
        $self->field('saved_data')->_set_value($saved_data);

        # A pre_finished lets a form pass validation but not actually finish
        if ($page->pre_finished) {
            my $success = $page->pre_finished->($self);
            return unless $success;
        }

        # And check to see if there is a function to call on the page
        if ($page->finished) {
            my $success = $page->finished->($self);
            if (!$success) {
                $self->add_form_error('Something went wrong, please try again')
                    unless $self->has_form_errors;
            } else {
                delete $self->c->session->{form_unique_id};
            }
        }
    }
};

=head2 process_photo

Photo upload is mostly handled for you automatically if you use the right
fields. These functions deal with the plumbing involved.

=cut

sub process_photo {
    my ($form, $field) = @_;

    my $saved_data = $form->saved_data;
    my $fileid = $field . '_fileid';
    my $c = $form->{c};
    $c->stash->{photo_upload_prefix} = $field;
    $c->stash->{photo_upload_fileid_field} = $fileid;
    $c->forward('/photo/process_photo');
    $saved_data->{$field} = $c->stash->{$fileid};
    $saved_data->{$fileid} = '';
}

sub update_photo {
    my ($form, $field, $fields) = @_;
    my $saved_data = $form->saved_data;

    if ($saved_data->{$field}) {
        my $fileid = $field . '_fileid';
        $saved_data->{$fileid} = $saved_data->{$field};
        $fields->{$fileid} = { default => $saved_data->{$field} };
    }
}

=head2 File upload methods

FileIdUpload fields are handled similarly to Photo fields. These methods
deal with saving uploaded files and managing their state across form pages.

=head3 file_upload

Called automatically by get_params() when processing FileIdUpload fields.
Saves the uploaded file to upload_dir with a SHA1 hash filename.

=cut

sub file_upload {
    my ($form, $field) = @_;

    my $c = $form->{c};
    my $saved_data = $form->saved_data;

    my $upload = $c->req->upload($field);
    if ( $upload ) {
        FixMyStreet::PhotoStorage::base64_decode_upload($c, $upload);
        my ($p, $n, $ext) = fileparse($upload->filename, qr/\.[^.]*/);
        my $key = sha1_hex($upload->slurp) . $ext;
        my $out = $form->upload_dir->child($key);
        unless (copy($upload->tempname, $out)) {
            $c->log->info('Couldn\'t copy temp file to destination: ' . $!);
            $c->stash->{photo_error} = _("Sorry, we couldn't save your file(s), please try again.");
            return;
        }
        # Store the file hash along with the original filename for display
        $saved_data->{$field} = { files => $key, filenames => [ $upload->raw_basename ] };
    }
}

=head3 handle_upload

Called in a page's update_field_list to restore upload field state from saved_data.

    update_field_list => sub {
        my ($form) = @_;
        my $fields = {};
        $form->handle_upload('field_name', $fields);
        return $fields;
    },

=cut

sub handle_upload {
    my ($form, $field, $fields) = @_;

    my $saved_data = $form->saved_data;
    if ( $saved_data->{$field} ) {
        $fields->{$field} = { default => $saved_data->{$field}->{files}, tags => $saved_data->{$field} };
    }
}

=head3 process_upload

Called in a page's post_process to save upload field data.

    post_process => sub {
        my ($form) = @_;
        $form->process_upload('field_name');
    },

=cut

sub process_upload {
    my ($form, $field) = @_;

    my $saved_data = $form->saved_data;
    my $c = $form->{c};

    if ( !$saved_data->{$field} && $c->req->params->{$field . '_fileid'} ) {
        # The data was already passed in from when it was saved before (also in tags, from above)
        $saved_data->{$field} = $form->field($field)->init_value;
    }
}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1;
