package FixMyStreet::Cobrand::Surrey;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use FixMyStreet::Geocode::Address;
use JSON::MaybeXS;

sub council_area_id { 2242 }
sub council_area { 'Surrey' }
sub council_name { 'Surrey County Council' }
sub council_url { 'surrey' }
sub is_two_tier { 1 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.2478663,-0.4205895',
        span   => '0.4000678,0.9071629',
        bounds => [ 51.0714965, -0.8489465, 51.4715643, 0.0582164 ],
        town => 'Surrey',
    };
}

=item * The default map view shows closed/fixed reports for 31 days

=cut

sub report_age {
    return {
        open => '90 days',
        closed => '31 days',
        fixed  => '31 days',
    };
}

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=item * We do not send alerts to report authors.

=cut

sub suppress_reporter_alerts { 1 }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

sub enter_postcode_text { 'Enter a nearby UK postcode, or street name and area' }


=item * Don't show reports before go live date

=cut

sub cut_off_date { '2024-09-16' }


=head2 problems_restriction/problems_sql_restriction/problems_on_map_restriction

Reports made on FMS.com before the cut off date are not shown on the Surrey cobrand;
however if a report is fetched over Open311 it is shown regardless of the cut off date.

=cut

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');

    $rs = $rs->to_body($self->body);

    my $date = $self->cut_off_date;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search([
        { "$table.created" => { '>=', $date } },
        { "$table.service" => 'Open311' },
    ]);
}

sub problems_sql_restriction {
    my ($self, $item_table) = @_;
    my $date = $self->cut_off_date;
    return " AND ( created >= '$date' OR service = 'Open311' )";
}

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    my $date = $self->cut_off_date;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search([
        { "$table.created" => { '>=', $date } },
        { "$table.service" => 'Open311' },
    ]);
}


=item * The privacy policy is held on Surrey's own site

=cut

sub privacy_policy_url {
    return 'https://www.surreycc.gov.uk/council-and-democracy/your-privacy/our-privacy-notices/fixmystreet'
}

=item * Doesn't allow the reopening of reports

=cut

sub reopening_disallowed { 1 }

=item * Allows anonymous reporting

=cut

sub allow_anonymous_reports { 'button' }

=item * Do not allow email addresses in title or detail

=back

=cut

sub report_validation {
    my ($self, $report, $errors) = @_;

    my $regex = Utils::email_regex;

    if ($report->detail =~ /$regex/ || $report->title =~ /$regex/) {
        $errors->{detail} = 'Please remove any email addresses and other personal information from your report';
    }

    return $errors;
}

=item * Anyone with a surreycc.gov.uk email shows up in the admin

=cut

sub admin_user_domain { 'surreycc.gov.uk' }


=head2 get_town

Returns the name of the town from the problem's geocode information, if present.

=cut

sub get_town {
    my ($self, $p) = @_;

    return unless $p->geocode;
    my $geocode = FixMyStreet::Geocode::Address->new($p->geocode);
    my $address = $geocode->{LPI} || $geocode->{address} || ($geocode->can('address') ? $geocode->address : '');
    return unless $address;
    my $town = $address->{town} || $address->{city} || $address->{TOWN_NAME} || $address->{locality} || $address->{village} || $address->{suburb};
    return $town;
}


=head2 get_geocoder

The OSM geocoder is used for Surrey.

=cut

sub get_geocoder { 'OSM' }


=head2 categories_restriction

Surrey don't want a particular district category on their cobrand.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { 'me.category' => {  -not_in => [ 'Rubbish (refuse and recycling)' ] } } );
}

=head2 dashboard_export_problems_add_columns

Surrey has an extra column in their stats export showing the number of subscribers to a report.
They are set up not to subscribe the original reporter to their own report so the alert number
is the number of users who have subscribed to the report for updates

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        alerts_count => "Subscribers",
    );

    my $alerts_lookup = $csv->dbi ? undef : $self->csv_update_alerts;

    $csv->csv_extra_data(sub {
        my $report = shift;

        if ($alerts_lookup) {
            return { alerts_count => ($alerts_lookup->{$report->id} || 0) };
        } else {
            return { alerts_count => ($report->{alerts_count} || 0) };
        }
    });
}

