package FixMyStreet::App::Controller::Reports::New;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Geocode;
use Encode;
use Sort::Key qw(keysort);
use List::MoreUtils qw(uniq);
use HTML::Entities;

=head1 NAME

FixMyStreet::App::Controller::Reports::New

=head1 DESCRIPTION

Create a new report, or complete a partial one .

=head1 PARAMETERS

=head2 flow control

submit_map: true if we reached this page by clicking on the map

submit_problem: true if a problem has been submitted

=head2 location (required)

We require a location - either lat/lng or a tile click.

longitude, latitude: location of the report - either determined from the
address/postcode or from a map click.

x, y, tile_xxx.yyy.x, tile_xxx.yyy.y: x and y are the tile locations. The
'tile_xxx.yyy' pair are the click locations on the tile. These can be converted
back into lat/lng by the map code.

=head2 optional

pc: location user searched for

skipped: true if the map was skipped - may mean that the location is not as
accurate as we'd like. Default is false.

upload_fileid: set if there is an uploaded file (might not be needed if we use the Catalyst upload handlers)

anonymous: bool - false if the user wants this report to be anonymous. NOTE -
this is the inverse of what you expect. FIXME - rename to 'may_show_name' to be
clearer.

title

detail

name

email

phone

council

partial

=head2 can be ignored

all_pins: related to map display - not relevant to creation of a new report

=cut

sub report_new : Path : Args(0) {
    my ( $self, $c ) = @_;

    # FIXME - deal with partial reports here

    # work out the location for this report and do some checks
    $c->forward('determine_location') || return;
    $c->forward('check_councils')     || return;

    # create a problem from the submitted details
    $c->stash->{template} = "reports/new/fill_in_details.html";
    $c->forward('prepare_report');
    $c->forward('generate_map');

}

=head2 determine_location

Work out what the location of the report should be - either by using lat,lng or
a tile click or a user search query C<pc>. Returns false if no location could be
found.

=cut 

sub determine_location : Private {
    my ( $self, $c ) = @_;

    return
      unless $c->forward('determine_location_from_tile_click')
          || $c->forward('determine_location_from_coords')
          || $c->forward('determine_location_from_pc');

    # Check this location is okay to be displayed for the cobrand
    my ( $success, $error_msg ) = $c->cobrand->council_check(    #
        { lat => $c->stash->{latitude}, lon => $c->stash->{longitude} },
        'submit_problem'
    );

    # all good
    return 1 if $success;

    # show error
    $c->stash->{pc_error} = $error_msg;
    return;
}

=head2 determine_location_from_tile_click

Detect that the map tiles have been clicked on by looking for the tile
parameters.

=cut 

sub determine_location_from_tile_click : Private {
    my ( $self, $c ) = @_;

    # example: 'tile_1673.1451.x'
    my $param_key_regex = '^tile_(\d+)\.(\d+)\.[xy]$';

    my @matching_param_keys =
      grep { m/$param_key_regex/ } keys %{ $c->req->params };

    # did we find any matches
    return unless scalar(@matching_param_keys) == 2;

    # get the x and y keys
    my ( $x_key, $y_key ) = sort @matching_param_keys;

    # Extract the data needed
    my ( $pin_tile_x, $pin_tile_y ) = $x_key =~ m{$param_key_regex};
    my $pin_x = $c->req->param($x_key);
    my $pin_y = $c->req->param($y_key);

    # convert the click to lat and lng
    my ( $latitude, $longitude ) =
      FixMyStreet::Map::click_to_wgs84( $pin_tile_x, $pin_x, $pin_tile_y,
        $pin_y );

    # store it on the stash
    $c->stash->{latitude}  = $latitude;
    $c->stash->{longitude} = $longitude;

    # return true as we found a location
    return 1;
}

=head2 determine_location_from_coords

Use latitude and longitude if provided in parameters.

=cut 

sub determine_location_from_coords : Private {
    my ( $self, $c ) = @_;

    my $latitude  = $c->req->param('latitude');
    my $longitude = $c->req->param('longitude');

    if ( defined $latitude && defined $longitude ) {
        $c->stash->{latitude}  = $latitude;
        $c->stash->{longitude} = $longitude;
        return 1;
    }

    return;
}

=head2 determine_location_from_pc

User has searched for a location - try to find it for them.

If one match is found returns true and lat/lng is set.

If several possible matches are found puts an array onto stash so that user can be prompted to pick one and returns false.

If no matches are found returns false.

=cut 

sub determine_location_from_pc : Private {
    my ( $self, $c ) = @_;

    # check for something to search
    my $pc = $c->req->param('pc') || return;
    $c->stash->{pc} = $pc;    # for template

    my ( $latitude, $longitude, $error ) =
      eval { FixMyStreet::Geocode::lookup( $pc, $c->req ) };

    # Check that nothing blew up
    if ($@) {
        warn "Error: $@";
        return;
    }

    # If we got a lat/lng set to stash and return true
    if ( defined $latitude && defined $longitude ) {
        $c->stash->{latitude}  = $latitude;
        $c->stash->{longitude} = $longitude;
        return 1;
    }

    # $error doubles up to return multiple choices by being an array
    if ( ref($error) eq 'ARRAY' ) {
        @$error = map { decode_utf8($_) } @$error;
        $c->stash->{possible_location_matches} = $error;
        return;
    }

    # pass errors back to the template
    $c->stash->{pc_error} = $error;
    return;
}

=head2 check_councils

