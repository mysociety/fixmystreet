package FixMyStreet::App::Controller::Report;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Report - display a report

=head1 DESCRIPTION

Show a report

=head1 ACTIONS

=head2 index

Redirect to homepage unless C<id> parameter in query, in which case redirect to
'/report/$id'.

=cut

sub index : Path('') : Args(0) {
    my ( $self, $c ) = @_;

    my $id = $c->req->param('id');

    my $uri =
        $id
      ? $c->uri_for( '/report', $id )
      : $c->uri_for('/');

    $c->res->redirect($uri);
}

=head2 report_display

Display a report.

=cut

sub display : Path('') : Args(1) {
    my ( $self, $c, $id ) = @_;

#     my ($q, $errors, $field_errors) = @_;
#     my @errors = @$errors;
#     my %field_errors = %{$field_errors};
#     my $cobrand = Page::get_cobrand($q);
#     push @errors, _('There were problems with your update. Please see below.') if (scalar keys %field_errors);

#     my @vars = qw(id name rznvy update fixed add_alert upload_fileid submit_update);
#     my %input = map { $_ => $q->param($_) || '' } @vars;
#     my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;
#     my $base = Cobrand::base_url($cobrand);

    if (
        $id =~ m{ ^ 3D (\d+) $ }x         # Some council with bad email software
        || $id =~ m{ ^(\d+) \D .* $ }x    # trailing garbage
      )
    {
        return $c->res->redirect( $c->uri_for($1), 301 );
    }

    $c->forward('load_problem_or_display_error', [ $id ] );

    #     my $extra_data = Cobrand::extra_data($cobrand, $q);
    #     my $google_link = Cobrand::base_url_for_emails($cobrand, $extra_data)
    #         . '/report/' . $problem->{id};
    #     # truncate the lat,lon for nicer rss urls
    #     my ( $short_lat, $short_lon ) =
    #       map { Utils::truncate_coordinate($_) }    #
    #       ( $problem->{latitude}, $problem->{longitude} );

#     my $map_links = '';
#     $map_links = "<p id='sub_map_links'>"
#       . "<a href=\"http://maps.google.co.uk/maps?output=embed&amp;z=16&amp;q="
#       . URI::Escape::uri_escape_utf8( $problem->{title} . ' - ' . $google_link )
#       . "\@$short_lat,$short_lon\">View on Google Maps</a></p>"
#         if mySociety::Config::get('COUNTRY') eq 'GB';

    $c->stash->{banner} = $c->cobrand->generate_problem_banner($c->stash->{problem});

#     my $banner;
#     if ($q->{site} ne 'emptyhomes' && $problem->{state} eq 'confirmed' && $problem->{duration} > 8*7*24*60*60) {
#         $banner = $q->p({id => 'unknown'}, _('This problem is old and of unknown status.'));
#     }
#     if ($problem->{state} eq 'fixed') {
#         $banner = $q->p({id => 'fixed'}, _('This problem has been fixed') . '.');
#     }

#     my $contact_url = Cobrand::url($cobrand, NewURL($q, -retain => 1, pc => undef, x => undef, 'y' => undef, -url=>'/contact?id=' . $input{id}), $q);
#     my $back = Cobrand::url($cobrand, NewURL($q, -url => '/',
#         lat => $short_lat, lon => $short_lon,
#         -retain => 1, pc => undef, x => undef, 'y' => undef, id => undef
#     ), $q);
#     my $fixed = ($input{fixed}) ? ' checked' : '';

    $c->forward( 'format_problem_for_display' );
#     my %vars = (
#         unsuitable => $q->a({rel => 'nofollow', href => $contact_url}, _('Offensive? Unsuitable? Tell us')),
#         more_problems => '<a href="' . $back . '">' . _('More problems nearby') . '</a>',
#         url_home => Cobrand::url($cobrand, '/', $q),
#         alert_link => Cobrand::url($cobrand, NewURL($q, -url => '/alert?type=updates;id='.$input_h{id}, -retain => 1, pc => undef, x => undef, 'y' => undef ), $q),
#         alert_text => _('Email me updates'),
#         email_label => _('Email:'),
#         subscribe => _('Subscribe'),
#         blurb => _('Receive email when updates are left on this problem'),
#         cobrand_form_elements1 => Cobrand::form_elements($cobrand, 'alerts', $q),
#         form_alert_action => Cobrand::url($cobrand, '/alert', $q),
#         rss_url => Cobrand::url($cobrand,  NewURL($q, -retain=>1, -url => '/rss/'.$input_h{id}, pc => undef, x => undef, 'y' => undef, id => undef), $q),
#         rss_title => _('RSS feed'),
#         rss_alt => _('RSS feed of updates to this problem'),
#         update_heading => $q->h2(_('Provide an update')),
#         field_errors => \%field_errors,
#         add_alert_checked => ($input{add_alert} || !$input{submit_update}) ? ' checked' : '',
#         name_label => _('Name:'),
#         update_label => _('Update:'),
#         alert_label => _('Alert me to future updates'),
#         post_label => _('Post'),
#         cobrand_form_elements => Cobrand::form_elements($cobrand, 'updateForm', $q),
#         form_action => Cobrand::url($cobrand, '/', $q),
#         input_h => \%input_h,
#         optional => _('(optional)'),
#     );
#
#     $vars{update_blurb} = $q->p($q->small(_('Please note that updates are not sent to the council. If you leave your name it will be public. Your information will only be used in accordance with our <a href="/faq#privacy">privacy policy</a>')))
#         unless $q->{site} eq 'emptyhomes'; # No council blurb
#
#     if (@errors) {
#         $vars{errors} = '<ul class="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
#     }
#
#     my $allow_photo_upload = Cobrand::allow_photo_upload($cobrand);
#     if ($allow_photo_upload) {
#         my $photo_label = _('Photo:');
#         $vars{enctype} = ' enctype="multipart/form-data"';
#         $vars{photo_element} = <<EOF;
# <div id="fileupload_normalUI">
# <label for="form_photo">$photo_label</label>
# <input type="file" name="photo" id="form_photo">
# </div>
# EOF
#     }
#
#     my %params = (
#         rss => [ _('Updates to this problem, FixMyStreet'), "/rss/$input_h{id}" ],
#         robots => 'index, nofollow',
#         js => FixMyStreet::Map::header_js(),
#         title => $problem->{title}
#     );
#
#     my $page = Page::template_include('problem', $q, Page::template_root($q), %vars);
#     return ($page, %params);

}

