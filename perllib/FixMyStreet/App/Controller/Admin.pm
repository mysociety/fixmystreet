package FixMyStreet::App::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use POSIX qw(strcoll);
use List::Util 'first';
use FixMyStreet::SMS;

=head1 NAME

FixMyStreet::App::Controller::Admin- Catalyst Controller

=head1 DESCRIPTION

Admin pages

=head1 METHODS

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    $c->uri_disposition('relative');

    # User must be logged in to see cobrand, and meet whatever checks the
    # cobrand specifies. Default cobrand just requires superuser flag to be set.
    unless ( $c->user_exists ) {
        $c->detach( '/auth/redirect' );
    }
    unless ( $c->cobrand->admin_allow_user($c->user) ) {
        $c->detach('/page_error_403_access_denied', []);
    }

    if ( $c->cobrand->moniker eq 'zurich' ) {
        $c->cobrand->admin_type();
    }

    $c->forward('check_page_allowed');
}

=head2 summary

Redirect to index page. There to make the allowed pages stuff neater

=cut

sub summary : Path( 'summary' ) : Args(0) {
    my ( $self, $c ) = @_;
    $c->go( 'index' );
}

=head2 index

Displays some summary information for the requests.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if ($c->cobrand->moniker eq 'zurich') {
        if ($c->stash->{admin_type} eq 'super') {
            $c->forward('/admin/stats/gather');
            return 1;
        } else {
            return $c->cobrand->admin();
        }
    }

    my @unsent = $c->cobrand->problems->search( {
        state => [ FixMyStreet::DB::Result::Problem::open_states() ],
        whensent => undef,
        bodies_str => { '!=', undef },
        # Ignore very recent ones that probably just haven't been sent yet
        confirmed => { '<', \"current_timestamp - '5 minutes'::interval" },
    },
    {
        order_by => 'confirmed',
    } )->all;
    $c->stash->{unsent_reports} = \@unsent;

    $c->forward('fetch_all_bodies');

    return 1;
}

sub config_page : Path( 'config' ) : Args(0) {
    my ($self, $c) = @_;
    my $dir = FixMyStreet->path_to();
    my $git_version = `cd $dir && git describe --tags`;
    chomp $git_version;
    $c->stash(
        git_version => $git_version,
    );
}

sub timeline : Path( 'timeline' ) : Args(0) {
    my ($self, $c) = @_;

    my %time;

    my $probs = $c->cobrand->problems->timeline;

    foreach ($probs->all) {
        push @{$time{$_->created->epoch}}, { type => 'problemCreated', date => $_->created, obj => $_ };
        push @{$time{$_->confirmed->epoch}}, { type => 'problemConfirmed', date => $_->confirmed, obj => $_ } if $_->confirmed;
        push @{$time{$_->whensent->epoch}}, { type => 'problemSent', date => $_->whensent, obj => $_ } if $_->whensent;
    }

    my $questionnaires = $c->model('DB::Questionnaire')->timeline( $c->cobrand->restriction );

    foreach ($questionnaires->all) {
        push @{$time{$_->whensent->epoch}}, { type => 'quesSent', date => $_->whensent, obj => $_ };
        push @{$time{$_->whenanswered->epoch}}, { type => 'quesAnswered', date => $_->whenanswered, obj => $_ } if $_->whenanswered;
    }

    my $updates = $c->cobrand->updates->timeline;

    foreach ($updates->all) {
        push @{$time{$_->created->epoch}}, { type => 'update', date => $_->created, obj => $_} ;
    }

    my $alerts = $c->model('DB::Alert')->timeline_created( $c->cobrand->restriction );

    foreach ($alerts->all) {
        push @{$time{$_->whensubscribed->epoch}}, { type => 'alertSub', date => $_->whensubscribed, obj => $_ };
    }

    $alerts = $c->model('DB::Alert')->timeline_disabled( $c->cobrand->restriction );

    foreach ($alerts->all) {
        push @{$time{$_->whendisabled->epoch}}, { type => 'alertDel', date => $_->whendisabled, obj => $_ };
    }

    $c->stash->{time} = \%time;

    return 1;
}

