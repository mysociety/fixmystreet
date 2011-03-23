package FixMyStreet::App::Controller::Reports::New;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Geocode;
use Encode;
use Sort::Key qw(keysort);
use List::MoreUtils qw(uniq);
use HTML::Entities;
use mySociety::MaPit;

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
    return
      unless $c->forward('determine_location')
          && $c->forward('load_councils');

    # create a problem from the submitted details
    $c->stash->{template} = "reports/new/fill_in_details.html";
    $c->forward('setup_categories_and_councils');
    $c->forward('generate_map');

    # deal with the user and report and check both are happy
    return
      unless $c->forward('process_user')
          && $c->forward('process_report')
          && $c->forward('check_form_submitted')
          && $c->forward('check_for_errors')
          && $c->forward('save_user_and_report')
          && $c->forward('redirect_or_confirm_creation');
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

    # These should be set now
    my $lat = $c->stash->{latitude};
    my $lon = $c->stash->{longitude};

    # Check this location is okay to be displayed for the cobrand
    my ( $success, $error_msg ) = $c->cobrand->council_check(    #
        { lat => $lat, lon => $lon },
        'submit_problem'
    );

    # If in UK and we have a lat,lon coocdinate check it is in UK
    # FIXME - is this a redundant check as we already see if report has a body
    # to handle it?
    if ( !$error_msg && $c->config->{COUNTRY} eq 'GB' ) {
        eval { Utils::convert_latlon_to_en( $lat, $lon ); };
        $error_msg =
          _( "We had a problem with the supplied co-ordinates - outside the UK?"
          ) if $@;
    }

    # all good
    return 1 if !$error_msg;

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

=head2 load_councils

Try to load councils for this location and check that we have at least one. If
there are no councils then return false.

=cut

sub load_councils : Private {
    my ( $self, $c ) = @_;
    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    # Look up councils and do checks for the point we've got
    my @area_types = $c->cobrand->area_types();

    # TODO: I think we want in_gb_locale around the next line, needs testing
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

    # If we don't have any councils we can't accept the report
    if ( !scalar keys %$all_councils ) {
        $c->stash->{location_error} =
          _(    'That spot does not appear to be covered by a council. If you'
              . ' have tried to report an issue past the shoreline, for'
              . ' example, please specify the closest point on land.' );
        return;
    }

    # edit hash in-place
    _remove_redundant_councils($all_councils);

    # all good if we have some councils left
    $c->stash->{all_councils} = $all_councils;
    $c->stash->{all_council_names} =
      [ map { $_->{name} } values %$all_councils ];
    return 1;
}

# FIXME - should not be here.
# These are country specific tweaks that should be in the cobrands
sub _remove_redundant_councils {
    my $all_councils = shift;

    # UK specific tweaks
    if ( FixMyStreet->config('COUNTRY') eq 'GB' ) {

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
    if ( FixMyStreet->config('COUNTRY') eq 'NO' ) {

        # Oslo is both a kommune and a fylke, we only want to show it once
        delete $all_councils->{301}     #
          if $all_councils->{3};
    }

}

=head2 setup_categories_and_councils

Look up categories for this council or councils

=cut

sub setup_categories_and_councils : Private {
    my ( $self, $c ) = @_;

    my @all_council_ids = keys %{ $c->stash->{all_councils} };

    my @contacts                #
      = $c                      #
      ->model('DB::Contact')    #
      ->not_deleted             #
      ->search( { area_id => \@all_council_ids } )    #
      ->all;

    # variables to populate
    my @area_ids_to_list = ();       # Areas with categories assigned
    my @category_options = ();       # categories to show
    my $category_label   = undef;    # what to call them

    # FIXME - implement in cobrand
    if ( $c->cobrand->moniker eq 'emptyhomes' ) {

        # add all areas found to the list
        foreach (@contacts) {
            push @area_ids_to_list, $_->area_id;
        }

        # set our own categories
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

        if (@category_options) {
            @category_options =
              ( _('-- Pick a category --'), @category_options, _('Other') );
            $category_label = _('Category:');
        }
    }

    # put results onto stash for display
    $c->stash->{area_ids_to_list} = \@area_ids_to_list;
    $c->stash->{category_label}   = $category_label;
    $c->stash->{category_options} = \@category_options;

    # add some conveniant things to the stash
    my $all_councils = $c->stash->{all_councils};
    my %area_ids_to_list_hash = map { $_ => 1 } @area_ids_to_list;

    my @missing_details_councils =
      grep { !$area_ids_to_list_hash{$_} }    #
      keys %$all_councils;

    my @missing_details_council_names =
      map { $all_councils->{$_}->{name} }     #
      @missing_details_councils;

    $c->stash->{missing_details_councils}      = @missing_details_councils;
    $c->stash->{missing_details_council_names} = @missing_details_council_names;
}

=head2 process_user

Load user from the database or prepare a new one.

=cut

sub process_user : Private {
    my ( $self, $c ) = @_;

    # FIXME - If user already logged in use them regardless

    # Extract all the params to a hash to make them easier to work with
    my %params =    #
      map { $_ => scalar $c->req->param($_) }    #
      ( 'email', 'name', 'phone', );

    my $report_user =
      $c->model('DB::User')->find_or_new( { email => $params{email} } );

    # set the user's name and phone (if given)
    $report_user->name( $params{name} );
    $report_user->phone( $params{phone} ) if $params{phone};

    $c->stash->{report_user} = $report_user;

    return 1;
}

=head2 process_report

Looking at the parameters passed in create a new item and return it. Does not
save anything to the database. If no item can be created (ie no information
provided) returns undef.

=cut

sub _cleanup_text {
    my $input = shift || '';

    # lowercase everything if looks like it might be SHOUTING
    $input = lc $input if $input !~ /[a-z]/;

    # Start with a capital
    $input = ucfirst $input;

    # clean up language and tradmarks
    for ($input) {

        # shit -> poo
        s{\bdog\s*shit\b}{dog poo}ig;

        # 'portakabin' to '[portable cabin]' (and variations)
        s{\b(porta)\s*([ck]abin|loo)\b}{[$1ble $2]}ig;
        s{kabin\]}{cabin\]}ig;
    }

    return $input;
}

