package FixMyStreet::Cobrand::Default;
use base 'FixMyStreet::Cobrand::Base';

use strict;
use warnings;
use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::Geocode;
use FixMyStreet::Geocode::Address;
use FixMyStreet::OutOfHours;
use DateTime;
use JSON::MaybeXS;
use List::MoreUtils 'none';
use URI;
use Digest::MD5 qw(md5_hex);

use Carp;
use mySociety::PostcodeUtil;
use mySociety::Random;

=head1 The default cobrand

This module provides the default cobrand functions used by the codebase,
if not overridden by the cobrand in use.

=head1 Functions

=over

=item path_to_web_templates

    $path = $cobrand->path_to_web_templates(  );

Returns the path to the templates for this cobrand - by default
"templates/web/$moniker" (and then base in Web.pm).

=cut

sub path_to_web_templates {
    my $self = shift;
    my $paths = [
        FixMyStreet->path_to( 'templates/web', $self->moniker ),
    ];
    return $paths;
}

=item path_to_email_templates

    $path = $cobrand->path_to_email_templates(  );

Returns the path to the email templates for this cobrand - by default
"templates/email/$moniker" (and then default in Email.pm).

=cut

sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    my $paths = [
        FixMyStreet->path_to( 'templates', 'email', $self->moniker, $lang_code ),
        FixMyStreet->path_to( 'templates', 'email', $self->moniker ),
    ];
    return $paths;
}

=item feature

A helper utility to let you provide per-cobrand hooks for configuration.
Mostly useful if running a site with multiple cobrands.

=cut

sub feature {
    my ($self, $feature) = @_;
    my $features = FixMyStreet->config('COBRAND_FEATURES');
    return unless $features && ref $features eq 'HASH';
    return unless $features->{$feature} && ref $features->{$feature} eq 'HASH';
    return $features->{$feature}->{$self->moniker} // $features->{$feature}->{_fallback};
}

sub csp_config {
    FixMyStreet->config('CONTENT_SECURITY_POLICY');
}

sub add_response_headers {
    my $self = shift;
    # uncoverable branch true
    return if $self->{c}->debug;
    if (my $csp_domains = $self->csp_config) {
        $csp_domains = '' if $csp_domains eq '1';
        $csp_domains = join(' ', @$csp_domains) if ref $csp_domains;
        my $csp_nonce = $self->{c}->stash->{csp_nonce} = unpack('h*', mySociety::Random::random_bytes(16, 1));
        $self->{c}->res->header('Content-Security-Policy', "script-src 'self' 'unsafe-inline' 'nonce-$csp_nonce' $csp_domains; object-src 'none'; base-uri 'none'")
    }
}

=item password_minimum_length

Returns the minimum length a password can be set to.

=cut

sub password_minimum_length { 8 }

=item country

Returns the country that this cobrand operates in, as an ISO3166-alpha2 code.
Default is none. This is not really used for anything important (minor GB only
things involving eastings/northings mostly).

=cut

sub country {
    return '';
}

=item problems

Returns a ResultSet of Problems, potentially restricted to a subset if we're on
a cobrand that only wants some of the data.

=cut

sub problems {
    my $self = shift;
    return $self->problems_restriction(FixMyStreet::DB->resultset('Problem'));
}

=item problems_on_map

Returns a ResultSet of Problems to be shown on the /around map, potentially
restricted to a subset if we're on a cobrand that only wants some of the data.

=cut

sub problems_on_map {
    my $self = shift;
    return $self->problems_on_map_restriction(FixMyStreet::DB->resultset('Problem'));
}

=item problems_on_dashboard

Returns a ResultSet of Problems to be shown on the /dashboard.
Defaults to the same as problems.

=cut

sub problems_on_dashboard {
    my $self = shift;
    return $self->problems;
}

=item updates

Returns a ResultSet of Comments, potentially restricted to a subset if we're on
a cobrand that only wants some of the data.

=cut

sub updates {
    my $self = shift;
    return $self->updates_restriction(FixMyStreet::DB->resultset('Comment'));
}

=item problems_restriction/updates_restriction

Used to restricts reports and updates in a cobrand in a particular way. Do
nothing by default.

