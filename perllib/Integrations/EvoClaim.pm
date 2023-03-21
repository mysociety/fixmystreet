package Integrations::EvoClaim;

use Moo;
use LWP::UserAgent;
use JSON::MaybeXS;
use MIME::Base64;
use Digest::SHA qw(hmac_sha256);
use Digest::MD5;
use DateTime;
use URI::Escape qw(uri_escape);
use Types::Standard qw(Str);
use Path::Tiny;
use Try::Tiny;
use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::App::Form::Claims;
use FixMyStreet::App::Model::PhotoSet;

=head1 NAME

Integrations::EvoClaim - Integration with DWF's EvoClaim system

=head1 SYNOPSIS

  my $evo_claim = Integrations::EvoClaim->new(
      base_url => $base_url,
      app_id   => $app_id,
      api_key  => $api_key,
  );
  $evo_claim->send_claims($problems, $bucks_cobrand);

=head1 DESCRIPTION

Sends claim data along with associated photos and files to EvoClaim.

=head1 ATTRIBUTES

=head2 base_url

The base URL of the EvoClaim API.

=head2 app_id

The application ID for the EvoClaim API.

=head2 api_key

The API key for the EvoClaim API.

=head2 user_agent

The LWP::UserAgent object to use for making requests to the API.
(Optional, defaults to a new LWP::UserAgent object.)

=head2 claims_files_directory

The directory where files associated with claims are stored.
(Optional, defaults to the value of the 'UPLOAD_DIR' key in the
'PHOTO_STORAGE_OPTIONS' config setting.)

=head2 verbose

Whether to print verbose messages. (Optional, defaults to 0.)

=cut

has base_url => (is => 'ro', isa => Str, required => 1);

has app_id => (is => 'ro', isa => Str, required => 1);

has api_key => (is => 'ro', isa => Str, required => 1);

has user_agent => (is => 'ro', default => sub { LWP::UserAgent->new });

has claims_files_directory => (is => 'ro', isa => Str, default => sub {
    path(
        FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{UPLOAD_DIR},
        "claims_files"
    )->absolute(FixMyStreet->path_to())->stringify
});

has verbose => (is => 'rw', default => 0);

=head1 METHODS

=head2 send_claims

  $evo_claim->send_claims($problems, $bucks_cobrand);

Send claims to EvoClaim API. The $problems argument should be an iterator
of FixMyStreet::DB::Result::Problem objects.

=cut

sub send_claims {
    my ($self, $problems, $cobrand) = @_;

    # If there are no problems then print a message and exit
    if ($problems->count == 0) {
        print "No claims to send to EVO\n" if $self->verbose;
        return;
    }

    while (my $problem = $problems->next) {
        # Check this problem is a claim
        if ($problem->cobrand_data ne 'claim') {
            print "Skipping problem ID: " . $problem->id . " as it is not a claim\n" if $self->verbose;
            next;
        }

        print "Processing problem ID: " . $problem->id . "\n" if $self->verbose;

        # If the problem was created more than 2 days ago print a warning
        my $two_days_ago = DateTime->now->subtract(days => 2);
        if ($problem->created < $two_days_ago) {
            print "WARNING: Claim with problem ID: " . $problem->id . " was created more than 2 days ago. Is there a problem sending it?\n";
        }

        my $fields = $self->_claim_form_fields;
        my $where_cause_options = $self->_where_cause_options;

        my $data = $problem->get_extra_metadata;

        my @photo_field_names = qw(photos property_photos vehicle_photos);
        my @file_field_names = qw(property_insurance property_invoices v5 vehicle_receipts);

        # Create a JSON object using the field names and populate it with the data
        my $json = {};
        for my $field_name (sort @$fields) {
            if (ref $data->{$field_name} eq 'HASH' && exists $data->{$field_name}{year}) {
                my $date = sprintf("%04d-%02d-%02d", $data->{$field_name}{year}, $data->{$field_name}{month}, $data->{$field_name}{day});
                $json->{$field_name} = $date;
                next;
            }

            my $filename_prefix = $problem->id . "_$field_name";

            # If the field is a photo field, process the photos and add the file IDs to the JSON object
            if (grep { $_ eq $field_name } @photo_field_names) {
                $json->{$field_name} = $self->_process_photos($data->{$field_name}, $filename_prefix);
                next;
            }

            # If the field is a file field, process the files and add the file IDs to the JSON object
            if (grep { $_ eq $field_name } @file_field_names) {
                $json->{$field_name} = $self->_process_files($data->{$field_name}, $filename_prefix);
                next;
            }

            # If it's the where_cause field then lookup the "pretty" name of the field from the form
            if ($field_name eq 'where_cause') {
                my $where_cause = $data->{$field_name};
                my $where_cause_pretty = $where_cause_options->{$where_cause};
                $json->{$field_name} = $where_cause_pretty;
                next;
            }

            # If it's the location field then populate with the claim location from the cobrand
            if ($field_name eq 'location') {
                $json->{$field_name} = $cobrand->claim_location($problem);
                next;
            }

            if ($field_name eq 'report_id') {
                $json->{$field_name} = $problem->id;
                next;
            }

            $json->{$field_name} = $data->{$field_name};
        }

        $json->{fault_id} = $data->{report_id};

        $self->_submit_claim_fnol($json);

        # Mark the problem as sent to EVO
        $problem->set_extra_metadata( sent_to_evo => 1 );
        $problem->update;

        print "FNOL submitted successfully for problem ID: " . $problem->id . "\n" if $self->verbose;
    }
}

