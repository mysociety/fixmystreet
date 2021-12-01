package FixMyStreet::Cobrand::Buckinghamshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Path::Tiny;
use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::BoroughEmails';
use SUPER;

sub council_area_id { return 2217; }
sub council_area { return 'Buckinghamshire'; }
sub council_name { return 'Buckinghamshire Council'; }
sub council_url { return 'buckinghamshire'; }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Buckinghamshire';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.7852948471218,-0.812140044990842',
        span   => '0.596065946222112,0.664092167105497',
        bounds => [ 51.4854160129405, -1.1406945585036, 52.0814819591626, -0.476602391398098 ],
    };
}

sub on_map_default_status { ('open', 'fixed') }

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    # updated to match Oxon CC
    return 'grey' if $p->state eq 'not responsible' || !$self->owns_problem( $p );
    return 'grey' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons {
    return '/cobrands/oxfordshire/images/';
}

sub admin_user_domain { ( 'buckscc.gov.uk', 'buckinghamshire.gov.uk' ) }

sub send_questionnaires {
    return 0;
}

sub open311_extra_data_exclude { [ 'road-placement' ] }

sub open311_pre_send {
    my ($self, $row, $open311) = @_;
    if ($row->category eq 'Claim') {
        if ($row->get_extra_metadata('fault_fixed') eq 'Yes') {
            # We want to send to Confirm, but with slightly altered information
            $row->update_extra_field({ name => 'title', value => $row->get_extra_metadata('direction') }); # XXX See doc note
            $row->update_extra_field({ name => 'description', value => $row->get_extra_metadata('describe_cause') });
        } else {
            # We do not want to send to Confirm, only email
            return 'SKIP';
        }
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful (or a non-Open311 Claim)
    my $non_open311_claim = $row->category eq 'Claim' && $row->get_extra_metadata('fault_fixed') ne 'Yes';
    return unless $row->external_id || $non_open311_claim;
    return if $row->get_extra_metadata('extra_email_sent');

    # For certain categories, send an email also
    my $emails = $self->feature('open311_email');
    my $addresses = {
        'Flytipping' => [ $emails->{flytipping}, "TfB" ],
        'Blocked drain' => [ $emails->{flood}, "Flood Management" ],
        'Ditch issue' => [ $emails->{flood}, "Flood Management" ],
        'Flooded subway' => [ $emails->{flood}, "Flood Management" ],
        'Claim' => [ $emails->{claim}, 'TfB' ],
    };
    my $dest = $addresses->{$row->category};
    return unless $dest;

    my $sender = FixMyStreet::SendReport::Email->new( to => [ $dest ] );
    if (!$sender->send($row, $h)) {
        $row->set_extra_metadata(extra_email_sent => 1);
    }
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{mark_reopen} = 1;
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    push @$meta, {
        code => 'road-placement',
        datatype => 'singlevaluelist',
        description => 'Is the fly-tip located on',
        order => 100,
        required => 'true',
        variable => 'true',
        values => [
            { key => 'road', name => 'The road' },
            { key => 'off-road', name => 'Off the road/on a verge' },
        ],
    } if $service->{service_name} eq 'Flytipping';
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    return unless $report->category eq 'Flytipping';
    return unless $self->{c}->stash->{report}->to_body_named('Buckinghamshire');

    my $placement = $self->{c}->get_param('road-placement');
    return unless $placement && $placement eq 'off-road';

    $report->category('Flytipping (off-road)');
}

sub filter_report_description {
    my ($self, $description) = @_;

    # this allows _ in the domain name but I figure it's unlikely to
    # generate false positives so lets go with that for the same of
    # a simpler regex
    $description =~ s/\b[\w.!#$%&'*+\-\/=?^_{|}~]+\@[\w\-]+\.[^ ]+\b//g;
    $description =~ s/ (?: \+ \d{2} \s? | \b 0 ) (?:
        \d{2} \s? \d{4} \s? \d{4}   # 0xx( )xxxx( )xxxx
      | \d{3} \s \d{3} \s? \d{4}    # 0xxx xxx( )xxxx
      | \d{3} \s? \d{2} \s \d{4,5}  # 0xxx( )xx xxxx(x)
      | \d{4} \s \d{5,6}            # 0xxxx xxxxx(x)
    ) \b //gx;

    return $description;
}

sub default_map_zoom { 4 }

sub _dashboard_export_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns( staff_user => 'Staff User' );

    my $user_lookup = $self->csv_staff_users;

    $csv->csv_extra_data(sub {
        my $report = shift;
        my $staff_user = $self->csv_staff_user_lookup($report->get_extra_metadata('contributed_by'), $user_lookup);
        return {
            staff_user => $staff_user,
        };
    });
}

sub dashboard_export_updates_add_columns {
    shift->_dashboard_export_add_columns(@_);
}

sub dashboard_export_problems_add_columns {
    shift->_dashboard_export_add_columns(@_);
}

# Enable adding/editing of parish councils in the admin
sub add_extra_areas {
    my ($self, $areas) = @_;

    # This is a list of all Parish Councils within Buckinghamshire,
    # taken from https://mapit.mysociety.org/area/2217/covers.json?type=CPC
    my $parish_ids = [
        "135493",
        "135494",
        "148713",
        "148714",
        "53319",
        "53360",
        "53390",
        "53404",
        "53453",
        "53486",
        "53515",
        "53542",
        "53612",
        "53822",
        "53874",
        "53887",
        "53942",
        "53991",
        "54003",
        "54014",
        "54158",
        "54174",
        "54178",
        "54207",
        "54289",
        "54305",
        "54342",
        "54355",
        "54402",
        "54465",
        "54479",
        "54493",
        "54590",
        "54615",
        "54672",
        "54691",
        "54721",
        "54731",
        "54787",
        "54846",
        "54879",
        "54971",
        "55290",
        "55326",
        "55534",
        "55638",
        "55724",
        "55775",
        "55896",
        "55900",
        "55915",
        "55945",
        "55973",
        "56007",
        "56091",
        "56154",
        "56268",
        "56350",
        "56379",
        "56418",
        "56432",
        "56498",
        "56524",
        "56592",
        "56609",
        "56641",
        "56659",
        "56664",
        "56709",
        "56758",
        "56781",
        "57099",
        "57138",
        "57330",
        "57332",
        "57366",
        "57367",
        "57507",
        "57529",
        "57582",
        "57585",
        "57666",
        "57701",
        "58166",
        "58208",
        "58229",
        "58279",
        "58312",
        "58333",
        "58405",
        "58523",
        "58659",
        "58815",
        "58844",
        "58891",
        "58965",
        "58980",
        "59003",
        "59007",
        "59012",
        "59067",
        "59144",
        "59152",
        "59179",
        "59211",
        "59235",
        "59288",
        "59353",
        "59491",
        "59518",
        "59727",
        "59763",
        "59971",
        "60027",
        "60137",
        "60321",
        "60322",
        "60438",
        "60456",
        "60462",
        "60532",
        "60549",
        "60598",
        "60622",
        "60640",
        "60731",
        "60777",
        "60806",
        "60860",
        "60954",
        "61100",
        "61102",
        "61107",
        "61142",
        "61144",
        "61167",
        "61172",
        "61249",
        "61268",
        "61269",
        "61405",
        "61445",
        "61471",
        "61479",
        "61898",
        "61902",
        "61920",
        "61964",
        "62226",
        "62267",
        "62296",
        "62311",
        "62321",
        "62431",
        "62454",
        "62640",
        "62657",
        "62938",
        "63040",
        "63053",
        "63068",
        "63470",
        "63476",
        "63501",
        "63507",
        "63517",
        "63554",
        "63715",
        "63723"
    ];
    my $ids_string = join ",", @{ $parish_ids };

    my $extra_areas = mySociety::MaPit::call('areas', [ $ids_string ]);

    my %all_areas = (
        %$areas,
        %$extra_areas
    );
    return \%all_areas;
}

# Make sure CPC areas are included in point lookups for new reports
sub add_extra_area_types {
    my ($self, $types) = @_;

    my @types = (
        @$types,
        'CPC',
    );
    return \@types;
}

sub is_two_tier { 1 }

sub should_skip_sending_update {
    my ($self, $update ) = @_;

    # Bucks don't want to receive updates into Confirm that were made by anyone
    # except the original problem reporter.
    return $update->user_id != $update->problem->user_id;
}

sub disable_phone_number_entry { 1 }

sub report_sent_confirmation_email { 'external_id' }

sub is_council_with_case_management { 1 }

# Try OSM for Bucks as it provides better disamiguation descriptions.
sub get_geocoder { 'OSM' }

sub categories_restriction {
    my ($self, $rs) = @_;

    return $rs->search( { category => { '!=', 'Flytipping (off-road)'} } );
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;
    @$contacts = grep { $_->category ne 'Claim' } @$contacts;
    $self->SUPER::munge_report_new_contacts($contacts);
}

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/bucks",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "Whole_Street",
    property => "site_code",
    accept_feature => sub {
        my $feature = shift;

        # There are only certain features we care about, the rest can be ignored.
        my @valid_types = ( "2", "3A", "3B", "4A", "4B", "HE", "HWOA", "HWSA", "P" );
        my %valid_types = map { $_ => 1 } @valid_types;
        my $type = $feature->{properties}->{feature_ty};

        return $valid_types{$type};
    }
} }