=cut

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs;
}

sub updates_restriction {
    my ($self, $rs) = @_;
    return $rs;
}

=item categories_restriction

Used to restrict categories available when making new report in a cobrand in a
particular way. Do nothing by default.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs;
}


=item problems_on_map_restriction

Used to restricts reports shown on the /around map in a cobrand in a particular way. Do
nothing by default.

=cut

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    return $rs;
}

=item users

Returns a ResultSet of Users, potentially restricted to a subset if we're on
a cobrand that only wants some of the data.

=cut

sub users {
    my $self = shift;
    return $self->users_restriction(FixMyStreet::DB->resultset('User'));
}

=item users_staff_admin

Returns a ResultSet of Users, restricted to staff users.

=cut

sub users_staff_admin {
    my $self = shift;
    return FixMyStreet::DB->resultset('User')->search({ from_body => { '!=', undef } });
}

=item users_restriction

Used to restricts users in the admin in a cobrand in a particular way. Do
nothing by default.

=cut

sub users_restriction {
    my ($self, $rs) = @_;
    return $rs;
}

sub site_key { return 0; }

=item restriction

Return a restriction to data saved while using this specific cobrand site.

=cut

sub restriction {
    my $self = shift;

    return $self->moniker ? { cobrand => $self->moniker } : {};
}

=item base_url_with_lang

=cut

sub base_url_with_lang {
    my $self = shift;
    return $self->base_url;
}

=item admin_base_url

Base URL for the admin interface.

=cut

sub admin_base_url {
    my $self = shift;
    return FixMyStreet->config('ADMIN_BASE_URL') || $self->base_url . "/admin";
}

=item base_url

Return the base url for the cobranded version of the site

=cut

sub base_url { FixMyStreet->config('BASE_URL') }

=item base_url_for_report

Return the base url for a report (might be different in a two-tier county, but
most of the time will be same as base_url_with_lang). Report may be an object,
or a hashref.

=cut

sub base_url_for_report {
    my ( $self, $report ) = @_;
    return $self->base_url_with_lang;
}

=item relative_url_for_report

Returns the relative base url for a report (might be different in a two-tier
county, but normally blank). Report may be an object, or a hashref.

=cut

sub relative_url_for_report {
    my ( $self, $report ) = @_;
    return "";
}

=item base_host

Return the base host for the cobranded version of the site

=cut

sub base_host {
    my $self = shift;
    my $uri  = URI->new( $self->base_url );
    return $uri->host;
}

=item enter_postcode_text

Return override text that prompts the user to enter their postcode/place name.
Can be specified in template.

=cut

sub enter_postcode_text { }

=item set_lang_and_domain

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

    FixMyStreet::DB->schema->lang($set_lang);

    return $set_lang;
}
sub languages { FixMyStreet->config('LANGUAGES') || [] }
sub language_domain { }
sub language_override { }

=item alert_list_options

Return HTML for a list of alert options for the cobrand, given QUERY and
OPTIONS.

=cut

sub alert_list_options { 0 }

=item recent_photos

Return N recent photos. If EASTING, NORTHING and DISTANCE are supplied, the
photos must be attached to problems within DISTANCE of the point defined by
EASTING and NORTHING.

=cut

sub recent_photos {
    my ($self, $area, $num, $lat, $lon, $dist) = @_;
    return $self->problems->recent_photos({
        num => $num,
        point => [$lat, $lon, $dist],
    });
}

=item recent

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

sub front_stats_show_middle { 'fixed' }

=item front_stats_data

Return a data structure containing the front stats information that a template
can then format.

=cut

sub front_stats_data {
    my ( $self ) = @_;

    my $recency         = '1 week';
    my $shorter_recency = '3 days';

    my ($fixed, $completed);
    if ($self->front_stats_show_middle eq 'completed') {
        $completed = $self->problems->recent_completed();
    } elsif ($self->front_stats_show_middle eq 'fixed') {
        $fixed = $self->problems->recent_fixed();
    }
    my $updates = $self->problems->number_comments();
    my $new     = $self->problems->recent_new( $recency );

    my $middle = $fixed // $completed // 0;
    if ( $new > $middle && $self->shorten_recency_if_new_greater_than_fixed ) {
        $recency = $shorter_recency;
        $new     = $self->problems->recent_new( $recency );
    }

    my $stats = {
        completed => $completed,
        fixed   => $fixed,
        updates => $updates,
        new     => $new,
        recency => $recency,
    };

    return $stats;
}

