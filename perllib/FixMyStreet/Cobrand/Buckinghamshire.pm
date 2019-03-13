package FixMyStreet::Cobrand::Buckinghamshire;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { return 2217; }
sub council_area { return 'Buckinghamshire'; }
sub council_name { return 'Buckinghamshire County Council'; }
sub council_url { return 'buckinghamshire'; }


sub example_places {
    return ( 'HP19 7QF', "Walton Road" );
}

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fixmystreet.buckscc.gov.uk';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Buckinghamshire';

    # The geocoder returns two results for 'Aylesbury', so force the better
    # result to be used.
    $town = "$town, HP20 2NH" if $string =~ /[\s]*aylesbury[\s]*/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.7852948471218,-0.812140044990842',
        span   => '0.596065946222112,0.664092167105497',
        bounds => [ 51.4854160129405, -1.1406945585036, 52.0814819591626, -0.476602391398098 ],
    };
}

sub on_map_default_status { 'open' }

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub admin_user_domain { 'buckscc.gov.uk' }

sub contact_email {
    my $self = shift;
    return join( '@', 'fixmystreetbs', 'email.buckscc.gov.uk' );
}

sub send_questionnaires {
    return 0;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    # Reports made via FMS.com or the app probably won't have a site code
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $site_code = $self->lookup_site_code($row)) {
            push @$extra,
                { name => 'site_code',
                value => $site_code };
        }
    }

    $row->set_extra_fields(@$extra);
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    return unless $row->extra;
    my $extra = $row->get_extra_fields;
    if (@$extra) {
        @$extra = grep { $_->{name} ne 'road-placement' } @$extra;
        $row->set_extra_fields(@$extra);
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    # For certain categories, send an email also
    my $addresses = {
        'Flytipping' => [ join('@', 'illegaldumpingcosts', $self->admin_user_domain), "TfB" ],
        'Blocked drain' => [ join('@', 'floodmanagement', $self->admin_user_domain), "Flood Management" ],
        'Ditch issue' => [ join('@', 'floodmanagement', $self->admin_user_domain), "Flood Management" ],
        'Flooded subway' => [ join('@', 'floodmanagement', $self->admin_user_domain), "Flood Management" ],
    };
    my $dest = $addresses->{$row->category};
    return unless $dest;

    my $sender = FixMyStreet::SendReport::Email->new( to => [ $dest ] );
    $sender->send($row, $h);
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

sub process_open311_extras {
    my ($self, $c, $body, $extra) = @_;

    return unless $c->stash->{report}; # Don't care about updates

    $self->flytipping_body_fix(
        $c->stash->{report},
        $c->get_param('road-placement'),
        $c->stash->{field_errors},
    );
}

sub flytipping_body_fix {
    my ($self, $report, $road_placement, $errors) = @_;

    return unless $report->category eq 'Flytipping';

    if ($report->bodies_str =~ /,/) {
        # Sent to both councils in the area
        my @bodies = values %{$report->bodies};
        my $county = (grep { $_->name =~ /^Buckinghamshire/ } @bodies)[0];
        my $district = (grep { $_->name !~ /^Buckinghamshire/ } @bodies)[0];
        # Decide which to send to based upon the answer to the extra question:
        if ($road_placement eq 'road') {
            $report->bodies_str($county->id);
        } elsif ($road_placement eq 'off-road') {
            $report->bodies_str($district->id);
        }
    } else {
        # If the report is only being sent to the district, we do
        # not care about the road question, if it is missing
        if (!$report->to_body_named('Buckinghamshire')) {
            delete $errors->{'road-placement'};
        }
    }
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

sub map_type { 'Buckinghamshire' }

sub default_map_zoom { 3 }

sub enable_category_groups { 1 }

sub _dashboard_export_add_columns {
    my $self = shift;
    my $c = $self->{c};

    push @{$c->stash->{csv}->{headers}}, "Staff User";
    push @{$c->stash->{csv}->{columns}}, "staff_user";

    # All staff users, for contributed_by lookup
    my @user_ids = $c->model('DB::User')->search(
        { from_body => $self->body->id },
        { columns => [ 'id', 'email', ] })->all;
    my %user_lookup = map { $_->id => $_->email } @user_ids;

    $c->stash->{csv}->{extra_data} = sub {
        my $report = shift;
        my $staff_user = '';
        if (my $contributed_by = $report->get_extra_metadata('contributed_by')) {
            $staff_user = $user_lookup{$contributed_by};
        }
        return {
            staff_user => $staff_user,
        };
    };
}

sub dashboard_export_updates_add_columns {
    shift->_dashboard_export_add_columns;
}

sub dashboard_export_problems_add_columns {
    shift->_dashboard_export_add_columns;
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
    # Buckinghamshire is a two-tier council, but only want to display
    # county-level categories on their cobrand.
    return $rs->search( [ { 'body_areas.area_id' => 2217 }, { category => 'Flytipping' } ], { join => { body => 'body_areas' } });
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

1;
