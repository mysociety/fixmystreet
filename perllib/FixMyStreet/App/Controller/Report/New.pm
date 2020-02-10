package FixMyStreet::App::Controller::Report::New;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use utf8;
use Encode;
use List::MoreUtils qw(uniq);
use List::Util 'first';
use HTML::Entities;
use Path::Class;
use Utils;
use mySociety::EmailUtil;
use JSON::MaybeXS;
use Text::CSV;
use FixMyStreet::SMS;

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
    $c->forward('/auth/get_csrf_token');

    my @shortlist = grep { /^shortlist-(add|remove)-(\d+)$/ } keys %{$c->req->params};
    if (@shortlist) {
        my ($cmd, $id) = $shortlist[0] =~ /^shortlist-(add|remove)-(\d+)$/;
        $c->req->params->{id} = $id;
        $c->req->params->{"shortlist-$cmd"} = 1;
        $c->detach('/my/planned_change');
    }

    # work out the location for this report and do some checks
    # Also show map if we're just updating the filters
    return $c->forward('redirect_to_around')
      if !$c->forward('determine_location') || $c->get_param('pc_override') || $c->get_param('filter_update');

    # create a problem from the submitted details
    $c->stash->{template} = "report/new/fill_in_details.html";
    $c->forward('setup_categories_and_bodies');
    $c->forward('setup_report_extra_fields');
    $c->forward('check_for_category');
    $c->forward('setup_report_extras');

    # deal with the user and report and check both are happy

    $c->detach('generate_map') unless $c->forward('check_form_submitted');

    $c->forward('/auth/check_csrf_token');
    $c->forward('process_report');
    $c->forward('process_user');
    $c->forward('/photo/process_photo');
    $c->detach('generate_map') unless $c->forward('check_for_errors');
    $c->forward('save_user_and_report');
    $c->forward('redirect_or_confirm_creation');
}

# This is for the new phonegap versions of the app. It looks a lot like
# report_new but there's a few workflow differences as we only ever want
# to sent JSON back here

sub report_new_ajax : Path('mobile') : Args(0) {
    my ( $self, $c ) = @_;

    # Apps are sending email as username
    # Prepare for when they upgrade
    if (!$c->get_param('username')) {
        $c->set_param('username', $c->get_param('email'));
    }

    # create the report - loading a partial if available
    $c->forward('initialize_report');

    unless ( $c->forward('determine_location') ) {
        $c->stash->{ json_response } = { errors => 'Unable to determine location' };
        $c->forward('send_json_response');
        return 1;
    }

    $c->forward('setup_categories_and_bodies');
    $c->forward('setup_report_extra_fields');
    $c->forward('check_for_category');
    $c->forward('process_report');
    $c->forward('process_user');
    $c->forward('/photo/process_photo');

    unless ($c->forward('check_for_errors')) {
        $c->stash->{ json_response } = { errors => $c->stash->{field_errors} };
        $c->stash->{ json_response }->{check_name} = $c->user->name if $c->stash->{check_name};
        $c->forward('send_json_response');
        return 1;
    }

    $c->forward('save_user_and_report');

    my $report = $c->stash->{report};
    if ( $report->confirmed ) {
        $c->forward( 'create_reporter_alert' );
        $c->stash->{ json_response } = { success => 1, report => $report->id };
    } else {
        $c->forward( 'send_problem_confirm_email' );
        $c->stash->{ json_response } = { success => 1 };
    }

    $c->forward('send_json_response');
}

sub send_json_response : Private {
    my ( $self, $c ) = @_;

    my $body = encode_json($c->stash->{json_response});
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);
}

sub report_form_ajax : Path('ajax') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('initialize_report');

    # work out the location for this report and do some checks
    if ( ! $c->forward('determine_location') ) {
        $c->stash->{json_response} = { error => $c->stash->{location_error} };
        $c->detach('send_json_response');
    }

    $c->forward('setup_categories_and_bodies');
    $c->forward('setup_report_extra_fields');

    # render templates to get the html
    my $category = $c->render_fragment( 'report/new/category.html');
    my $councils_text = $c->render_fragment( 'report/new/councils_text.html');
    my $councils_text_private = $c->render_fragment( 'report/new/councils_text_private.html');
    my $top_message = $c->render_fragment('report/new/top_message.html');
    my $extra_name_info = $c->stash->{extra_name_info}
        ? $c->render_fragment('report/new/extra_name.html')
        : '';

    my $extra_titles_list = $c->cobrand->title_list($c->stash->{all_areas});

    my @list_of_names = map { $_->name } values %{$c->stash->{bodies}};
    my %display_names = map {
        my $name = $_->cobrand_name;
        ( $_->name ne $name ) ? ( $_->name => $name ) : ();
    } values %{$c->stash->{bodies}};
    my $contribute_as = {};
    if ($c->user_exists) {
        my @bodies = keys %{$c->stash->{bodies}};
        my $ca_another_user = $c->user->has_permission_to('contribute_as_another_user', \@bodies);
        my $ca_anonymous_user = $c->user->has_permission_to('contribute_as_anonymous_user', \@bodies);
        my $ca_body = $c->user->from_body && $c->user->has_permission_to('contribute_as_body', \@bodies);
        $contribute_as->{another_user} = $ca_another_user if $ca_another_user;
        $contribute_as->{anonymous_user} = $ca_anonymous_user if $ca_anonymous_user;
        $contribute_as->{body} = $ca_body if $ca_body;
    }

    my %by_category;
    foreach my $contact (@{$c->stash->{category_options}}) {
        next if ref $contact eq 'HASH'; # Ignore the 'Pick a category' line
        my $cat = $c->stash->{category} = $contact->category;
        my $body = $c->forward('by_category_ajax_data', [ 'all', $cat ]);
        $by_category{$cat} = $body;
    }

    $c->stash->{json_response} = {
        bodies          => \@list_of_names,
        councils_text   => $councils_text,
        councils_text_private => $councils_text_private,
        category        => $category,
        extra_name_info => $extra_name_info,
        titles_list     => $extra_titles_list,
        %display_names ? (display_names   => \%display_names) : (),
        %$contribute_as ? (contribute_as => $contribute_as) : (),
        $top_message ? (top_message => $top_message) : (),
        unresponsive => $c->stash->{unresponsive}->{ALL} || '',
        by_category => \%by_category,
    };
    $c->detach('send_json_response');
}