=item disambiguate_location

Returns any disambiguating information available. Defaults to none.

=cut

sub disambiguate_location { FixMyStreet->config('GEOCODING_DISAMBIGUATION') or {}; }

=item header_params

Return any params to be added to responses

=cut

sub header_params { return {} }

=item map_type

Return an override type of map if necessary.

=cut

sub map_type {
    my $self = shift;
    return 'OSM' if $self->{c} && $self->{c}->req->uri->host =~ /^osm\./;
    return;
}

=item reports_per_page

The number of reports to show per page on all reports page.

=cut

sub reports_per_page {
    return FixMyStreet->config('ALL_REPORTS_PER_PAGE') || 100;
}

sub report_age {
    return '6 months';
}

=item reports_ordering

The order_by clause to use for reports on all reports page

=cut

sub reports_ordering {
    return 'updated-desc';
}

=item on_map_default_status

Return the default ?status= query parameter to use for filter on map page.

=cut

sub on_map_default_status { return 'all'; }

=item allow_photo_upload

Return a boolean indicating whether the cobrand allows photo uploads

=cut

sub allow_photo_upload { return 1; }

=item allow_photo_display

Return a boolean indicating whether the cobrand allows photo display
for the particular report and photo.

=cut

sub allow_photo_display {
    my ( $self, $r, $num ) = @_;
    return 1;
}

=item allow_update_reporting

Return a boolean indication whether users should see links next to updates
allowing them to report them as offensive.

=cut

sub allow_update_reporting { return 0; }

=item updates_disallowed

Returns a boolean indicating whether updates on a particular report are allowed
or not. Default behaviour is disallowed if "closed_updates" metadata is set, or
if the report's category has its "updates_disallowed" flag set.

=cut

sub updates_disallowed {
    my ($self, $problem) = @_;
    return 'problem-closed' if $problem->get_extra_metadata('closed_updates');
    return 'category-closed' if $problem->contact && $problem->contact->get_extra_metadata('updates_disallowed');
    return '';
}

sub body_disallows_state_change {
    return $_[0]->feature('update_states_disallowed');
}

=item reopening_disallowed

Returns a boolean indicating whether reopening of a particular report is
allowed or not. Default behaviour is allowed unless the report's category
has its reopening_disallowed flag set.

=cut

sub reopening_disallowed {
    my ($self, $problem) = @_;
    return 1 if $problem->contact && $problem->contact->get_extra_metadata('reopening_disallowed');
    return 0;
}

=item geocode_postcode

Given a QUERY, return LAT/LON and/or ERROR.

=cut

sub geocode_postcode {
    my ( $self, $s ) = @_;
    return {};
}

=item geocoded_string_check

Parameters are LOCATION, QUERY. Return a boolean indicating whether the
string LOCATION passes the cobrands checks.

=cut

sub geocoded_string_check { return 1; }

=item find_closest

Used by send-reports and similar to attach nearest things to the bottom of the
report. This can be called with either a hash of lat/lon or a Problem.

=cut

sub find_closest {
    my ($self, $data) = @_;
    $data = { problem => $data } if ref $data ne 'HASH';

    my $problem = $data->{problem};
    my $lat = $problem ? $problem->latitude : $data->{latitude};
    my $lon = $problem ? $problem->longitude : $data->{longitude};
    my $j = $problem ? $problem->geocode : undef;

    if (!$j) {
        $j = FixMyStreet::Geocode::reverse($self, $lat, $lon);
        if ($problem) {
            # cache the geocoder results for use in alerts
            $problem->geocode( $j );
            $problem->update;
        }
    }

    return FixMyStreet::Geocode::Address->new($j);
}

=item find_closest_address_for_rss

Used by rss feeds to provide a bit more context

=cut

