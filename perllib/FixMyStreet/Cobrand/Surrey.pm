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

=item * We include the C<external_id> (Zendesk reference) in the acknowledgement email.

=cut

sub report_sent_confirmation_email { 'external_id' }

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

sub enter_postcode_text { 'Enter a nearby UK postcode, or street name and area' }

=item * The privacy policy is held on Surrey's own site

=cut

sub privacy_policy_url {
    return 'https://www.surreycc.gov.uk/council-and-democracy/your-privacy/our-privacy-notices/fixmystreet'
}

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

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

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
        { name => 'category',
          value => $row->category },
        { name => 'group',
          value => $row->get_extra_metadata('group', '') },
    ];

    # Surrey Open311 doesn't actually use the service_code value we send, but it
    # must pass the input schema validation of open311-adapter. The majority of the
    # Surrey contacts currently have actual email addresses, so we instead send
    # the contact row ID.
    # XXX this feels a bit hacky, is there a better way?
    $contact->email($contact->id);

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
        if (my $ref = $self->lookup_site_code($row, 'USRN,ROADNAME')) {
          my $props = $ref->{properties} || {};
          $row->update_extra_field({ name => 'USRN', value => $props->{USRN} }) if $props->{USRN};
          $row->update_extra_field({ name => 'ROADNAME', value => $props->{ROADNAME} }) if $props->{ROADNAME};
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

    # Surrey want the value *and* the question label to be passed to their API,
    # so we do a slightly horrid thing and encode those two values into a JSON
    # object which we pass as the extra field value over Open311.
    my $extra = $row->get_extra_fields();
    foreach my $field (@$extra) {
        if ($field->{description}) {
            $field->{value} = encode_json({ description => $field->{description}, value => $field->{value} });
        }
    }
    $row->set_extra_fields( @$extra ) if @$extra;
}

1;
