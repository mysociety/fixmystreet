package FixMyStreet::App::Controller::Alert;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use mySociety::EmailUtil qw(is_valid_email);

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


#    my $q = shift;
#    my $cobrand = Page::get_cobrand($q);
#    my $error = shift;
#    my $errors = '';
#    $errors = '<ul class="error"><li>' . $error . '</li></ul>' if $error;
#
#    my $form_action = Cobrand::url(Page::get_cobrand($q), '/alert', $q);
#    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'alerts', $q);
#    my $cobrand_extra_data = Cobrand::extra_data($cobrand, $q);
#
#    $out .= $errors . qq(<form method="get" action="$form_action">);
#    $out .= $q->p($pc_label, '<input type="text" name="pc" value="' . $input_h{pc} . '">
#<input type="submit" value="' . $submit_text . '">');
#    $out .= $cobrand_form_elements;
#
#    my %vars = (error => $error,
#                header => $header,
#                intro => $intro,
#                pc_label => $pc_label,
#                form_action => $form_action,
#                input_h => \%input_h,
#                submit_text => $submit_text,
#                cobrand_form_elements => $cobrand_form_elements,
#                cobrand_extra_data => $cobrand_extra_data,
#                url_home => Cobrand::url($cobrand, '/', $q));
#
#    my $cobrand_page = Page::template_include('alert-front-page', $q, Page::template_root($q), %vars);
#    $out = $cobrand_page if ($cobrand_page);
#
#    return $out if $q->referer() && $q->referer() =~ /fixmystreet\.com/;
#    my $recent_photos = Cobrand::recent_photos($cobrand, 10);
#    $out .= '<div id="alert_recent">' . $q->h2(_('Some photos of recent reports')) . $recent_photos . '</div>' if $recent_photos;
#
#    return $out;
}

sub list : Path('list') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{rznvy} = $c->req->param('rznvy');
    $c->stash->{selected_feed} = $c->req->param('feed');

 #    my ($q, @errors) = @_;
 #    my @vars = qw(pc rznvy lat lon);
 #    my %input = map { $_ => scalar $q->param($_) } @vars;
 #    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
 #
 # Try to create a location for whatever we have
    unless ( $c->forward('/location/determine_location_from_coords')
        || $c->forward('/location/determine_location_from_pc') )
    {

        if ( $c->stash->{possible_location_matches} ) {
            $c->stash->{choose_target_uri} = $c->uri_for('/alert/list');
            $c->detach('choose');
        }

        $c->go('index') if $c->stash->{location_error};
    }

    $c->log->debug($_)
      for ( $c->stash->{pc}, $c->stash->{latitude}, $c->stash->{longitude} );

    $c->forward('prettify_pc');

    # truncate the lat,lon for nicer urls
    ( $c->stash->{latitude}, $c->stash->{longitude} ) =
      map { Utils::truncate_coordinate($_) }
      ( $c->stash->{latitude}, $c->stash->{longitude} );
    $c->log->debug($_)
      for ( $c->stash->{pc}, $c->stash->{latitude}, $c->stash->{longitude} );

#
#    my $errors = '';
#    $errors = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>' if @errors;
#
    $c->stash->{council_check_action} = 'alert';
    unless ( $c->forward('/council/load_and_check_councils_and_wards') ) {
        $c->go('index');
    }

    ( $c->stash->{options}, $c->stash->{reported_to_options} ) =
      $c->cobrand->council_rss_alert_options( $c->stash->{all_councils} );

    my $dist =
      mySociety::Gaze::get_radius_containing_population( $c->stash->{latitude},
        $c->stash->{longitude}, 200000 );
    $dist                          = int( $dist * 10 + 0.5 );
    $dist                          = $dist / 10.0;
    $c->stash->{population_radius} = $dist;

