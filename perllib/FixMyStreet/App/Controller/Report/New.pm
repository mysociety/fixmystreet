package FixMyStreet::App::Controller::Report::New;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Geocode;
use Encode;
use Image::Magick;
use List::MoreUtils qw(uniq);
use POSIX 'strcoll';
use HTML::Entities;
use mySociety::MaPit;
use Path::Class;
use Utils;
use mySociety::EmailUtil;
use mySociety::TempFiles;

=head1 NAME

FixMyStreet::App::Controller::Report::New

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

=head2 image related

Parameters are 'photo' or 'upload_fileid'. The 'photo' is used when a user has selected a file. Once it has been uploaded it is cached on disk so that if there are errors on the form it need not be uploaded again. The cache location is stored in 'upload_fileid'. 

=head2 optional

pc: location user searched for

skipped: true if the map was skipped - may mean that the location is not as
accurate as we'd like. Default is false.

upload_fileid: set if there is an uploaded file (might not be needed if we use the Catalyst upload handlers)

may_show_name: bool - false if the user wants this report to be anonymous.

title

detail

name

email

phone

partial

=head2 can be ignored

all_pins: related to map display - not relevant to creation of a new report

=cut

sub report_new : Path : Args(0) {
    my ( $self, $c ) = @_;

    # create the report - loading a partial if available
    $c->forward('initialize_report');

    # work out the location for this report and do some checks
    return $c->forward('redirect_to_around')
      unless $c->forward('determine_location');

    # create a problem from the submitted details
    $c->stash->{template} = "report/new/fill_in_details.html";
    $c->forward('setup_categories_and_councils');
    $c->forward('generate_map');

    # deal with the user and report and check both are happy
    return
      unless $c->forward('process_user')
          && $c->forward('process_report')
          && $c->forward('process_photo')
          && $c->forward('check_form_submitted')
          && $c->forward('check_for_errors')
          && $c->forward('save_user_and_report')
          && $c->forward('redirect_or_confirm_creation');
}

=head2 report_import

Action to accept report creations from iPhones and other mobile apps. URL is
'/import' to be compatible with existing apps.

=cut

