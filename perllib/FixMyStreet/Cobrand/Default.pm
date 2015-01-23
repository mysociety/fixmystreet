package FixMyStreet::Cobrand::Default;
use base 'FixMyStreet::Cobrand::Base';

use strict;
use warnings;
use FixMyStreet;
use FixMyStreet::Geocode::Bing;
use DateTime;
use Encode;
use List::MoreUtils 'none';
use URI;
use Digest::MD5 qw(md5_hex);

use Carp;
use mySociety::MaPit;
use mySociety::PostcodeUtil;

=head1 path_to_web_templates

    $path = $cobrand->path_to_web_templates(  );

Returns the path to the templates for this cobrand - by default
"templates/web/$moniker" and "templates/web/fixmystreet"

=cut

sub path_to_web_templates {
    my $self = shift;
    my $paths = [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify,
    ];
    return $paths;
}

=head1 country

Returns the country that this cobrand operates in, as an ISO3166-alpha2 code.
Default is none. This is not really used for anything important (minor GB only
things involving eastings/northings mostly).

=cut

sub country {
    return '';
}

=head1 problems

Returns a ResultSet of Problems, restricted to a subset if we're on a cobrand
that only wants some of the data.

=cut

sub problems {
    my $self = shift;
    return $self->{c}->model('DB::Problem');
}

=head1 body_restriction

Return an extra query parameter to restrict reports to those sent to a
particular body.

=cut

sub body_restriction {}

sub site_key { return 0; }

=head2 restriction

Return a restriction to data saved while using this specific cobrand site.

=cut

sub restriction {
    my $self = shift;

    return $self->moniker ? { cobrand => $self->moniker } : {};
}

=head2 base_url_with_lang 

=cut

sub base_url_with_lang {
    my $self = shift;
    return $self->base_url;
}

=head2 admin_base_url

Base URL for the admin interface.

=cut

sub admin_base_url { FixMyStreet->config('ADMIN_BASE_URL') || '' }

=head2 base_url

Return the base url for the cobranded version of the site

=cut

sub base_url { FixMyStreet->config('BASE_URL') }

=head2 base_url_for_report

Return the base url for a report (might be different in a two-tier county, but
most of the time will be same as base_url). Report may be an object, or a
hashref.

=cut

sub base_url_for_report {
    my ( $self, $report ) = @_;
    return $self->base_url;
}

=head2 base_host

Return the base host for the cobranded version of the site

=cut

sub base_host {
    my $self = shift;
    my $uri  = URI->new( $self->base_url );
    return $uri->host;
}

=head2 enter_postcode_text

Return override text that prompts the user to enter their postcode/place name.
Can be specified in template.

=cut

sub enter_postcode_text { }

=head2 set_lang_and_domain

    my $set_lang = $cobrand->set_lang_and_domain( $lang, $unicode, $dir )

Set the language and domain of the site based on the cobrand and host.

=cut

sub set_lang_and_domain {
    my ( $self, $lang, $unicode, $dir ) = @_;

    my @languages = @{$self->languages};
    push @languages, 'en-gb,English,en_GB' if none { /en-gb/ } @languages;
    my $languages = join('|', @languages);
    my $lang_override = $self->language_override || $lang;
    my $lang_domain = $self->language_domain || 'FixMyStreet';

    my $headers = $self->{c} ? $self->{c}->req->headers : undef;
    my $set_lang = mySociety::Locale::negotiate_language( $languages, $lang_override, $headers );
    mySociety::Locale::gettext_domain( $lang_domain, $unicode, $dir );
    mySociety::Locale::change();

    if ($mySociety::Locale::langmap{$set_lang}) {
        DateTime->DefaultLocale( $mySociety::Locale::langmap{$set_lang} );
    } else {
        DateTime->DefaultLocale( 'en_US' );
    }

    return $set_lang;
}
sub languages { FixMyStreet->config('LANGUAGES') || [] }
sub language_domain { }
sub language_override { }

=head2 alert_list_options

Return HTML for a list of alert options for the cobrand, given QUERY and
OPTIONS.

=cut

sub alert_list_options { 0 }

=head2 recent_photos