#
#    my $checked = '';
#    $checked = ' checked' if $q->param('feed') && $q->param('feed') eq "local:$lat:$lon";
#    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'alerts', $q);
#    my $pics = Cobrand::recent_photos($cobrand, 5, $lat, $lon, $dist);
#    $pics = '<div id="alert_photos">' . $q->h2(_('Photos of recent nearby reports')) . $pics . '</div>' if $pics;

    #    my $form_action = Cobrand::url($cobrand, '/alert', $q);
    #$cobrand_form_elements
    #$pics
    #
    #EOF
    #    $out .= $errors;
    #    $out .= <<EOF;
    $c->stash->{rss_feed_id} =
      sprintf( 'local:%s:%s', $c->stash->{latitude}, $c->stash->{longitude} );

    my $rss_feed;
    if ( $c->stash->{pretty_pc_text} ) {
        $rss_feed =
          $c->cobrand->uri( "/rss/pc/" . $c->stash->{pretty_pc_text},
            $c->fake_q );
    }
    else {
        $rss_feed = $c->cobrand->uri(
            sprintf( "/rss/l/%s,%s",
                $c->stash->{latitude},
                $c->stash->{longitude} ),
            $c->fake_q
        );
    }

    $c->stash->{rss_feed_uri} = $rss_feed;

#    my $default_link = Cobrand::url($cobrand, "/alert?type=local;feed=local:$lat:$lon", $q);

    $c->stash->{rss_feed_2k} = $c->cobrand->uri( $rss_feed . '/2', $c->fake_q );
    $c->stash->{rss_feed_5k} = $c->cobrand->uri( $rss_feed . '/5', $c->fake_q );
    $c->stash->{rss_feed_10k} =
      $c->cobrand->uri( $rss_feed . '/10', $c->fake_q );
    $c->stash->{rss_feed_20k} =
      $c->cobrand->uri( $rss_feed . '/20', $c->fake_q );
}

=head2 subscribe

Target for subscribe form

=cut

sub subscribe : Path('subscribe') : Args(0) {
    my ( $self, $c ) = @_;

    if ( $c->req->param( 'rss' ) ) {
        $c->detach( 'rss' );
    } elsif ( $c->req->param( 'rznvy' ) ) {
        $c->detach( 'subscribe_email' );
    }
}

=head2 rss

Redirects to relevant RSS feed

=cut

sub rss : Private {
    my ( $self, $c ) = @_;
    my $feed = $c->req->params->{feed};

    unless ($feed) {
        $c->stash->{errors} = [ _('Please select the feed you want') ];
        $c->go('list');
    }

    my $extra_params = $c->cobrand->extra_params( $c->fake_q );
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
        ( my $id = $1 ) =~ tr{:_}{/+};
        $url = $c->cobrand->base_url() . '/rss/l/' . $id;
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

    my $type = $c->req->param('type');
    $c->stash->{email_type} = 'alert';

    my @errors;
    push @errors, _('Please enter a valid email address') unless is_valid_email($c->req->param('rznvy'));
    push @errors, _('Please select the type of alert you want') if $type && $type eq 'local' && !$c->req->param('feed');
    if (@errors) {
        $c->stash->{errors} = \@errors;
        $c->go('list');
#        return alert_updates_form($q, @errors) if $type && $type eq 'updates';
#        return alert_list($q, @errors) if $type && $type eq 'local';
#        return alert_front_page($q, @errors);
    }

    my $alert_id;
    my $email = $c->req->param('rznvy');
#    my $cobrand = Page::get_cobrand($q);
#    my $cobrand_data = Cobrand::extra_alert_data($cobrand, $q);
    if ($type eq 'updates') {
#        my $id = $q->param('id');
#        $alert_id = FixMyStreet::Alert::create($email, 'new_updates', $cobrand, $cobrand_data, $id);
    } elsif ($type eq 'problems') {
#        $alert_id = FixMyStreet::Alert::create($email, 'new_problems', $cobrand, $cobrand_data);
    } elsif ($type eq 'local') {
        my $feed = $c->req->param('feed');

        my ( $type, @params );
        if ($feed =~ /^area:(?:\d+:)?(\d+)/) {
            $type = 'area_problems';
            push @params, $1;
        } elsif ($feed =~ /^council:(\d+)/) {
            $type = 'council_problems';
            push @params, $1, $1;
        } elsif ($feed =~ /^ward:(\d+):(\d+)/) {
            $type = 'ward_problems';
            push @params, $1, $2;
        } elsif ($feed =~ m{ \A local: ( [\+\-]? \d+ \.? \d* ) : ( [\+\-]? \d+ \.? \d* ) }xms ) {
            $type = 'local_problems';
            push @params, $1, $2;
#            my $lat = $1;
#            my $lon = $2;
#            $alert_id = FixMyStreet::Alert::create($email, 'local_problems', $cobrand, $cobrand_data, $lon, $lat);
        }

        my $options = {
            email => $email,
            alert_type  => $type
        };

        if ( scalar @params == 1 ) {
            $options->{parameter} = $params[0];
        } elsif ( scalar @params == 2 ) {
            $options->{parameter} = $params[0];
            $options->{parameter2} = $params[1];
        }

        my $alert = $c->model('DB::Alert')->find(
            $options
        );

        unless ( $alert ) {
            $options->{cobrand} = $c->cobrand->moniker();
            $options->{cobrand_data} = $c->cobrand->extra_update_data();

            $alert = $c->model('DB::Alert')->new( $options );
            $alert->insert();
        }

        $c->log->debug( 'created alert ' . $alert->id );
        $c->stash->{template} = 'email_sent.html';
    } else {
        throw FixMyStreet::Alert::Error('Invalid type');
    }
#
#    my %h = ();
#    $h{url} = Page::base_url_with_lang($q, undef, 1) . '/A/'
#        . mySociety::AuthToken::store('alert', { id => $alert_id, type => 'subscribe', email => $email } );
#    dbh()->commit();
#    return Page::send_confirmation_email($q, $email, undef, 'alert', %h);
}

