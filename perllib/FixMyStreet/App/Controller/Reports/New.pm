package FixMyStreet::App::Controller::Reports::New;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Geocode;
use Encode;

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
    $c->forward('prepare_report') || return;

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

=cut 

sub determine_location_from_tile_click : Private {
    my ( $self, $c ) = @_;

    warn "FIXME - implement";

    # # Get tile co-ordinates if map clicked
    # ( $input{x} ) = $input{x} =~ /^(\d+)/;
    # $input{x} ||= 0;
    # ( $input{y} ) = $input{y} =~ /^(\d+)/;
    # $input{y} ||= 0;
    # my @ps = $q->param;
    # foreach (@ps) {
    #     ( $pin_tile_x, $pin_tile_y, $pin_x ) = ( $1, $2, $q->param($_) )
    #       if /^tile_(\d+)\.(\d+)\.x$/;
    #     $pin_y = $q->param($_) if /\.y$/;
    # }

# # tilma map was clicked on
#   ($latitude, $longitude)  = FixMyStreet::Map::click_to_wgs84($pin_tile_x, $pin_x, $pin_tile_y, $pin_y);

    return;
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
    return 1;
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

    return;

}

# sub display_form {
#     my ( $q, $errors, $field_errors ) = @_;
#     my @errors       = @$errors;
#     my %field_errors = %{$field_errors};
#     my $cobrand      = Page::get_cobrand($q);
#     push @errors, _('There were problems with your report. Please see below.')
#       if ( scalar keys %field_errors );
#
#     my ( $pin_x, $pin_y, $pin_tile_x, $pin_tile_y ) = ( 0, 0, 0, 0 );
#     my @vars =
#       qw(title detail name email phone pc latitude longitude x y skipped council anonymous partial upload_fileid);
#
#     my %input   = ();
#     my %input_h = ();
#
#     foreach my $key (@vars) {
#         my $val = $q->param($key);
#         $input{$key} = defined($val) ? $val : '';   # '0' is valid for longitude
#         $input_h{$key} = ent( $input{$key} );
#     }
#
# # Convert lat/lon to easting/northing if given
# # if ($input{lat}) {
# #     try {
# #         ($input{easting}, $input{northing}) = mySociety::GeoUtil::wgs84_to_national_grid($input{lat}, $input{lon}, 'G');
# #         $input_h{easting} = $input{easting};
# #         $input_h{northing} = $input{northing};
# #     } catch Error::Simple with {
# #         my $e = shift;
# #         push @errors, "We had a problem with the supplied co-ordinates - outside the UK?";
# #     };
# # }
#
#     # Get tile co-ordinates if map clicked
#     ( $input{x} ) = $input{x} =~ /^(\d+)/;
#     $input{x} ||= 0;
#     ( $input{y} ) = $input{y} =~ /^(\d+)/;
#     $input{y} ||= 0;
#     my @ps = $q->param;
#     foreach (@ps) {
#         ( $pin_tile_x, $pin_tile_y, $pin_x ) = ( $1, $2, $q->param($_) )
#           if /^tile_(\d+)\.(\d+)\.x$/;
#         $pin_y = $q->param($_) if /\.y$/;
#     }
#
# # We need either a map click, an E/N, to be skipping the map, or be filling in a partial form
#     return display_location( $q, @errors )
#       unless ( $pin_x && $pin_y )
#       || ( $input{latitude} && $input{longitude} )
#       || ( $input{skipped}  && $input{pc} )
#       || ( $input{partial}  && $input{pc} );
#
#     # Work out some co-ordinates from whatever we've got
#     my ( $latitude, $longitude );
#     if ( $input{skipped} ) {
#
#         # Map is being skipped
#         if ( length $input{latitude} && length $input{longitude} ) {
#             $latitude  = $input{latitude};
#             $longitude = $input{longitude};
#         }
#         else {
#             my ( $lat, $lon, $error ) =
#               FixMyStreet::Geocode::lookup( $input{pc}, $q );
#             $latitude  = $lat;
#             $longitude = $lon;
#         }
#     }
#     elsif ( $pin_x && $pin_y ) {
#
#         # tilma map was clicked on
#         ( $latitude, $longitude ) =
#           FixMyStreet::Map::click_to_wgs84( $pin_tile_x, $pin_x, $pin_tile_y,
#             $pin_y );
#     }
#     elsif ($input{partial}
#         && $input{pc}
#         && !length $input{latitude}
#         && !length $input{longitude} )
#     {
#         my $error;
#         try {
#             ( $latitude, $longitude, $error ) =
#               FixMyStreet::Geocode::lookup( $input{pc}, $q );
#         }
#         catch Error::Simple with {
#             $error = shift;
#         };
#         return FixMyStreet::Geocode::list_choices( $error, '/', $q )
#           if ref($error) eq 'ARRAY';
#         return front_page( $q, $error ) if $error;
#     }
#     else {
#
#         # Normal form submission
#         $latitude  = $input_h{latitude};
#         $longitude = $input_h{longitude};
#     }
#
#     # Look up councils and do checks for the point we've got
#     my @area_types = Cobrand::area_types($cobrand);
#
#     # XXX: I think we want in_gb_locale around the next line, needs testing
#     my $all_councils =
#       mySociety::MaPit::call( 'point', "4326/$longitude,$latitude",
#         type => \@area_types );
#
#     # Let cobrand do a check
#     my ( $success, $error_msg ) =
#       Cobrand::council_check( $cobrand, { all_councils => $all_councils },
#         $q, 'submit_problem' );
#     if ( !$success ) {
#         return front_page( $q, $error_msg );
#     }
#
#     if ( mySociety::Config::get('COUNTRY') eq 'GB' ) {
#
# # Ipswich & St Edmundsbury are responsible for everything in their areas, not Suffolk
#         delete $all_councils->{2241}
#           if $all_councils->{2446} || $all_councils->{2443};
#
#         # Norwich is responsible for everything in its areas, not Norfolk
#         delete $all_councils->{2233} if $all_councils->{2391};
#
#     }
#     elsif ( mySociety::Config::get('COUNTRY') eq 'NO' ) {
#
#         # Oslo is both a kommune and a fylke, we only want to show it once
#         delete $all_councils->{301} if $all_councils->{3};
#
#     }
#
#     return display_location(
#         $q,
#         _(
#             'That spot does not appear to be covered by a council.
# If you have tried to report an issue past the shoreline, for example,
# please specify the closest point on land.'
#         )
#     ) unless %$all_councils;
#
#     # Look up categories for this council or councils
#     my $category = '';
#     my ( %council_ok, @categories );
#     my $categories = select_all(
#         "select area_id, category from contacts
#         where deleted='f' and area_id in ("
#           . join( ',', keys %$all_councils ) . ')'
#     );
#     if ( $q->{site} ne 'emptyhomes' ) {
#         @$categories =
#           sort { strcoll( $a->{category}, $b->{category} ) } @$categories;
#         foreach (@$categories) {
#             $council_ok{ $_->{area_id} } = 1;
#             next if $_->{category} eq _('Other');
#             push @categories, $_->{category};
#         }
#         if ( $q->{site} eq 'scambs' ) {
#             @categories = Page::scambs_categories();
#         }
#         if (@categories) {
#             @categories =
#               ( _('-- Pick a category --'), @categories, _('Other') );
#             $category = _('Category:');
#         }
#     }
#     else {
#         foreach (@$categories) {
#             $council_ok{ $_->{area_id} } = 1;
#         }
#         @categories = (
#             _('-- Pick a property type --'),
#             _('Empty house or bungalow'),
#             _('Empty flat or maisonette'),
#             _('Whole block of empty flats'),
#             _('Empty office or other commercial'),
#             _('Empty pub or bar'),
#             _('Empty public building - school, hospital, etc.')
#         );
#         $category = _('Property type:');
#     }
#     $category = $q->label( { 'for' => 'form_category' }, $category )
#       . $q->popup_menu(
#         -name       => 'category',
#         -values     => \@categories,
#         -id         => 'form_category',
#         -attributes => { id => 'form_category' }
#       ) if $category;
#
#  # Work out what help text to show, depending on whether we have council details
#     my @councils = keys %council_ok;
#     my $details;
#     if ( @councils == scalar keys %$all_councils ) {
#         $details = 'all';
#     }
#     elsif ( @councils == 0 ) {
#         $details = 'none';
#     }
#     else {
#         $details = 'some';
#     }
#
#     # Forms that allow photos need a different enctype
#     my $allow_photo_upload = Cobrand::allow_photo_upload($cobrand);
#     my $enctype            = '';
#     if ($allow_photo_upload) {
#         $enctype = ' enctype="multipart/form-data"';
#     }
#
#     my %vars;
#     $vars{input_h}      = \%input_h;
#     $vars{field_errors} = \%field_errors;
#     if ( $input{skipped} ) {
#         my $cobrand_form_elements =
#           Cobrand::form_elements( $cobrand, 'mapSkippedForm', $q );
#         my $form_action = Cobrand::url( $cobrand, '/', $q );
#         $vars{form_start} = <<EOF;
# <form action="$form_action" method="post" name="mapSkippedForm"$enctype>
# <input type="hidden" name="pc" value="$input_h{pc}">
# <input type="hidden" name="skipped" value="1">
# $cobrand_form_elements
# <div id="skipped-map">
# EOF
#     }
#     else {
#         my $type;
#         if ($allow_photo_upload) {
#             $type = 2;
#         }
#         else {
#             $type = 1;
#         }
#         $vars{form_start} = FixMyStreet::Map::display_map(
#             $q,
#             latitude  => $latitude,
#             longitude => $longitude,
#             type      => $type,
#             pins      => [ [ $latitude, $longitude, 'purple' ] ],
#         );
#         my $partial_id;
#         if ( my $token = $input{partial} ) {
#             $partial_id = mySociety::AuthToken::retrieve( 'partial', $token );
#             if ($partial_id) {
#                 $vars{form_start} .= $q->p(
#                     { id => 'unknown' }, 'Please note your report has
#                 <strong>not yet been sent</strong>. Choose a category
#                 and add further information below, then submit.'
#                 );
#             }
#         }
#         $vars{text_located} = $q->p(
#             _(
# 'You have located the problem at the point marked with a purple pin on the map.
# If this is not the correct location, simply click on the map again. '
#             )
#         );
#     }
#     $vars{page_heading} = $q->h1( _('Reporting a problem') );
#
#     if ( $details eq 'all' ) {
#         my $council_list = join(
#             '</strong>' . _(' or ') . '<strong>',
#             map { $_->{name} } values %$all_councils
#         );
#         if ( $q->{site} eq 'emptyhomes' ) {
#             $vars{text_help} = '<p>' . sprintf(
#                 _(
# 'All the information you provide here will be sent to <strong>%s</strong>.
# On the site, we will show the subject and details of the problem, plus your
# name if you give us permission.'
#                 ),
#                 $council_list
#             );
#         }
#         else {
#             $vars{text_help} = '<p>' . sprintf(
#                 _(
# 'All the information you provide here will be sent to <strong>%s</strong>.
# The subject and details of the problem will be public, plus your
# name if you give us permission.'
#                 ),
#                 $council_list
#             );
#         }
#         $vars{text_help} .= '<input type="hidden" name="council" value="'
#           . join( ',', keys %$all_councils ) . '">';
#     }
#     elsif ( $details eq 'some' ) {
#         my $e = Cobrand::contact_email($cobrand);
#         my %councils = map { $_ => 1 } @councils;
#         my @missing;
#         foreach ( keys %$all_councils ) {
#             push @missing, $_ unless $councils{$_};
#         }
#         my $n = @missing;
#         my $list =
#           join( _(' or '), map { $all_councils->{$_}->{name} } @missing );
#         $vars{text_help} = '<p>'
#           . _('All the information you provide here will be sent to')
#           . ' <strong>'
#           . join(
#             '</strong>' . _(' or ') . '<strong>',
#             map { $all_councils->{$_}->{name} } @councils
#           ) . '</strong>. ';
#         $vars{text_help} .= _(
# 'The subject and details of the problem will be public, plus your name if you give us permission.'
#         );
#         $vars{text_help} .= ' '
#           . mySociety::Locale::nget(
# 'We do <strong>not</strong> yet have details for the other council that covers this location.',
# 'We do <strong>not</strong> yet have details for the other councils that cover this location.',
#             $n
#           );
#         $vars{text_help} .= ' '
#           . sprintf(
#             _(
# "You can help us by finding a contact email address for local problems for %s and emailing it to us at <a href='mailto:%s'>%s</a>."
#             ),
#             $list, $e, $e
#           );
#         $vars{text_help} .=
#             '<input type="hidden" name="council" value="'
#           . join( ',', @councils ) . '|'
#           . join( ',', @missing ) . '">';
#     }
#     else {
#         my $e    = Cobrand::contact_email($cobrand);
#         my $list = join( _(' or '), map { $_->{name} } values %$all_councils );
#         my $n    = scalar keys %$all_councils;
#         if ( $q->{site} ne 'emptyhomes' ) {
#             $vars{text_help} = '<p>';
#             $vars{text_help} .= mySociety::Locale::nget(
# 'We do not yet have details for the council that covers this location.',
# 'We do not yet have details for the councils that cover this location.',
#                 $n
#             );
#             $vars{text_help} .= _(
# "If you submit a problem here the subject and details of the problem will be public, but the problem will <strong>not</strong> be reported to the council."
#             );
#             $vars{text_help} .= sprintf(
#                 _(
# "You can help us by finding a contact email address for local problems for %s and emailing it to us at <a href='mailto:%s'>%s</a>."
#                 ),
#                 $list, $e, $e
#             );
#         }
#         else {
#             $vars{text_help} = '<p>'
#               . _(
# 'We do not yet have details for the council that covers this location.'
#               )
#               . ' '
#               . _(
# "If you submit a report here it will be left on the site, but not reported to the council &ndash; please still leave your report, so that we can show to the council the activity in their area."
#               );
#         }
#         $vars{text_help} .= '<input type="hidden" name="council" value="-1">';
#     }
#
#     if ( $input{skipped} ) {
#         $vars{text_help} .= $q->p(
#             _(
#                 'Please fill in the form below with details of the problem,
# and describe the location as precisely as possible in the details box.'
#             )
#         );
#     }
#     elsif ( $q->{site} eq 'scambs' ) {
#         $vars{text_help} .=
#           '<p>Please fill in details of the problem below. We won\'t be able
# to help unless you leave as much detail as you can, so please describe the exact location of
# the problem (e.g. on a wall), what it is, how long it has been there, a description (and a
# photo of the problem if you have one), etc.';
#     }
#     elsif ( $q->{site} eq 'emptyhomes' ) {
#         $vars{text_help} .= $q->p( _(<<EOF) );
# Please fill in details of the empty property below, saying what type of
# property it is e.g. an empty home, block of flats, office etc. Tell us
# something about its condition and any other information you feel is relevant.
# There is no need for you to give the exact address. Please be polite, concise
# and to the point; writing your message entirely in block capitals makes it hard
# to read, as does a lack of punctuation.
# EOF
#     }
#     elsif ( $details ne 'none' ) {
#         $vars{text_help} .= $q->p(
#             _(
# 'Please fill in details of the problem below. The council won\'t be able
# to help unless you leave as much detail as you can, so please describe the exact location of
# the problem (e.g. on a wall), what it is, how long it has been there, a description (and a
# photo of the problem if you have one), etc.'
#             )
#         );
#     }
#     else {
#         $vars{text_help} .=
#           $q->p( _('Please fill in details of the problem below.') );
#     }
#
#     $vars{text_help} .= '
# <input type="hidden" name="latitude" value="' . $latitude . '">
# <input type="hidden" name="longitude" value="' . $longitude . '">';
#
#     if (@errors) {
#         $vars{errors} =
#             '<ul class="error"><li>'
#           . join( '</li><li>', @errors )
#           . '</li></ul>';
#     }
#
#     $vars{anon} =
#       ( $input{anonymous} ) ? ' checked' : ( $input{title} ? '' : ' checked' );
#
#     $vars{form_heading} = $q->h2( _('Empty property details form') )
#       if $q->{site} eq 'emptyhomes';
#     $vars{subject_label} = _('Subject:');
#     $vars{detail_label}  = _('Details:');
#     $vars{photo_label}   = _('Photo:');
#     $vars{name_label}    = _('Name:');
#     $vars{email_label}   = _('Email:');
#     $vars{phone_label}   = _('Phone:');
#     $vars{optional}      = _('(optional)');
#     if ( $q->{site} eq 'emptyhomes' ) {
#         $vars{anonymous} = _('Can we show your name on the site?');
#     }
#     else {
#         $vars{anonymous} = _('Can we show your name publicly?');
#     }
#     $vars{anonymous2} = _('(we never show your email address or phone number)');
#
#     my $partial_id;
#     if ( my $token = $input{partial} ) {
#         $partial_id = mySociety::AuthToken::retrieve( 'partial', $token );
#         if ($partial_id) {
#             $vars{partial_field} =
#               '<input type="hidden" name="partial" value="' . $token . '">';
#             $vars{partial_field} .=
#               '<input type="hidden" name="has_photo" value="'
#               . $q->param('has_photo') . '">';
#         }
#     }
#     my $photo_input = '';
#     if ($allow_photo_upload) {
#         $photo_input = <<EOF;
# <div id="fileupload_normalUI">
# <label for="form_photo">$vars{photo_label}</label>
# <input type="file" name="photo" id="form_photo">
# </div>
# EOF
#     }
#     if ( $partial_id && $q->param('has_photo') ) {
#         $vars{photo_field} =
# "<p>The photo you uploaded was:</p> <p><img src='/photo?id=$partial_id'></p>";
#     }
#     else {
#         $vars{photo_field} = $photo_input;
#     }
#
#     if ( $q->{site} ne 'emptyhomes' ) {
#         $vars{text_notes} =
#           $q->p( _("Please note:") ) . "<ul>"
#           . $q->li(
#             _(
# "We will only use your personal information in accordance with our <a href=\"/faq#privacy\">privacy policy.</a>"
#             )
#           )
#           . $q->li( _("Please be polite, concise and to the point.") )
#           . $q->li(
#             _(
# "Please do not be abusive &mdash; abusing your council devalues the service for all users."
#             )
#           )
#           . $q->li(
#             _(
# "Writing your message entirely in block capitals makes it hard to read, as does a lack of punctuation."
#             )
#           )
#           . $q->li(
#             _(
# "Remember that FixMyStreet is primarily for reporting physical problems that can be fixed. If your problem is not appropriate for submission via this site remember that you can contact your council directly using their own website."
#             )
#           );
#         $vars{text_notes} .= $q->li(
#             _(
# "FixMyStreet and the Guardian are providing this service in partnership in <a href=\"/faq#privacy\">certain cities</a>. In those cities, both have access to any information submitted, including names and email addresses, and will use it only to ensure the smooth running of the service, in accordance with their privacy policies."
#             )
#         ) if mySociety::Config::get('COUNTRY') eq 'GB';
#         $vars{text_notes} .= "</ul>\n";
#     }
#
#     %vars = (
#         %vars,
#         category      => $category,
#         map_end       => FixMyStreet::Map::display_map_end(1),
#         url_home      => Cobrand::url( $cobrand, '/', $q ),
#         submit_button => _('Submit')
#     );
#     return (
#         Page::template_include(
#             'report-form', $q, Page::template_root($q), %vars
#         ),
#         robots => 'noindex,nofollow',
#         js     => FixMyStreet::Map::header_js(),
#     );
# }

__PACKAGE__->meta->make_immutable;

1;
