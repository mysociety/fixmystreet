package FixMyStreet::Cobrand::Hounslow;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 2483 }
sub council_area { 'Hounslow' }
sub council_name { 'Hounslow Highways' }
sub council_url { 'hounslow' }

sub map_type { 'Hounslow' }

sub enter_postcode_text {
    my ($self) = @_;
    return "Enter a Hounslow street name and area, or postcode";
}

sub admin_user_domain { ('hounslowhighways.org', 'hounslow.gov.uk') }

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = "Hounslow";

    # Some specific Hounslow roads produce lots of geocoder results
    # for the same road; this picks just one.
    ( $string, $town ) = ( "TW3 4HR", "" ) if $string =~ /lampton\s+road/i;
    ( $string, $town ) = ( "TW3 4AJ", "" ) if $string =~ /kingsley\s+road/i;
    ( $string, $town ) = ( "TW3 1YQ", "" ) if $string =~ /stanborough\s+road/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        string => $string,
        centre => '51.468495,-0.366134',
        town => $town,
        bounds => [ 51.420739, -0.461502, 51.502850, -0.243443 ],
    };
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub on_map_default_status { 'open' }

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'yellow';
}

sub send_questionnaires { 0 }

sub categories_restriction {
    my ($self, $rs) = @_;
    # Categories covering the Hounslow area have a mixture of Open311 and Email
    # send methods. Hounslow only want Open311 categories to be visible on their
    # cobrand, not the email categories from FMS.com. We've set up the
    # Email categories with a devolved send_method, so can identify Open311
    # categories as those which have a blank send_method.
    return $rs->search({
        'me.send_method' => undef,
        'body.name' => [ 'Hounslow Borough Council', 'Highways England' ],
    });
}

sub report_sent_confirmation_email { 'external_id' }

# Used to change the "Sent to" line on report pages
sub link_to_council_cobrand { "Hounslow Highways" }

# The "all reports" link will default to using council_name, which
# in our case doesn't correspond to a body and so causes an infinite redirect.
# Instead, force the borough council name to be used.
sub all_reports_single_body { { name => "Hounslow Borough Council" } }

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Stop the email being sent for each Open311 failure; only the once.
    return if $row->get_extra_metadata('hounslow_email_sent');

    my $e = join( '@', 'enquiries', $self->council_url . 'highways.org' );
    my $sender = FixMyStreet::SendReport::Email->new( to => [ [ $e, 'Hounslow Highways' ] ] );
    if (!$sender->send($row, $h)) {
        $row->set_extra_metadata('hounslow_email_sent', 1);
    }
}

around 'open311_config' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    $params->{upload_files} = 1;
    $self->$orig($row, $h, $params);
};

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # Hounslow want to make it clear in Confirm when an update is left by
    # someone who's not the original reporter.
    unless ($comment->user eq $comment->problem->user) {
        $params->{description} = "[This comment was not left by the original problem reporter] " . $params->{description};
    }
}

sub open311_skip_report_fetch {
  my ($self, $problem) = @_;

  return 1 if $problem->non_public;
}

# Make sure fetched report description isn't shown.
sub filter_report_description { "" }

sub setup_general_enquiries_stash {
  my $self = shift;

  my @bodies = $self->{c}->model('DB::Body')->active->for_areas(( $self->council_area_id ))->all;
  my %bodies = map { $_->id => $_ } @bodies;
  my @contacts                #
    = $self->{c}              #
    ->model('DB::Contact')    #
    ->active
    ->search(
        {
          'me.body_id' => [ keys %bodies ]
        },
        {
          prefetch => 'body',
          order_by => 'me.category',
        }
      )->all;
  @contacts = grep {
    my $group = $_->get_extra_metadata('group') || '';
    $group eq 'Other' || $group eq 'General Enquiries';
  } @contacts;
  $self->{c}->stash->{bodies} = \%bodies;
  $self->{c}->stash->{bodies_to_list} = \%bodies;
  $self->{c}->stash->{contacts} = \@contacts;
  $self->{c}->stash->{missing_details_bodies} = [];
  $self->{c}->stash->{missing_details_body_names} = [];

  $self->{c}->set_param('title', "General Enquiry");
  # Can't use (0, 0) for lat lon so default to the rough location
  # of Hounslow Highways HQ.
  $self->{c}->stash->{latitude} = 51.469;
  $self->{c}->stash->{longitude} = -0.35;

  return 1;
}

sub abuse_reports_only { 1 }

sub lookup_site_code_config { {
    buffer => 50, # metres
    url => "https://tilma.mysociety.org/mapserver/hounslow",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "streets",
    property => "SITE_CODE",
    accept_feature => sub { 1 }
} }

# Hounslow don't want any reports made before their go-live date visible on
# their cobrand at all.
sub cut_off_date { '2019-05-06' }

1;
