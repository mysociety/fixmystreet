=head1 NAME

FixMyStreet::Cobrand::Dumfries - code specific to the Dumfries and Galloway cobrand

=head1 SYNOPSIS

Dumfries and Galloway Council (DGC) is a unitary authority, with an Alloy backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Dumfries;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';

use strict;
use warnings;
use DateTime::Format::Strptime;

sub council_area_id { return 2656; }
sub council_area { return 'Dumfries and Galloway'; }
sub council_name { return 'Dumfries and Galloway Council'; }
sub council_url { return 'dumfries'; }

=item * Dumfries use their own privacy policy

=cut

sub privacy_policy_url { 'https://www.dumfriesandgalloway.gov.uk/sites/default/files/2025-03/privacy-notice-customer-services-centres-dumfries-and-galloway-council.pdf' }


=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }


=item * Make a few improvements to the display of geocoder results

Remove 'Dumfries and Galloway' and 'Alba / Scotland', skip any that don't mention Dumfries and Galloway at all

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Dumfries and Galloway';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '55.0706745777256,-3.95683358209527',
        span   => '0.830832259321063,2.33028835283733',
        bounds => [ 54.6332195775134, -5.18762505731414, 55.4640518368344, -2.8573367044768 ],
        result_only_if => 'Dumfries and Galloway',
        result_strip => ', Dumfries and Galloway, Alba / Scotland',
    };
}

=item * Map starts at zoom level 5, closer than default and not based on population density.

=cut

sub default_map_zoom { 5 }

=item * Custom postcode text which includes hint about reference number search

=cut

sub enter_postcode_text {
    'Enter a Dumfries and Galloway post code or street name and area, or a reference number of a problem previously reported'
}


=head2 open311_update_missing_data

All reports sent to Alloy should have a parent asset they're associated with.
This is indicated by the value in the asset_resource_id field. For certain
categories (e.g. street lights) this will be the asset the user
selected from the map. For other categories (e.g. potholes) or if the user
didn't select an asset then we look up the nearest road from DGC's
Alloy server and use that as the parent.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    if (!$row->get_extra_field_value('asset_resource_id')) {
        if (my $item_id = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'asset_resource_id', value => $item_id });
        }
    }
}


sub lookup_site_code_config {
    my ($self) = @_;
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";

    my $suffix = FixMyStreet->config('STAGING_SITE') ? "staging" : "assets";
    return {
        buffer => 200, # metres
        _nearest_uses_latlon => 1,
        proxy_url => "https://$host/alloy/layer.php",
        layer => "designs_highwaysNetworkAsset_64bf8f949c5fa17f953be9d6",
        url => "https://dumfries.$suffix",
        property => "itemId",
        accept_feature => sub { 1 }
    };
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    # Alloy layer proxy needs the bbox in lat/lons
    my ($w, $s, $e, $n) = split(/,/, $cfg->{bbox});
    ($s, $w) = Utils::convert_en_to_latlon($w, $s);
    ($n, $e) = Utils::convert_en_to_latlon($e, $n);
    my $bbox = "$w,$s,$e,$n";

    my $uri = URI->new($cfg->{proxy_url});
    $uri->query_form(
        layer => $cfg->{layer},
        url => $cfg->{url},
        bbox => $bbox,
    );

    return $uri;
}

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=head2 open311_get_update_munging

Dumfries want certain fields shown in updates on FMS.

These values, if present, are passed back from open311-adapter in the <extras>
element. If the template being used for this update has placeholders matching
any field configured in the 'response_template_variables' Config entry, they
get replaced with the value from extras, or an empty string otherwise.

=cut

sub open311_get_update_munging {
    my ($self, $comment, $state, $request) = @_;

    my $text = $self->open311_get_update_munging_template_variables($comment->text, $request);
    $comment->text($text);

    if ( $text = $comment->private_email_text ) {
        $text = $self->open311_get_update_munging_template_variables(
            $text, $request );
        $comment->private_email_text($text);
    }

    # If the update includes a latest_inspection_time, store it on the problem
    # If the value is 'NOT COMPLETE', unset the metadata
    if (exists $request->{extras}{latest_inspection_time}) {
        my $inspection_time = $request->{extras}{latest_inspection_time};
        my $problem = $comment->problem;
        if ($inspection_time eq 'NOT COMPLETE') {
            $problem->unset_extra_metadata('latest_inspection_time');
        } else {
            $problem->set_extra_metadata(latest_inspection_time => $inspection_time);
        }
        $problem->update;
    }
}

=head2 _updates_disallowed_check

Updates are only allowed on reports in a closed state (closed, duplicate, etc.),
and only if the problem has a latest_inspection_time set and at least 14 days
have passed since that inspection time. When these conditions are met, only
staff or the original reporter can leave updates.

=cut

