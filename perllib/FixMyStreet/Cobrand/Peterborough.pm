=head1 NAME

FixMyStreet::Cobrand::Peterborough - code specific to the Peterborough cobrand

=head1 SYNOPSIS

We integrate with Peterborough's Confirm back end.
We also integrate with Bartec for waste collection services, including bulky
waste collection.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Peterborough;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use utf8;
use strict;
use warnings;
use Utils;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::Open311Multi';
with 'FixMyStreet::Cobrand::Peterborough::Waste';

=head2 Defaults

=over 4

=cut

sub council_area_id { 2566 }
sub council_area { 'Peterborough' }
sub council_name { 'Peterborough City Council' }
sub council_url { 'peterborough' }

=item * Admin user domain is 'peterborough.gov.uk'

=cut

sub admin_user_domain { "peterborough.gov.uk" }

=item * Default map zoom is set to 5

=cut

sub default_map_zoom { 5 }

=item * We do not send questionnaires

=cut

sub send_questionnaires { 0 }

=item * Max title length is 50

=cut

sub max_title_length { 50 }

=item * We allow 'display_name' as an extra field on contacts

=back

=cut

sub contact_extra_fields { [ 'display_name' ] }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.6085234396978,-0.253091266573947',
        bounds => [ 52.5060949603654, -0.497663559599628, 52.6752139533306, -0.0127696975457487 ],
    };
}

sub geocoder_munge_results {
    my ($self, $result) = @_;
    $result->{display_name} = '' unless $result->{display_name} =~ /City of Peterborough/;
    $result->{display_name} =~ s/, UK$//;
    $result->{display_name} =~ s/, United Kingdom$//;
    $result->{display_name} =~ s/, City of Peterborough, East of England, England//;
    $result->{display_name} =~ s/, City of Peterborough, Cambridgeshire and Peterborough, England//;
}

=head2 (around) open311_update_missing_data

If we have a UPRN (a waste report), we do not need to look up the site code.
This hooks around the default from Roles::ConfirmOpen311.

=cut

around open311_update_missing_data => sub {
    my ($orig, $self, $row, $h, $contact) = @_;
    return if $row->get_extra_field_value('uprn');
    return $self->$orig($row, $h, $contact);
};

around open311_extra_data_include => sub {
    my ($orig, $self, $row, $h) = @_;

    my $open311_only = $self->$orig($row, $h);
    foreach (@$open311_only) {
        if ($_->{name} eq 'description') {
            my ($ref) = grep { $_->{name} =~ /pcc-Skanska-csc-ref/i } @{$row->get_extra_fields};
            $_->{value} .= "\n\nSkanska CSC ref: $ref->{value}" if $ref;
        }
    }
    if ( $row->geocode && $row->contact->email =~ /Bartec/ ) {
        my $parts = $row->nearest_address_parts;
        if ($parts->{number} || $parts->{street} || $parts->{postcode}) {
            push @$open311_only, (
                { name => 'postcode', value => $parts->{postcode} },
                { name => 'house_no', value => $parts->{number} },
                { name => 'street', value => $parts->{street} }
            );
        }
    }
    if ( $row->contact->email =~ /Bartec/ && $row->get_extra_metadata('contributed_by') ) {
        push @$open311_only, (
            {
                name => 'contributed_by',
                value => $self->csv_staff_user_lookup($row->get_extra_metadata('contributed_by'), $self->csv_staff_users),
            },
        );
    }
    return $open311_only;
};
# remove categories which are informational only
sub open311_extra_data_exclude {
    my ($self, $row, $h) = @_;
    # We need to store this as Open311 pre_send needs to check it and it will
    # have been removed due to this function.
    $self->{cache_pcc_witness} = $row->get_extra_field_value('pcc-witness');
    [ '^PCC-', '^emergency$', '^private_land$', '^extra_detail$' ]
}

sub lookup_site_code_config { {
    buffer => 50, # metres
    url => 'https://peterborough.assets/7/query?',
    type => 'arcgis',
    outFields => 'USRN',
    property => "USRN",
    accept_feature => sub { 1 },
    accept_types => { Polygon => 1 },
} }

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # Peterborough want to make it clear in Confirm when an update has come
    # from FMS.
    $params->{description} = "[Customer FMS update] " . $params->{description};

    # Send the FMS problem ID with the update.
    $params->{service_request_id_ext} = $comment->problem->id;
}

