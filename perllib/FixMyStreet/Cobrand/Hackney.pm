package FixMyStreet::Cobrand::Hackney;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use JSON::MaybeXS;
use URI::Escape;
use mySociety::EmailUtil qw(is_valid_email is_valid_email_list);

sub council_area_id { return 2508; }
sub council_area { return 'Hackney'; }
sub council_name { return 'Hackney Council'; }
sub council_url { return 'hackney'; }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Hackney';

    # Teale Street is on the boundary with Tower Hamlets and
    # shows the 'please use fixmystreet.com' message, but Hackney
    # do provide services on that road.
    ($string, $town) = ('E2 9AA', '') if $string =~ /^teale\s+st/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        string => $string,
        town   => $town,
        centre => '51.552267,-0.063316',
        bounds => [ 51.519814, -0.104511, 51.577784, -0.016527 ],
    };
}

sub do_not_reply_email { shift->feature('do_not_reply_email') }

sub verp_email_domain { shift->feature('verp_email_domain') }

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub geocoder_munge_query_params {
    my ($self, $params) = @_;

    $params->{addressdetails} = 1;
}

sub geocoder_munge_results {
    my ($self, $result) = @_;
    if (my $a = $result->{address}) {
        if ($a->{road} && $a->{suburb} && $a->{postcode}) {
            $result->{display_name} = "$a->{road}, $a->{suburb}, $a->{postcode}";
            return;
        }
    }
    $result->{display_name} = '' unless $result->{display_name} =~ /Hackney/;
    $result->{display_name} =~ s/, United Kingdom$//;
    $result->{display_name} =~ s/, London, Greater London, England//;
    $result->{display_name} =~ s/, London Borough of Hackney//;
}

sub address_for_uprn {
    my ($self, $uprn) = @_;

    my $api = $self->feature('address_api');
    my $url = $api->{url};
    my $key = $api->{key};

    $url .= '?uprn=' . uri_escape_utf8($uprn);
    my $ua = LWP::UserAgent->new;
    $ua->default_header(Authorization => $key);
    my $res = $ua->get($url);
    my $data = decode_json($res->decoded_content);
    my $address = $data->{data}->{address}->[0];
    return "" unless $address;

    my $string = join(", ",
        grep { $_ && $_ ne 'Hackney' }
        map { s/((^\w)|(\s\w))/\U$1/g; $_ }
        map { lc $address->{"line$_"} }
        (1..3)
    );
    $string .= ", $address->{postcode}";
    return $string;
}

sub addresses_for_postcode {
    my ($self, $postcode) = @_;

    my $api = $self->feature('address_api');
    my $url = $api->{url};
    my $key = $api->{key};
    my $pageAttr = $api->{pageAttr};

    $url .= '?format=detailed&postcode=' . uri_escape_utf8($postcode);
    my $ua = LWP::UserAgent->new;
    $ua->default_header(Authorization => $key);

    my $pages = 1;
    my @addresses;
    my $outside;
    for (my $page = 1; $page <= $pages; $page++) {
        my $res = $ua->get($url . '&page=' . $page);
        my $data = decode_json($res->decoded_content);
        $pages = $data->{data}->{$pageAttr} || 0;
        foreach my $address (@{$data->{data}->{address}}) {
            unless ($address->{locality} eq 'HACKNEY') {
                $outside = 1;
                next;
            }
            my $string = join(", ",
                grep { $_ && $_ ne 'Hackney' }
                map { s/((^\w)|(\s\w))/\U$1/g; $_ }
                map { lc $address->{"line$_"} }
                (1..3)
            );
            push @addresses, {
                value => $address->{UPRN},
                latitude => $address->{latitude},
                longitude => $address->{longitude},
                label => $string,
            };
        }
    }
    return { error => 'Sorry, that postcode appears to lie outside Hackney' } if !@addresses && $outside;
    return { addresses => \@addresses };
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
}

sub open311_extra_data {
    my ($self, $row, $h, $contact) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
        { name => 'category',
          value => $row->category },
    ];

    # Make sure contact 'email' set correctly for Open311
    if (my $split_match = $row->get_extra_metadata('split_match')) {
        $row->unset_extra_metadata('split_match');
        my $code = $split_match->{$contact->email};
        $contact->email($code) if $code;
    }

    return $open311_only;
}

sub map_type { 'OSM' }

sub default_map_zoom { 6 }

sub admin_user_domain { 'hackney.gov.uk' }

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
        name => 'Anonymous user',
    };
}