sub category_extras_ajax : Path('category_extras') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('initialize_report');
    if ( ! $c->forward('determine_location') ) {
        $c->stash->{json_response} = { error => _("Sorry, we could not find that location.") };
        $c->detach('send_json_response');
    }
    $c->forward('setup_categories_and_bodies');
    $c->forward('setup_report_extra_fields');

    $c->forward('check_for_category');
    $c->stash->{json_response} = $c->forward('by_category_ajax_data', [ 'one', $c->stash->{category} ]);
    $c->forward('send_json_response');
}

sub by_category_ajax_data : Private {
    my ($self, $c, $type, $category) = @_;

    my @bodies;
    my $bodies = [];
    my $vars = {};
    if ($category) {
        $bodies = $c->forward('contacts_to_bodies', [ $category ]);
        @bodies = @$bodies;
        $vars->{list_of_names} = [ map { $_->cobrand_name } @bodies ];
    } else {
        @bodies = values %{$c->stash->{bodies_to_list}};
    }

    my $non_public = $c->stash->{non_public_categories}->{$category};
    my $anon_button = ($c->cobrand->allow_anonymous_reports($category) eq 'button');
    my $body = {
        bodies => [ map { $_->name } @bodies ],
        $non_public ? ( non_public => JSON->true ) : (),
        $anon_button ? ( allow_anonymous => JSON->true ) : (),
    };

    if ( $c->stash->{category_extras}->{$category} && @{ $c->stash->{category_extras}->{$category} } >= 1 ) {
        my $disable_form = $c->forward('disable_form_message');
        $body->{disable_form} = $disable_form if %$disable_form;

        # Remove the full disable_form extras, as included in disable form output
        @{$c->stash->{category_extras}->{$c->stash->{category}}} = grep {
            !$_->{disable_form} || $_->{disable_form} ne 'true'
        } @{$c->stash->{category_extras}->{$c->stash->{category}}};
    }

    if (($c->stash->{category_extras}->{$category} && @{ $c->stash->{category_extras}->{$category} } >= 1) or
            $c->stash->{unresponsive}->{$category} or $c->stash->{report_extra_fields}) {
        $body->{category_extra} = $c->render_fragment('report/new/category_extras.html', $vars);
        $body->{category_extra_json} = $c->forward('generate_category_extra_json');
    }

    my $unresponsive = $c->stash->{unresponsive}->{$category};
    $unresponsive ||= $c->stash->{unresponsive}->{ALL} || '' if $type eq 'one';

    # unresponsive must return empty string if okay, as that's what mobile app checks
    # councils_text.html must be rendered if it differs from the default output,
    # which currently means for unresponsive and non_public categories.
    if ($type eq 'one' || ($type eq 'all' && $unresponsive)) {
        $body->{unresponsive} = $unresponsive;
        # Check for no bodies here, because if there are any (say one
        # unresponsive, one not), can use default display code for that.
        if ($type eq 'all' && !@$bodies) {
            $body->{councils_text} = $c->render_fragment( 'report/new/councils_text.html', $vars);
            $body->{councils_text_private} = $c->render_fragment( 'report/new/councils_text_private.html');
        }
    }
    if ($non_public) {
        $body->{councils_text} = $c->render_fragment( 'report/new/councils_text.html', $vars);
    }

    return $body;
}