sub find_closest_address_for_rss {
    my ( $self, $problem ) = @_;
    my $j = ref($problem) eq 'HASH' ? $problem->{geocode} : $problem->geocode;
    return FixMyStreet::Geocode::Address->new($j)->for_alert;
}

=item format_postcode

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
=item area_check

Paramters are AREAS, QUERY, CONTEXT. Return a boolean indicating whether
AREAS pass any extra checks. CONTEXT is where we are on the site.

=cut

sub area_check { return ( 1, '' ); }

=item all_reports_single_body

Return a boolean indicating whether the cobrand displays a report of all
councils

=cut

sub all_reports_single_body { 0 }

=item ask_ever_reported

Return a boolean indicating whether people should be asked whether this is the
first time they' ve reported a problem

=cut

sub ask_ever_reported { 1 }

=item send_questionnaires

Return a boolean indicating whether people should be sent questionnaire emails.

=cut

sub send_questionnaires { 1 }

=item admin_pages

List of names of pages to display on the admin interface

=cut

sub admin_pages {
    my $self = shift;

    my $user = $self->{c}->user;

    my $pages = {
         'summary' => [_('Summary'), 0],
         'stats'  => [_('Stats'), 8],
    };

    # There are some pages that only super users can see
    if ( $user->is_superuser ) {
        $pages->{flagged} = [ _('Flagged'), 101 ];
        $pages->{states} = [ _('States'), 102 ];
        $pages->{config} = [ _('Configuration'), 103 ];
        $pages->{manifesttheme} = [ _('Manifest Theme'), 104 ];
        $pages->{user_import} = [ undef, undef ];
    };
    # And some that need special permissions
    if ( $user->has_body_permission_to('category_edit') ) {
        my $page_title = $user->is_superuser ? _('Bodies') : _('Categories');
        $pages->{bodies} = [ $page_title, 1 ];
        $pages->{body} = [ undef, undef ];
    }
    if ( $user->has_body_permission_to('report_edit') ) {
        $pages->{reports} = [ _('Reports'), 2 ];
        $pages->{timeline} = [_('Timeline'), 7];
        $pages->{report_edit} = [ undef, undef ];
        $pages->{update_edit} = [ undef, undef ];
    }
    if ( $user->has_body_permission_to('template_edit') ) {
        $pages->{templates} = [ _('Templates'), 3 ];
        $pages->{template_edit} = [ undef, undef ];
    };
    if ( $user->has_body_permission_to('responsepriority_edit') ) {
        $pages->{responsepriorities} = [ _('Priorities'), 4 ];
        $pages->{responsepriority_edit} = [ undef, undef ];
    };
    if ( $user->has_body_permission_to('user_edit') ) {
        $pages->{reports} = [ _('Reports'), 2 ];
        $pages->{users} = [ _('Users'), 5 ];
        $pages->{roles} = [ _('Roles'), 6 ];
        $pages->{user_edit} = [ undef, undef ];
    }
    if ( $self->allow_report_extra_fields && $user->has_body_permission_to('category_edit') ) {
        $pages->{reportextrafields} = [ _('Extra Fields'), 10 ];
        $pages->{reportextrafields_edit} = [ undef, undef ];
    }
    if ( $user->has_body_permission_to('emergency_message_edit') ) {
        $pages->{sitemessage} = [ _('Site message'), 12 ];
    }
    if ( $user->has_body_permission_to('wasteworks_config') ) {
        $pages->{waste} = [ _('WasteWorks config'), 201];
    }

    return $pages;
}

=item admin_show_creation_graph

Show the problem creation graph in the admin interface
=cut

sub admin_show_creation_graph { 1 }

=item admin_allow_user

Perform checks on whether this user can access admin. By default only superusers
are allowed.

=cut

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
}

=item available_permissions

Grouped lists of permission types available for use in the admin

=cut