sub process_report : Private {
    my ( $self, $c ) = @_;

    # Extract all the params to a hash to make them easier to work with
    my %params =    #
      map { $_ => scalar $c->req->param($_) }    #
      (
        'title', 'detail', 'pc',                 #
        'name', 'may_show_name',                 #
        'category',                              #
        'partial', 'skipped', 'upload_fileid',   #
      );

    # create a new report, but don't save it yet
    my $report = $c->model('DB::Problem')->new( {} );

    # Enter the location
    $report->postcode( $params{pc} );
    $report->latitude( $c->stash->{latitude} );
    $report->longitude( $c->stash->{longitude} );

    # set some simple bool values (note they get inverted)
    $report->used_map( $params{skipped}        ? 0 : 1 );
    $report->anonymous( $params{may_show_name} ? 0 : 1 );

    # clean up text before setting
    $report->title( _cleanup_text( $params{title} ) );
    $report->detail( _cleanup_text( $params{detail} ) );

    # set these straight from the params
    $report->name( $params{name} );
    $report->category( $params{category} );

    #         my $fh = $q->upload('photo');
    #         if ($fh) {
    #             my $err = Page::check_photo( $q, $fh );
    #             $field_errors{photo} = $err if $err;
    #         }

    my $mapit_query =
      sprintf( "4326/%s,%s", $report->longitude, $report->latitude );
    my $areas = mySociety::MaPit::call( 'point', $mapit_query );
    $report->areas( ',' . join( ',', sort keys %$areas ) . ',' );

    # determine the area_types that this cobrand is interested in
    my @area_types = $c->cobrand->area_types();
    my %area_types_lookup = map { $_ => 1 } @area_types;

    # get all the councils that are of these types and cover this area
    my %councils =
      map { $_ => 1 }    #
      grep { $area_types_lookup{ $areas->{$_}->{type} } }    #
      keys %$areas;

    # partition the councils onto these two arrays
    my @councils_with_category    = ();
    my @councils_without_category = ();

    # all councils have all categories for emptyhomes
    if ( $c->cobrand->moniker eq 'emptyhomes' ) {
        @councils_with_category = keys %councils;
    }
    else {

        my @contacts = $c->       #
          model('DB::Contact')    #
          ->not_deleted           #
          ->search(
            {
                area_id  => [ keys %councils ],    #
                category => $report->category
            }
          )->all;

        # clear category if it is not in db for possible councils
        $report->category(undef) unless @contacts;

        my %councils_with_contact_for_category =
          map { $_->area_id => 1 } @contacts;

        foreach my $council_key ( keys %councils ) {
            $councils_with_contact_for_category{$council_key}
              ? push( @councils_with_category,    $council_key )
              : push( @councils_without_category, $council_key );
        }

    }

    # construct the council string:
    #  'x,x'     - x are councils_ids that have this category
    #  'x,x|y,y' - x are councils_ids that have this category, y don't
    # '-1'       - no councils have this category
    my $council_string = join '|', grep { $_ }    #
      (
        join( ',', @councils_with_category ),
        join( ',', @councils_without_category )
      );
    $report->council($council_string);

    # set defaults that make sense
    $report->state('unconfirmed');

#         my $image;
#         if ($fh) {
#             try {
#                 $image = Page::process_photo($fh);
#             }
#             catch Error::Simple with {
#                 my $e = shift;
#                 $field_errors{photo} = sprintf(
#                     _(
# "That image doesn't appear to have uploaded correctly (%s), please try again."
#                     ),
#                     $e
#                 );
#             };
#         }
#
#         if ( $input{upload_fileid} ) {
#             open FP,
#               mySociety::Config::get('UPLOAD_CACHE') . $input{upload_fileid};
#             $image = join( '', <FP> );
#             close FP;
#         }
#

    # save the cobrand and language related information
    $report->cobrand( $c->cobrand->moniker );
    $report->cobrand_data( $c->cobrand->extra_problem_data );
    $report->lang( $c->stash->{lang_code} );

    #         if ( my $token = $input{partial} ) {

    #             my $id = mySociety::AuthToken::retrieve( 'partial', $token );

#             if ($id) {
#                 dbh()->do(
# "update problem set postcode=?, latitude=?, longitude=?, title=?, detail=?,
#                     name=?, email=?, phone=?, state='confirmed', council=?, used_map='t',
#                     anonymous=?, category=?, areas=?, cobrand=?, cobrand_data=?, confirmed=ms_current_timestamp(),
#                     lastupdate=ms_current_timestamp() where id=?", {},
#                     $input{pc}, $input{latitude}, $input{longitude},
#                     $input{title}, $input{detail}, $input{name}, $input{email},
#                     $input{phone}, $input{council},
#                     $input{anonymous} ? 'f' : 't',
#                     $input{category}, $areas, $cobrand, $cobrand_data, $id
#                 );

#                 Utils::workaround_pg_bytea(
#                     'update problem set photo=? where id=?',
#                     1, $image, $id )
#                   if $image;
#                 dbh()->commit();
#                 $out = $q->p(
#                     sprintf(
#                         _(
# 'You have successfully confirmed your report and you can now <a href="%s">view it on the site</a>.'
#                         ),
#                         "/report/$id"
#                     )
#                 );
#                 my $display_advert = Cobrand::allow_crosssell_adverts($cobrand);
#                 if ($display_advert) {
#                     $out .=
#                       CrossSell::display_advert( $q, $input{email},
#                         $input{name} );
#                 }
#             }
#             else {
#                 $out = $q->p(
# 'There appears to have been a problem updating the details of your report.
#     Please <a href="/contact">let us know what went on</a> and we\'ll look into it.'
#                 );
#             }
#         }
#         else {
#         }
#         return $out;
#     }

    $c->stash->{report} = $report;
    return 1;
}