Return N recent photos. If EASTING, NORTHING and DISTANCE are supplied, the
photos must be attached to problems within DISTANCE of the point defined by
EASTING and NORTHING.

=cut

sub recent_photos {
    my $self = shift;
    my $area = shift;
    return $self->problems->recent_photos(@_);
}

=head2 recent

Return recent problems on the site.

=cut

sub recent {
    my ( $self ) = @_;
    return $self->problems->recent();
}

=item shorten_recency_if_new_greater_than_fixed

By default we want to shorten the recency so that the numbers are more
attractive.

=cut

sub shorten_recency_if_new_greater_than_fixed {
    return 1;
}

=head2 front_stats_data

Return a data structure containing the front stats information that a template
can then format.

=cut

sub front_stats_data {
    my ( $self ) = @_;

    my $recency         = '1 week';
    my $shorter_recency = '3 days';

    my $fixed   = $self->problems->recent_fixed();
    my $updates = $self->problems->number_comments();
    my $new     = $self->problems->recent_new( $recency );

    if ( $new > $fixed && $self->shorten_recency_if_new_greater_than_fixed ) {
        $recency = $shorter_recency;
        $new     = $self->problems->recent_new( $recency );
    }

    my $stats = {
        fixed   => $fixed,
        updates => $updates,
        new     => $new,
        recency => $recency,
    };

    return $stats;
}

=head2 disambiguate_location

Returns any disambiguating information available. Defaults to none.

=cut 

sub disambiguate_location { FixMyStreet->config('GEOCODING_DISAMBIGUATION') or {}; }

=head2 cobrand_data_for_generic_update

Parameter is UPDATE_DATA, a reference to a hash of non-cobranded update data.
Return cobrand extra data for the update

=cut

sub cobrand_data_for_generic_update { '' }

=head2 cobrand_data_for_generic_update

Parameter is PROBLEM_DATA, a reference to a hash of non-cobranded problem data.
Return cobrand extra data for the problem

=cut

sub cobrand_data_for_generic_problem { '' }

=head2 uri

Given a URL ($_[1]), QUERY, EXTRA_DATA, return a URL with any extra params
needed appended to it.

In the default case, if we're using an OpenLayers map, we need to make
sure zoom is always present if lat/lon are, to stop OpenLayers defaulting
to null/0.

=cut

sub uri {
    my ( $self, $uri ) = @_;

    {
        no warnings 'once';
        (my $map_class = $FixMyStreet::Map::map_class) =~ s/^FixMyStreet::Map:://;
        return $uri unless $map_class =~ /OSM|FMS/;
    }

    $uri->query_param( zoom => 3 )
      if $uri->query_param('lat') && !$uri->query_param('zoom');

    return $uri;
}


=head2 header_params

Return any params to be added to responses

=cut

sub header_params { return {} }

=head2 map_type

Return an override type of map if necessary.

=cut
sub map_type {
    my $self = shift;
    return 'OSM' if $self->{c}->req->uri->host =~ /^osm\./;
    return;
}

=head2 reports_per_page

The number of reports to show per page on all reports page.

=cut

sub reports_per_page {
    return FixMyStreet->config('ALL_REPORTS_PER_PAGE') || 100;
}

=head2 reports_ordering

The order_by clause to use for reports on all reports page

=cut

sub reports_ordering {
    return { -desc => 'lastupdate' };
}

=head2 on_map_list_limit

Return the maximum number of items to be given in the list of reports on the map

=cut

sub on_map_list_limit { return undef; }

=head2 on_map_default_max_pin_age

Return the default maximum age for pins.

=cut

sub on_map_default_max_pin_age { return '6 months'; }

=head2 on_map_default_status

Return the default ?status= query parameter to use for filter on map page.

=cut

sub on_map_default_status { return 'all'; }

=head2 allow_photo_upload

Return a boolean indicating whether the cobrand allows photo uploads

=cut

sub allow_photo_upload { return 1; }

=head2 allow_photo_display

Return a boolean indicating whether the cobrand allows photo display

=cut

sub allow_photo_display {
    my ( $self, $r ) = @_;
    return 1;
}

=head2 allow_update_reporting