Load all the councils and check that they are ok. Do a small amount of cleanup.

=cut

sub check_councils : Private {
    my ( $self, $c ) = @_;
    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    # Look up councils and do checks for the point we've got
    my @area_types = $c->cobrand->area_types();

    # XXX: I think we want in_gb_locale around the next line, needs testing
    my $all_councils =
      mySociety::MaPit::call( 'point', "4326/$longitude,$latitude",
        type => \@area_types );

    # Let cobrand do a check
    my ( $success, $error_msg ) =
      $c->cobrand->council_check( { all_councils => $all_councils },
        'submit_problem' );
    if ( !$success ) {
        $c->stash->{location_error} = $error_msg;
        return;
    }

    # UK specific tweaks
    # FIXME - move into cobrand
    if ( mySociety::Config::get('COUNTRY') eq 'GB' ) {

        # Ipswich & St Edmundsbury are responsible for everything in their
        # areas, not Suffolk
        delete $all_councils->{2241}
          if $all_councils->{2446}    #
              || $all_councils->{2443};

        # Norwich is responsible for everything in its areas, not Norfolk
        delete $all_councils->{2233}    #
          if $all_councils->{2391};
    }

    # Norway specific tweaks
    # FIXME - move into cobrand
    if ( mySociety::Config::get('COUNTRY') eq 'NO' ) {

        # Oslo is both a kommune and a fylke, we only want to show it once
        delete $all_councils->{301}     #
          if $all_councils->{3};
    }

    # were councils found for this location
    if ( !scalar keys %$all_councils ) {
        $c->stash->{location_error} =
          _(    'That spot does not appear to be covered by a council. If you'
              . ' have tried to report an issue past the shoreline, for'
              . ' example, please specify the closest point on land.' );
        return;
    }

    # all good if we have some councils left
    $c->stash->{all_councils} = $all_councils;
    return 1;
}

=head2 setup_categories_and_councils

Look up categories for this council or councils

=cut

sub setup_categories_and_councils : Private {
    my ( $self, $c ) = @_;

    my @all_council_ids = keys %{ $c->stash->{all_councils} };

    my @contacts                 #
      = $c                       #
      ->model('DB::Contacts')    #
      ->not_deleted              #
      ->search( { area_id => \@all_council_ids } )    #
      ->all;

    # variables to populate
    my @area_ids_to_list = ();
    my @category_options = ();
    my $category_label   = undef;

    # FIXME - implement in cobrand
    if ( $c->cobrand->moniker eq 'emptyhomes' ) {
        foreach (@contacts) {
            push @area_ids_to_list, $_->area_id;
        }
        @category_options = (
            _('-- Pick a property type --'),
            _('Empty house or bungalow'),
            _('Empty flat or maisonette'),
            _('Whole block of empty flats'),
            _('Empty office or other commercial'),
            _('Empty pub or bar'),
            _('Empty public building - school, hospital, etc.')
        );
        $category_label = _('Property type:');
    }
    else {

        @contacts = keysort { $_->category } @contacts;
        foreach my $contact (@contacts) {
            push @area_ids_to_list, $contact->area_id;
            push @category_options, $contact->category
              unless $contact->category eq _('Other');
        }

        # defunct...
        # if ( $q->{site} eq 'scambs' ) {
        #     @categories = Page::scambs_categories();
        # }

        if (@category_options) {
            @category_options =
              ( _('-- Pick a category --'), @category_options, _('Other') );
            $category_label = _('Category:');
        }

    }

    # put results onto stash
    $c->stash->{area_ids_to_list} = @area_ids_to_list;
    $c->stash->{category_options} = @category_options;
    $c->stash->{category_label}   = $category_label;

}

=head2 prepare_report

Looking at the parameters passed in create a new item and return it. Does not
save anything to the database. If no item can be created (ie no information
provided) returns undef.

=cut

sub prepare_report : Private {
    my ( $self, $c ) = @_;

    # create a new report, but don't save it yet
    my $report = $c->model('DB::Problem')->new(
        {
            latitude  => $c->stash->{latitude},
            longitude => $c->stash->{longitude},
        }
    );

    return 1;
}

=head2 generate_map

Add the html needed to for the map to the stash.

=cut

# FIXME - much of this should not happen here or in maps code but in the
# templates.

sub generate_map : Private {
    my ( $self, $c ) = @_;
    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    # Forms that allow photos need a different enctype
    my $allow_photo_upload = $c->cobrand->allow_photo_upload;

    # Don't do anything if the user skipped the map
    if ( $c->req->param('skipped') ) {

        my $enctype =
          $allow_photo_upload
          ? ' enctype="multipart/form-data"'
          : '';

        my $cobrand_form_elements =
          $c->cobrand->form_elements('mapSkippedForm');

        my $form_action = $c->uri_for('');
        my $pc          = encode_entities( $c->stash->{pc} );

        $c->stash->{map_html} = <<END_MAP_HTML;
<form action="$form_action" method="post" name="mapSkippedForm"$enctype>
<input type="hidden" name="pc" value="pc">
<input type="hidden" name="skipped" value="1">
$cobrand_form_elements
<div id="skipped-map">
END_MAP_HTML

    }
    else {
        my $map_type = $allow_photo_upload ? 2 : 1;

        $c->stash->{map_html} = FixMyStreet::Map::display_map(
            $c->req,
            latitude  => $latitude,
            longitude => $longitude,
            type      => $map_type,
            pins      => [ [ $latitude, $longitude, 'purple' ] ],
        );
    }
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
