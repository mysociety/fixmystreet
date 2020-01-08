package FixMyStreet::App::Controller::Alert;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use mySociety::EmailUtil qw(is_valid_email);
use FixMyStreet::Gaze;

=head1 NAME

FixMyStreet::App::Controller::Alert - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 alert

Show the alerts page

=cut

sub index : Path('') : Args(0) {
    my ( $self, $c ) = @_;

    unless ( $c->req->referer && $c->req->referer =~ /fixmystreet\.com/ ) {
        $c->forward( 'add_recent_photos', [10] );
    }
}

sub list : Path('list') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');

    return
      unless $c->forward('setup_request')
          && $c->forward('prettify_pc')
          && $c->forward('determine_location')
          && $c->forward( 'add_recent_photos', [5] )
          && $c->forward('setup_council_rss_feeds')
          && $c->forward('setup_coordinate_rss_feeds');
}

=head2 subscribe

Target for subscribe form

=cut

sub subscribe : Path('subscribe') : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach('rss') if $c->get_param('rss');

    my $id = $c->get_param('id');
    $c->forward('/report/load_problem_or_display_error', [ $id ]) if $id;

    # if it exists then it's been submitted so we should
    # go to subscribe email and let it work out the next step
    $c->detach('subscribe_email')
        if $c->get_param('rznvy') || $c->get_param('alert');

    $c->go('updates') if $id;

    # shouldn't get to here but if we have then do something sensible
    $c->go('index');
}

=head2 rss

Redirects to relevant RSS feed

=cut

sub rss : Private {
    my ( $self, $c ) = @_;
    my $feed = $c->get_param('feed');

    unless ($feed) {
        $c->stash->{errors} = [ _('Please select the feed you want') ];
        $c->go('list');
    }

    my $url;
    if ( $feed =~ /^area:(?:\d+:)+(.*)$/ ) {
        ( my $id = $1 ) =~ tr{:_}{/+};
        $url = $c->cobrand->base_url() . '/rss/area/' . $id;
        $c->res->redirect($url);
    }
    elsif ( $feed =~ /^(?:council|ward):(?:\d+:)+(.*)$/ ) {
        ( my $id = $1 ) =~ tr{:_}{/+};
        $url = $c->cobrand->base_url() . '/rss/reports/' . $id;
        $c->res->redirect($url);
    }
    elsif ( $feed =~ /^local:([\d\.-]+):([\d\.-]+)$/ ) {
        $url = $c->cobrand->base_url() . '/rss/l/' . $1 . ',' . $2;
        $c->res->redirect($url);
    }
    else {
        $c->stash->{errors} = [ _('Illegal feed selection') ];
        $c->go('list');
    }
}

=head2 subscribe_email

Sign up to email alerts

=cut

sub subscribe_email : Private {
    my ( $self, $c ) = @_;

    $c->forward('/auth/check_csrf_token');

    $c->stash->{errors} = [];
    $c->forward('process_user');

    my $type = $c->get_param('type') || "";
    if ( $type eq 'updates' ) {
        $c->forward('set_update_alert_options');
    } elsif ( $type eq 'local' ) {
        $c->forward('set_local_alert_options');
    } else {
        $c->detach( '/page_error_404_not_found', [ 'Invalid type' ] );
    }

    push @{ $c->stash->{errors} }, _('Please select the type of alert you want')
      if !$c->stash->{alert_options};

    $c->go($type eq 'updates' ? 'updates' : 'list') if @{ $c->stash->{errors} };

    $c->forward('create_alert');
    if ( $c->stash->{alert}->confirmed ) {
        $c->stash->{confirm_type} = 'created';
        $c->stash->{template} = 'tokens/confirm_alert.html';
    } else {
        $c->forward('send_confirmation_email');
    }
}

sub updates : Path('updates') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('/auth/get_csrf_token');

    $c->stash->{email} = $c->get_param('rznvy');
    $c->stash->{email} ||= $c->user->email if $c->user_exists;
}

=head2 confirm

Confirm signup to or unsubscription from an alert. Forwarded here from Tokens.

=cut

sub confirm : Private {
    my ( $self, $c ) = @_;

    my $alert = $c->stash->{alert};

    if ( $c->stash->{confirm_type} eq 'subscribe' ) {
        $alert->confirm();
    }
    elsif ( $c->stash->{confirm_type} eq 'unsubscribe' ) {
        $alert->disable();
    }
}