sub updates_sent_to_body {
    my ($self, $problem) = @_;

    my $code = $problem->contact->email;
    return 0 if $code =~ /^Bartec/;
    return 1;
}

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $code = $update->problem->contact->email;
    return 1 if $code =~ /^Bartec/;
    return 0;
}

around 'open311_config' => sub {
    my ($orig, $self, $row, $h, $params, $contact) = @_;

    $params->{upload_files} = 1;
    $self->$orig($row, $h, $params, $contact);
};

sub get_body_sender {
    my ($self, $body, $problem) = @_;
    my %flytipping_cats = map { $_ => 1 } @{ $self->_flytipping_categories };

    my ($x, $y) = Utils::convert_latlon_to_en(
        $problem->latitude,
        $problem->longitude,
        'G'
    );
    if ( $flytipping_cats{ $problem->category } ) {
        # look for land belonging to the council
        my $features = $self->_fetch_features(
            {
                type => 'arcgis',
                url => 'https://peterborough.assets/4/query?',
                buffer => 1,
            },
            $x,
            $y,
        );

        # if not then check if it's land leased out or on a road.
        unless ( $features && scalar @$features ) {
            my $leased_features = $self->_fetch_features(
                {
                    type => 'arcgis',
                    url => 'https://peterborough.assets/3/query?',
                    buffer => 1,
                },
                $x,
                $y,
            );

            # some PCC land is leased out and not dealt with in bartec
            $features = [] if $leased_features && scalar @$leased_features;

            # if it's not council, or leased out land check if it's on an
            # adopted road
            unless ( $leased_features && scalar @$leased_features ) {
                my $road_features = $self->_fetch_features(
                    {
                        buffer => 1, # metres
                        type => 'arcgis',
                        url => 'https://peterborough.assets/7/query?',
                    },
                    $x,
                    $y,
                );

                $features = $road_features if $road_features && scalar @$road_features;
            }
        }

        # is on land that is handled by bartec so send
        if ( $features && scalar @$features ) {
            return $self->SUPER::get_body_sender($body, $problem);
        }

        # neither of those so just send email for records
        my $emails = $self->feature('open311_email');
        if ( $emails->{flytipping} ) {
            my $contact = $self->SUPER::get_body_sender($body, $problem)->{contact};
            $problem->set_extra_metadata('flytipping_email' => $emails->{flytipping});
            $self->{cache_flytipping_email} = 1; # This is available in post_report_sent
            return { method => 'Email', contact => $contact};
        }
    }

    return $self->SUPER::get_body_sender($body, $problem);
}

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    if ( $row->get_extra_metadata('flytipping_email') ) {
        $params->{To} = [ [
            $row->get_extra_metadata('flytipping_email'), $self->council_name
        ] ];
    }
}