=head2 check_form_submitted

    $bool = $c->forward('check_form_submitted');

Returns true if the form has been submitted, false if not. Determines this based
on the presence of the C<submit_problem> parameter.

=cut

sub check_form_submitted : Private {
    my ( $self, $c ) = @_;
    return !!$c->req->param('submit_problem');
}

=head2 check_for_errors

Examine the user and the report for errors. If found put them on stash and
return false.

=cut

sub check_for_errors : Private {
    my ( $self, $c ) = @_;

    # let the model check for errors
    my %field_errors = (
        %{ $c->stash->{report_user}->check_for_errors },
        %{ $c->stash->{report}->check_for_errors }
    );

    # all good if no errors
    return 1 unless scalar keys %field_errors;

    $c->stash->{field_errors} = \%field_errors;

    use Data::Dumper;
    local $Data::Dumper::Sortkeys = 1;
    warn Dumper( \%field_errors );

    return;
}

=head2 save_user_and_report

Save the user and the report.

Be smart about the user - only set the name and phone if user did not exist
before or they are currently logged in. Otherwise discard any changes.

Save the problem as unconfirmed. FIXME - change this behaviour with respect to
the user's logged in status.

=cut

sub save_user_and_report : Private {
    my ( $self, $c ) = @_;
    my $report_user = $c->stash->{report_user};
    my $report      = $c->stash->{report};

    # Save or update the user if appropriate
    if ( !$report_user->in_storage ) {
        $report_user->insert();    # FIXME - set user state to 'unconfirmed'
    }
    elsif ( $c->user && $report_user->id == $c->user->id ) {
        $report_user->update();
        $report->confirmed(1);     # as we know the user is genuine
        $report->state('confirmed');
        $report->confirmed( \'ms_current_timestamp()' ); # FIXME - move to model
    }
    else {

        # user exists and we are not logged in as them. Throw away changes to
        # the name and phone. FIXME - propagate changes using tokens.
        $report_user->discard_changes();
    }

    # add the user to the report
    $report->user($report_user);

    # Set a default if possible
    $report->category( _('Other') ) unless $report->category;

    # save the report;
    $report->insert();

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

=head2 redirect_or_confirm_creation

Now that the report has been created either redirect the user to its page if it
has been confirmed or email them a token if it has not been.

=cut

sub redirect_or_confirm_creation : Private {
    my ( $self, $c ) = @_;
    my $report = $c->stash->{report};

    # If confirmed send the user straigh there.
    if ( $report->confirmed ) {
        my $report_uri = $c->uri_for( '/reports', $report->id );
        $c->res->redirect($report_uri);
        $c->detach;
    }

    # otherwise create a confirm token and email it to them.
    my $token =
      $c->model("DB::Token")
      ->create( { scope => 'problem', data => $report->id } );
    $c->stash->{token_url} = $c->uri_for( '/P', $token->token );
    $c->send_email( 'problem-confirm.txt', { to => $report->user->email } );

    # tell user that they've been sent an email
    $c->stash->{template}   = 'email_sent.html';
    $c->stash->{email_type} = 'problem';
}

__PACKAGE__->meta->make_immutable;

1;
