package FixMyStreet::App::Controller::Report::New;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use Encode;
use List::MoreUtils qw(uniq);
use POSIX 'strcoll';
use HTML::Entities;
use mySociety::MaPit;
use Path::Class;
use Utils;
use mySociety::EmailUtil;
use JSON;

=head1 NAME

FixMyStreet::App::Controller::Report::New

=head1 DESCRIPTION

Create a new report, or complete a partial one.

=head1 PARAMETERS

=head2 flow control

submit_problem: true if a problem has been submitted, at all.
submit_sign_in: true if the sign in button has been clicked by logged out user.
submit_register: true if the register/confirm by email button has been clicked
by logged out user.

=head2 location (required)

We require a location - either lat/lng or a tile click.

longitude, latitude: location of the report - either determined from the
address/postcode or from a map click.

x, y, tile_xxx.yyy.x, tile_xxx.yyy.y: x and y are the tile locations. The
'tile_xxx.yyy' pair are the click locations on the tile. These can be converted
back into lat/lng by the map code.

=head2 image related

Parameters are 'photo' or 'upload_fileid'. The 'photo' is used when a user has
selected a file. Once it has been uploaded it is cached on disk so that if
there are errors on the form it need not be uploaded again. The hash of the
photo is stored in 'upload_fileid'.

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

=cut

use constant COUNCIL_ID_BROMLEY => 2482;

sub report_new : Path : Args(0) {
    my ( $self, $c ) = @_;

    # create the report - loading a partial if available
    $c->forward('initialize_report');

    # work out the location for this report and do some checks
    return $c->forward('redirect_to_around')
      unless $c->forward('determine_location');

    # create a problem from the submitted details
    $c->stash->{template} = "report/new/fill_in_details.html";
    $c->forward('setup_categories_and_bodies');
    $c->forward('generate_map');
    $c->forward('check_for_category');

    # deal with the user and report and check both are happy

    return unless $c->forward('check_form_submitted');
    $c->forward('process_user');
    $c->forward('process_report');
    $c->forward('/photo/process_photo');
    return unless $c->forward('check_for_errors');
    $c->forward('save_user_and_report');
    $c->forward('redirect_or_confirm_creation');
}

# This is for the new phonegap versions of the app. It looks a lot like
# report_new but there's a few workflow differences as we only ever want
# to sent JSON back here

sub report_new_test : Path('_test_') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template}   = 'email_sent.html';
    $c->stash->{email_type} = $c->get_param('email_type');
}

sub report_new_ajax : Path('mobile') : Args(0) {
    my ( $self, $c ) = @_;

    # create the report - loading a partial if available
    $c->forward('initialize_report');

    unless ( $c->forward('determine_location') ) {
        $c->stash->{ json_response } = { errors => 'Unable to determine location' };
        $c->forward('send_json_response');
        return 1;
    }

    $c->forward('setup_categories_and_bodies');
    $c->forward('process_user');
    $c->forward('process_report');
    $c->forward('/photo/process_photo');

    unless ($c->forward('check_for_errors')) {
        $c->stash->{ json_response } = { errors => $c->stash->{field_errors} };
        $c->stash->{ json_response }->{check_name} = $c->user->name if $c->stash->{check_name};
        $c->forward('send_json_response');
        return 1;
    }

    $c->forward('save_user_and_report');

    my $report = $c->stash->{report};
    my $data = $c->stash->{token_data} || {};
    my $token = $c->model("DB::Token")->create( {
        scope => 'problem',
        data => {
            %$data,
            id => $report->id
        }
    } );
    if ( $report->confirmed ) {
        $c->stash->{ json_response } = { success => 1, report => $report->id };
    } else {
        $c->stash->{token_url} = $c->uri_for_email( '/P', $token->token );
        $c->send_email( 'problem-confirm.txt', {
            to => [ $report->name ? [ $report->user->email, $report->name ] : $report->user->email ],
        } );
        $c->stash->{ json_response } = { success => 1 };
    }

    $c->forward('send_json_response');
}

sub send_json_response : Private {
    my ( $self, $c ) = @_;

    my $body = JSON->new->utf8(1)->encode(
        $c->stash->{json_response},
    );
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);
}