sub available_permissions {
    my $self = shift;

    return {
        _("Problems") => {
            moderate => _("Moderate report details"),
            report_edit => _("Edit reports"),
            report_edit_category => _("Edit report category"), # future use
            report_edit_priority => _("Edit report priority"), # future use
            report_mark_private => _("View/Mark private reports"),
            report_inspect => _("Markup problem details"),
            report_instruct => _("Instruct contractors to fix problems"), # future use
            report_prefill => _("Automatically populate report subject/detail"),
            planned_reports => _("Manage shortlist"),
            contribute_as_another_user => _("Create reports/updates on a user's behalf"),
            contribute_as_anonymous_user => _("Create reports/updates as anonymous user"),
            contribute_as_body => _("Create reports/updates as the council"),
            default_to_body => _("Default to creating reports/updates as the council"),
            view_body_contribute_details => _("See user detail for reports created as the council"),
            assign_report_to_user => _("Assign problem reports to users"),
        },
        _("Users") => {
            user_edit => _("Edit users' details/search for their reports"),
            user_manage_permissions => _("Edit other users' permissions"),
            user_assign_body => _("Grant access to the admin"),
            user_assign_areas => _("Assign users to areas"), # future use
        },
        _("Bodies") => {
            category_edit => _("Add/edit problem categories"),
            template_edit => _("Add/edit response templates"),
            responsepriority_edit => _("Add/edit response priorities"),
            emergency_message_edit => _("Add/edit site message"),
        },
    };
}

=item admin_templates_state_and_external_status_code

Whether the cobrand allows response templates with both state and external
status code. Normally this is not allowed, but if a cobrand is updating report
state by email (and so the state is being used for the new state, not the
existing one), then we would want to allow it.

=cut

sub admin_templates_state_and_external_status_code { 0 }

=item area_types

The MaPit types this site handles

=cut

sub area_types          { FixMyStreet->config('MAPIT_TYPES') || [ 'ZZZ' ] }
sub area_types_children { FixMyStreet->config('MAPIT_TYPES_CHILDREN') || [] }
sub area_types_for_admin { $_[0]->area_types }

=item fetch_area_children

Fetches the children of a particular MapIt area ID that match the current
cobrand's area_types_children type.

=cut

sub fetch_area_children {
    my ($self, $area_ids, $body, $all_generations) = @_;

    $area_ids = [ $area_ids ] unless ref $area_ids eq 'ARRAY';

    my %all_children;

    foreach my $area_id (@$area_ids) {
        my $children = FixMyStreet::MapIt::call('area/children', $area_id,
            type => $self->area_types_children,
            $all_generations ? (min_generation => 1) : (),
        );
        %all_children = ( %all_children, %$children );
    }

    return \%all_children;
}

=item contact_name, contact_email, do_not_reply_email

Return the contact name or email for the cobranded version of the site (to be
used in emails). do_not_reply_email is used for emails you don't expect a reply
to (for example, confirmation emails).

=cut

sub contact_name  { FixMyStreet->config('CONTACT_NAME') }
sub contact_email { FixMyStreet->config('CONTACT_EMAIL') }
sub do_not_reply_email { FixMyStreet->config('DO_NOT_REPLY_EMAIL') }

=item abuse_reports_only

Return true if only abuse reports should be allowed from the contact form.

=cut

sub abuse_reports_only { 0; }

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
    $name =~ tr{/}{_};
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
        push @options, {
            type      => 'council',
            id        => sprintf( 'area:%s', $_->{id} ),
            text      => sprintf( _('Problems within %s'), $_->{name}),
            rss_text  => sprintf( _('RSS feed of problems within %s'), $_->{name}),
            uri       => $c->uri_for( '/rss/area/' . $_->{id} ),
        };
    }

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

=item reports_body_check

This function is called by the All Reports page, and lets you do some cobrand
specific checking on the URL passed to try and match to a relevant body.

=cut

sub reports_body_check {
    my ( $self, $c, $code ) = @_;
    return 0;
}

=item default_photo_resize

Size that photos are to be resized to for display. If photos aren't
to be resized then return 0;

=cut

sub default_photo_resize { return 0; }

=item get_report_stats

Get stats to display on the council reports page

=cut

sub get_report_stats { return 0; }

sub get_body_sender {
    my ( $self, $body, $problem ) = @_;

    # look up via category
    my $category = $problem->category;
    my $contact = $body->contacts->search( { category => $category } )->first;
    if ( $body->can_be_devolved && $contact && $contact->send_method ) {
        return { method => $contact->send_method, config => $contact, contact => $contact };
    }

    if ( $body->send_method ) {
        return { method => $body->send_method, config => $body, contact => $contact };
    }

    return $self->_fallback_body_sender( $body, $category, $contact );
}

