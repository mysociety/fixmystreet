package FixMyStreet::App::Form::Licence;

use Moose::Role;
use Path::Tiny;

=head1 NAME

FixMyStreet::App::Form::Licence - Role for TfL licence application forms

=head1 DESCRIPTION

This role provides shared functionality for all licence application forms,
including summary display methods.

File upload methods (file_upload, handle_upload, process_upload) are provided
by the base Wizard class.

=cut

# Upload directory for licence files (separate from claims)
# Note: This shadows the upload_dir from Wizard.pm when this role is composed
has upload_dir => ( is => 'ro', lazy => 1, default => sub {
    my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
    my $dir = $cfg ? $cfg->{UPLOAD_DIR} : FixMyStreet->config('UPLOAD_DIR');
    path($dir, "licence_files")->absolute(FixMyStreet->path_to())->mkdir;
});

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
