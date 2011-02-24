package FixMyStreet::Cobrand::Default;

use strict;
use warnings;
use FixMyStreet;
use URI;

use Carp;

=head2 new

    my $cobrand = $class->new;
    my $cobrand = $class->new( { request => $c->req } );

Create a new cobrand object, optionally setting the web request.

You probably shouldn't need to do this and should get the cobrand object via a
method in L<FixMyStreet::Cobrand> instead.

=cut

sub new {
    my $class = shift;
    my $self = shift || {};
    return bless $self, $class;
}

=head2 moniker

    $moniker = $cobrand_class->moniker();

Returns a moniker that can be used to identify this cobrand. By default this is
the last part of the class name lowercased - eg 'F::C::SomeCobrand' becomes
'somecobrand'.

=cut

sub moniker {
    my $class = ref( $_[0] ) || $_[0];    # deal with object or class
    my ($last_part) = $class =~ m{::(\w+)$};
    return lc($last_part);
}

=head2 is_default

    $bool = $cobrand->is_default();

Returns true if this is the default cobrand, false otherwise.

=cut

sub is_default {
    my $self = shift;
    return $self->moniker eq 'default';
}

=head2 q

    $request = $cobrand->q;

Often the cobrand needs access to the request so we add it at the start by
passing it to ->new. If the request has not been set and you call this (or a
method that needs it) then it croaks. This is probably because you are trying to
use a request-related method out of a request-context.

=cut

sub q {
    my $self = shift;
    return $self->{request}
      || croak "No request has been set"
      . " - should you be calling this method outside of a web request?";
}

=head2 path_to_web_templates

    $path = $cobrand->path_to_web_templates(  );

Returns the path to the templates for this cobrand - by default
"templates/web/$moniker"

=cut

sub path_to_web_templates {
    my $self = shift;
    return FixMyStreet->path_to( 'templates/web', $self->moniker );
}

=head1 site_restriction

Return a site restriction clause and a site key if the cobrand uses a subset of
the FixMyStreet data. Parameter is any extra data the cobrand needs. Returns an
empty string and site key 0 if the cobrand uses all the data.

=cut

sub site_restriction { return ( "", 0 ) }

=head2 contact_restriction

Return a contact restriction clause if the cobrand uses a subset of the
FixMyStreet contact data.

=cut

sub contact_restriction {
    '';
}

=head2 base_url_for_emails

Return the base url to use in links in emails for the cobranded version of the
site, parameter is extra data.

=cut

sub base_url_for_emails {
    my $self = shift;
    return $self->base_url;
}

=head2 admin_base_url

Base URL for the admin interface.

=cut

sub admin_base_url { 0 }

=head2 writetothem_url

URL for writetothem; parameter is COBRAND_DATA.

=cut

sub writetothem_url { 0 }

=head2 base_url

Return the base url for the cobranded version of the site

=cut

sub base_url { mySociety::Config::get('BASE_URL') }

=head2 base_host

Return the base host for the cobranded version of the site

=cut

sub base_host {
    my $self = shift;
    my $uri  = URI->new( $self->base_url );
    return $uri->host;
}

=head2 enter_postcode_text

Return the text that prompts the user to enter their postcode/place name.
Parameter is QUERY

=cut

sub enter_postcode_text { '' }

=head2 set_lang_and_domain

    my $set_lang = $cobrand->set_lang_and_domain( $lang, $unicode, $dir )

Set the language and domain of the site based on the cobrand and host.

=cut

sub set_lang_and_domain {
    my ( $self, $lang, $unicode, $dir ) = @_;
    my $set_lang = mySociety::Locale::negotiate_language(
        'en-gb,English,en_GB|nb,Norwegian,nb_NO', $lang );    # XXX Testing
    mySociety::Locale::gettext_domain( 'FixMyStreet', $unicode, $dir );
    mySociety::Locale::change();
    return $set_lang;
}

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
    return Problems::recent_photos(@_);
}

=head2 recent

Return recent problems on the site.

=cut

sub recent {
    my $self = shift;
    return Problems::recent(@_);
}

=head2 front_stats

Given a QUERY, return a block of html for showing front stats for the site

=cut

sub front_stats {
    my $self = shift;
    return Problems::front_stats(@_);
}

=head2 disambiguate_location

Given a STRING ($_[1]) representing a location and a QUERY, return a string that
includes any disambiguating information available

=cut 

sub disambiguate_location { "$_[1]&gl=uk" }

=head2 prettify_epoch 

Parameter is EPOCHTIME

=cut

sub prettify_epoch { 0 }

=head2 form_elements

Parameters are FORM_NAME, QUERY. Return HTML for any extra needed elements for
FORM_NAME

=cut

sub form_elements { '' }

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

=head2 extra_problem_data

Parameter is QUERY. Return a string of extra data to be stored with a problem

=cut

sub extra_problem_data { '' }

=head2 extra_update_data

Parameter is QUERY. Return a string of extra data to be stored with an update

=cut 

sub extra_update_data { '' }

=head2 extra_alert_data