sub _fallback_body_sender {
    my ( $self, $body, $category, $contact ) = @_;

    return { method => 'Email', contact => $contact };
};

sub body {
    my $self = shift;

    my $cobrand = $self->moniker;
    return FixMyStreet::DB->resultset("Body")->find({ cobrand => $cobrand });
}

sub example_places {
    # uncoverable branch true
    FixMyStreet->config('EXAMPLE_PLACES') || [ 'High Street', 'Main Street' ];
}

=item title_list

Returns an arrayref of possible titles for a person to send to the mobile app.

=cut

sub title_list { return undef; }

=item only_authed_can_create

If true, only users with the from_body flag set are able to create reports.

=cut

sub only_authed_can_create {
    return 0;
}

=item areas_on_around

If set to an arrayref, will plot those area ID(s) from mapit on all the /around pages.

=cut

sub areas_on_around { []; }

=item report_form_extras

A list of extra fields we wish to save to the database in the 'extra' column of
problems based on variables passed in by the form. Return a list of hashrefs
of values we wish to save, e.g.
( { name => 'address', required => 1 }, { name => 'passport', required => 0 } )

=cut

sub report_form_extras {}

sub process_open311_extras {}

=item pin_colour

Returns the colour of pin to be used for a particular report
(so perhaps different depending upon the age of the report).

=cut
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    #return 'green' if time() - $p->confirmed->epoch < 7 * 24 * 60 * 60;
    return 'yellow' if $context eq 'around' || $context eq 'reports' || $context eq 'report';
    return $p->is_fixed ? 'green' : 'red';
}

=item pin_new_report_colour

Returns the colour of pin to be used for a new report.

=cut
sub pin_new_report_colour {
    return 'green';
}

=item path_to_pin_icons

Used to override the path for the pin icons if you want to add custom pin icons
for your cobrand.

=cut

sub path_to_pin_icons { '/i/pins/' }

=item tweak_all_reports_map

Used to tweak the display settings of the map on the all reports pages.

Used in some cobrands to improve the intial display for Internet Explorer.

=cut

sub tweak_all_reports_map {}

sub can_support_problems { return 0; }

=item default_map_zoom

default_map_zoom is used when displaying a map overriding the
default that depends on population density.

=cut

sub default_map_zoom { undef };

sub users_can_hide { return 0; }

=item default_show_name

Returns true if the show name checkbox should be ticked by default.

=cut

sub default_show_name { 0 }

=item report_check_for_errors

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

sub report_sent_confirmation_email { '' }

=item post_report_sent

Perform any cobrand specific actions that need to happen to a report after it
has been sent. Takes the report as an argument.

=cut

sub post_report_sent { '' }

=item never_confirm_reports

If true then we never send an email to confirm a report

=cut

sub never_confirm_reports { 0; }

=item allow_anonymous_reports

If true then a report submission with no user details will default to the user
given via the anonymous_account function, and create it anonymously. If set to
'button', then this will happen only when a report_anonymously button is
pressed in the front end, rather than whenever a username is not provided.

=cut

sub allow_anonymous_reports {
    my ($self, $category_name, $lookup) = @_;

    $category_name ||= $self->{c}->stash->{category};
    return 0 unless $category_name;

    return $lookup->{$category_name} if defined $lookup->{$category_name};
    if ( $self->body ) {
        my $category_rs = FixMyStreet::DB->resultset("Contact")->search({
            body_id => $self->body->id,
            category => $category_name
        });
        if ( my $category = $category_rs->first ) {
            return 'button' if $category->get_extra_metadata('anonymous_allowed');
        }
    }

    return 0;
}

=item allow_anonymous_updates

If true then an update submission with no user details will default to the user
given via the anonymous_account function, and create it anonymously. If set to
'button', then this will happen only when a report_anonymously button is
pressed in the front end, rather than whenever a username is not provided.

=cut

sub allow_anonymous_updates { 0 }

=item anonymous_account