Return a boolean indication whether users should see links next to updates
allowing them to report them as offensive.

=cut

sub allow_update_reporting { return 0; }

=head2 geocode_postcode

Given a QUERY, return LAT/LON and/or ERROR.

=cut

sub geocode_postcode {
    my ( $self, $s ) = @_;
    return {};
}

=head2 geocoded_string_check

Parameters are LOCATION, QUERY. Return a boolean indicating whether the
string LOCATION passes the cobrands checks.

=cut

sub geocoded_string_check { return 1; }

=head2 find_closest

Used by send-reports to attach nearest things to the bottom of the report

=cut

sub find_closest {
    my ( $self, $latitude, $longitude, $problem ) = @_;
    my $str = '';

    if ( my $j = FixMyStreet::Geocode::Bing::reverse( $latitude, $longitude, disambiguate_location()->{bing_culture} ) ) {
        # cache the bing results for use in alerts
        if ( $problem ) {
            $problem->geocode( $j );
            $problem->update;
        }
        if ($j->{resourceSets}[0]{resources}[0]{name}) {
            $str .= sprintf(_("Nearest road to the pin placed on the map (automatically generated by Bing Maps): %s"),
                $j->{resourceSets}[0]{resources}[0]{name}) . "\n\n";
        }
    }

    return $str;
}

=head2 find_closest_address_for_rss

Used by rss feeds to provide a bit more context

=cut

sub find_closest_address_for_rss {
    my ( $self, $latitude, $longitude, $problem ) = @_;
    my $str = '';

    my $j;
    if ( $problem && ref($problem) =~ /FixMyStreet/ && $problem->can( 'geocode' ) ) {
       $j = $problem->geocode;
    } else {
        $problem = FixMyStreet::App->model('DB::Problem')->find( { id => $problem->{id} } );
        $j = $problem->geocode;
    }

    # if we've not cached it then we don't want to look it up in order to avoid
    # hammering the bing api
    # if ( !$j ) {
    #     $j = FixMyStreet::Geocode::Bing::reverse( $latitude, $longitude, disambiguate_location()->{bing_culture}, 1 );

    #     $problem->geocode( $j );
    #     $problem->update;
    # }

    if ($j && $j->{resourceSets}[0]{resources}[0]{name}) {
        my $address = $j->{resourceSets}[0]{resources}[0]{address};
        my @address;
        push @address, $address->{addressLine} if $address->{addressLine} and $address->{addressLine} !~ /^Street$/i;
        push @address, $address->{locality} if $address->{locality};
        $str .= sprintf(_("Nearest road to the pin placed on the map (automatically generated by Bing Maps): %s"),
            join( ', ', @address ) ) if @address;
    }

    return $str;
}

=head2 format_postcode

Takes a postcode string and if it looks like a valid postcode then transforms it
into the canonical postcode.

=cut

sub format_postcode {
    my ( $self, $postcode ) = @_;

    if ( $postcode ) {
        $postcode = mySociety::PostcodeUtil::canonicalise_postcode($postcode)
            if $postcode && mySociety::PostcodeUtil::is_valid_postcode($postcode);
    }

    return $postcode;
}
=head2 area_check

Paramters are AREAS, QUERY, CONTEXT. Return a boolean indicating whether
AREAS pass any extra checks. CONTEXT is where we are on the site.

=cut

sub area_check { return ( 1, '' ); }

=head2 all_reports_single_body

Return a boolean indicating whether the cobrand displays a report of all
councils

=cut

sub all_reports_single_body { 0 }

=head2 ask_ever_reported

Return a boolean indicating whether people should be asked whether this is the
first time they' ve reported a problem

=cut

sub ask_ever_reported { 1 }

=head2 send_questionnaires

Return a boolean indicating whether people should be sent questionnaire emails.

=cut

sub send_questionnaires { 1 }

=head2 admin_pages

List of names of pages to display on the admin interface

=cut

sub admin_pages { 0 }

=head2 admin_show_creation_graph

Show the problem creation graph in the admin interface
=cut

sub admin_show_creation_graph { 1 }

=head2 area_types

The MaPit types this site handles

=cut