sub _updates_disallowed_check {
    my ($self, $cfg, $problem, $body_user) = @_;

    # First check parent class restrictions
    my $parent_result = $self->next::method($cfg, $problem, $body_user);
    return $parent_result if $parent_result;

    my $c = $self->{c};
    my $superuser = $c->user_exists && $c->user->is_superuser;
    my $staff = $body_user || $superuser;

    return '' if $staff; # superusers/staff can do whatever XXX remove after client testing

    my $reporter = $c->user_exists && $c->user->id == $problem->user->id;

    # Check if state is a closed state
    my $closed_states = FixMyStreet::DB::Result::Problem->closed_states();
    unless ($closed_states->{$problem->state}) {
        return 1;
    }

    # Check if the problem has a latest_inspection_time
    my $inspection_time = $problem->get_extra_metadata('latest_inspection_time');
    unless ($inspection_time) {
        return 1;
    }

    # Parse the inspection time and check if at least 14 days have passed
    my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%dT%H:%M:%S');
    my $inspection_dt = $parser->parse_datetime($inspection_time);
    unless ($inspection_dt) {
        return 1; # If we can't parse the date, disallow updates
    }

    my $cutoff = DateTime->now(time_zone => FixMyStreet->local_time_zone)->subtract(days => 14);
    if ($inspection_dt > $cutoff) {
        return 1;
    }

    # Only staff or the original reporter can leave updates
    unless ($staff || $reporter) {
        return 1;
    }

    return '';  # Updates are allowed
}

=item * Use Scotland bank holidays for out of hours messages

=cut

sub is_scotland { 1 }


=item * We allow response templates to be associated with the 'planned' state

=cut

sub state_groups_inspect {
    my $rs = FixMyStreet::DB->resultset("State");
    my @fixed = FixMyStreet::DB::Result::Problem->fixed_states;
    [
        [ $rs->display('confirmed'), [ FixMyStreet::DB::Result::Problem->open_states ] ],
        @fixed ? [ $rs->display('fixed'), [ 'fixed - council' ] ] : (),
        [ $rs->display('closed'), [ FixMyStreet::DB::Result::Problem->closed_states ] ],
    ]
}


=head2 validate_response_template_external_status_code

Validates that an external_status_code entered in the admin templates page
conforms to Dumfries format rules:

- Must have exactly 3 colon-separated segments (status:outcome:priority)
- Each segment must be either empty, a '*' wildcard, or an Alloy ID
- Wildcards cannot be mixed with other text in a segment
- At least one segment must be a concrete Alloy ID (not empty or wildcard)
  i.e. '::' and '*:*:*' are not valid

Returns an error message string if invalid, undef if valid.

=cut

sub validate_response_template_external_status_code {
    my ($self, $ext_code) = @_;

    return unless defined $ext_code && $ext_code ne '';

    my @parts = split /:/, $ext_code, -1;

    if (@parts != 3) {
        return _('External status code must have exactly 3 colon-separated parts (status:outcome:priority).');
    }

    for my $i (0..2) {
        my $part = $parts[$i];
        # Each part must be: empty, exactly '*', or a non-* value (Alloy ID)
        if ($part ne '' && $part ne '*' && $part =~ /\*/) {
            return _('Wildcards (*) cannot be mixed with other text. Each segment must be empty, a single *, or an Alloy ID.');
        }
    }

    # Must have at least one non-empty, non-wildcard segment
    my @concrete = grep { $_ ne '' && $_ ne '*' } @parts;
    if (!@concrete) {
        return _('External status code must have at least one concrete value (not empty or wildcard).');
    }

    return;  # Valid
}


=head2 expand_external_status_code_for_template_match

Dumfries external status codes from Alloy are colon-separated values
(status:outcome:priority). This method generates all possible wildcard
variants for matching response templates.

A template with external_status_code '123:*:*' will match any incoming
code starting with '123:' followed by two non-empty segments.

Wildcards only substitute for non-empty segments - if the incoming code
has an empty segment (e.g. '123::789'), that segment stays empty in all
variants and won't match a '*' in a template.

=cut

sub expand_external_status_code_for_template_match {
    my ($self, $ext_code) = @_;

    my @parts = split /:/, $ext_code, -1;  # -1 preserves trailing empty strings
    my %seen;

    # Generate 2^N combinations where each non-empty part can be itself or '*'
    my $n = scalar @parts;
    for my $mask (0 .. (2**$n - 1)) {
        my @combo;
        for my $i (0 .. $n-1) {
            # Only substitute '*' for non-empty parts
            if (($mask & (1 << $i)) && $parts[$i] ne '') {
                push @combo, '*';
            } else {
                push @combo, $parts[$i];
            }
        }
        $seen{join(':', @combo)} = 1;
    }

    return [ keys %seen ];
}


1;