sub report_import : Path('/import') {
    my ( $self, $c ) = @_;

    # If this is not a POST then just print out instructions for using page
    return unless $c->req->method eq 'POST';

    # anything else we return is plain text
    $c->res->content_type('text/plain; charset=utf-8');

    my %input =
      map { $_ => $c->req->param($_) || '' } (
        'service', 'subject',  'detail', 'name', 'email', 'phone',
        'easting', 'northing', 'lat',    'lon',  'id',    'phone_id',
      );

    my @errors;

    # Get our location
    my $latitude  = $input{lat} ||= 0;
    my $longitude = $input{lon} ||= 0;
    if (
        !( $latitude || $longitude )    # have not been given lat or lon
        && ( $input{easting} && $input{northing} )    # but do have e and n
      )
    {
        ( $latitude, $longitude ) =
          Utils::convert_en_to_latlon( $input{easting}, $input{northing} );
    }

    # handle the photo upload
    $c->forward( 'process_photo_upload', [ { rotate_photo => 1 } ] );
    my $photo = $c->stash->{upload_fileid};
    if ( my $error = $c->stash->{photo_error} ) {
        push @errors, $error;
    }

    push @errors, 'You must supply a service' unless $input{service};
    push @errors, 'Please enter a subject'    unless $input{subject} =~ /\S/;
    push @errors, 'Please enter your name'    unless $input{name} =~ /\S/;

    if ( $input{email} !~ /\S/ ) {
        push @errors, 'Please enter your email';
    }
    elsif ( !mySociety::EmailUtil::is_valid_email( $input{email} ) ) {
        push @errors, 'Please enter a valid email';
    }

    if ( $latitude && $c->cobrand->country eq 'GB' ) {
        eval { Utils::convert_latlon_to_en( $latitude, $longitude ); };
        push @errors,
          "We had a problem with the supplied co-ordinates - outside the UK?"
          if $@;
    }

    unless ( $photo || ( $latitude || $longitude ) ) {
        push @errors, 'Either a location or a photo must be provided.';
    }

    # if we have errors then we should bail out
    if (@errors) {
        my $body = join '', map { "ERROR:$_\n" } @errors;
        $c->res->body($body);
        return;
    }

### leaving commented out for now as the values stored here never appear to
### get used and the new user accounts might make them redundant anyway.
    #
    # # Store for possible future use
    # if ( $input{id} || $input{phone_id} ) {
    #     my $id = $input{id} || $input{phone_id};
    #     my $already =
    #       dbh()
    #       ->selectrow_array(
    #         'select id from partial_user where service=? and nsid=?',
    #         {}, $input{service}, $id );
    #     unless ($already) {
    #         dbh()->do(
    #             'insert into partial_user (service, nsid, name, email, phone)'
    #               . ' values (?, ?, ?, ?, ?)',
    #             {},
    #             $input{service},
    #             $id,
    #             $input{name},
    #             $input{email},
    #             $input{phone}
    #         );
    #     }
    # }

    # find or create the user
    my $report_user = $c->model('DB::User')->find_or_create(
        {
            email => $input{email},
            name  => $input{name},
            phone => $input{phone}
        }
    );

    # create a new report (don't save it yet)
    my $report = $c->model('DB::Problem')->new(
        {
            user      => $report_user,
            postcode  => '',
            latitude  => $latitude,
            longitude => $longitude,
            title     => $input{subject},
            detail    => $input{detail},
            name      => $input{name},
            service   => $input{service},
            state     => 'partial',
            used_map  => 1,
            anonymous => 0,
            category  => '',
            areas     => '',

        }
    );

    # If there was a photo add that too
    if ( my $fileid = $c->stash->{upload_fileid} ) {
        my $file = file( $c->config->{UPLOAD_CACHE}, "$fileid.jpg" );
        my $blob = $file->slurp;
        $file->remove;
        $report->photo($blob);
    }

    # save the report;
    $report->insert();

    my $token =
      $c->model("DB::Token")
      ->create( { scope => 'partial', data => $report->id } );

    $c->stash->{report} = $report;
    $c->stash->{token_url} = $c->uri_for_email( '/L', $token->token );

    $c->send_email( 'partial.txt', { to => $report->user->email, } );

    $c->res->body('SUCCESS');
    return 1;
}

=head2 initialize_report

Create the report and set up some basics in it. If there is a partial report
requested then use that .

Partial reports are created when people submit to us e.g. via mobile apps.
They are in the database but are not completed yet. Users reach us by following
a link we email them that contains a token link. This action looks for the
token and if found retrieves the report in it.

=cut

sub initialize_report : Private {
    my ( $self, $c ) = @_;

    # check to see if there is a partial report that we should use, otherwise
    # create a new one. Stick it on the stash.
    my $report = undef;

    if ( my $partial = scalar $c->req->param('partial') ) {

        for (1) {    # use as pseudo flow control

            # did we find a token
            last unless $partial;

            # is it in the database
            my $token =
              $c->model("DB::Token")
              ->find( { scope => 'partial', token => $partial } )    #
              || last;

            # can we get an id from it?
            my $id = $token->data                                    #
              || last;

            # load the related problem
            $report = $c->cobrand->problems                          #
              ->search( { id => $id, state => 'partial' } )          #
              ->first;

            if ($report) {

                # log the problem creation user in to the site
                $c->authenticate( { email => $report->user->email },
                    'no_password' );

                # save the token to delete at the end
                $c->stash->{partial_token} = $token if $report;

            }
            else {

                # no point keeping it if it is done.
                $token->delete;
            }
        }
    }

    if ( !$report ) {

        # If we didn't find a partial then create a new one
        $report = $c->model('DB::Problem')->new( {} );

        # If we have a user logged in let's prefill some values for them.
        if ( $c->user ) {
            my $user = $c->user->obj;
            $report->user($user);
            $report->name( $user->name );
        }

    }

    $c->stash->{report} = $report;

    return 1;
}

=head2 determine_location

Work out what the location of the report should be - either by using lat,lng or
a tile click or what's come in from a partial. Returns false if no location
could be found.

=cut 