sub load_problem_or_display_error : Private {
    my ( $self, $c, $id ) = @_;

    # try to load a report if the id is a number
    my $problem    #
      = $id =~ m{\D}    # is id non-numeric?
      ? undef           # ...don't even search
      : $c->model('DB::Problem')->find(
        { id => $id },
        {
            select => [
                'id',
                'latitude',
                'longitude',
                'council',
                'category',
                'title', 'detail', 'photo',
                'used_map',
                'name',
                'anonymous',
                'state',
                'service',
                'cobrand',
                'cobrand_data',
                'external_body',
                {
                    extract => 'epoch from confirmed',
                    -as     => 'time',
                },
                {
                    extract => 'epoch from whensent-confirmed',
                    -as     => 'whensent'
                },
                {
                    extract => 'epoch from ms_current_timestamp()-lastupdate',
                    -as     => 'duration'
                }

            ]
        }
      );

    # check that the problem is suitable to show.
    if ( !$problem || $problem->state eq 'unconfirmed' ) {
        $c->detach( '/page_error_404_not_found', [ _('Unknown problem ID') ] );
    }
    elsif ( $problem->state eq 'hidden' ) {
        $c->detach(
            '/page_error_410_gone',
            [ _('That report has been removed from FixMyStreet.') ]    #
        );
    }

    $c->stash->{problem} = $problem;

    return 1;
}

sub format_problem_for_display : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    ( my $detail = $problem->detail ) =~ s/\r//g;
    my @detail = split /\n{2,}/, $detail;
    $c->stash->{detail} = \@detail;

    $c->forward('generate_map_tags');
    $c->forward('generate_problem_photo');
    $c->forward('generate_problem_meta');

    return 1;
}

sub generate_map_tags : Private {
    my ( $self, $c ) = @_;

    my $map_links = '';
    my $problem   = $c->stash->{problem};

    $c->stash->{map_start_html} = FixMyStreet::Map::display_map(
        $c->fake_q,
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        type      => 0,
        pins      => $problem->used_map
        ? [ [ $problem->latitude, $problem->longitude, 'blue' ] ]
        : [],
        post => $map_links
    );
    $c->stash->{map_end_html} = FixMyStreet::Map::display_map_end(0),

      return 1;
}

sub generate_problem_photo : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    if ( $c->cobrand->allow_photo_display and $problem->photo ) {
        my $photo = {};
        ( $photo->{width}, $photo->{height} ) =
          Image::Size::imgsize( \$problem->photo );
        $photo->{url} = '/photo/?id=' . $problem->id;
        $c->stash->{photo} = $photo;
    }
}

sub generate_problem_meta : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};
    my $date_time =
      Page::prettify_epoch( $c->req, $problem->get_column('time') );
    my $meta = '';
    if ( $problem->anonymous ) {
        if (    $problem->service
            and $problem->category && $problem->category ne _('Other') )
        {
            $meta =
              sprintf( _('Reported by %s in the %s category anonymously at %s'),
                $problem->service, $problem->category, $date_time );
        }
        elsif ( $problem->service ) {
            $meta = sprintf( _('Reported by %s anonymously at %s'),
                $problem->service, $date_time );
        }
        elsif ( $problem->category and $problem->category ne _('Other') ) {
            $meta = sprintf( _('Reported in the %s category anonymously at %s'),
                $problem->category, $date_time );
        }
        else {
            $meta = sprintf( _('Reported anonymously at %s'), $date_time );
        }
    }
    else {
        if (    $problem->service
            and $problem->category && $problem->category ne _('Other') )
        {
            $meta = sprintf(
                _('Reported by %s in the %s category by %s at %s'),
                $problem->service, $problem->category,
                $problem->name,    $date_time
            );
        }
        elsif ( $problem->service ) {
            $meta = sprintf( _('Reported by %s by %s at %s'),
                $problem->service, $problem->name, $date_time );
        }
        elsif ( $problem->category and $problem->category ne _('Other') ) {
            $meta = sprintf( _('Reported in the %s category by %s at %s'),
                $problem->category, $problem->name, $date_time );
        }
        else {
            $meta =
              sprintf( _('Reported by %s at %s'), $problem->name, $date_time );
        }
    }

    $c->stash->{meta} = $meta;

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
