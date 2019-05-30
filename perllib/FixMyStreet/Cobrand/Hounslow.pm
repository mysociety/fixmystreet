package FixMyStreet::Cobrand::Hounslow;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2483 }
sub council_area { 'Hounslow' }
sub council_name { 'Hounslow Highways' }
sub council_url { 'hounslow' }
sub example_places { ( 'TW3 1SN', "Depot Road" ) }

sub map_type { 'Hounslow' }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fms.hounslowhighways.org';
}

sub enter_postcode_text {
    my ($self) = @_;
    return "Enter a Hounslow street name and area, or postcode";
}

sub admin_user_domain { 'hounslowhighways.org' }

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

sub contact_email {
    my $self = shift;
    return join( '@', 'enquiries', $self->council_url . 'highways.org' );
}

sub send_questionnaires { 0 }

sub enable_category_groups { 1 }

sub suggest_duplicates { 1 }

sub categories_restriction {
    my ($self, $rs) = @_;
    # Categories covering the Hounslow area have a mixture of Open311 and Email
    # send methods. Hounslow only want Open311 categories to be visible on their
    # cobrand, not the email categories from FMS.com. We've set up the
    # Email categories with a devolved send_method, so can identify Open311
    # categories as those which have a blank send_method.
    return $rs->search( { 'me.send_method' => undef, 'body.name' => 'Hounslow Borough Council' } );
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

    # Check Open311 was successful
    return unless $row->external_id;

    my $e = join( '@', 'enquiries', $self->council_url . 'highways.org' );
    my $sender = FixMyStreet::SendReport::Email->new( to => [ [ $e, 'Hounslow Highways' ] ] );
    $sender->send($row, $h);
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

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

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

sub allow_general_enquiries { 1 }

sub setup_general_enquiries_stash {
  my $self = shift;

  my @bodies = $self->{c}->model('DB::Body')->active->for_areas(( $self->council_area_id ))->all;
  my %bodies = map { $_->id => $_ } @bodies;
  my @contacts                #
    = $self->{c}              #
    ->model('DB::Contact')    #
    ->active
    ->search( { 'me.body_id' => [ keys %bodies ] }, { prefetch => 'body' } )->all;
  @contacts = grep { $_->get_extra_metadata('group') eq 'Other' || $_->get_extra_metadata('group') eq 'General Enquiries'} @contacts;
  $self->{c}->stash->{bodies} = \%bodies;
  $self->{c}->stash->{contacts} = \@contacts;
  $self->{c}->stash->{missing_details_bodies} = [];
  $self->{c}->stash->{missing_details_body_names} = [];
}

sub lookup_site_code_config { {
    buffer => 50, # metres
    url => "https://tilma.mysociety.org/mapserver/hounslow",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "streets",
    property => "SITE_CODE",
    accept_feature => sub { 1 }
} }

1;