sub determine_location : Private {
    my ( $self, $c ) = @_;

    $c->stash->{fetch_all_areas} = 1;
    return 1
      if    #
          (    #
              $c->forward('determine_location_from_tile_click')
              || $c->forward('/location/determine_location_from_coords')
              || $c->forward('determine_location_from_report')
          )    #
          && $c->forward('/around/check_location_is_acceptable');
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

    # return if they are both 0 - this happens when you submit the form by
    # hitting enter and not using the button. It also happens if you click
    # exactly there on the map but that is less likely than hitting return to
    # submit. Lesser of two evils...
    return unless $pin_x && $pin_y;

    # convert the click to lat and lng
    my ( $latitude, $longitude ) = FixMyStreet::Map::click_to_wgs84(
        $c,
        $pin_tile_x, $pin_x, $pin_tile_y, $pin_y
    );

    # store it on the stash
    $c->stash->{latitude}  = $latitude;
    $c->stash->{longitude} = $longitude;

    # set a flag so that the form is not considered submitted. This will prevent
    # errors showing on the fields.
    $c->stash->{force_form_not_submitted} = 1;

    # return true as we found a location
    return 1;
}

=head2 determine_location_from_report

Use latitude and longitude stored in the report - this is probably result of a
partial report being loaded.

=cut 

sub determine_location_from_report : Private {
    my ( $self, $c ) = @_;

    my $report = $c->stash->{report};

    if ( defined $report->latitude && defined $report->longitude ) {
        $c->stash->{latitude}  = $report->latitude;
        $c->stash->{longitude} = $report->longitude;
        return 1;
    }

    return;
}

=head2 setup_categories_and_councils

Look up categories for this council or councils

=cut

