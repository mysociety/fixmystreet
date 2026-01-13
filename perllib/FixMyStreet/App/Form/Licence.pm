package FixMyStreet::App::Form::Licence;

use Moose::Role;
use Path::Tiny;
use File::Copy;
use Digest::SHA qw(sha1_hex);
use File::Basename;

=head1 NAME

FixMyStreet::App::Form::Licence - Role for TfL licence application forms

=head1 DESCRIPTION

This role provides shared functionality for all licence application forms,
including file upload handling and summary display methods.

=cut

# Upload directory for licence files (separate from claims)
has upload_dir => ( is => 'ro', lazy => 1, default => sub {
    my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
    my $dir = $cfg ? $cfg->{UPLOAD_DIR} : FixMyStreet->config('UPLOAD_DIR');
    $dir = path($dir, "licence_files")->absolute(FixMyStreet->path_to())->mkdir;
    return $dir;
});

=head2 handle_upload

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

=head2 process_upload

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

=head2 file_upload

Called by Wizard.pm when processing FileIdUpload fields. Saves the uploaded
file to the upload directory with a SHA1 hash filename.

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

=head2 fields_for_display

Returns an array of pages with their fields, formatted for display on the
summary page. Each page contains:

    {
        stage  => 'page_name',
        title  => 'Page Title',
        hide   => 0/1,  # optional
        fields => [
            {
                name   => 'field_name',
                desc   => 'Field Label',
                type   => 'Text',
                pretty => 'Formatted value',
                value  => 'raw_value',
                hide   => 0/1,  # optional
            },
            ...
        ]
    }

=cut

sub fields_for_display {
    my ($form) = @_;

    my $things = [];
    for my $page ( @{ $form->pages } ) {
        my $x = {
            stage => $page->{name},
            title => $page->{title},
            ( $page->tag_exists('hide') ? ( hide => $page->get_tag('hide') ) : () ),
            fields => []
        };

        for my $f ( @{ $page->fields } ) {
            my $field = $form->field($f);
            next if $field->type eq 'Submit';
            my $value = $form->saved_data->{$field->{name}} // '';
            push @{$x->{fields}}, {
                name => $field->{name},
                desc => $field->{label},
                type => $field->type,
                pretty => $form->format_for_display( $field->{name}, $value ),
                value => $value,
                ( $field->tag_exists('hide') ? ( hide => $field->get_tag('hide') ) : () ),
            };
        }

        push @$things, $x;
    }

    return $things;
}

=head2 format_for_display

Converts a field value to a human-readable format for display.

Handles special cases:
- Select fields: returns the label for the selected value
- DateTime fields: formats as day/month/year
- Checkbox fields: returns 'Yes' or 'No'
- FileIdUpload fields: returns comma-separated filenames

=cut

sub format_for_display {
    my ($form, $field_name, $value) = @_;
    my $field = $form->field($field_name);

    if ( $field->{type} eq 'Select' ) {
        # Find label for the selected value
        for my $opt (@{$field->options}) {
            return $opt->{label} if defined $opt->{value} && $opt->{value} eq $value;
        }
        return $value;
    } elsif ( $field->{type} eq 'DateTime' ) {
        if ( ref $value eq 'DateTime' ) {
            return join( '/', $value->day, $value->month, $value->year);
        } elsif ( ref $value eq 'HASH' && $value->{day} ) {
            return "$value->{day}/$value->{month}/$value->{year}";
        }
        return "";
    } elsif ( $field->{type} eq 'Checkbox' ) {
        return $value ? 'Yes' : 'No';
    } elsif ( $field->{type} eq 'FileIdUpload' ) {
        if ( ref $value eq 'HASH' && $value->{filenames} ) {
            return join( ', ', @{ $value->{filenames} } );
        }
        return "";
    }

    return $value // '';
}

1;