=head2 create_alert

Take the alert options from the stash and use these to create a new
alert. If it finds an existing alert that's the same then use that

=cut 

sub create_alert : Private {
    my ( $self, $c ) = @_;

    my $options = $c->stash->{alert_options};

    my $alert = $c->model('DB::Alert')->find($options);

    unless ($alert) {
        $options->{cobrand}      = $c->cobrand->moniker();
        $options->{cobrand_data} = '';
        $options->{lang}         = $c->stash->{lang_code};

        $alert = $c->model('DB::Alert')->new($options);
        $alert->insert();
    }

    if ( $c->user_exists && ($c->user->id == $alert->user->id || $c->stash->{can_create_for_another})) {
        $alert->confirm();
    } else {
        $alert->confirmed(0);
    }

    $c->stash->{alert} = $alert;
}

=head2 set_update_alert_options

Set up the options in the stash required to create a problem update alert

=cut

sub set_update_alert_options : Private {
    my ( $self, $c ) = @_;

    my $options = {
        user       => $c->stash->{alert_user},
        alert_type => 'new_updates',
        parameter  => $c->stash->{problem}->id,
    };

    $c->stash->{alert_options} = $options;
}

=head2 set_local_alert_options

Set up the options in the stash required to create a local problems alert

=cut

sub set_local_alert_options : Private {
    my ( $self, $c ) = @_;

    my $feed = $c->get_param('feed');

    my ( $type, @params, $alert );
    if ( $feed =~ /^area:(?:\d+:)?(\d+)/ ) {
        $type = 'area_problems';
        push @params, $1;
    }
    elsif ( $feed =~ /^council:(\d+)/ ) {
        $type = 'council_problems';
        push @params, $1, $1;
    }
    elsif ( $feed =~ /^ward:(\d+):(\d+)/ ) {
        $type = 'ward_problems';
        push @params, $1, $2;
    }
    elsif ( $feed =~
        m{ \A local: ( [\+\-]? \d+ \.? \d* ) : ( [\+\-]? \d+ \.? \d* ) }xms )
    {
        $type = 'local_problems';
        push @params, $2, $1; # Note alert parameters are lon,lat
    }
    return unless $type;

    my $options = {
        user       => $c->stash->{alert_user},
        alert_type => $type
    };

    if ( scalar @params == 1 ) {
        $options->{parameter} = $params[0];
    }
    elsif ( scalar @params == 2 ) {
        $options->{parameter}  = $params[0];
        $options->{parameter2} = $params[1];
    }

    $c->stash->{alert_options} = $options;
}

=head2 send_confirmation_email

Generate a token and send out an alert subscription confirmation email and
then display confirmation page.

=cut

sub send_confirmation_email : Private {
    my ( $self, $c ) = @_;

    my $user = $c->stash->{alert}->user;

    # People using 2FA can not log in by code
    $c->detach( '/page_error_403_access_denied', [] ) if $user->has_2fa;

    my $token = $c->model("DB::Token")->create(
        {
            scope => 'alert',
            data  => {
                id    => $c->stash->{alert}->id,
                type  => 'subscribe',
                email => $user->email
            }
        }
    );

    $c->stash->{token_url} = $c->uri_for_email( '/A', $token->token );

    $c->send_email( 'alert-confirm.txt', { to => $user->email } );

    $c->stash->{email_type} = 'alert';
    $c->stash->{template} = 'email_sent.html';
}

=head2 prettify_pc

This will canonicalise and prettify the postcode and stick a pretty_pc and pretty_pc_text in the stash.

=cut

sub prettify_pc : Private {
    my ( $self, $c ) = @_;

    my $pretty_pc = $c->get_param('pc');

    if ( mySociety::PostcodeUtil::is_valid_postcode( $c->get_param('pc') ) )
    {
        $pretty_pc = mySociety::PostcodeUtil::canonicalise_postcode(
            $c->get_param('pc') );
        my $pretty_pc_text = $pretty_pc;
        $pretty_pc_text =~ s/ //g;
        $c->stash->{pretty_pc_text} = $pretty_pc_text;
    }

    $c->stash->{pretty_pc} = $pretty_pc;

    return 1;
}

=head2 process_user

Fetch/check email address

=cut