sub setup_categories_and_councils : Private {
    my ( $self, $c ) = @_;

    my $all_councils = $c->stash->{all_councils};
    my $first_council = ( values %$all_councils )[0];

    my @contacts                #
      = $c                      #
      ->model('DB::Contact')    #
      ->not_deleted             #
      ->search( { area_id => [ keys %$all_councils ] } )    #
      ->all;

    # variables to populate
    my %area_ids_to_list = ();       # Areas with categories assigned
    my @category_options = ();       # categories to show
    my $category_label   = undef;    # what to call them

    # FIXME - implement in cobrand
    if ( $c->cobrand->moniker eq 'emptyhomes' ) {

        # add all areas found to the list
        foreach (@contacts) {
            $area_ids_to_list{ $_->area_id } = 1;
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

    } elsif ($first_council->{type} eq 'LBO') {

        $area_ids_to_list{ $first_council->{id} } = 1;
        @category_options = (
            _('-- Pick a category --'),
            sort keys %{ Utils::london_categories() }
        );
        $category_label = _('Category:');

    } else {

        # keysort does not appear to obey locale so use strcoll (see i18n.t)
        @contacts = sort { strcoll( $a->category, $b->category ) } @contacts;

        my %seen;
        foreach my $contact (@contacts) {

            $area_ids_to_list{ $contact->area_id } = 1;

            next    # TODO - move this to the cobrand
              if $c->cobrand->moniker eq 'southampton'
                  && $contact->category eq 'Street lighting';

            next if $contact->category eq _('Other');

            push @category_options, $contact->category
                unless $seen{$contact->category};
            $seen{$contact->category} = 1;
        }

        if (@category_options) {
            @category_options =
              ( _('-- Pick a category --'), @category_options, _('Other') );
            $category_label = _('Category:');
        }
    }

    # put results onto stash for display
    $c->stash->{area_ids_to_list} = [ keys %area_ids_to_list ];
    $c->stash->{category_label}   = $category_label;
    $c->stash->{category_options} = \@category_options;

    my @missing_details_councils =
      grep { !$area_ids_to_list{$_} }    #
      keys %$all_councils;

    my @missing_details_council_names =
      map { $all_councils->{$_}->{name} }     #
      @missing_details_councils;

    $c->stash->{missing_details_councils}      = \@missing_details_councils;
    $c->stash->{missing_details_council_names} = \@missing_details_council_names;
}

=head2 check_form_submitted

    $bool = $c->forward('check_form_submitted');

Returns true if the form has been submitted, false if not. Determines this based
on the presence of the C<submit_problem> parameter.

=cut

sub check_form_submitted : Private {
    my ( $self, $c ) = @_;
    return if $c->stash->{force_form_not_submitted};
    return $c->req->param('submit_problem') || '';
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

    # cleanup the email address
    my $email = $params{email} ? lc $params{email} : '';
    $email =~ s{\s+}{}g;

    my $report = $c->stash->{report};
    my $report_user                              #
      = ( $report ? $report->user : undef )
      || $c->model('DB::User')->find_or_new( { email => $email } );

    # set the user's name and phone (if given)
    $report_user->name( Utils::trim_text( $params{name} ) );
    $report_user->phone( Utils::trim_text( $params{phone} ) ) if $params{phone};

    $c->stash->{report_user} = $report_user;

    return 1;
}

=head2 process_report

Looking at the parameters passed in create a new item and return it. Does not
save anything to the database. If no item can be created (ie no information
provided) returns undef.

=cut

sub process_report : Private {
    my ( $self, $c ) = @_;

    # Extract all the params to a hash to make them easier to work with
    my %params =       #
      map { $_ => scalar $c->req->param($_) }    #
      (
        'title', 'detail', 'pc',                 #
        'name', 'may_show_name',                 #
        'category',                              #
        'partial', 'skipped', 'submit_problem'   #
      );

    # load the report
    my $report = $c->stash->{report};

    # Enter the location and other bits which are not from the form
    $report->postcode( $params{pc} );
    $report->latitude( $c->stash->{latitude} );
    $report->longitude( $c->stash->{longitude} );

    # Capture whether the map was used
    $report->used_map( $params{skipped} ? 0 : 1 );

    # Short circuit unless the form has been submitted
    return 1 unless $params{submit_problem};

    # set some simple bool values (note they get inverted)
    $report->anonymous( $params{may_show_name} ? 0 : 1 );

    # clean up text before setting
    $report->title( Utils::cleanup_text( $params{title} ) );
    $report->detail(
        Utils::cleanup_text( $params{detail}, { allow_multiline => 1 } ) );

    # set these straight from the params
    $report->name( Utils::trim_text( $params{name} ) );
    $report->category( _ $params{category} );

    my $areas = $c->stash->{all_areas};
    $report->areas( ',' . join( ',', sort keys %$areas ) . ',' );

    # From earlier in the process.
    my $councils = $c->stash->{all_councils};
    my $first_council = ( values %$councils )[0];

    if ( $c->cobrand->moniker eq 'emptyhomes' ) {

        $councils = join( ',', @{ $c->stash->{area_ids_to_list} } ) || -1;
        $report->council( $councils );

    } elsif ( $first_council->{type} eq 'LBO') {

        unless ( Utils::london_categories()->{ $report->category } ) {
            # TODO Perfect world, this wouldn't short-circuit, other errors would
            # be included as well.
            $c->stash->{field_errors} = { category => _('Please choose a category') };
            return;
        }
        $report->council( $first_council->{id} );

    } elsif ( $report->category ) {

        # FIXME All contacts were fetched in setup_categories_and_councils,
        # so can this DB call also be avoided?
        my @contacts = $c->       #
          model('DB::Contact')    #
          ->not_deleted           #
          ->search(
            {
                area_id  => [ keys %$councils ],
                category => $report->category
            }
          )->all;

        unless ( @contacts ) {
            $c->stash->{field_errors} = { category => _('Please choose a category') };
            return;
        }

        # construct the council string:
        #  'x,x'     - x are council IDs that have this category
        #  'x,x|y,y' - x are council IDs that have this category, y council IDs with *no* contact
        my $council_string = join( ',', map { $_->area_id } @contacts );
        $council_string .=
          '|' . join( ',', @{ $c->stash->{missing_details_councils} } )
            if $council_string && @{ $c->stash->{missing_details_councils} };
        $report->council($council_string);

    } elsif ( @{ $c->stash->{area_ids_to_list} } ) {

        # There was an area with categories, but we've not been given one. Bail.
        $c->stash->{field_errors} = { category => _('Please choose a category') };
        return;

    } else {

        # If we're here, we've been submitted somewhere
        # where we have no contact information at all.
        $report->council( -1 );

    }

    # set defaults that make sense
    $report->state('unconfirmed');

    # save the cobrand and language related information
    $report->cobrand( $c->cobrand->moniker );
    $report->cobrand_data( $c->cobrand->extra_problem_data );
    $report->lang( $c->stash->{lang_code} );

    return 1;
}

=head2 process_photo

Handle the photo - either checking and storing it after an upload or retrieving
it from the cache.

Store any error message onto 'photo_error' in stash.
=cut

sub process_photo : Private {
    my ( $self, $c ) = @_;

    return
         $c->forward('process_photo_upload')
      || $c->forward('process_photo_cache')
      || 1;    # always return true
}

sub process_photo_upload : Private {
    my ( $self, $c, $args ) = @_;

    # setup args and set defaults
    $args ||= {};
    $args->{rotate_photo} ||= 0;

    # check for upload or return
    my $upload = $c->req->upload('photo')
      || return;

    # check that the photo is a jpeg
    my $ct = $upload->type;
    unless ( $ct eq 'image/jpeg' || $ct eq 'image/pjpeg' ) {
        $c->stash->{photo_error} = _('Please upload a JPEG image only');
        return;
    }

    # convert the photo into a blob (also resize etc)
    my $photo_blob =
      eval { _process_photo( $upload->fh, $args->{rotate_photo} ) };
    if ( my $error = $@ ) {
        my $format = _(
"That image doesn't appear to have uploaded correctly (%s), please try again."
        );
        $c->stash->{photo_error} = sprintf( $format, $error );
        return;
    }

    # we have an image we can use - save it to the cache in case there is an
    # error
    my $cache_dir = dir( $c->config->{UPLOAD_CACHE} );
    $cache_dir->mkpath;
    unless ( -d $cache_dir && -w $cache_dir ) {
        warn "Can't find/write to photo cache directory '$cache_dir'";
        return;
    }

    # create a random name and store the file there
    my $fileid = int rand 1_000_000_000;
    my $file   = $cache_dir->file("$fileid.jpg");
    $file->openw->print($photo_blob);

    # stick the random number on the stash
    $c->stash->{upload_fileid} = $fileid;

    return 1;
}

=head2 process_photo_cache

Look for the upload_fileid parameter and check it matches a file on disk. If it
does return true and put fileid on stash, otherwise false.

=cut

sub process_photo_cache : Private {
    my ( $self, $c ) = @_;

    # get the fileid and make sure it is just a number
    my $fileid = $c->req->param('upload_fileid') || '';
    $fileid =~ s{\D+}{}g;
    return unless $fileid;

    my $file = file( $c->config->{UPLOAD_CACHE}, "$fileid.jpg" );
    return unless -e $file;

    $c->stash->{upload_fileid} = $fileid;
    return 1;
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
        %{ $c->stash->{report}->check_for_errors },
    );

    # add the photo error if there is one.
    if ( my $photo_error = delete $c->stash->{photo_error} ) {
        $field_errors{photo} = $photo_error;
    }

    # all good if no errors
    return 1 unless scalar keys %field_errors;

    $c->stash->{field_errors} = \%field_errors;

    return;
}