sub _witnessed_general_flytipping {
    my ($self, $row) = @_;
    my $witness = $self->{cache_pcc_witness} || '';
    return ($row->category eq 'General fly tipping' && $witness eq 'yes');
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;
    return 'SKIP' if $self->_witnessed_general_flytipping($row);

    # This is a temporary addition to workaround an issue with the bulky goods
    # backend Peterborough are using.
    # In addition to sending the booking details as extra fields in the usual
    # manner, we concatenate all relevant details into the report's title field,
    # which is displayed as a service request note in Bartec.
    if ($row->category eq 'Bulky collection') {
        my $title = "Crew notes: " . ( $row->get_extra_field_value("CREW NOTES") || "" );
        $title .= "\n\nItems:\n";

        my $max = $self->bulky_items_maximum;
        for (1..$max) {
            my $two = sprintf("%02d", $_);
            if (my $item = $row->get_extra_field_value("ITEM_$two")) {
                $title .= "$two. $item\n";
            }
        }
        $row->update_extra_field({ name => "title", value => $title});
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    my $send_email = $row->external_id || $self->_witnessed_general_flytipping($row);
    return unless $send_email;

    my $emails = $self->feature('open311_email');
    my %flytipping_cats = map { $_ => 1 } @{ $self->_flytipping_categories };
    if ( $emails->{flytipping} && $flytipping_cats{$row->category} ) {
        my $dest = [ $emails->{flytipping}, "Environmental Services" ];
        my $sender = FixMyStreet::SendReport::Email->new( to => [ $dest ] );
        $sender->send($row, $h);
    }
}

sub suppress_report_sent_email {
    my ($self, $report) = @_;
    return 1 if $report->category eq 'Bulky cancel' && $report->get_extra_metadata('bulky_amendment_cancel');
    return 0;
}

sub post_report_sent {
    my ($self, $problem) = @_;

    if ( $self->{cache_flytipping_email} ) {
        my $template = 'report/new/flytipping_text.html';
        $template = 'report/new/graffiti_text.html' if $problem->category =~ /graffiti/i;
        $self->_post_report_sent_close($problem, $template);
    }
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;
    my $uri = URI->new( $cfg->{url} );
    if ( $cfg->{type} && $cfg->{type} eq 'arcgis' ) {
        $uri->query_form(
            inSR => 27700,
            outSR => 3857,
            f => "geojson",
            geometry => $cfg->{bbox},
            outFields => $cfg->{outFields},
        );
        return URI->new(
            'https://tilma.mysociety.org/resource-proxy/proxy.php?' .
            $uri
        );
    } else {
        return $self->SUPER::_fetch_features_url($cfg);
    }
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    my @contacts = $csv->body->contacts->order_by('category')->all;
    my %extra_columns;
    foreach my $contact (@contacts) {
        foreach (@{$contact->get_metadata_for_storage}) {
            next unless $_->{code} =~ /^PCC-/i;
            $extra_columns{"extra.$_->{code}"} = $_->{description};
        }
    }
    my @extra_columns = map { $_ => $extra_columns{$_} } sort keys %extra_columns;

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        usrn => 'USRN',
        nearest_address => 'Nearest address',
        external_id => 'External ID',
        external_status_code => 'External status code',
        @extra_columns,
    );

    if ($csv->dbi) {
        $csv->csv_extra_data(sub {
            my $report = shift;

            my $addr = FixMyStreet::Geocode::Address->new($report->{geocode});
            my $address = $addr->summary;
            my $ext_code = $csv->_extra_metadata($report, 'external_status_code');
            my $state = FixMyStreet::DB->resultset("State")->display($report->{state});
            my $extra = {
                nearest_address => $address,
                external_status_code => $ext_code,
                state => $state,
                db_state => $report->{state},
            };

            foreach (@{$csv->_extra_field($report)}) {
                $extra->{usrn} = $_->{value} if $_->{name} eq 'site_code';
                $extra->{"extra.$_->{name}"} = $_->{value} if $_->{name} =~ /^PCC-/i;
            }

            return $extra;
        });
        return;
    }

    my $user_lookup = $self->csv_staff_users;

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $address = $report->nearest_address(1);
        my $staff_user = $self->csv_staff_user_lookup($report->get_extra_metadata('contributed_by'), $user_lookup);
        my $ext_code = $csv->_extra_metadata($report, 'external_status_code');
        my $state = FixMyStreet::DB->resultset("State")->display($report->state);
        my $extra = {
            nearest_address => $address,
            staff_user => $staff_user,
            external_status_code => $ext_code,
            external_id => $report->external_id,
            state => $state,
        };

        foreach (@{$csv->_extra_field($report)}) {
            $extra->{usrn} = $_->{value} if $_->{name} eq 'site_code';
            $extra->{"extra.$_->{name}"} = $_->{value} if $_->{name} =~ /^PCC-/i;
        }

        return $extra;
    });
}


sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete inactive contacts
    return $contacts->search({ state => { '!=' => 'inactive' } });
}

sub _flytipping_categories { [
    "General fly tipping",
    "Hazardous fly tipping",
    "Non offensive graffiti",
    "Offensive graffiti",
    "Offensive graffiti - STAFF ONLY",
] }

# We can resend reports upon category change
sub category_change_force_resend {
    my ($self, $old, $new) = @_;

    # Get the Open311 identifiers
    my $contacts = $self->{c}->stash->{contacts};
    ($old) = map { $_->email } grep { $_->category eq $old } @$contacts;
    ($new) = map { $_->email } grep { $_->category eq $new } @$contacts;

    return 0 if $old =~ /^Bartec/ && $new =~ /^Bartec/;
    return 0 if $old =~ /^Ezytreev/ && $new =~ /^Ezytreev/;
    return 0 if $old !~ /^(Bartec|Ezytreev)/ && $new !~ /^(Bartec|Ezytreev)/;
    return 1;
}

1;