sub disable_form_message : Private {
    my ( $self, $c ) = @_;

    my %out;

    # do not set disable form message if they are a staff user
    return \%out if $c->cobrand->call_hook('staff_ignore_form_disable_form');

    foreach (@{$c->stash->{category_extras}->{$c->stash->{category}}}) {
        if ($_->{disable_form} && $_->{disable_form} eq 'true') {
            $out{all} .= ' ' if $out{all};
            $out{all} .= $_->{description};
        } elsif (($_->{variable} || '') eq 'true' && @{$_->{values} || []}) {
            my %category;
            foreach my $opt (@{$_->{values}}) {
                if ($opt->{disable}) {
                    $category{message} = $opt->{disable_message} || $_->{datatype_description};
                    $category{code} = $_->{code};
                    push @{$category{answers}}, $opt->{key};
                }
            }
            push @{$out{questions}}, \%category if %category;
        }
    }

    return \%out;
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
        'easting', 'northing', 'lat',    'lon',
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

    # find or create the user
    my $report_user = $c->model('DB::User')->find_or_create(
        {
            email => lc $input{email},
            email_verified => 1,
            name  => $input{name},
            phone => $input{phone}
        },
        {
            key => 'users_email_verified_key'
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

    if ( $c->get_param('web') ) {
        $c->res->content_type('text/html; charset=utf-8');
        $c->stash->{template}   = 'email_sent.html';
        $c->stash->{email_type} = 'problem';
        return 1;
    }
    $c->res->body('SUCCESS');
    return 1;
}

sub oauth_callback : Private {
    my ( $self, $c, $token_code ) = @_;
    my $auth_token = $c->forward(
        '/tokens/load_auth_token', [ $token_code, 'problem/social' ]);
    $c->stash->{oauth_report} = $auth_token->data;
    $c->detach('report_new');
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

            # is it in the database
            my $token =
              $c->model("DB::Token")
              ->find( { scope => 'partial', token => $partial } )
              || last;

            # can we get an id from it?
            my $id = $token->data || last;

            # load the related problem
            $report = $c->cobrand->problems
              ->search( { id => $id, state => 'partial' } )
              ->first;

            if ($report) {
                # log the problem creation user in to the site, if not already logged in
                if (!$c->user_exists || $c->user->email ne $report->user->email) {
                    $c->authenticate( { email => $report->user->email, email_verified => 1 },
                        'no_password' );
                }

                # save the token to delete at the end
                $c->stash->{partial_token} = $token if $report;

                $c->stash->{email} = $report->user->email;
                $c->stash->{phone} = $report->user->phone_display;

            } else {
                # no point keeping it if it is done.
                $token->delete;
            }
        }
    }

    if (!$report && $c->stash->{oauth_report}) {
        $report = $c->model("DB::Problem")->new($c->stash->{oauth_report});
    }

    if ($report) {
        # Stash the photo IDs for "already got" display
        $c->stash->{upload_fileid} = $report->get_photoset->data;
    } else {
        # If we didn't find one otherwise, start with a blank report
        $report = $c->model('DB::Problem')->new( {} );
    }

    # If we have a user logged in let's prefill some values for them.
    if (!$report->user && $c->user) {
        my $user = $c->user->obj;
        $report->user($user);
        $report->name( $user->name );
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
          && $c->forward('/around/check_location_is_acceptable', []);
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

    my @bodies = $c->model('DB::Body')->active->for_areas(keys %$all_areas)->all;
    my %bodies = map { $_->id => $_ } @bodies;

    $c->cobrand->call_hook(munge_report_new_bodies => \%bodies);

    my $contacts                #
      = $c                      #
      ->model('DB::Contact')    #
      ->active
      ->search( { 'me.body_id' => [ keys %bodies ] }, { prefetch => 'body' } );
    my @contacts = $c->cobrand->categories_restriction($contacts)->all_sorted;

    $c->cobrand->call_hook(munge_report_new_contacts => \@contacts);

    # variables to populate
    my %bodies_to_list = ();       # Bodies with categories assigned
    my @category_options = ();       # categories to show
    my %category_extras  = ();       # extra fields to fill in for open311
    my %category_extras_hidden =
      (); # whether all of a category's fields are hidden
    my %category_extras_notices =
      (); # whether all of a category's fields are simple notices and not inputs
    my %non_public_categories =
      ();    # categories for which the reports are not public
    $c->stash->{unresponsive} = {};

    my @refused_bodies = grep { ($_->send_method || "") eq 'Refused' } values %bodies;
    if (@refused_bodies && @refused_bodies == values %bodies) {
        # If all bodies are set to Refused, we can show the
        # message immediately, before they select a category.
        my $k = 'ALL';
        if ($c->action->name eq 'category_extras_ajax' && $c->req->method eq 'POST') {
            # The mobile app doesn't currently use this, in which case make
            # sure the message is output, either below with a category, or when
            # a blank category call is made.
            $k = "";
        }
        $c->stash->{unresponsive}{$k} = { map { $_ => 1 } keys %bodies };
    }

    my %seen;
    foreach my $contact (@contacts) {

        $bodies_to_list{ $contact->body_id } = $contact->body;

        my $metas = $contact->get_metadata_for_input;
        if (@$metas) {
            push @{$category_extras{$contact->category}}, @$metas;
            my $all_hidden = (grep { !$c->cobrand->category_extra_hidden($_) } @$metas) ? 0 : 1;
            if (exists($category_extras_hidden{$contact->category})) {
                $category_extras_hidden{$contact->category} &&= $all_hidden;
            } else {
                $category_extras_hidden{$contact->category} = $all_hidden;
            }

            my $all_notices = (grep {
                ( $_->{variable} || '' ) ne 'false'
                && !$c->cobrand->category_extra_hidden($_)
            } @$metas) ? 0 : 1;
            if (exists($category_extras_notices{$contact->category})) {
                $category_extras_notices{$contact->category} &&= $all_notices;
            } else {
                $category_extras_notices{$contact->category} = $all_notices;
            }
        }

        $non_public_categories{ $contact->category } = 1 if $contact->non_public;

        my $body_send_method = $contact->body->send_method || '';
        $c->stash->{unresponsive}{$contact->category}{$contact->body_id} = 1
            if !$c->stash->{unresponsive}{ALL} &&
                ($contact->email =~ /^REFUSED$/i || $body_send_method eq 'Refused');

        push @category_options, $contact unless $seen{$contact->category};
        $seen{$contact->category} = $contact;
    }

    if (@category_options) {
        # If there's an Other category present, put it at the bottom
        @category_options = (
            { category => _('-- Pick a category --'), category_display => _('-- Pick a category --'), group => '' },
            grep { $_->category ne _('Other') } @category_options );
        push @category_options, $seen{_('Other')} if $seen{_('Other')};
    }

    $c->cobrand->call_hook(munge_report_new_category_list => \@category_options, \@contacts, \%category_extras);

    # put results onto stash for display
    $c->stash->{bodies} = \%bodies;
    $c->stash->{contacts} = \@contacts;
    $c->stash->{bodies_to_list} = \%bodies_to_list;
    $c->stash->{bodies_ids} = [ map { $_ } keys %bodies ];
    $c->stash->{category_options} = \@category_options;
    $c->stash->{category_extras}  = \%category_extras;
    $c->stash->{category_extras_hidden}  = \%category_extras_hidden;
    $c->stash->{category_extras_notices}  = \%category_extras_notices;
    $c->stash->{non_public_categories}  = \%non_public_categories;
    $c->stash->{extra_name_info} = $first_area->{id} == COUNCIL_ID_BROMLEY ? 1 : 0;

    # escape these so we can then split on , cleanly in the template.
    my @list_of_names = map { $_->name } values %bodies_to_list;
    my $csv = Text::CSV->new();
    $csv->combine(@list_of_names);
    $c->stash->{list_of_names_as_string} = $csv->string;

    my @missing_details_bodies = grep { !$bodies_to_list{$_->id} } values %bodies;
    my @missing_details_body_names = map { $_->name } @missing_details_bodies;

    $c->stash->{missing_details_bodies} = \@missing_details_bodies;
    $c->stash->{missing_details_body_names} = \@missing_details_body_names;

    $c->forward('/report/stash_category_groups', [ \@category_options ]) if $c->cobrand->enable_category_groups;
}

sub setup_report_extra_fields : Private {
    my ( $self, $c ) = @_;

    return unless $c->cobrand->allow_report_extra_fields;

    my @extras = $c->model('DB::ReportExtraField')->for_cobrand($c->cobrand)->for_language($c->stash->{lang_code})->all;
    $c->stash->{report_extra_fields} = \@extras;
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

    # Report form includes two username fields: #form_username_register and #form_username_sign_in
    $params{username} = (first { $_ } $c->get_param_list('username')) || '';

    my $anon_button = $c->cobrand->allow_anonymous_reports eq 'button' && $c->get_param('report_anonymously');
    my $anon_fallback = $c->cobrand->allow_anonymous_reports eq '1' && !$c->user_exists && !$params{username};
    if ($anon_button || $anon_fallback) {
        my $anon_details = $c->cobrand->anonymous_account;
        my $user = $c->model('DB::User')->find_or_new({ email => $anon_details->{email} });
        $user->name($anon_details->{name});
        $report->user($user);
        $report->name($user->name);
        $c->stash->{no_reporter_alert} = 1;
        $c->stash->{contributing_as_anonymous_user} = 1;
        return 1;
    }

    # The user is already signed in. Extra bare block for 'last'.
    if ( $c->user_exists ) { {
        my $user = $c->user->obj;

        if ($c->stash->{contributing_as_another_user}) {
            if ($params{username} || $params{phone}) {
                # Act as if not logged in (and it will be auto-confirmed later on)
                $report->user(undef);
                last;
            }
        }

        $report->user( $user );
        $c->forward('update_user', [ \%params ]);

        $c->stash->{phone} = $report->user->phone_display;
        $c->stash->{email} = $report->user->email;

        if ($c->stash->{contributing_as_body} or $c->stash->{contributing_as_anonymous_user}) {
            my $name = $user->moderating_user_name;
            $report->name($name);
            $user->name($name) unless $user->name;
            $c->stash->{no_reporter_alert} = 1;
        } elsif ($c->stash->{contributing_as_another_user}) {
            $c->stash->{no_reporter_alert} = 1;
        }

        return 1;
    } }

    if ( $c->stash->{contributing_as_another_user} && !$params{username} ) {
        # If the 'username' (i.e. email) field is blank, then use the phone
        # field for the username.
        $params{username} = $params{phone};
    }

    my $parsed = FixMyStreet::SMS->parse_username($params{username});
    my $type = $parsed->{type} || 'email';
    $type = 'email' unless FixMyStreet->config('SMS_AUTHENTICATION') || $c->stash->{contributing_as_another_user};
    $report->user( $c->model('DB::User')->find_or_new( { $type => $parsed->{username} } ) )
        unless $report->user;

    $c->stash->{phone_may_be_mobile} = $type eq 'phone' && $parsed->{may_be_mobile};

    $c->forward('update_user', [ \%params ]);

    $c->stash->{phone} = Utils::trim_text( $type eq 'phone' ? $report->user->phone_display : $params{phone} );
    $c->stash->{email} = Utils::trim_text( $type eq 'email' ? $report->user->email : $params{email} );


    # The user is trying to sign in. We only care about username from the params.
    if ( $c->get_param('submit_sign_in') || $c->get_param('password_sign_in') ) {
        $c->stash->{tfa_data} = {
            detach_to => '/report/new/report_new',
            login_success => 1,
            oauth_report => { $report->get_inflated_columns }
        };
        unless ( $c->forward( '/auth/sign_in', [ $params{username} ] ) ) {
            $c->stash->{field_errors}->{password} = _('There was a problem with your login information. If you cannot remember your password, or do not have one, please fill in the ‘No’ section of the form.');
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

    if ($params{password_register}) {
        $c->forward('/auth/test_password', [ $params{password_register} ]);
        $report->user->password($params{password_register});
    }

    return 1;
}

sub update_user : Private {
    my ($self, $c, $params) = @_;
    my $report = $c->stash->{report};
    my $user = $report->user;
    $user->name( Utils::trim_text( $params->{name} ) );
    $report->name($user->name);
    if (!$user->phone_verified) {
        $user->phone( Utils::trim_text( $params->{phone} ) );
    } elsif (!$user->email_verified) {
        $user->email( Utils::trim_text( $params->{email} ) );
    }
    my $user_title = Utils::trim_text( $params->{fms_extra_title} );
    $user->title( $user_title ) if $user_title;
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
        'detail_size',
        'may_show_name',                         #
        'subcategory',                              #
        'partial',                               #
        'service',                               #
        'non_public',
      );
    $params{category} = $c->stash->{category};

    # load the report
    my $report = $c->stash->{report};

    # Enter the location and other bits which are not from the form
    $report->postcode( $params{pc} );
    $report->latitude( $c->stash->{latitude} );
    $report->longitude( $c->stash->{longitude} );
    $report->send_questionnaire( $c->cobrand->send_questionnaires() );

    if ( $c->user_exists ) {
        my $user = $c->user->obj;
        $c->stash->{contributing_as_another_user} = $user->contributing_as('another_user', $c, $c->stash->{bodies});
        $c->stash->{contributing_as_body} = $user->contributing_as('body', $c, $c->stash->{bodies});
        $c->stash->{contributing_as_anonymous_user} = $user->contributing_as('anonymous_user', $c, $c->stash->{bodies});
    }
    # This is also done in process_user, but is needed here for anonymous() just below
    my $anon_button = $c->cobrand->allow_anonymous_reports($params{category}) eq 'button' && $c->get_param('report_anonymously');
    if ($anon_button) {
        $c->stash->{contributing_as_anonymous_user} = 1;
        $c->stash->{contributing_as_body} = undef;
        $c->stash->{contributing_as_another_user} = undef;
    }

    # set some simple bool values (note they get inverted)
    if ($c->stash->{contributing_as_body}) {
        $report->anonymous(0);
    } elsif ($c->stash->{contributing_as_anonymous_user}) {
        $report->anonymous(1);
    } else {
        $report->anonymous( $params{may_show_name} ? 0 : 1 );
    }

    $report->non_public($params{non_public} ? 1 : 0);

    # clean up text before setting
    $report->title( Utils::cleanup_text( $params{title} ) );

    my $detail = Utils::cleanup_text( $params{detail}, { allow_multiline => 1 } );
    for my $w ('size') {
        next unless $params{"detail_$w"};
        $detail .= "\n\n\u$w: " . $params{"detail_$w"};
    }
    $report->detail( $detail );

    # mobile device type
    $report->service( $params{service} ) if $params{service};

    # set these straight from the params
    $report->category( _ $params{category} ) if $params{category};
    $c->cobrand->call_hook(report_new_munge_category => $report);
    $report->subcategory( $params{subcategory} );

    my $areas = $c->stash->{all_areas_mapit};
    $report->areas( ',' . join( ',', sort keys %$areas ) . ',' );

    if ( $report->category ) {
        my @contacts = grep { $_->category eq $report->category } @{$c->stash->{contacts}};
        unless ( @contacts ) {
            $c->stash->{field_errors}->{category} = _('Please choose a category');
            $report->bodies_str( -1 );
            return 1;
        }

        # check that we've not indicated we only want to sent to a single body
        # and if we find a matching one then only send to that. e.g. if we clicked
        # on a TfL road on the map.
        my $body_string = do {
            if (my $single_body_only = $c->get_param('single_body_only')) {
                my $body = $c->model('DB::Body')->search({ name => $single_body_only })->first;
                if ($body) {
                    # Drop the contacts down to those in this body
                    # (potentially none for e.g. Highways England)
                    # so that set_report_extras doesn't error when
                    # there are 'missing' extra fields
                    @contacts = grep { $_->body->id == $body->id } @contacts;
                    $body->id;
                } else {
                    '-1';
                }
            } else {
                my $contact_options = {};
                $contact_options->{do_not_send} = [ $c->get_param_list('do_not_send', 1) ];
                my $bodies = $c->forward('contacts_to_bodies', [ $report->category, $contact_options ]);
                join(',', map { $_->id } @$bodies) || '-1';
            }
        };

        $report->bodies_str($body_string);
        # Record any body IDs which might have meant to match, but had no contact
        if ($body_string ne '-1' && @{ $c->stash->{missing_details_bodies} }) {
            my $missing = join( ',', map { $_->id } @{ $c->stash->{missing_details_bodies} } );
            $report->bodies_missing($missing);
        }

        $c->forward('set_report_extras', [ \@contacts ]);

        if ( $c->stash->{non_public_categories}->{ $report->category } ) {
            $report->non_public( 1 );
        }
    } elsif ( %{ $c->stash->{bodies_to_list} } ) {

        # There was an area with categories, but we've not been given one. Bail.
        $c->stash->{field_errors}->{category} = _('Please choose a category');

    } else {

        # If we're here, we've been submitted somewhere
        # where we have no contact information at all.
        $report->bodies_str( -1 );

    }

    # Get a list of custom form fields we want and store them in extra metadata
    foreach my $field ($c->cobrand->report_form_extras) {
        my $form_name = $field->{name};
        my $value = $c->get_param($form_name) || '';
        $c->stash->{field_errors}->{$form_name} = _('This information is required')
            if $field->{required} && !$value;
        if ($field->{validator}) {
            eval {
                $value = $field->{validator}->($value);
            };
            if ($@) {
                $c->stash->{field_errors}->{$form_name} = $@;
            }
        }
        $report->set_extra_metadata( $form_name => $value );
    }

    # set defaults that make sense
    $report->state($c->cobrand->default_problem_state);

    # save the cobrand and language related information
    $report->cobrand( $c->cobrand->moniker );
    $report->cobrand_data( '' );
    $report->lang( $c->stash->{lang_code} );

    return 1;
}

sub contacts_to_bodies : Private {
    my ($self, $c, $category, $options) = @_;

    my @contacts = grep { $_->category eq $category } @{$c->stash->{contacts}};

    # check that the front end has not indicated that we should not send to a
    # body. This is usually because the asset code thinks it's not near enough
    # to a road.
    if ($options->{do_not_send}) {
        my %do_not_send_check = map { $_ => 1 } @{$options->{do_not_send}};
        my @contacts_filtered = grep { !$do_not_send_check{$_->body->name} } @contacts;
        @contacts = @contacts_filtered if scalar @contacts_filtered;
    }

    my $unresponsive = $c->stash->{unresponsive}{$category} || $c->stash->{unresponsive}{ALL};
    if ($unresponsive) {
        @contacts = grep { !$unresponsive->{$_->body_id} } @contacts;
    } elsif (@contacts) {
        if ( $c->cobrand->call_hook('singleton_bodies_str') ) {
            # Cobrands like Zurich can only ever have a single body: 'x', because some functionality
            # relies on string comparison against bodies_str.
            @contacts = ($contacts[0]);
        }
    }
    [ map { $_->body } @contacts ];
}

sub setup_report_extras : Private {
    my ($self, $c) = @_;

    # report_meta is used by the templates to fill in the extra field values
    my $extra = $c->stash->{report}->get_extra_fields;
    $c->stash->{report_meta} = { map { 'x' . $_->{name} => $_ } @$extra };
}

sub set_report_extras : Private {
    my ($self, $c, $contacts, $param_prefix) = @_;

    $param_prefix ||= "";
    my @metalist = map { [ $_->get_metadata_for_storage, $param_prefix ] } @$contacts;
    push @metalist, map { [ $_->get_extra_fields, "extra[" . $_->id . "]" ] } @{$c->stash->{report_extra_fields}};

    my @extra;
    foreach my $item (@metalist) {
        my ($metas, $param_prefix) = @$item;
        foreach my $field ( @$metas ) {
            if ( lc( $field->{required} || '' ) eq 'true' && !$c->cobrand->category_extra_hidden($field)) {
                unless ( $c->get_param($param_prefix . $field->{code}) ) {
                    $c->stash->{field_errors}->{ 'x' . $field->{code} } = _('This information is required');
                }
            }
            push @extra, {
                name => $field->{code},
                description => $field->{description},
                value => $c->get_param($param_prefix . $field->{code}) || '',
            };
        }
    }

    $c->cobrand->process_open311_extras( $c, @$contacts[0]->body, \@extra )
        if ( scalar @$contacts );

    if ( @extra ) {
        $c->stash->{report_meta} = { map { 'x' . $_->{name} => $_ } @extra };
        $c->stash->{report}->set_extra_fields( @extra );
    }
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

    my $report = $c->stash->{report};

    # Zurich, we don't care about title or name
    # There is no title, and name is optional
    if ( $c->cobrand->moniker eq 'zurich' ) {
        delete $field_errors{title};
        delete $field_errors{name};
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

    # If we're making an anonymous report, we do not care about the name field
    if ( $c->stash->{contributing_as_anonymous_user} ) {
        delete $field_errors{name};
    }

    # if using social login then we don't care about other errors
    $c->stash->{is_social_user} = $c->get_param('social_sign_in') ? 1 : 0;
    if ( $c->stash->{is_social_user} ) {
        delete $field_errors{name};
        delete $field_errors{username};
    }

    # if we're contributing as someone else then allow landline numbers
    if ( $field_errors{phone} && $c->stash->{contributing_as_another_user} && !$c->stash->{phone_may_be_mobile}) {
        delete $field_errors{username};
        delete $field_errors{phone};
    }

    # add the photo error if there is one.
    if ( my $photo_error = delete $c->stash->{photo_error} ) {
        $field_errors{photo} = $photo_error;
    }

    # all good if no errors
    return 1 unless scalar keys %field_errors || $c->stash->{login_success};

    $c->stash->{field_errors} = \%field_errors;

    if ( $c->cobrand->allow_anonymous_reports ) {
        my $anon_details = $c->cobrand->anonymous_account;
        $report->user->email(undef) if $report->user->email eq $anon_details->{email};
        $report->name(undef) if $report->name eq $anon_details->{name};
    }

    return;
}

# Store changes in token for when token is validated.
sub tokenize_user : Private {
    my ($self, $c, $report) = @_;
    $c->stash->{token_data} = {
        name => $report->user->name,
        (!$report->user->phone_verified ? (phone => $report->user->phone) : ()),
        (!$report->user->email_verified ? (email => $report->user->email) : ()),
        password => $report->user->password,
        title => $report->user->title,
    };
    $c->forward('/auth/set_oauth_token_data', [ $c->stash->{token_data} ])
        if $c->get_param('oauth_need_email');
}

sub send_problem_confirm_email : Private {
    my ( $self, $c ) = @_;
    my $data = $c->stash->{token_data} || {};
    my $report = $c->stash->{report};
    my $token = $c->model("DB::Token")->create( {
        scope => 'problem',
        data => {
            %$data,
            id => $report->id
        }
    } );

    my $template = 'problem-confirm.txt';
    $template = 'problem-confirm-not-sending.txt' unless $report->bodies_str;

    $c->stash->{token_url} = $c->uri_for_email( '/P', $token->token );
    $c->cobrand->call_hook(problem_confirm_email_extras => $report);

    $c->send_email( $template, {
        to => [ $report->name ? [ $report->user->email, $report->name ] : $report->user->email ],
    } );
}

sub send_problem_confirm_text : Private {
    my ( $self, $c ) = @_;
    my $data = $c->stash->{token_data} || {};
    my $report = $c->stash->{report};

    $data->{id} = $report->id;
    $c->forward('/auth/phone/send_token', [ $data, 'problem', $report->user->phone ]);
    $c->stash->{submit_url} = '/report/new/text';
}

sub confirm_by_text : Path('text') {
    my ( $self, $c ) = @_;

    $c->stash->{submit_url} = '/report/new/text';
    $c->forward('/auth/phone/code', [ 'problem', '/report/new/process_confirmation' ]);
}

sub process_confirmation : Private {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'tokens/confirm_problem.html';
    my $data = $c->stash->{token_data};

    unless ($c->stash->{report}) {
        # Look at all problems, not just cobrand, in case am approving something we don't actually show
        $c->stash->{report} = $c->model('DB::Problem')->find({ id => $data->{id} }) || return;
    }
    my $problem = $c->stash->{report};

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $problem->is_from_abuser ) {
        $problem->update(
            { state => 'hidden', lastupdate => \'current_timestamp' } );
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    # For Zurich, email confirmation simply sets a flag, it does not change the
    # problem state, log in, or anything else
    if ($c->cobrand->moniker eq 'zurich') {
        $problem->set_extra_metadata( email_confirmed => 1 );
        $problem->update( {
            confirmed => \'current_timestamp',
        } );

        if ( $data->{name} || $data->{password} ) {
            $problem->user->name( $data->{name} ) if $data->{name};
            $problem->user->phone( $data->{phone} ) if $data->{phone};
            $problem->user->update;
        }

        return 1;
    }

    if ($problem->state ne 'unconfirmed') {
        my $report_uri = $c->cobrand->base_url_for_report( $problem ) . $problem->url;
        $c->res->redirect($report_uri);
        return;
    }

    # We have an unconfirmed problem
    $problem->confirm;
    $problem->update(
        {
            lastupdate => \'current_timestamp',
        }
    );

    # Subscribe problem reporter to email updates
    $c->forward( '/report/new/create_reporter_alert' );

    # log the problem creation user in to the site
    if ( $data->{name} || $data->{password} ) {
        if (!$problem->user->email_verified) {
            $problem->user->email( $data->{email} ) if $data->{email};
        } elsif (!$problem->user->phone_verified) {
            $problem->user->phone( $data->{phone} ) if $data->{phone};
        }
        $problem->user->password( $data->{password}, 1 ) if $data->{password};
        for (qw(name title facebook_id twitter_id)) {
            $problem->user->$_( $data->{$_} ) if $data->{$_};
        }
        $problem->user->add_oidc_id($data->{oidc_id}) if $data->{oidc_id};
        $problem->user->extra({
            %{ $problem->user->get_extra() },
            %{ $data->{extra} }
        }) if $data->{extra};

        $problem->user->update;

        # Make sure extra oauth state is restored, if applicable
        foreach (qw/logout_redirect_uri change_password_uri/) {
            if ($data->{$_}) {
                $c->session->{oauth} ||= ();
                $c->session->{oauth}{$_} = $data->{$_};
            }
        }
    }
    if ($problem->user->email_verified) {
        $c->authenticate( { email => $problem->user->email, email_verified => 1 }, 'no_password' );
    } elsif ($problem->user->phone_verified) {
        $c->authenticate( { phone => $problem->user->phone, phone_verified => 1 }, 'no_password' );
    } else {
        warn "Reached user authentication with no username verification";
    }
    $c->set_session_cookie_expire(0);

    $c->stash->{created_report} = 'fromemail';
    return 1;
}

=head2 save_user_and_report

Save the user and the report.

Be smart about the user - only set the name and phone if user did not exist
before or they are currently logged in. Otherwise discard any changes.

=cut

sub save_user_and_report : Private {
    my ( $self, $c ) = @_;
    my $report = $c->stash->{report};

    # If there was a photo add that
    if ( my $fileid = $c->stash->{upload_fileid} ) {
        $report->photo($fileid);
    }

    # Set a default if possible
    $report->category( _('Other') ) unless $report->category;

    # Set unknown to DB unknown
    $report->bodies_str( undef ) if $report->bodies_str eq '-1';

    # if there is a Message Manager message ID, pass it back to the client view
    if (($c->get_param('external_source_id') || "") =~ /^\d+$/) {
        $c->stash->{external_source_id} = $c->get_param('external_source_id');
        $report->external_source_id( $c->get_param('external_source_id') );
        $report->external_source( $c->config->{MESSAGE_MANAGER_URL} ) ;
    }

    if ( $report->is_from_abuser ) {
        $c->stash->{template} = 'tokens/abuse.html';
        $c->detach;
    }

    if ( $c->stash->{is_social_user} ) {
        my $token = $c->model("DB::Token")->create( {
            scope => 'problem/social',
            data => { $report->get_inflated_columns },
        } );

        $c->stash->{detach_to} = '/report/new/oauth_callback';
        $c->stash->{detach_args} = [$token->token];

        $c->forward('/auth/social/handle_sign_in') if $c->get_param('social_sign_in');
    }

    # Save or update the user if appropriate
    if ( $c->cobrand->never_confirm_reports ) {
        $report->user->update_or_insert;
        $report->confirm();
    # If created on behalf of someone else, we automatically confirm it,
    # but we don't want to update the user account
    } elsif ($c->stash->{contributing_as_another_user}) {
        $report->set_extra_metadata( contributed_as => 'another_user');
        $report->set_extra_metadata( contributed_by => $c->user->id );
        $report->confirm();
    } elsif ($c->stash->{contributing_as_body}) {
        $report->set_extra_metadata( contributed_as => 'body' );
        $report->confirm();
    } elsif ($c->stash->{contributing_as_anonymous_user}) {
        $report->set_extra_metadata( contributed_as => 'anonymous_user' );
        if ( $c->user_exists && $c->user->from_body ) {
            # If a staff user has clicked the 'report anonymously' button then
            # there would be no record of who that staff member was as we've
            # used the cobrand's anonymous_account for the report. In this case
            # record the staff user ID in the report metadata.
            $report->set_extra_metadata( contributed_by => $c->user->id );
        }
        $report->confirm();
    } elsif ( !$report->user->in_storage ) {
        # User does not exist.
        $c->forward('tokenize_user', [ $report ]);
        $report->user->name( undef );
        if (!$report->user->email_verified) {
            $report->user->email( undef );
        } elsif (!$report->user->phone_verified) {
            $report->user->phone( undef );
        }
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
        $c->forward('tokenize_user', [ $report ]);
        $report->user->discard_changes();
        $c->log->info($report->user->id . ' exists, but is not logged in for this report');
    }

    $c->cobrand->call_hook(report_new_munge_before_insert => $report);

    $report->update_or_insert;

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
    $c->stash->{page} = 'new';
    if ( $c->stash->{report}->used_map ) {
        FixMyStreet::Map::display_map(
            $c,
            latitude  => $latitude,
            longitude => $longitude,
            clickable => 1,
            pins      => [ {
                latitude  => $latitude,
                longitude => $longitude,
                draggable => 1,
                colour    => $c->cobrand->pin_new_report_colour,
            } ],
        );
    }

    return 1;
}

sub check_for_category : Private {
    my ( $self, $c ) = @_;

    my $category = $c->get_param('category') || $c->stash->{report}->category || '';
    $category = '' if $category eq _('Loading...') || $category eq _('-- Pick a category --');
    $c->stash->{category} = $category;

    # Bit of a copy of set_report_extras, because we need the results here, but
    # don't want to run all of that fn until later as it e.g. alters field
    # errors at that point. Also, the report might already have some answers in
    # too if e.g. gone via social login... TODO Improve this?
    my $extra = $c->stash->{report}->get_extra_fields;
    my %current = map { $_->{name} => $_ } @$extra;

    my @contacts = grep { $_->category eq $category } @{$c->stash->{contacts}};
    my @metalist = map { @{$_->get_metadata_for_storage} } @contacts;
    my @extra;
    foreach my $field (@metalist) {
        push @extra, {
            name => $field->{code},
            description => $field->{description},
            value => $c->get_param($field->{code}) || $current{$field->{code}}{value} || '',
        };
    }
    $c->stash->{report}->set_extra_fields( @extra );

    # Work out if the selected category (or category extra question answer) should lead
    # to a message being shown not to use the form
    if ( $c->stash->{category_extras}->{$category} && @{ $c->stash->{category_extras}->{$category} } >= 1 ) {
        my $disable_form_messages = $c->forward('disable_form_message');
        if ($disable_form_messages->{all}) {
            $c->stash->{disable_form_message} = $disable_form_messages->{all};
        } elsif (my $questions = $disable_form_messages->{questions}) {
            foreach my $question (@$questions) {
                my $answer = $c->get_param($question->{code});
                my $message = $question->{message};
                if ($answer) {
                    foreach (@{$question->{answers}}) {
                        if ($answer eq $_) {
                            $c->stash->{disable_form_message} = $message;
                        }
                    }
                }
            }
            if (!$c->stash->{disable_form_message}) {
                $c->stash->{have_disable_qn_to_answer} = 1;
            }
        }
    }

    if ($c->get_param('submit_category_part_only') || $c->stash->{disable_form_message}) {
        # If we've clicked the first-part category button (no-JS only probably),
        # or the category submitted will be showing a disabled form message,
        # we only want to reshow the form
        $c->stash->{force_form_not_submitted} = 1;
    }
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
        if ($c->stash->{contributing_as_another_user} && $report->user->email
            && $report->user->id != $c->user->id
            && !$c->cobrand->report_sent_confirmation_email) {
                $c->send_email( 'other-reported.txt', {
                    to => [ [ $report->user->email, $report->name ] ],
                } );
        }
        # If the user has shortlist permission, and either we're not on a
        # council cobrand or the just-created problem is owned by the cobrand
        # (so we'll stay on-cobrand), redirect to the problem.
        if ($c->user_exists && $c->user->has_body_permission_to('planned_reports') &&
            (!$c->cobrand->is_council || $c->cobrand->owns_problem($report))) {
            $c->log->info($report->user->id . ' is an inspector - redirecting straight to report page for ' . $report->id);
            $c->res->redirect( $report->url );
        } else {
            $c->log->info($report->user->id . ' was logged in, showing confirmation page for ' . $report->id);
            $c->stash->{created_report} = 'loggedin';
            $c->stash->{template} = 'tokens/confirm_problem.html';
        }
        return 1;
    }

    # People using 2FA can not log in by code
    $c->detach( '/page_error_403_access_denied', [] ) if $report->user->has_2fa;

    # otherwise email or text a confirm token to them.
    my $thing = 'email';
    if ($report->user->email_verified) {
        $c->forward( 'send_problem_confirm_email' );
        # tell user that they've been sent an email
        $c->stash->{template}   = 'email_sent.html';
        $c->stash->{email_type} = 'problem';
    } elsif ($report->user->phone_verified) {
        $c->forward( 'send_problem_confirm_text' );
        $thing = 'text';
    } else {
        warn "Reached problem confirmation with no username verification";
    }
    $c->log->info($report->user->id . ' created ' . $report->id . ", $thing sent, " . ($c->stash->{token_data}->{password} ? 'password set' : 'password not set'));
}

sub create_reporter_alert : Private {
    my ( $self, $c ) = @_;

    return if $c->stash->{no_reporter_alert};
    return if $c->cobrand->call_hook('suppress_reporter_alerts');

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
        lat => $c->stash->{latitude},
        lon => $c->stash->{longitude},
    };
    foreach (qw(pc zoom)) {
        $params->{$_} = $c->get_param($_);
    }

    if (my $pc_override = $c->get_param('pc_override')) {
        delete $params->{lat};
        delete $params->{lon};
        $params->{pc} = $pc_override;
    }

    my $csv = Text::CSV->new;
    foreach (qw(status filter_category)) {
        $csv->combine($c->get_param_list($_, 1));
        $params->{$_} = $csv->string;
    }

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

sub generate_category_extra_json : Private {
    my ( $self, $c ) = @_;

    my $true = JSON->true;
    my $false = JSON->false;

    my @fields = map {
        my %data = %$_;

        # Mobile app still looks in datatype_description
        if (($_->{variable} || '') eq 'true' && @{$_->{values} || []}) {
            foreach my $opt (@{$_->{values}}) {
                if ($opt->{disable}) {
                    my $message = $opt->{disable_message} || $_->{datatype_description};
                    $data{datatype_description} = $message;
                }
            }
        }

        # Remove unneeded
        delete $data{$_} for qw(datatype protected variable order disable_form);
        delete $data{datatype_description} unless $data{datatype_description};

        $data{required} = ($_->{required} || '') eq "true" ? $true : $false;
        \%data;
    } @{ $c->stash->{category_extras}->{$c->stash->{category}} };

    return \@fields;
}

__PACKAGE__->meta->make_immutable;

1;