sub area_types          { FixMyStreet->config('MAPIT_TYPES') || [ 'ZZZ' ] }
sub area_types_children { FixMyStreet->config('MAPIT_TYPES_CHILDREN') || [] }

=head2 contact_name, contact_email

Return the contact name or email for the cobranded version of the site (to be
used in emails).

=cut

sub contact_name  { FixMyStreet->config('CONTACT_NAME') }
sub contact_email { FixMyStreet->config('CONTACT_EMAIL') }

=item email_host

Return if we are the virtual host that sends email for this cobrand

=cut

sub email_host {
    return 1;
}

=item remove_redundant_areas

Remove areas whose reports go to another area (XXX)

=cut

sub remove_redundant_areas {
    my $self = shift;
    my $all_areas = shift;

    my $whitelist = FixMyStreet->config('MAPIT_ID_WHITELIST');
    return unless $whitelist && ref $whitelist eq 'ARRAY' && @$whitelist;

    my %whitelist = map { $_ => 1 } @$whitelist;
    foreach (keys %$all_areas) {
        delete $all_areas->{$_} unless $whitelist{$_};
    }
}

=item short_name

Remove extra information from body names for tidy URIs

=cut

sub short_name {
    my $self = shift;
    my ($area) = @_;

    my $name = $area->{name} || $area->name;
    $name = URI::Escape::uri_escape_utf8($name);
    $name =~ s/%20/+/g;
    return $name;
}

=item is_council

For UK sub-cobrands, to specify various alternations needed for them.

=cut
sub is_council { 0; }

=item is_two_tier

For UK sub-cobrands, to specify various alternations needed for them.

=cut
sub is_two_tier { 0; }

=item council_rss_alert_options

Generate a set of options for council rss alerts. 

=cut

sub council_rss_alert_options {
    my ( $self, $all_areas, $c ) = @_;

    my ( @options, @reported_to_options );
    foreach (values %$all_areas) {
        $_->{short_name} = $self->short_name( $_ );
        ( $_->{id_name} = $_->{short_name} ) =~ tr/+/_/;
        push @options, {
            type      => 'council',
            id        => sprintf( 'area:%s:%s', $_->{id}, $_->{id_name} ),
            text      => sprintf( _('Problems within %s'), $_->{name}),
            rss_text  => sprintf( _('RSS feed of problems within %s'), $_->{name}),
            uri       => $c->uri_for( '/rss/area/' . $_->{short_name} ),
        };
    }

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

=head2 reports_body_check

This function is called by the All Reports page, and lets you do some cobrand
specific checking on the URL passed to try and match to a relevant body.

=cut

sub reports_body_check {
    my ( $self, $c, $code ) = @_;
    return 0;
}

=head2 default_photo_resize

Size that photos are to be resized to for display. If photos aren't
to be resized then return 0;

=cut

sub default_photo_resize { return 0; }

=head2 get_report_stats

Get stats to display on the council reports page

=cut

sub get_report_stats { return 0; }

sub get_body_sender {
    my ( $self, $body, $category ) = @_;

    if ( $body->can_be_devolved ) {
        # look up via category
        my $config = FixMyStreet::App->model("DB::Contact")->search( { body_id => $body->id, category => $category } )->first;
        if ( $config->send_method ) {
            return { method => $config->send_method, config => $config };
        } else {
            return { method => $body->send_method, config => $body };
        }
    } elsif ( $body->send_method ) {
        return { method => $body->send_method, config => $body };
    }

    return $self->_fallback_body_sender( $body, $category );
}

sub _fallback_body_sender {
    my ( $self, $body, $category ) = @_;

    return { method => 'Email' };
};

sub example_places {
    my $e = FixMyStreet->config('EXAMPLE_PLACES') || [ 'High Street', 'Main Street' ];
    $e = [ map { Encode::decode('UTF-8', $_) } @$e ];
    return $e;
}

=head2 title_list

Returns an arrayref of possible titles for a person to send to the mobile app.

=cut

sub title_list { return undef; }

=head2 only_authed_can_create

If true, only users with the from_body flag set are able to create reports.

=cut

sub only_authed_can_create {
    return 0;
}

=head2 areas_on_around

If set to an arrayref, will plot those area ID(s) from mapit on all the /around pages.

=cut

sub areas_on_around { []; }

sub process_extras {}

=head 2 pin_colour

Returns the colour of pin to be used for a particular report
(so perhaps different depending upon the age of the report).

=cut
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    #return 'green' if time() - $p->confirmed->epoch < 7 * 24 * 60 * 60;
    return 'yellow' if $context eq 'around' || $context eq 'reports' || $context eq 'report';
    return $p->is_fixed ? 'green' : 'red';
}