=head2 prettify_pc

This will canonicalise and prettify the postcode and stick a pretty_pc and pretty_pc_text in the stash.

=cut

sub prettify_pc : Private {
    my ( $self, $c ) = @_;

# FIXME previously this had been run through ent so need to do similar here or in template
    my $pretty_pc = $c->req->params->{'pc'};

    #    my $pretty_pc = $input_h{pc};
    #    my $pretty_pc_text;# This one isnt't getting the nbsp.
    if ( mySociety::PostcodeUtil::is_valid_postcode( $c->req->params->{'pc'} ) )
    {
        $pretty_pc = mySociety::PostcodeUtil::canonicalise_postcode(
            $c->req->params->{'pc'} );
        my $pretty_pc_text = $pretty_pc;
        $pretty_pc_text =~ s/ //g;
        $c->stash->{pretty_pc_text} = $pretty_pc_text;

        # this may be better done in template
        $pretty_pc =~ s/ /&nbsp;/;
    }

    $c->stash->{pretty_pc} = $pretty_pc;
}

sub council_options : Private {
    my ( $self, $c ) = @_;

    if ( $c->config->{COUNTRY} eq 'NO' ) {

#    my ($options, $options_start, $options_end);
#    if (mySociety::Config::get('COUNTRY') eq 'NO') {
#
#        my (@options, $fylke, $kommune);
#        foreach (values %$areas) {
#            if ($_->{type} eq 'NKO') {
#                $kommune = $_;
#            } else {
#                $fylke = $_;
#            }
#        }
#        my $kommune_name = $kommune->{name};
#        my $fylke_name = $fylke->{name};
#
#        if ($fylke->{id} == 3) { # Oslo
#
#            push @options, [ 'council', $fylke->{id}, Page::short_name($fylke),
#                sprintf(_("Problems within %s"), $fylke_name) ];
#
#            $options_start = "<div><ul id='rss_feed'>";
#            $options = alert_list_options($q, @options);
#            $options_end = "</ul>";
#
#        } else {
#
#            push @options,
#                [ 'area', $kommune->{id}, Page::short_name($kommune), $kommune_name ],
#                [ 'area', $fylke->{id}, Page::short_name($fylke), $fylke_name ];
#            $options_start = '<div id="rss_list">';
#            $options = $q->p($q->strong(_('Problems within the boundary of:'))) .
#                $q->ul(alert_list_options($q, @options));
#            @options = ();
#            push @options,
#                [ 'council', $kommune->{id}, Page::short_name($kommune), $kommune_name ],
#                [ 'council', $fylke->{id}, Page::short_name($fylke), $fylke_name ];
#            $options .= $q->p($q->strong(_('Or problems reported to:'))) .
#                $q->ul(alert_list_options($q, @options));
#            $options_end = $q->p($q->small(_('FixMyStreet sends different categories of problem
#to the appropriate council, so problems within the boundary of a particular council
#might not match the problems sent to that council. For example, a graffiti report
#will be sent to the district council, so will appear in both of the district
#council&rsquo;s alerts, but will only appear in the "Within the boundary" alert
#for the county council.'))) . '</div><div id="rss_buttons">';
#
#        }
#
    }
}

sub choose : Private {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'alert/choose.html';
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