Details to use for anonymous reports. This should return a hashref with an email and
a name key if allowed. Use anonymous_domain or admin_user_domain to set the domain.

=cut

sub anonymous_account {
    my $self = shift;
    my $local = $self->feature('anonymous_account');
    return unless $local;
    my $domain = $self->call_hook('anonymous_domain') || $self->call_hook('admin_user_domain') || 'unknown';
    return {
        email => $local . '@' . $domain,
        name => 'Anonymous user',
    };
}

=item show_unconfirmed_reports

Whether reports in state 'unconfirmed' should still be shown on the public site.
(They're always included in the admin interface.)

=cut

sub show_unconfirmed_reports {
    0;
}

=item enable_category_groups

Whether body category groups should be displayed on the new report form. If this is
not enabled then any groups will be ignored and a flat list of categories displayed.

=cut

sub enable_category_groups {
    my $self = shift;
    return $self->feature('category_groups');
}

sub default_problem_state { 'unconfirmed' }

sub state_groups_admin {
    my $rs = FixMyStreet::DB->resultset("State");
    my @fixed = FixMyStreet::DB::Result::Problem->fixed_states;
    [
        [ $rs->display('confirmed'), [ FixMyStreet::DB::Result::Problem->open_states ] ],
        @fixed ? [ $rs->display('fixed'), [ FixMyStreet::DB::Result::Problem->fixed_states ] ] : (),
        [ $rs->display('closed'), [ FixMyStreet::DB::Result::Problem->closed_states ] ],
        [ $rs->display('hidden'), [ FixMyStreet::DB::Result::Problem->hidden_states ] ]
    ]
}

sub state_groups_inspect {
    my $rs = FixMyStreet::DB->resultset("State");
    my @fixed = FixMyStreet::DB::Result::Problem->fixed_states;
    [
        [ $rs->display('confirmed'), [ grep { $_ ne 'planned' } FixMyStreet::DB::Result::Problem->open_states ] ],
        @fixed ? [ $rs->display('fixed'), [ 'fixed - council' ] ] : (),
        [ $rs->display('closed'), [ FixMyStreet::DB::Result::Problem->closed_states ] ],
    ]
}

sub max_detailed_info_length { 0 }

sub prefill_report_fields_for_inspector { 0 }

=item never_confirm_updates

If true then we never send an email to confirm an update

=cut

sub never_confirm_updates { 0; }

sub include_time_in_update_alerts { 0; }

=item prettify_dt

    my $date = $c->prettify_dt( $datetime );

Takes a datetime object and returns a string representation.

=cut

sub prettify_dt {
    my $self = shift;
    my $dt = shift;

    return Utils::prettify_dt( $dt, 1 );
}

=item extra_contact_validation

Perform any extra validation on the contact form.

=cut

sub extra_contact_validation { (); }


=item get_geocoder

Return the default geocoder from config.

=cut

sub get_geocoder {
    FixMyStreet->config('GEOCODER');
}

=item get_reverse_geocoder

Return the default reverse geocoder from config.

=cut

sub get_reverse_geocoder {
    my $self = shift;
    return $self->feature('geocoder_reverse') || 'OSM';
}

sub sms_authentication { FixMyStreet->config('SMS_AUTHENTICATION') }

sub problem_as_hashref {
    my $self = shift;
    my $problem = shift;

    return $problem->as_hashref;
}

sub updates_as_hashref {
    my $self = shift;
    my $problem = shift;

    return {};
}

sub jurisdiction_id_example {
    my $self = shift;
    return $self->moniker;
}

=item lookup_by_ref_regex

Returns a regex to match postcode form input against to determine if a lookup
by id should be done.

=cut

sub lookup_by_ref_regex {
    return qr/^\s*ref:\s*(\d+)\s*$/;
}

=item category_extra_hidden

Return true if an Open311 service attribute should be a hidden field.
=cut

sub category_extra_hidden {
    my ($self, $meta) = @_;
    return 1 if ($meta->{automated} || '') eq 'hidden_field';
    return 0;
}

=item display_days_ago_threshold

Used to control whether a relative 'n days ago' or absolute date is shown
for problems/updates. If a problem/update's `days_ago` value is <= this figure,
the 'n days ago' format is used. By default the absolute date is always used.

=cut
sub display_days_ago_threshold { 0 }

=item allow_report_extra_fields

Used to control whether site-wide extra fields are available. If true,
users with the category_edit permission can add site-wide fields via the
admin.

=cut

sub allow_report_extra_fields { 0 }

sub social_auth_enabled {
    my $self = shift;
    my $key_present = FixMyStreet->config('FACEBOOK_APP_ID') || FixMyStreet->config('TWITTER_KEY');
    return $key_present && !$self->call_hook("social_auth_disabled");
}


=item send_moderation_notifications

Used to control whether an email is sent to the problem reporter when a report
is moderated.

Note that this is called in the context of the cobrand used to perform the
moderation, so e.g. if a UK council cobrand disables the moderation
notifications and a report is moderated on fixmystreet.com, the email will
still be sent (because it wasn't disabled on the FixMyStreet cobrand).

=back

=cut

sub send_moderation_notifications { 1 }

=item privacy_policy_url

The URL of the privacy policy to use on the report and update submissions forms.

=cut

sub privacy_policy_url { '/about/privacy' }

=item site_message

Site message, if one has been set in the admin.

=cut

sub site_message {
    my $self = shift;
    my $type = shift;
    my $body = $self->body;
    return unless $body;
    my $msg = $body->site_message($type);
    my $ooh_msg = $body->site_message($type, 1);
    if ($ooh_msg) {
        my $ooh = $self->ooh_times($body);
        $msg = $ooh_msg if $ooh->active;
    }
    FixMyStreet::Template::SafeString->new($msg) if $msg;
}

sub ooh_times {
    my ($self, $body) = @_;
    my $times = $body->get_extra_metadata("ooh_times");
    return FixMyStreet::OutOfHours->new(times => $times);
}

# Report if cobrand denies updates by user
# Default 'allows'
sub deny_updates_by_user {
    return;
}

=item report_a_problem_link

Cobrand-specific option for the 'Report a problem here' link displayed in the
top left-hand corner of the page after a problem report.

Default is empty string (false).

=cut

sub post_report_report_problem_link {
    return;
}


=item nearby_distances

Specifies the distance in metres to search for nearby reports for
inspector de-duplication and report duplicate suggestions features.

Defaults to 1000m for inspectors, 250m for duplicate suggestions.

Returning a distance of 0 means no nearby reports will be returned at all.

Should return a hashref of the form

{
    inspector => 1000,
    suggestions => 250,
}

where each key corresponds to value for the C<mode> query param passed to
/report/<id>/nearby.json or /around/nearby

=cut

sub nearby_distances { {
    inspector => 1000,
    suggestions => 250,
} }

=item new_report_title_field_label

Returns override text for the label of the title field on a new report.
Applied when it's known before submission that the report will go to a body with this cobrand.

=cut

sub new_report_title_field_label {
    return;
}

=item new_report_title_field_hint

Returns override text for the hint for the title field on a new report.
Applied when it's known before submission that the report will go to a body with this cobrand.
Superseded by a contact specific override if set.

=cut

sub new_report_title_field_hint {
    return;
}

=item new_report_detail_field_label

Return override text for the label of the detail field on a new report.
Applied when it's known before submission that the report will go to a body with this cobrand.
Superseded by a contact specific override if set.

=cut

sub new_report_detail_field_label {
    return;
}

=item new_report_detail_field_hint

Return override text for the hint text for the detail field on a new report.
Applied when it's known before submission that the report will go to a body with this cobrand.
Superseded by a contact specific override if set.

=cut

sub new_report_detail_field_hint {
    return;
}

=item suppress_report_sent_email

Returns true when a report sent email should not be sent for the given report.

=cut

sub suppress_report_sent_email { 0; }


=head2 staff_cant_assign_to_disabled_categories

Returns true when staff can assign a report to a disabled category.

=cut

sub staff_can_assign_reports_to_disabled_categories { 1; }

=item direct_debit_collection_method

Returns the method of collection for Direct Debit payments.

=cut

sub direct_debit_collection_method { 'redirect' }

1;