sub fetch_contacts : Private {
    my ( $self, $c ) = @_;

    my $contacts = $c->stash->{body}->contacts->search(undef, { order_by => [ 'category' ] } );
    $c->stash->{contacts} = $contacts;
    $c->stash->{live_contacts} = $contacts->not_deleted_admin;
    $c->stash->{any_not_confirmed} = $contacts->search({ state => 'unconfirmed' })->count;

    if ( $c->get_param('text') && $c->get_param('text') eq '1' ) {
        $c->stash->{template} = 'admin/council_contacts.txt';
        $c->res->content_type('text/plain; charset=utf-8');
        return 1;
    }

    return 1;
}

sub fetch_languages : Private {
    my ( $self, $c ) = @_;

    my $lang_map = {};
    foreach my $lang (@{$c->cobrand->languages}) {
        my ($id, $name, $code) = split(',', $lang);
        $lang_map->{$id} = { name => $name, code => $code };
    }

    $c->stash->{languages} = $lang_map;

    return 1;
}

sub update_user : Private {
    my ($self, $c, $object) = @_;
    my $parsed = FixMyStreet::SMS->parse_username($c->get_param('username'));
    if ($parsed->{email} || ($parsed->{phone} && $parsed->{may_be_mobile})) {
        my $user = $c->model('DB::User')->find_or_create({ $parsed->{type} => $parsed->{username} });
        if ($user->id && $user->id != $object->user->id) {
            $object->user( $user );
            return 1;
        }
    }
    return 0;
}

sub update_edit : Path('update_edit') : Args(1) {
    my ( $self, $c, $id ) = @_;

    my $update = $c->cobrand->updates->search({ 'me.id' => $id })->first;

    $c->detach( '/page_error_404_not_found', [] )
      unless $update;

    $c->forward('/auth/get_csrf_token');

    $c->stash->{update} = $update;

    if (my $rotate_photo_param = $c->forward('_get_rotate_photo_param')) {
        $c->forward('rotate_photo', [ $update, @$rotate_photo_param ]);
        return 1;
    }

    $c->forward('check_username_for_abuse', [ $update->user ] );

    if ( $c->get_param('banuser') ) {
        $c->forward('users/ban');
    }
    elsif ( $c->get_param('flaguser') ) {
        $c->forward('users/flag');
        $c->stash->{update}->discard_changes;
    }
    elsif ( $c->get_param('removeuserflag') ) {
        $c->forward('users/flag_remove');
        $c->stash->{update}->discard_changes;
    }
    elsif ( $c->get_param('submit') ) {
        $c->forward('/auth/check_csrf_token');

        my $old_state = $update->state;
        my $new_state = $c->get_param('state');

        my $edited = 0;

        # $update->name can be null which makes ne unhappy
        my $name = $update->name || '';

        if ( $c->get_param('name') ne $name
          || $c->get_param('anonymous') ne $update->anonymous
          || $c->get_param('text') ne $update->text ) {
              $edited = 1;
        }

        my $remove_photo_param = $c->forward('_get_remove_photo_param');
        if ($remove_photo_param) {
            $c->forward('remove_photo', [$update, $remove_photo_param]);
        }

        $c->stash->{status_message} = _('Updated!');

        # Must call update->hide while it's not hidden (so is_latest works)
        if ($new_state eq 'hidden') {
            my $outcome = $update->hide;
            $c->stash->{status_message} .= _('Problem marked as open.')
                if $outcome->{reopened};
        }

        $update->name( $c->get_param('name') || '' );
        $update->text( $c->get_param('text') );
        $update->anonymous( $c->get_param('anonymous') );
        $update->state( $new_state );

        $edited = 1 if $c->forward('update_user', [ $update ]);

        if ( $new_state eq 'confirmed' and $old_state eq 'unconfirmed' ) {
            $update->confirmed( \'current_timestamp' );
            if ( $update->problem_state && $update->created > $update->problem->lastupdate ) {
                $update->problem->state( $update->problem_state );
                $update->problem->lastupdate( \'current_timestamp' );
                $update->problem->update;
            }
        }

        $update->update;

        if ( $new_state ne $old_state ) {
            $c->forward( 'log_edit',
                [ $update->id, 'update', 'state_change' ] );
        }

        if ($edited) {
            $c->forward( 'log_edit', [ $update->id, 'update', 'edit' ] );
        }

    }

    return 1;
}