sub _lookup_site_name {
    my $self = shift;
    my $row = shift;

    my $cfg = {
        buffer => 200,
        url => "https://tilma.mysociety.org/mapserver/bucks",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Whole_Street",
        accept_feature => sub { 1 }
    };
    my ($x, $y) = $row->local_coords;
    my $features = $self->_fetch_features($cfg, $x, $y);
    return $self->_nearest_feature($cfg, $x, $y, $features);
}

around 'munge_sendreport_params' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    if ($row->category eq 'Claim') {
        # Update subject
        my $type = $row->get_extra_metadata('what');
        my $name = $row->name;
        my $road = $self->_lookup_site_name($row);
        my $site_name = $road->{properties}->{site_name};
        $site_name =~ s/([\w']+)/\u\L$1/g;
        my $area_name = $road->{properties}->{area_name};
        $area_name =~ s/([\w']+)/\u\L$1/g;
        my $external_id = $row->external_id || $row->get_extra_metadata('report_id') || '(no ID)';
        my $subject = "New claim - $type - $name - $external_id - $site_name, $area_name";
        $params->{Subject} = $subject;

        my $user = $self->body->comment_user;
        if ( $user ) {
            # Attach auto-response template if present
            my $template = $row->response_templates->search({ 'me.state' => $row->state })->first;
            my $description = $template->text if $template;
            if ( $description ) {
                my $updates = Open311::GetServiceRequestUpdates->new(
                    system_user => $user,
                    current_body => $self->body,
                    blank_updates_permitted => 1,
                );

                my $request = {
                    service_request_id => $row->id,
                    update_id => 'auto-internal',
                    # Add a second so it is definitely later than problem confirmed timestamp,
                    # which uses current_timestamp (and thus microseconds) whilst this update
                    # is rounded down to the nearest second
                    comment_time => DateTime->now->add( seconds => 1 ),
                    status => 'open',
                    description => $description,
                };
                my $update = $updates->process_update($request, $row);
                if ($update) {
                    $h->{update} = {
                        item_text => $update->text,
                        item_extra => $update->get_column('extra'),
                    };

                    # Stop any alerts being sent out about this update as included here.
                    my @alerts = FixMyStreet::DB->resultset('Alert')->search({
                        alert_type => 'new_updates',
                        parameter => $row->id,
                        confirmed => 1,
                    });
                    for my $alert (@alerts) {
                        my $alerts_sent = FixMyStreet::DB->resultset('AlertSent')->find_or_create({
                            alert_id  => $alert->id,
                            parameter => $update->id,
                        });
                    }
                }
            }
        }

        # Attach photos and documents
        my @photos = grep { $_ } (
            $row->photo,
            $row->get_extra_metadata('vehicle_photos'),
            $row->get_extra_metadata('property_photos'),
        );
        my $photoset = FixMyStreet::App::Model::PhotoSet->new({
            db_data => join(',', @photos),
        });

        my $num = $photoset->num_images;
        my $id = $row->id;
        my @attachments;
        foreach (0..$num-1) {
            my $image = $photoset->get_raw_image($_);
            push @attachments, {
                body => $image->{data},
                attributes => {
                    filename => "$id.$_." . $image->{extension},
                    content_type => $image->{content_type},
                    encoding => 'base64', # quoted-printable ends up with newlines corrupting binary data
                    name => "$id.$_." . $image->{extension},
                },
            };
        }

        my @files = grep { $_ } (
            $row->get_extra_metadata('v5'),
            $row->get_extra_metadata('vehicle_receipts'),
            $row->get_extra_metadata('tyre_receipts'),
            $row->get_extra_metadata('property_insurance'),
            $row->get_extra_metadata('property_invoices'),
        );
        foreach (@files) {
            my $filename = $_->{filenames}[0];
            my $id = $_->{files};
            my $dir = FixMyStreet->config('PHOTO_STORAGE_OPTIONS')->{UPLOAD_DIR};
            $dir = path($dir, "claims_files")->absolute(FixMyStreet->path_to());
            my $data = path($dir, $id)->slurp_raw;
            push @attachments, {
                body => $data,
                attributes => {
                    filename => $filename,
                    #content_type => $image->{content_type},
                    encoding => 'base64', # quoted-printable ends up with newlines corrupting binary data
                    name => $filename,
                },
            };
        }

        $params->{_attachments_} = \@attachments;
        return;
    }

    # The district areas don't exist in MapIt past generation 36, so look up
    # what district this report would have been in and temporarily override
    # the areas column so BoroughEmails::munge_sendreport_params can do its
    # thing.
    my ($lat, $lon) = ($row->latitude, $row->longitude);
    my $district = FixMyStreet::MapIt::call( 'point', "4326/$lon,$lat", type => 'DIS', generation => 36 );
    ($district) = keys %$district;

    my $original_areas = $row->areas;
    $row->areas(",$district,");

    $self->$orig($row, $h, $params);

    $row->areas($original_areas);
};

sub council_rss_alert_options {
    my ($self, @args) = @_;
    my ($options) = super();

    # rename old district councils to 'area' and remove 'ward' from their wards
    # remove 'County' from Bucks Council name
    for my $area (@$options) {
        for my $key (qw(rss_text text)) {
            $area->{$key} =~ s/District Council/area/ && $area->{$key} =~ s/ ward//;
            $area->{$key} =~ s/ County//;
        }
    }

    return ($options);
}

1;