sub open311_skip_existing_contact {
    my ($self, $contact) = @_;

    # For Hackney we want the 'protected' flag to prevent any changes to this
    # contact at all.
    return $contact->get_extra_metadata("open311_protect") ? 1 : 0;
}

sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete open311 protected contacts when importing
    return $contacts->search({
        extra => { -not_like => '%T15:open311_protect,I1:1%' },
    });
}

sub problem_is_within_area_type {
    my ($self, $problem, $type) = @_;
    my $layer_map = {
        park => "greenspaces:hackney_park",
        estate => "housing:lbh_estate",
    };
    my $layer = $layer_map->{$type};
    return unless $layer;

    my ($x, $y) = $problem->local_coords;

    my $cfg = {
        url => "https://map.hackney.gov.uk/geoserver/wfs",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => $layer,
        outputformat => "json",
        filter => "<Filter xmlns:gml=\"http://www.opengis.net/gml\"><Intersects><PropertyName>geom</PropertyName><gml:Point srsName=\"27700\"><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Intersects></Filter>",
    };

    my $features = $self->_fetch_features($cfg, $x, $y) || [];
    return scalar @$features ? 1 : 0;
}

sub get_body_sender {
    my ( $self, $body, $problem ) = @_;

    my $contact = $body->contacts->search( { category => $problem->category } )->first;

    if (my ($park, $estate, $other) = $self->_split_emails($contact->email)) {
        my $to = $other;
        if ($self->problem_is_within_area_type($problem, 'park')) {
            $to = $park;
        } elsif ($self->problem_is_within_area_type($problem, 'estate')) {
            $to = $estate;
        }
        $problem->set_extra_metadata(split_match => { $contact->email => $to });
        if (is_valid_email($to)) {
            return { method => 'Email', contact => $contact };
        }
    }
    return $self->SUPER::get_body_sender($body, $problem);
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;
    @$contacts = grep { $_->category ne 'Noise report' } @$contacts;
    $self->SUPER::munge_report_new_contacts($contacts);
}

# Translate email address to actual delivery address
sub noise_destination_email {
    my ($self, $row, $name) = @_;
    my $emails = $self->feature('open311_email');
    my $where = $row->get_extra_metadata('where');
    if (my $recipient = $emails->{"noise_$where"}) {
        my @emails = split(/,/, $recipient);
        return [ map { [ $_, $name ] } @emails ];
    }
}

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    if ($row->cobrand_data eq 'noise') {
        my $name = $params->{To}[0][1];
        if (my $recipient = $self->noise_destination_email($row, $name)) {
            $params->{To} = $recipient;
        }
        $params->{Subject} = "Noise report: " . $row->title;
        return;
    }

    my $split_match = $row->get_extra_metadata('split_match') or return;
    $row->unset_extra_metadata('split_match');
    for my $recip (@{$params->{To}}) {
        my ($email, $name) = @$recip;
        $recip->[0] = $split_match->{$email} if $split_match->{$email};
    }
}

sub _split_emails {
    my ($self, $email) = @_;

    my $parts = join '\s*', qw(^ park : (.*?) ; estate : (.*?) ; other : (.*?) $);
    my $regex = qr/$parts/i;

    if (my ($park, $estate, $other) = $email =~ $regex) {
        return ($park, $estate, $other);
    }
    return ();
}

sub validate_contact_email {
    my ( $self, $email ) = @_;

    return 1 if is_valid_email_list($email);

    my @emails = grep { $_ } $self->_split_emails($email);
    return unless @emails;
    return 1 if is_valid_email_list(join(",", @emails));
}

# We want to send confirmation emails only for Noise reports
sub report_sent_confirmation_email {
    my ($self, $report) = @_;
    return 'id' if $report->cobrand_data eq 'noise';
    return '';
};

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        nearest_address => 'Nearest address',
        nearest_address_postcode => 'Nearest postcode',
        extra_details => "Extra details",
    );

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $address = '';
        my $postcode = '';

        if ( $report->geocode ) {
            $address = $report->geocode->{resourceSets}->[0]->{resources}->[0]->{name};
            $postcode = $report->geocode->{resourceSets}->[0]->{resources}->[0]->{address}->{postalCode};
        }

        return {
            nearest_address => $address,
            nearest_address_postcode => $postcode,
            extra_details => $report->get_extra_metadata('detailed_information') || '',
        };
    });
}

1;