sub add_flags : Private {
    my ( $self, $c, $search ) = @_;

    return unless $c->user->is_superuser;

    my $users = $c->stash->{users};
    my %email2user = map { $_->email => $_ } grep { $_->email } @$users;
    my %phone2user = map { $_->phone => $_ } grep { $_->phone } @$users;
    my %username2user = (%email2user, %phone2user);
    my $usernames = $c->model('DB::Abuse')->search($search);

    foreach my $username (map { $_->email } $usernames->all) {
        # Slight abuse of the boolean flagged value
        if ($username2user{$username}) {
            $username2user{$username}->flagged( 2 );
        } else {
            push @{$c->stash->{users}}, { email => $username, flagged => 2 };
        }
    }
}

sub flagged : Path('flagged') : Args(0) {
    my ( $self, $c ) = @_;

    my $problems = $c->cobrand->problems->search( { flagged => 1 } );

    # pass in as array ref as using same template as search_reports
    # which has to use an array ref for sql quoting reasons
    $c->stash->{problems} = [ $problems->all ];

    my @users = $c->cobrand->users->search( { flagged => 1 } )->all;
    $c->stash->{users} = [ @users ];

    $c->forward('add_flags', [ {} ]);
    return 1;
}

=head2 set_allowed_pages

Sets up the allowed_pages stash entry for checking if the current page is
available in the current cobrand.

=cut

sub set_allowed_pages : Private {
    my ( $self, $c ) = @_;

    my $pages = $c->cobrand->admin_pages;

    my @allowed_links = sort {$pages->{$a}[1] <=> $pages->{$b}[1]}  grep {$pages->{$_}->[0] } keys %$pages;

    $c->stash->{allowed_pages} = $pages;
    $c->stash->{allowed_links} = \@allowed_links;

    return 1;
}

sub get_user : Private {
    my ( $self, $c ) = @_;

    my $user = ($c->user && $c->user->name);
    $user ||= $c->req->remote_user();
    $user ||= '';

    return $user;
}

=item log_edit

    $c->forward( 'log_edit', [ $object_id, $object_type, $action_performed ] );

Adds an entry into the admin_log table using the current user.

=cut

sub log_edit : Private {
    my ( $self, $c, $id, $object_type, $action, $time_spent ) = @_;

    $time_spent //= 0;
    $time_spent = 0 if $time_spent < 0;

    my $user_object = do {
        my $auth_user = $c->user;
        $auth_user ? $auth_user->get_object : undef;
    };

    $c->model('DB::AdminLog')->create(
        {
            admin_user => $c->forward('get_user'),
            $user_object ? ( user => $user_object ) : (), # as (rel => undef) doesn't work
            object_type => $object_type,
            action => $action,
            object_id => $id,
            time_spent => $time_spent,
        }
    )->insert();
}

=head2 check_username_for_abuse

    $c->forward('check_username_for_abuse', [ $user ] );

Checks if $user is in the abuse table and sets username_in_abuse accordingly.

=cut

sub check_username_for_abuse : Private {
    my ( $self, $c, $user ) = @_;

    my $is_abuse = $c->model('DB::Abuse')->find({ email => [ $user->phone, $user->email ] });

    $c->stash->{username_in_abuse} = 1 if $is_abuse;
}

=head2 rotate_photo

Rotate a photo 90 degrees left or right

=cut

# returns index of photo to rotate, if any
sub _get_rotate_photo_param : Private {
    my ($self, $c) = @_;
    my $key = first { /^rotate_photo/ } keys %{ $c->req->params } or return;
    my ($index) = $key =~ /(\d+)$/;
    my $direction = $c->get_param($key);
    return [ $index || 0, $direction ];
}

sub rotate_photo : Private {
    my ( $self, $c, $object, $index, $direction ) = @_;

    return unless $direction eq _('Rotate Left') or $direction eq _('Rotate Right');

    my $fileid = $object->get_photoset->rotate_image(
        $index,
        $direction eq _('Rotate Left') ? -90 : 90
    ) or return;

    $object->update({ photo => $fileid });

    return 1;
}

=head2 remove_photo

Remove a photo from a report

=cut

# Returns index of photo(s) to remove, if any
sub _get_remove_photo_param : Private {
    my ($self, $c) = @_;

    return 'ALL' if $c->get_param('remove_photo');

    my @keys = map { /(\d+)$/ } grep { /^remove_photo_/ } keys %{ $c->req->params } or return;
    return \@keys;
}

sub remove_photo : Private {
    my ($self, $c, $object, $keys) = @_;
    if ($keys eq 'ALL') {
        $object->get_photoset->delete_cached;
        $object->photo(undef);
    } else {
        my $fileids = $object->get_photoset->remove_images($keys);
        $object->photo($fileids);
    }
    return 1;
}

