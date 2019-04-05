package FixMyStreet::App::Controller::Contact::Enquiry;

use Moose;
use namespace::autoclean;
use Path::Tiny;
use File::Copy;
use Digest::SHA qw(sha1_hex);
use File::Basename;

BEGIN { extends 'Catalyst::Controller'; }

sub auto : Private {
    my ($self, $c) = @_;

    unless ( $c->cobrand->call_hook('setup_general_enquiries_stash') ) {
        $c->res->redirect( '/' );
        $c->detach;
    }
}

# This needs to be defined here so /contact/begin doesn't get run instead.
sub begin : Private {
    my ($self, $c) = @_;

    $c->forward('/begin');
}

sub index : Path : Args(0) {
    my ( $self, $c, $preserve_session ) = @_;

    # Make sure existing files aren't lost if we're rendering this
    # page as a result of validation error.
    delete $c->session->{enquiry_files} unless $preserve_session;

    $c->stash->{field_errors}->{name} = _("Please enter your full name.") if $c->stash->{field_errors}->{name};
}

sub submit : Path('submit') : Args(0) {
    my ( $self, $c ) = @_;

    unless ($c->req->method eq 'POST' && $c->forward("/report/new/check_form_submitted") ) {
        $c->res->redirect( '/contact/enquiry' );
        return;
    }

    # General enquiries are always private reports, and aren't
    # located by the user on the map
    $c->set_param('non_public', 1);
    $c->set_param('pc', '');
    $c->set_param('skipped', 1);

    $c->forward('/report/new/initialize_report');
    $c->forward('/report/new/check_for_category');
    $c->forward('/auth/check_csrf_token');
    $c->forward('/report/new/process_report');
    $c->forward('/report/new/process_user');
    $c->forward('handle_uploads');
    $c->forward('/photo/process_photo');
    $c->go('index', [ 1 ]) unless $c->forward('/report/new/check_for_errors');
    $c->forward('/report/new/save_user_and_report');
    $c->forward('confirm_report');
    $c->stash->{success} = 1;

    # Don't want these lingering around for the next time.
    delete $c->session->{enquiry_files};
}

sub confirm_report : Private {
    my ( $self, $c ) = @_;

    my $report = $c->stash->{report};

    # We don't ever want to modify an existing user, as general enquiries don't
    # require any kind of email confirmation.
    $report->user->insert unless $report->user->in_storage;
    $report->confirm();
    $report->update;
}

sub handle_uploads : Private {
    my ( $self, $c ) = @_;

    # NB. For simplicity's sake this relies on the UPLOAD_DIR config key provided
    # when using the FileSystem PHOTO_STORAGE_BACKEND. Should your FMS site not
    # be using this storage backend, you must ensure that UPLOAD_DIR is set
    # in order for general enquiries uploads to work.
    my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
    my $dir = $cfg ? $cfg->{UPLOAD_DIR} : FixMyStreet->config('UPLOAD_DIR');
    $dir = path($dir, "enquiry_files")->absolute(FixMyStreet->path_to());
    $dir->mkpath;

    my $files = $c->session->{enquiry_files} || {};
    foreach ($c->req->upload) {
        my $upload = $c->req->upload($_);
        if ($upload->type !~ /^image/) {
            # It's not a photo so remove it before /photo/process_photo rejects it
            delete $c->req->uploads->{$_};

            # For each file, copy it into place in a subdir of PHOTO_STORAGE_OPTIONS.UPLOAD_DIR
            FixMyStreet::PhotoStorage::base64_decode_upload($c, $upload);
            # Hash each file to get its filename, but preserve the file extension
            # so content-type is correct when POSTing to Open311.
            my ($p, $n, $ext) = fileparse($upload->filename, qr/\.[^.]*/);
            my $key = sha1_hex($upload->slurp) . $ext;
            my $out = path($dir, $key);
            unless (copy($upload->tempname, $out)) {
                $c->log->info('Couldn\'t copy temp file to destination: ' . $!);
                $c->stash->{photo_error} = _("Sorry, we couldn't save your file(s), please try again.");
                return;
            }
            # Then store the file hashes in report->extra along with the original filenames
            $files->{$key} = $upload->raw_basename;
        }
    }
    $c->session->{enquiry_files} = $files;
    $c->stash->{report}->set_extra_metadata(enquiry_files => $files);
}

1;