=head2 save_user_and_report

Save the user and the report.

Be smart about the user - only set the name and phone if user did not exist
before or they are currently logged in. Otherwise discard any changes.

=cut

sub save_user_and_report : Private {
    my ( $self, $c ) = @_;
    my $report_user = $c->stash->{report_user};
    my $report      = $c->stash->{report};

    # Save or update the user if appropriate
    if ( !$report_user->in_storage ) {
        $report_user->insert();
    }
    elsif ( $c->user && $report_user->id == $c->user->id ) {
        $report_user->update();
        $report->confirm;
    }
    else {

        # user exists and we are not logged in as them. Throw away changes to
        # the name and phone. TODO - propagate changes using tokens.
        $report_user->discard_changes();
    }

    # add the user to the report
    $report->user($report_user);

    # If there was a photo add that too
    if ( my $fileid = $c->stash->{upload_fileid} ) {
        my $file = file( $c->config->{UPLOAD_CACHE}, "$fileid.jpg" );
        my $blob = $file->slurp;
        $file->remove;
        $report->photo($blob);
    }

    # Set a default if possible
    $report->category( _('Other') ) unless $report->category;

    # Set unknown to DB unknown
    $report->council( undef ) if $report->council eq '-1';

    # save the report;
    $report->in_storage ? $report->update : $report->insert();

    # tidy up
    if ( my $token = $c->stash->{partial_token} ) {
        $token->delete;
    }

    return 1;
}