Parameter is QUERY. Return a string of extra data to be stored with an alert

=cut 

sub extra_alert_data { '' }

=head2 extra_data

Given a QUERY, extract any extra data required by the cobrand

=cut

sub extra_data { '' }

=head2 extra_params

Given a QUERY, return a hash of extra params to be included in any URLs in links
produced on the page returned by that query.

=cut

sub extra_params { '' }

=head2 extra_problem_meta_text

Returns any extra text to be displayed with a PROBLEM.

=cut

sub extra_problem_meta_text { '' }

=head2 extra_update_meta_text

Returns any extra text to be displayed with an UPDATE.

=cut 

sub extra_update_meta_text { '' }

=head2 url

Given a URL ($_[1]), QUERY, EXTRA_DATA, return a URL with any extra params
needed appended to it.

=cut

sub url { $_[1] }

=head2 header_params

Return any params to be added to responses

=cut

sub header_params { return {} }

=head2 root_path_js

Parameter is QUERY. Return some js to set the root path from which AJAX queries
should be made.

=cut

sub root_path_js { 'var root_path = "";' }

=head2 site_title

Return the title to be used in page heads.

=cut

sub site_title { 'FixMyStreet.com' }

=head2 on_map_list_limit

Return the maximum number of items to be given in the list of reports on the map

=cut

sub on_map_list_limit { return undef; }

=head2 allow_photo_upload

Return a boolean indicating whether the cobrand allows photo uploads

=cut

sub allow_photo_upload { return 1; }

=head2 allow_crosssell_adverts

Return a boolean indicating whether the cobrand allows the display of crosssell
adverts

=cut

sub allow_crosssell_adverts { return 1; }

=head2 allow_photo_display

Return a boolean indicating whether the cobrand allows photo display

=cut

sub allow_photo_display { return 1; }

=head2 allow_update_reporting

Return a boolean indication whether users should see links next to updates
allowing them to report them as offensive.

=cut

sub allow_update_reporting { return 0; }

=head2 geocoded_string_check

Parameters are LOCATION, QUERY. Return a boolean indicating whether the
string LOCATION passes the cobrands checks.

=cut

sub geocoded_string_check { return 1; }

=head2 council_check

Paramters are COUNCILS, QUERY, CONTEXT. Return a boolean indicating whether
COUNCILS pass any extra checks. CONTEXT is where we are on the site.

=cut

sub council_check { return ( 1, '' ); }

=head2 feed_xsl

Return an XSL to be used in rendering feeds

=cut

sub feed_xsl { '/xsl.xsl' }

=head2 all_councils_report

Return a boolean indicating whether the cobrand displays a report of all
councils

=cut

sub all_councils_report { 1 }

=head2 ask_ever_reported

Return a boolean indicating whether people should be asked whether this is the
first time they' ve reported a problem

=cut

sub ask_ever_reported { 1 }

=head2 admin_pages

List of names of pages to display on the admin interface

=cut

sub admin_pages { 0 }

=head2 admin_show_creation_graph

Show the problem creation graph in the admin interface
=cut

sub admin_show_creation_graph { 1 }

=head2 area_types, area_min_generation

The MaPit types this site handles

=cut

sub area_types          { return qw(DIS LBO MTD UTA CTY COI); }
sub area_min_generation { 10 }

=head2 contact_name, contact_email

Return the contact name or email for the cobranded version of the site (to be
used in emails).

=cut

sub contact_name  { $_[0]->get_cobrand_conf('CONTACT_NAME') }
sub contact_email { $_[0]->get_cobrand_conf('CONTACT_EMAIL') }

=head2 get_cobrand_conf COBRAND KEY

Get the value for KEY from the config file for COBRAND

=cut

sub get_cobrand_conf {
    my ( $self, $key ) = @_;
    my $value           = undef;
    my $cobrand_moniker = $self->moniker;

    my $cobrand_config_file =
      FixMyStreet->path_to("conf/cobrands/$cobrand_moniker/general");
    my $normal_config_file = FixMyStreet->path_to('conf/general');

    if ( -e $cobrand_config_file ) {

        # FIXME - don't rely on the config file name - should
        # change mySociety::Config so that it can return values from a
        # particular config file instead
        mySociety::Config::set_file("$cobrand_config_file");
        my $config_key = $key . "_" . uc($cobrand_moniker);
        $value = mySociety::Config::get( $config_key, undef );
        mySociety::Config::set_file("$normal_config_file");
    }

    # If we didn't find a value use one from normal config
    if ( !defined($value) ) {
        $value = mySociety::Config::get($key);
    }

    return $value;
}

=item email_host

Return if we are the virtual host that sends email for this cobrand

=cut

sub email_host {
    my $self               = shift;
    my $cobrand_moniker_uc = uc( $self->moniker );

    my $email_vhost =
         mySociety::Config::get("EMAIL_VHOST_$cobrand_moniker_uc")
      || mySociety::Config::get("EMAIL_VHOST")
      || '';

    return $email_vhost
      && "http://$email_vhost" eq mySociety::Config::get("BASE_URL");
}

1;