# Private methods related to processing claims.

sub _claim_form_fields {
    my $self = shift;

    my $form = FixMyStreet::App::Form::Claims->new( page_name => 'intro' );
    my %fields;
    for my $page ( @{ $form->pages } ) {
        for my $field_name ( @{ $page->{fields} } ) {
            my $field = $form->field($field_name);
            next if $field->type eq 'Submit';
            next if $field->name =~ /_fileid$/;
            next if $field->name eq 'location_matches';
            $fields{$field->name} = 1;
        }
    }

    return [ sort keys %fields ];
}

sub _where_cause_options {
    my $self = shift;

    my $form = FixMyStreet::App::Form::Claims->new( page_name => 'intro' );
    my $field = $form->field('where_cause');
    my %options = map { $_->{value} => $_->{label} } @{ $field->options };
    return \%options;
}

sub _process_photos {
    my ($self, $photos, $filename_prefix) = @_;

    return [] unless $photos;

    my $photoset = FixMyStreet::App::Model::PhotoSet->new({
        db_data => $photos,
    });

    my $num = $photoset->num_images;
    my @uploaded_photos;
    foreach (0..$num-1) {
        my $image = $photoset->get_raw_image($_);
        my $file_name = $filename_prefix . "_$_." . $image->{extension};
        my $file_content_base64 = encode_base64($image->{data});

        my $response = $self->_submit_claim_fnol_file($file_name, $file_content_base64);
        push @uploaded_photos, $file_name;
    }

    return \@uploaded_photos;
}

sub _process_files {
    my ($self, $file, $filename_prefix) = @_;

    # If file is not present, return an empty array
    return [] unless $file;

    my $id_with_ext = $file->{files};
    my $file_name = $filename_prefix . "_" . $id_with_ext;
    my $dir = $self->claims_files_directory;
    my $file_content = path($dir, $id_with_ext)->slurp_raw;
    my $file_content_base64 = encode_base64($file_content);

    my $response = $self->_submit_claim_fnol_file($file_name, $file_content_base64);
    return [ $file_name ];
}

# Private methods related to API calls.

sub _submit_claim_fnol_file {
    my ($self, $file_name, $file_content_base64) = @_;

    my $request_url = $self->base_url . '/api/SubmitClaimFnolFile';
    my $request_data = encode_json({ FileName => $file_name, FileContent => $file_content_base64 });
    my $request_headers = $self->_build_headers('POST', $request_url, $request_data);
    print "Sending $file_name\n" if $self->verbose;
    my $response = $self->user_agent->post($request_url, Content => $request_data, %$request_headers);

    print "Submit claim file response: " . $response->content . "\n" if $self->verbose;

    return $self->_handle_response($response);
}

sub _submit_claim_fnol {
    my ($self, $fnol_data) = @_;

    my $request_url = $self->base_url . '/api/SubmitClaimFnol';
    my $request_data = encode_json($fnol_data);
    my $request_headers = $self->_build_headers('POST', $request_url, $request_data);
    print "Sending FNOL\n" if $self->verbose;
    my $response = $self->user_agent->post($request_url, Content => $request_data, %$request_headers);

    print "Submit FNOL response: " . $response->content . "\n" if $self->verbose;

    return $self->_handle_response($response);
}

# Private methods related to API request handling.

sub _build_headers {
    my ($self, $request_method, $request_url, $request_data) = @_;

    my $request_uri = lc(uri_escape(lc($request_url)));
    my $request_time_stamp = time();
    my $nonce = Crypt::Misc::random_v4uuid();

    my $request_content_base64_string = '';
    if (defined $request_data && length($request_data) > 0) {
        my $md5 = Digest::MD5::md5($request_data);
        $request_content_base64_string = encode_base64($md5, '');
    }

    my $signature_raw_data = join('', $self->app_id, $request_method, $request_uri, $request_time_stamp, $nonce, $request_content_base64_string);
    my $request_signature_base64 = encode_base64(hmac_sha256($signature_raw_data, decode_base64($self->api_key)), '');
    my $hmac_auth = "hmacauth " . join(':', $self->app_id, $request_signature_base64, $nonce, $request_time_stamp);

    return {
        'Content-Type' => 'application/json',
        'Authorization' => $hmac_auth,
    };
}

sub _handle_response {
    my ($self, $response) = @_;
    my $decoded_response;

    try {
        $decoded_response = decode_json($response->content);
    } catch {
        die "Error decoding JSON response: $_\n" . $response->status_line . "\n" . $response->content;
    };

    if ($response->is_success) {
        return $decoded_response;
    }

    # Handle known errors
    if ($response->code == 400 && exists $decoded_response->{Data}{Error}) {
        my @errors = @{$decoded_response->{Data}{Error}};

        foreach my $error (@errors) {
            if ($error->{Code} eq 'FNOL02') {
                print "File already exists. Skipping...\n" if $self->verbose;
                return $decoded_response;
            } else {
                die "FNOL Error: " . $error->{Code} . " - " . $error->{Message} . "\n";
            }
        }
    }

    # Unknown error
    die "HTTP Error: " . $response->status_line . "\n" . $response->content;
}

__PACKAGE__->meta->make_immutable;

1;