=head2 generate_map

Add the html needed to for the map to the stash.

=cut

# Perhaps also create a map 'None' to use when map is skipped.

sub generate_map : Private {
    my ( $self, $c ) = @_;
    my $latitude  = $c->stash->{latitude};
    my $longitude = $c->stash->{longitude};

    ( $c->stash->{short_latitude}, $c->stash->{short_longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $c->stash->{latitude}, $c->stash->{longitude} );

    # Don't do anything if the user skipped the map
    unless ( $c->req->param('skipped') ) {
        FixMyStreet::Map::display_map(
            $c,
            latitude  => $latitude,
            longitude => $longitude,
            clickable => 1,
            pins      => [ {
                latitude  => $latitude,
                longitude => $longitude,
                colour    => 'purple',
            } ],
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

    # If confirmed send the user straight there.
    if ( $report->confirmed ) {
        # Subscribe problem reporter to email updates
        $c->forward( 'create_reporter_alert' );
        my $report_uri = $c->uri_for( '/report', $report->id );
        $c->res->redirect($report_uri);
        $c->detach;
    }

    # otherwise create a confirm token and email it to them.
    my $token =
      $c->model("DB::Token")
      ->create( { scope => 'problem', data => $report->id } );
    $c->stash->{token_url} = $c->uri_for_email( '/P', $token->token );
    $c->send_email( 'problem-confirm.txt', {
        to => [ [ $report->user->email, $report->name ] ],
    } );

    # tell user that they've been sent an email
    $c->stash->{template}   = 'email_sent.html';
    $c->stash->{email_type} = 'problem';
}

sub create_reporter_alert : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{report};
    my $alert = $c->model('DB::Alert')->find_or_create( {
        user         => $problem->user,
        alert_type   => 'new_updates',
        parameter    => $problem->id,
        cobrand      => $problem->cobrand,
        cobrand_data => $problem->cobrand_data,
        lang         => $problem->lang,
    } )->confirm;
}

=head2 redirect_to_around

Redirect the user to '/around' passing along all the relevant parameters.

=cut

sub redirect_to_around : Private {
    my ( $self, $c ) = @_;

    my $params = {
        pc => ( $c->stash->{pc} || $c->req->param('pc') || '' ),
        lat => $c->stash->{latitude},
        lon => $c->stash->{longitude},
    };

    # delete empty values
    for ( keys %$params ) {
        delete $params->{$_} if !$params->{$_};
    }

    if ( my $token = $c->stash->{partial_token} ) {
        $params->{partial} = $token->token;
    }

    my $around_uri = $c->uri_for( '/around', $params );

    return $c->res->redirect($around_uri);
}

sub _process_photo {
    my $fh = shift;
    my $import = shift;

    my $blob = join('', <$fh>);
    close $fh;
    my ($handle, $filename) = mySociety::TempFiles::named_tempfile('.jpeg');
    print $handle $blob;
    close $handle;

    my $photo = Image::Magick->new;
    my $err = $photo->Read($filename);
    unlink $filename;
    throw Error::Simple("read failed: $err") if "$err";
    $err = $photo->Scale(geometry => "250x250>");
    throw Error::Simple("resize failed: $err") if "$err";
    my @blobs = $photo->ImageToBlob();
    undef $photo;
    $photo = $blobs[0];
    return $photo unless $import; # Only check orientation for iPhone imports at present

    # Now check if it needs orientating
    ($fh, $filename) = mySociety::TempFiles::named_tempfile('.jpeg');
    print $fh $photo;
    close $fh;
    my $out = `jhead -se -autorot $filename`;
    if ($out) {
        open(FP, $filename) or throw Error::Simple($!);
        $photo = join('', <FP>);
        close FP;
    }
    unlink $filename;
    return $photo;
}

__PACKAGE__->meta->make_immutable;

1;