sub report_form_ajax : Path('ajax') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('initialize_report');

    # work out the location for this report and do some checks
    if ( ! $c->forward('determine_location') ) {
        my $body = JSON->new->utf8(1)->encode( {
            error => $c->stash->{location_error},
        } );
        $c->res->content_type('application/json; charset=utf-8');
        $c->res->body($body);
        return;
    }

    $c->forward('setup_categories_and_bodies');

    # render templates to get the html
    my $category = $c->render_fragment( 'report/new/category.html');
    my $councils_text = $c->render_fragment( 'report/new/councils_text.html');
    my $extra_name_info = $c->stash->{extra_name_info}
        ? $c->render_fragment('report/new/extra_name.html')
        : '';

    my $extra_titles_list = $c->cobrand->title_list($c->stash->{all_areas});

    my $body = JSON->new->utf8(1)->encode(
        {
            councils_text   => $councils_text,
            category        => $category,
            extra_name_info => $extra_name_info,
            titles_list     => $extra_titles_list,
            categories      => $c->stash->{category_options},
        }
    );

    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);
}

sub category_extras_ajax : Path('category_extras') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('initialize_report');
    if ( ! $c->forward('determine_location') ) {
        my $body = JSON->new->utf8(1)->encode(
            {
                error => _("Sorry, we could not find that location."),
            }
        );
        $c->res->content_type('application/json; charset=utf-8');
        $c->res->body($body);
        return 1;
    }
    $c->forward('setup_categories_and_bodies');
    $c->forward('check_for_category');

    my $category = $c->stash->{category};
    my $category_extra = '';
    my $generate;
    if ( $c->stash->{category_extras}->{$category} && @{ $c->stash->{category_extras}->{$category} } >= 1 ) {
        $c->stash->{report_meta} = {};
        $c->stash->{category_extras} = { $category => $c->stash->{category_extras}->{$category} };
        $generate = 1;
    }
    if ($c->stash->{unresponsive}->{$category}) {
        $generate = 1;
    }
    if ($generate) {
        $c->stash->{report} = { category => $category };
        $category_extra = $c->render_fragment( 'report/new/category_extras.html');
    }

    my $body = JSON->new->utf8(1)->encode(
        {
            category_extra => $category_extra,
        }
    );

    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);
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
      map { $_ => $c->get_param($_) || '' } (
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
    $c->forward( '/photo/process_photo' );
    my $fileid = $c->stash->{upload_fileid};
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

    unless ( $fileid || ( $latitude || $longitude ) ) {
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
            email => lc $input{email},
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
            cobrand   => $c->cobrand->moniker,
            lang      => $c->stash->{lang_code},

        }
    );

    # If there was a photo add that too
    if ( $fileid ) {
        $report->photo($fileid);
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

    if ( my $partial = $c->get_param('partial') ) {

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

    if ( $c->get_param('first_name') && $c->get_param('last_name') ) {
        $c->stash->{first_name} = $c->get_param('first_name');
        $c->stash->{last_name} = $c->get_param('last_name');

        $c->set_param('name', sprintf( '%s %s', $c->get_param('first_name'), $c->get_param('last_name') ));
    }

    # Capture whether the map was used
    $report->used_map( $c->get_param('skipped') ? 0 : 1 );

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
    my $pin_x = $c->get_param($x_key);
    my $pin_y = $c->get_param($y_key);

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
    ($c->stash->{latitude}, $c->stash->{longitude}) =
        map { Utils::truncate_coordinate($_) } ($latitude, $longitude);

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

=head2 setup_categories_and_bodies

Look up categories for the relevant body or bodies.

=cut

sub setup_categories_and_bodies : Private {
    my ( $self, $c ) = @_;

    my $all_areas = $c->stash->{all_areas};
    my $first_area = ( values %$all_areas )[0];

    my @bodies = $c->model('DB::Body')->search(
        { 'body_areas.area_id' => [ keys %$all_areas ], deleted => 0 },
        { join => 'body_areas' }
    )->all;
    my %bodies = map { $_->id => $_ } @bodies;
    my $first_body = ( values %bodies )[0];

    my @contacts                #
      = $c                      #
      ->model('DB::Contact')    #
      ->not_deleted             #
      ->search( { body_id => [ keys %bodies ] } )
      ->all;

    # variables to populate
    my %bodies_to_list = ();       # Bodies with categories assigned
    my @category_options = ();       # categories to show
    my %category_extras  = ();       # extra fields to fill in for open311
    my %non_public_categories =
      ();    # categories for which the reports are not public
    $c->stash->{unresponsive} = {};

    if (keys %bodies == 1 && $first_body->send_method && $first_body->send_method eq 'Refused') {
        $c->stash->{unresponsive}{ALL} = $first_body->id;
    }

    # FIXME - implement in cobrand
    if ( $c->cobrand->moniker eq 'emptyhomes' ) {

        # add all bodies found to the list
        foreach (@contacts) {
            $bodies_to_list{ $_->body_id } = 1;
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

    } else {

        # keysort does not appear to obey locale so use strcoll (see i18n.t)
        @contacts = sort { strcoll( $a->category, $b->category ) } @contacts;

        my %seen;
        foreach my $contact (@contacts) {

            $bodies_to_list{ $contact->body_id } = 1;

            unless ( $seen{$contact->category} ) {
                push @category_options, $contact->category;

                my $metas = $contact->get_extra_fields;
                $category_extras{ $contact->category } = $metas
                    if scalar @$metas;

                $c->stash->{unresponsive}{$contact->category} = $contact->body_id
                    if $contact->email =~ /^REFUSED$/i;

                $non_public_categories{ $contact->category } = 1 if $contact->non_public;
            }
            $seen{$contact->category} = 1;
        }

        if (@category_options) {
            # If there's an Other category present, put it at the bottom
            @category_options = ( _('-- Pick a category --'), grep { $_ ne _('Other') } @category_options );
            push @category_options, _('Other') if $seen{_('Other')};
        }
    }

    $c->cobrand->munge_category_list(\@category_options, \@contacts, \%category_extras)
        if $c->cobrand->can('munge_category_list');

    if ($c->cobrand->can('hidden_categories')) {
        my %hidden_categories = map { $_ => 1 }
            $c->cobrand->hidden_categories;

        @category_options = grep { 
            !$hidden_categories{$_} 
            } @category_options;
    }

    # put results onto stash for display
    $c->stash->{bodies} = \%bodies;
    $c->stash->{all_body_names} = [ map { $_->name } values %bodies ];
    $c->stash->{all_body_urls} = [ map { $_->external_url } values %bodies ];
    $c->stash->{bodies_to_list} = [ keys %bodies_to_list ];
    $c->stash->{category_options} = \@category_options;
    $c->stash->{category_extras}  = \%category_extras;
    $c->stash->{non_public_categories}  = \%non_public_categories;
    $c->stash->{category_extras_json}  = encode_json \%category_extras;
    $c->stash->{extra_name_info} = $first_area->{id} == COUNCIL_ID_BROMLEY ? 1 : 0;

    my @missing_details_bodies = grep { !$bodies_to_list{$_->id} } values %bodies;
    my @missing_details_body_names = map { $_->name } @missing_details_bodies;

    $c->stash->{missing_details_bodies} = \@missing_details_bodies;
    $c->stash->{missing_details_body_names} = \@missing_details_body_names;
}

=head2 check_form_submitted

    $bool = $c->forward('check_form_submitted');

Returns true if the form has been submitted, false if not. Determines this based
on the presence of the C<submit_problem> parameter.

=cut

sub check_form_submitted : Private {
    my ( $self, $c ) = @_;
    return if $c->stash->{force_form_not_submitted};
    return $c->get_param('submit_problem') || '';
}

=head2 process_user

Load user from the database or prepare a new one.

=cut

sub process_user : Private {
    my ( $self, $c ) = @_;

    my $report = $c->stash->{report};

    # Extract all the params to a hash to make them easier to work with
    my %params = map { $_ => $c->get_param($_) }
      ( 'email', 'name', 'phone', 'password_register', 'fms_extra_title' );

    my $user_title = Utils::trim_text( $params{fms_extra_title} );

    if ( $c->cobrand->allow_anonymous_reports ) {
        my $anon_details = $c->cobrand->anonymous_account;

        for my $key ( qw( email name ) ) {
            $params{ $key } ||= $anon_details->{ $key };
        }
    }

    # The user is already signed in
    if ( $c->user_exists ) {
        my $user = $c->user->obj;
        $user->name( Utils::trim_text( $params{name} ) ) if $params{name};
        $user->phone( Utils::trim_text( $params{phone} ) );
        $user->title( $user_title ) if $user_title;
        $report->user( $user );
        $report->name( $user->name );
        return 1;
    }

    # cleanup the email address
    my $email = $params{email} ? lc $params{email} : '';
    $email =~ s{\s+}{}g;

    $report->user( $c->model('DB::User')->find_or_new( { email => $email } ) )
        unless $report->user;

    # The user is trying to sign in. We only care about email from the params.
    if ( $c->get_param('submit_sign_in') || $c->get_param('password_sign_in') ) {
        unless ( $c->forward( '/auth/sign_in' ) ) {
            $c->stash->{field_errors}->{password} = _('There was a problem with your email/password combination. If you cannot remember your password, or do not have one, please fill in the &lsquo;sign in by email&rsquo; section of the form.');
            return 1;
        }
        my $user = $c->user->obj;
        $report->user( $user );
        $report->name( $user->name );
        $c->stash->{check_name} = 1;
        $c->stash->{login_success} = 1;
        $c->log->info($user->id . ' logged in during problem creation');
        return 1;
    }

    # set the user's name, phone, and password
    $report->user->name( Utils::trim_text( $params{name} ) ) if $params{name};
    $report->user->phone( Utils::trim_text( $params{phone} ) );
    $report->user->password( Utils::trim_text( $params{password_register} ) )
        if $params{password_register};
    $report->user->title( $user_title ) if $user_title;
    $report->name( Utils::trim_text( $params{name} ) );

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
      map { $_ => $c->get_param($_) }
      (
        'title', 'detail', 'pc',                 #
        'detail_size', 'detail_depth',
        'detail_offensive',
        'may_show_name',                         #
        'category',                              #
        'subcategory',                              #
        'partial',                               #
        'service',                               #
      );

    # load the report
    my $report = $c->stash->{report};

    # Enter the location and other bits which are not from the form
    $report->postcode( $params{pc} );
    $report->latitude( $c->stash->{latitude} );
    $report->longitude( $c->stash->{longitude} );
    $report->send_questionnaire( $c->cobrand->send_questionnaires() );

    # set some simple bool values (note they get inverted)
    $report->anonymous( $params{may_show_name} ? 0 : 1 );

    # clean up text before setting
    $report->title( Utils::cleanup_text( $params{title} ) );

    my $detail = Utils::cleanup_text( $params{detail}, { allow_multiline => 1 } );
    for my $w ('depth', 'size', 'offensive') {
        next unless $params{"detail_$w"};
        next if $params{"detail_$w"} eq '-- Please select --';
        $detail .= "\n\n\u$w: " . $params{"detail_$w"};
    }
    $report->detail( $detail );

    # mobile device type
    $report->service( $params{service} ) if $params{service};

    # set these straight from the params
    $report->category( _ $params{category} ) if $params{category};

    $report->subcategory( $params{subcategory} );

    my $areas = $c->stash->{all_areas_mapit};
    $report->areas( ',' . join( ',', sort keys %$areas ) . ',' );

    # From earlier in the process.
    $areas = $c->stash->{all_areas};
    my $bodies = $c->stash->{bodies};
    my $first_area = ( values %$areas )[0];
    my $first_body = ( values %$bodies )[0];

    if ( $c->cobrand->moniker eq 'emptyhomes' ) {

        $bodies = join( ',', @{ $c->stash->{bodies_to_list} } ) || -1;
        $report->bodies_str( $bodies );

        my %extra;
        $c->cobrand->process_extras( $c, undef, \%extra );
        if ( %extra ) {
            $report->extra( \%extra );
        }

    } elsif ( $report->category ) {

        # FIXME All contacts were fetched in setup_categories_and_bodies,
        # so can this DB call also be avoided?
        my @contacts = $c->       #
          model('DB::Contact')    #
          ->not_deleted           #
          ->search(
            {
                body_id => [ keys %$bodies ],
                category => $report->category
            }
          )->all;

        unless ( @contacts ) {
            $c->stash->{field_errors}->{category} = _('Please choose a category');
            $report->bodies_str( -1 );
            return 1;
        }

        if ($c->stash->{unresponsive}{$report->category} || $c->stash->{unresponsive}{ALL}) {
            # Unresponsive, don't try and send a report.
            $report->bodies_str(-1);
        } else {
            # construct the bodies string:
            my $body_string = do {
                if ( $c->cobrand->can('singleton_bodies_str') && $c->cobrand->singleton_bodies_str ) {
                    # Cobrands like Zurich can only ever have a single body: 'x', because some functionality
                    # relies on string comparison against bodies_str.
                    if (@contacts) {
                        $contacts[0]->body_id;
                    }
                    else {
                        '';
                    }
                }
                else {
                    #  'x,x' - x are body IDs that have this category
                    my $bs = join( ',', map { $_->body_id } @contacts );
                    $bs;
                };
            };
            $report->bodies_str($body_string);
            # Record any body IDs which might have meant to match, but had no contact
            if ($body_string && @{ $c->stash->{missing_details_bodies} }) {
                my $missing = join( ',', map { $_->id } @{ $c->stash->{missing_details_bodies} } );
                $report->bodies_missing($missing);
            }
        }

        my @extra;
        # NB: we are only checking extras for the *first* retrieved contact.
        my $metas = $contacts[0]->get_extra_fields();

        foreach my $field ( @$metas ) {
            if ( lc( $field->{required} ) eq 'true' ) {
                unless ( $c->get_param($field->{code}) ) {
                    $c->stash->{field_errors}->{ $field->{code} } = _('This information is required');
                }
            }
            push @extra, {
                name => $field->{code},
                description => $field->{description},
                value => $c->get_param($field->{code}) || '',
            };
        }

        if ( $c->stash->{non_public_categories}->{ $report->category } ) {
            $report->non_public( 1 );
        }

        $c->cobrand->process_extras( $c, $contacts[0]->body_id, \@extra );

        if ( @extra ) {
            $c->stash->{report_meta} = { map { $_->{name} => $_ } @extra };
            $report->set_extra_fields( @extra );
        }
    } elsif ( @{ $c->stash->{bodies_to_list} } ) {

        # There was an area with categories, but we've not been given one. Bail.
        $c->stash->{field_errors}->{category} = _('Please choose a category');

    } else {

        # If we're here, we've been submitted somewhere
        # where we have no contact information at all.
        $report->bodies_str( -1 );

    }

    # set defaults that make sense
    $report->state('unconfirmed');

    # save the cobrand and language related information
    $report->cobrand( $c->cobrand->moniker );
    $report->cobrand_data( '' );
    $report->lang( $c->stash->{lang_code} );

    return 1;
}

=head2 check_for_errors

Examine the user and the report for errors. If found put them on stash and
return false.

=cut

sub check_for_errors : Private {
    my ( $self, $c ) = @_;

    # let the model check for errors
    $c->stash->{field_errors} ||= {};
    my %field_errors = $c->cobrand->report_check_for_errors( $c );

    # Zurich, we don't care about title or name
    # There is no title, and name is optional
    if ( $c->cobrand->moniker eq 'zurich' ) {
        delete $field_errors{title};
        delete $field_errors{name};
        my $report = $c->stash->{report};
        $report->title( Utils::cleanup_text( substr($report->detail, 0, 25) ) );

        # We only want to validate the phone number web requests (where the
        # service parameter is blank) because previous versions of the mobile
        # apps don't validate the presence of a phone number.
        if ( ! $c->get_param('phone') and ! $c->get_param('service') ) {
            $field_errors{phone} = _("This information is required");
        }
    }

    # FIXME: need to check for required bromley fields here

    # if they're got the login details wrong when signing in then
    # we don't care about the name field even though it's validated
    # by the user object
    if ( $c->get_param('submit_sign_in') and $field_errors{password} ) {
        delete $field_errors{name};
    }

    # add the photo error if there is one.
    if ( my $photo_error = delete $c->stash->{photo_error} ) {
        $field_errors{photo} = $photo_error;
    }

    # all good if no errors
    return 1 unless scalar keys %field_errors || $c->stash->{login_success};

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
    my $report      = $c->stash->{report};

    # Save or update the user if appropriate
    if ( $c->cobrand->never_confirm_reports ) {
        if ( $report->user->in_storage() ) {
            $report->user->update();
        } else {
            $report->user->insert();
        }
        $report->confirm();
    } elsif ( !$report->user->in_storage ) {
        # User does not exist.
        # Store changes in token for when token is validated.
        $c->stash->{token_data} = {
            name => $report->user->name,
            phone => $report->user->phone,
            password => $report->user->password,
            title   => $report->user->title,
        };
        $report->user->name( undef );
        $report->user->phone( undef );
        $report->user->password( '', 1 );
        $report->user->title( undef );
        $report->user->insert();
        $c->log->info($report->user->id . ' created for this report');
    }
    elsif ( $c->user && $report->user->id == $c->user->id ) {
        # Logged in and matches, so instantly confirm (except Zurich, with no confirmation)
        $report->user->update();
        $report->confirm
            unless $c->cobrand->moniker eq 'zurich';
        $c->log->info($report->user->id . ' is logged in for this report');
    }
    else {
        # User exists and we are not logged in as them.
        # Store changes in token for when token is validated.
        $c->stash->{token_data} = {
            name => $report->user->name,
            phone => $report->user->phone,
            password => $report->user->password,
            title   => $report->user->title,
        };
        $report->user->discard_changes();
        $c->log->info($report->user->id . ' exists, but is not logged in for this report');
    }

    # If there was a photo add that too
    if ( my $fileid = $c->stash->{upload_fileid} ) {
        $report->photo($fileid);
    }

    # Set a default if possible
    $report->category( _('Other') ) unless $report->category;

    # Set unknown to DB unknown
    $report->bodies_str( undef ) if $report->bodies_str eq '-1';

    # if there is a Message Manager message ID, pass it back to the client view
    if ($c->cobrand->moniker eq 'fixmybarangay' && $c->get_param('external_source_id') =~ /^\d+$/) {
        $c->stash->{external_source_id} = $c->get_param('external_source_id');
        $report->external_source_id( $c->get_param('external_source_id') );
        $report->external_source( $c->config->{MESSAGE_MANAGER_URL} ) ;
    }
    
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

    # Don't do anything if the user skipped the map
    if ( $c->stash->{report}->used_map ) {
        $c->stash->{page} = 'new';
        FixMyStreet::Map::display_map(
            $c,
            latitude  => $latitude,
            longitude => $longitude,
            clickable => 1,
            pins      => [ {
                latitude  => $latitude,
                longitude => $longitude,
                colour    => 'green', # 'yellow',
            } ],
        );
    }

    return 1;
}

sub check_for_category : Private {
    my ( $self, $c ) = @_;

    $c->stash->{category} = $c->get_param('category');

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
        $c->log->info($report->user->id . ' was logged in, showing confirmation page for ' . $report->id);
        $c->stash->{created_report} = 'loggedin';
        $c->stash->{template} = 'tokens/confirm_problem.html';
        return 1;
    }

    my $template = 'problem-confirm.txt';
    $template = 'problem-confirm-not-sending.txt' unless $report->bodies_str;

    # otherwise create a confirm token and email it to them.
    my $data = $c->stash->{token_data} || {};
    my $token = $c->model("DB::Token")->create( {
        scope => 'problem',
        data => {
            %$data,
            id => $report->id
        }
    } );
    $c->stash->{token_url} = $c->uri_for_email( '/P', $token->token );
    if ($c->cobrand->can('problem_confirm_email_extras')) {
        $c->cobrand->problem_confirm_email_extras($report);
    }
    $c->send_email( $template, {
        to => [ $report->name ? [ $report->user->email, $report->name ] : $report->user->email ],
    } );

    # tell user that they've been sent an email
    $c->stash->{template}   = 'email_sent.html';
    $c->stash->{email_type} = 'problem';
    $c->log->info($report->user->id . ' created ' . $report->id . ', email sent, ' . ($data->{password} ? 'password set' : 'password not set'));
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
        pc => ( $c->stash->{pc} || $c->get_param('pc') || '' ),
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

__PACKAGE__->meta->make_immutable;

1;
