package FixMyStreet::App::Form::ManifestTheme;

use Path::Tiny;
use File::Copy;
use Digest::SHA qw(sha1_hex);
use File::Basename;
use HTML::FormHandler::Moose;
use FixMyStreet::App::Form::I18N;
use List::MoreUtils qw(uniq);
extends 'HTML::FormHandler::Model::DBIC';
use namespace::autoclean;

has 'cobrand' => ( isa => 'Str', is => 'ro' );

has '+widget_name_space' => ( default => sub { ['FixMyStreet::App::Form::Widget'] } );
has '+widget_tags' => ( default => sub { { wrapper_tag => 'p' } } );
has '+item_class' => ( default => 'ManifestTheme' );
has_field 'cobrand' => ( type => 'Select', empty_select => 'Select a cobrand', required => 1 );
has_field 'name' => ( required => 1 );
has_field 'short_name' => ( required => 1 );
has_field 'background_colour' => ( required => 0 );
has_field 'theme_colour' => ( required => 0 );
has_field 'icon' => ( required => 0, type => 'Upload', label => "Add icon" );
has_field 'delete_icon' => ( type => 'Multiple' );

sub _build_language_handle { FixMyStreet::App::Form::I18N->new }

sub options_cobrand {
    my @cobrands = uniq sort map { $_->{moniker} } FixMyStreet::Cobrand->available_cobrand_classes;
    return map { $_ => $_ } @cobrands;
}

sub validate {
    my $self = shift;

    my $value = $self->value;
    my $cobrand = $value->{cobrand} || $self->cobrand;
    my $upload = $value->{icon};

    if ( $upload ) {
        if( $upload->type !~ /^image/ ) {
            $self->field('icon')->add_error( _("File type not recognised. Please upload an image.") );
            return;
        }

        my $uri = '/theme/' . $cobrand;
        my $theme_path = path(FixMyStreet->path_to('web' . $uri));
        $theme_path->mkpath;
        FixMyStreet::PhotoStorage::base64_decode_upload(undef, $upload);
        my ($p, $n, $ext) = fileparse($upload->filename, qr/\.[^.]*/);
        my $key = sha1_hex($upload->slurp) . $ext;
        my $out = path($theme_path, $key);
        unless (copy($upload->tempname, $out)) {
            $self->field('icon')->add_error( _("Sorry, we couldn't save your file(s), please try again.") );
            return;
        }
    }

    foreach my $delete_icon ( @{ $value->{delete_icon} } ) {
        unlink FixMyStreet->path_to('web', $delete_icon);
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