=head2 path_to_pin_icons

Used to override the path for the pin icons if you want to add custom pin icons
for your cobrand.

=cut

sub path_to_pin_icons {
    return '/i/';
}


=head2 tweak_all_reports_map

Used to tweak the display settings of the map on the all reports pages.

Used in some cobrands to improve the intial display for Internet Explorer.

=cut

sub tweak_all_reports_map {}

sub can_support_problems { return 0; }

sub default_map_zoom { undef };

sub users_can_hide { return 0; }

=head2 default_show_name

Returns true if the show name checkbox should be ticked by default.

=cut

sub default_show_name {
    1;
}

=head2 report_check_for_errors

Perform validation for new reports. Takes Catalyst context object as an argument

=cut

sub report_check_for_errors {
    my $self = shift;
    my $c = shift;

    return (
        %{ $c->stash->{field_errors} },
        %{ $c->stash->{report}->user->check_for_errors },
        %{ $c->stash->{report}->check_for_errors },
    );
}

sub report_sent_confirmation_email { 0; }

=head2 never_confirm_reports

If true then we never send an email to confirm a report

=cut

sub never_confirm_reports { 0; }

=head2 allow_anonymous_reports

If true then can have reports that are truely anonymous - i.e with no email or name. You
need to also put details in the anonymous_account function too.

=cut

sub allow_anonymous_reports { 0; }

=head2 anonymous_account

Details to use for anonymous reports. This should return a hashref with an email and
a name key

=cut

sub anonymous_account { undef; }

=head2 show_unconfirmed_reports

Whether reports in state 'unconfirmed' should still be shown on the public site.
(They're always included in the admin interface.)

=cut

sub show_unconfirmed_reports {
    0;
}

=head2 never_confirm_updates

If true then we never send an email to confirm an update

=cut

sub never_confirm_updates { 0; }

sub include_time_in_update_alerts { 0; }

=head2 prettify_dt

    my $date = $c->prettify_dt( $datetime );

Takes a datetime object and returns a string representation.

=cut

sub prettify_dt {
    my $self = shift;
    my $dt = shift;

    return Utils::prettify_dt( $dt, 1 );
}

=head2 extra_contact_validation

Perform any extra validation on the contact form.

=cut

sub extra_contact_validation { (); }


=head2 get_geocoder

Return the default geocoder from config.

=cut

sub get_geocoder {
    my ($self, $c) = @_;
    return $c->config->{GEOCODER};
}


sub problem_as_hashref {
    my $self = shift;
    my $problem = shift;
    my $ctx = shift;

    return $problem->as_hashref( $ctx );
}

sub updates_as_hashref {
    my $self = shift;
    my $problem = shift;
    my $ctx = shift;

    return {};
}

sub get_country_for_ip_address {
    return 0;
}

sub jurisdiction_id_example {
    my $self = shift;
    return $self->moniker;
}

=head2 body_details_data

Returns a list of bodies to create with ensure_body.  These
are mostly just passed to ->find_or_create, but there is some
pre-processing so that you can enter:

    area_id => 123,
    parent => 'Big Town',

instead of

    body_areas => [ { area_id => 123 } ],
    parent => { name => 'Big Town' },

For example:

    return (
        {
            name => 'Big Town',
        },
        {
            name => 'Small town',
            parent => 'Big Town',
            area_id => 1234,
        },


=cut

sub body_details_data {
    return ();
}

=head2 contact_details_data

Returns a list of contact_data to create with setup_contacts.
See Zurich for an example.

=cut

sub contact_details_data {
    return ()
}

1;