=back

=head2 Open311

=over 1

=item * Fetched reports via Open311 use the service name as their title

=cut

sub open311_title_fetched_report {
    my ($self, $request) = @_;
    return $request->{service_name};
}

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{multi_photos} = 1;
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        { name => 'fixmystreet_id',
          value => $row->id },
        { name => 'easting',
          value => $h->{easting} },
        { name => 'northing',
          value => $h->{northing} },
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
        { name => 'subCategory_display',
          value => $row->category_display },
        { name => 'category',
          value => $row->category },
        { name => 'group',
          value => $row->get_extra_metadata('group', '') },
    ];

    return $open311_only;
}

sub lookup_by_ref {
    my ($self, $ref) = @_;

    return [
          id => $ref,
          external_id => "Zendesk_" . $ref
      ];
}

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    if (!$row->get_extra_field_value('USRN')) {
        if (my $ref = $self->lookup_site_code($row, 'USRN,ROADNAME,POSTTOWN')) {
          my $props = $ref->{properties} || {};
          $row->update_extra_field({ name => 'USRN', value => $props->{USRN} }) if $props->{USRN};
          $row->update_extra_field({ name => 'ROADNAME', value => $props->{ROADNAME} }) if $props->{ROADNAME};
          $row->update_extra_field({ name => 'POSTTOWN', value => $props->{POSTTOWN} }) if $props->{POSTTOWN};
        }
    }
}

sub lookup_site_code_config {
    my ( $self, $field ) = @_;
    # uncoverable subroutine
    # uncoverable statement
    my $layer = '2'; # 2 is USRN

    my %cfg = (
        buffer => 1000, # metres
        proxy_url => "https://tilma.mysociety.org/resource-proxy/proxy.php",
        url => "https://surrey.assets/$layer/query",
        outFields => $field, # use this instead of 'properties' so we get the entire feature returned from lookup_site_code, which we need for accessing USRN and ROADNAME
        accept_feature => sub { 1 },
    );
    return \%cfg;
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    # Surrey's asset proxy has a slightly different calling style to
    # a standard WFS server.
    my $uri = URI->new($cfg->{url});
    $uri->query_form(
        inSR => "27700",
        outSR => "27700",
        f => "geojson",
        outFields => $cfg->{outFields},
        geometry => $cfg->{bbox},
    );

    return $cfg->{proxy_url} . "?" . $uri->as_string;
}

sub default_map_zoom { 3 }

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    # Surrey want the value *and* the field label to be passed to their API,
    # so we do a slightly horrid thing and encode those two values into a JSON
    # object which we pass as the extra field value over Open311.
    # Additionally, they want the user-visible answer rather than the internal
    # key to be sent, so we have to look that up from the contact extra fields.
    my $extra = $row->get_extra_fields();
    my $contact_extra = $row->contact->get_extra_fields();
    my %fields = map { $_->{code} => { map({ $_->{key} => $_->{name} } @{ $_->{values} }) } } grep { $_->{variable} && $_->{variable} eq 'true' && $_->{values} } @$contact_extra;

    foreach my $field (@$extra) {
        next unless $field->{description};
        my @vals;
        my $val = $field->{value};
        # treat everything as an array because that's how Boomi wants it and
        # it makes it easier to deal with multivaluelist fields here.
        $val = [ $val ] unless ref $val eq 'ARRAY';

        foreach my $v (@$val) {
          if ( $fields{$field->{name}} && $fields{$field->{name}}->{$v} ) {
            push @vals, $fields{$field->{name}}->{$v};
          } else {
            push @vals, $v;
          }
        }
        $field->{value} = encode_json({ description => $field->{description}, value => \@vals });
    }
    $row->set_extra_fields( @$extra ) if @$extra;
}

1;

=back