sub process_user : Private {
    my ( $self, $c ) = @_;

    if ( $c->user_exists ) {
        $c->stash->{can_create_for_another} = $c->stash->{problem}
            && $c->user->has_permission_to(contribute_as_another_user => $c->stash->{problem}->bodies_str_ids);
        if (!$c->stash->{can_create_for_another}) {
            $c->stash->{alert_user} = $c->user->obj;
            return;
        }
    }

    my $email = $c->get_param('rznvy');
    $email = $email ? lc $email : '';
    $email =~ s{\s+}{}g;

    push @{ $c->stash->{errors} }, _('Please enter a valid email address')
      unless is_valid_email( $email );

    my $alert_user = $c->model('DB::User')->find_or_new( { email => $email } );
    $c->stash->{alert_user} = $alert_user;
}

=head2 setup_coordinate_rss_feeds

Takes the latitide and longitude from the stash and uses them to generate uris
for the local rss feeds

=cut 

sub setup_coordinate_rss_feeds : Private {
    my ( $self, $c ) = @_;

    $c->stash->{rss_feed_id} =
      sprintf( 'local:%s:%s', $c->stash->{latitude}, $c->stash->{longitude} );

    my $rss_feed;
    if ( $c->stash->{pretty_pc_text} ) {
        $rss_feed = $c->uri_for( "/rss/pc/" . $c->stash->{pretty_pc_text} );
    }
    else {
        $rss_feed = $c->uri_for(
            sprintf( "/rss/l/%s,%s",
                $c->stash->{latitude},
                $c->stash->{longitude} )
        );
    }

    $c->stash->{rss_feed_uri} = $rss_feed;

    $c->stash->{rss_feed_2k}  = $rss_feed . '/2';
    $c->stash->{rss_feed_5k}  = $rss_feed . '/5';
    $c->stash->{rss_feed_10k} = $rss_feed . '/10';
    $c->stash->{rss_feed_20k} = $rss_feed . '/20';

    return 1;
}

=head2 setup_council_rss_feeds

Generate the details required to display the council/ward/area RSS feeds

=cut

sub setup_council_rss_feeds : Private {
    my ( $self, $c ) = @_;

    $c->stash->{area_check_action} = 'alert';
    unless ( $c->forward('/council/load_and_check_areas_and_wards') ) {
        $c->go('index');
    }

    ( $c->stash->{options}, $c->stash->{reported_to_options} ) =
      $c->cobrand->council_rss_alert_options( $c->stash->{all_areas}, $c );

    return 1;
}

=head2 determine_location

Do all the things we need to do to work out where the alert is for
and to setup the location related things for later

=cut

sub determine_location : Private {
    my ( $self, $c ) = @_;

    # Try to create a location for whatever we have
    unless ( $c->forward('/location/determine_location_from_coords')
        || $c->forward('/location/determine_location_from_pc') )
    {

        if ( $c->stash->{possible_location_matches} ) {
            $c->stash->{choose_target_uri} = $c->uri_for('/alert/list');
            $c->detach('choose');
        }

        $c->go('index');
    }

    my $dist = FixMyStreet::Gaze::get_radius_containing_population($c->stash->{latitude}, $c->stash->{longitude});
    $c->stash->{population_radius} = $dist;

    return 1;
}

=head2 add_recent_photos

    $c->forward( 'add_recent_photos', [ $num_photos ] );

Adds the most recent $num_photos to the template. If there is coordinate 
and population radius information in the stash uses that to limit it.

=cut

sub add_recent_photos : Private {
    my ( $self, $c, $num_photos ) = @_;

    if (    $c->stash->{latitude}
        and $c->stash->{longitude}
        and $c->stash->{population_radius} )
    {

        $c->stash->{photos} = $c->cobrand->recent_photos(
            'alert',
            $num_photos,
            $c->stash->{latitude},
            $c->stash->{longitude},
            $c->stash->{population_radius}
        );
    }
    else {
        $c->stash->{photos} = $c->cobrand->recent_photos('alert', $num_photos);
    }

    return 1;
}

sub choose : Private {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'alert/choose.html';
}


=head2 setup_request

Setup the variables we need for the rest of the request

=cut

sub setup_request : Private {
    my ( $self, $c ) = @_;

    $c->stash->{rznvy} = $c->get_param('rznvy');
    $c->stash->{selected_feed} = $c->get_param('feed');

    if ( $c->user ) {
        $c->stash->{rznvy} ||= $c->user->email;
    }

    $c->stash->{template} = 'alert/list-ajax.html' if $c->get_param('ajax');

    return 1;
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