=head2 check_page_allowed

Checks if the current catalyst action is in the list of allowed pages and
if not then redirects to 404 error page.

=cut

sub check_page_allowed : Private {
    my ( $self, $c ) = @_;

    $c->forward('set_allowed_pages');

    (my $page = $c->req->path) =~ s#admin/?##;
    $page =~ s#/.*##;

    $page ||= 'summary';

    if ( !grep { $_ eq $page } keys %{ $c->stash->{allowed_pages} } ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    return 1;
}

sub fetch_all_bodies : Private {
    my ($self, $c ) = @_;

    my @bodies = $c->cobrand->call_hook('admin_fetch_all_bodies');
    if (!@bodies) {
        my $bodies = $c->model('DB::Body')->search(undef, {
            columns => [ "id", "name", "deleted", "parent" ],
        })->with_parent_name;
        $bodies = $bodies->with_defect_type_count if $c->stash->{with_defect_type_count};
        @bodies = $bodies->translated->all_sorted;
    }

    $c->stash->{bodies} = \@bodies;

    return 1;
}

sub fetch_body_areas : Private {
    my ($self, $c, $body ) = @_;

    my $children = $body->first_area_children;
    unless ($children) {
        # Body doesn't have any areas defined.
        delete $c->stash->{areas};
        delete $c->stash->{fetched_areas_body_id};
        return;
    }

    $c->stash->{areas} = [ sort { strcoll($a->{name}, $b->{name}) } values %$children ];
    # Keep track of the areas we've fetched to prevent a duplicate fetch later on
    $c->stash->{fetched_areas_body_id} = $body->id;
}

sub update_extra_fields : Private {
    my ($self, $c, $object) = @_;

    my @indices = grep { /^metadata\[\d+\]\.code/ } keys %{ $c->req->params };
    @indices = sort map { /(\d+)/ } @indices;

    my @extra_fields;
    foreach my $i (@indices) {
        my $meta = {};
        $meta->{code} = $c->get_param("metadata[$i].code");
        next unless $meta->{code};

        $meta->{order} = int $c->get_param("metadata[$i].order");
        $meta->{protected} = $c->get_param("metadata[$i].protected") ? 'true' : 'false';

        my $behaviour = $c->get_param("metadata[$i].behaviour") || 'question';
        if ($behaviour eq 'question') {
            $meta->{required} = $c->get_param("metadata[$i].required") ? 'true' : 'false';
            $meta->{variable} = 'true';
            my $desc = $c->get_param("metadata[$i].description");
            $meta->{description} = FixMyStreet::Template::sanitize($desc);
            $meta->{datatype} = $c->get_param("metadata[$i].datatype");

            if ( $meta->{datatype} eq "singlevaluelist" ) {
                $meta->{values} = [];
                my $re = qr{^metadata\[$i\]\.values\[\d+\]\.key};
                my @vindices = grep { /$re/ } keys %{ $c->req->params };
                @vindices = sort map { /values\[(\d+)\]/ } @vindices;
                foreach my $j (@vindices) {
                    my $name = $c->get_param("metadata[$i].values[$j].name");
                    my $key = $c->get_param("metadata[$i].values[$j].key");
                    my $disable = $c->get_param("metadata[$i].values[$j].disable");
                    my $disable_message = $c->get_param("metadata[$i].values[$j].disable_message");
                    push(@{$meta->{values}}, {
                        name => $name,
                        key => $key,
                        $disable ? (disable => 1, disable_message => $disable_message) : (),
                    }) if $name;
                }
            }
        } elsif ($behaviour eq 'notice') {
            $meta->{variable} = 'false';
            my $desc = $c->get_param("metadata[$i].description");
            $meta->{description} = FixMyStreet::Template::sanitize($desc);
            $meta->{disable_form} = $c->get_param("metadata[$i].disable_form") ? 'true' : 'false';
        } elsif ($behaviour eq 'hidden') {
            $meta->{automated} = 'hidden_field';
        } elsif ($behaviour eq 'server') {
            $meta->{automated} = 'server_set';
        }

        push @extra_fields, $meta;
    }
    @extra_fields = sort { $a->{order} <=> $b->{order} } @extra_fields;
    $object->set_extra_fields(@extra_fields);
}

sub trim {
    my $self = shift;
    my $e = shift;
    $e =~ s/^\s+//;
    $e =~ s/\s+$//;
    return $e;
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
