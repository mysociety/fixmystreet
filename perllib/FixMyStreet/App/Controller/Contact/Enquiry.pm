package FixMyStreet::App::Controller::Contact::Enquiry;

use Moose;
use namespace::autoclean;
use Path::Tiny 'path';
use File::Copy;
use Digest::SHA qw(sha1_hex);

BEGIN { extends 'Catalyst::Controller'; }

sub auto : Private {
    my ($self, $c) = @_;
    $c->forward('cobrand_enquiry_check');
    $c->forward('/auth/get_csrf_token');
    $c->cobrand->call_hook('setup_general_enquiries_stash');
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

    $c->set_param('pc', '');
    $c->set_param('non_public', 1);
    $c->set_param('skipped', 1);
    $c->set_param('title', "General Enquiry");
    $c->stash->{latitude} = 51.469;
    $c->stash->{longitude} = -0.35;

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
    $report->user->update_or_insert unless $report->user->in_storage;
    $report->confirm();
    $report->update_or_insert;
}

sub handle_uploads : Private {
    my ( $self, $c ) = @_;

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
            $self->_base64_decode_upload($upload);
            # Hash each file to get its filename
            my $key = sha1_hex($upload->slurp);
            my $out = path($dir, $key);
            unless (copy($upload->tempname, $out)) {
                $c->log->info('Couldn\'t copy temp file to destination: ' . $!);
                $c->stash->{photo_error} = _("Sorry, we couldn't save your file(s), please try again.");
                return;
            }
            # Then store the file hashes in report->extra along with the original filenames
            $files->{$key} = $upload->filename;
        }
    }
    $c->session->{enquiry_files} = $files;
    $c->stash->{report}->set_extra_metadata(enquiry_files => $files);
}

sub cobrand_enquiry_check : Private {
    my ( $self, $c ) = @_;

    $c->res->redirect( '/' ) and return unless $c->cobrand->call_hook('allow_general_enquiries');
}

sub _base64_decode_upload {
    my ( $self, $upload ) = @_;

    # base64 decode the file if it's encoded that way
    # Catalyst::Request::Upload doesn't do this automatically
    # unfortunately.
    my $transfer_encoding = $upload->headers->header('Content-Transfer-Encoding');
    if (defined $transfer_encoding && $transfer_encoding eq 'base64') {
        my $decoded = decode_base64($upload->slurp);
        if (open my $fh, '>', $upload->tempname) {
            binmode $fh;
            print $fh $decoded;
            close $fh
        } else {
            my $c = $self->c;
            $c->log->info('Couldn\'t open temp file to save base64 decoded image: ' . $!);
            $c->stash->{photo_error} = _("Sorry, we couldn't save your file(s), please try again.");
            return ();
        }
    }

}

1;
