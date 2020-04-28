package FixMyStreet::App::Controller::Admin::Reports;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use List::MoreUtils 'uniq';
use FixMyStreet::SMS;
use Utils;

=head1 NAME

FixMyStreet::App::Controller::Admin::Reports - Catalyst Controller

=head1 DESCRIPTION

Admin pages

=head1 METHODS

=cut

sub index : Path {
    my ( $self, $c ) = @_;

    $c->stash->{edit_body_contacts} = 1
        if grep { $_ eq 'body' } keys %{$c->stash->{allowed_pages}};

    my $query = {};
    if ( $c->cobrand->moniker eq 'zurich' ) {
        my $type = $c->stash->{admin_type};
        my $body = $c->stash->{body};
        if ( $type eq 'dm' ) {
            my @children = map { $_->id } $body->bodies->all;
            my @all = (@children, $body->id);
            $query = { bodies_str => \@all };
        } elsif ( $type eq 'sdm' ) {
            $query = { bodies_str => $body->id };
        }
    }

    my $order = $c->get_param('o') || 'id';
    my $dir = defined $c->get_param('d') ? $c->get_param('d') : 1;
    $c->stash->{order} = $order;
    $c->stash->{dir} = $dir;
    $order = $dir ? { -desc => "me.$order" } : "me.$order";

    my $p_page = $c->get_param('p') || 1;
    my $u_page = $c->get_param('u') || 1;

    return if $c->cobrand->call_hook(report_search_query => $query, $p_page, $u_page, $order);

    if (my $search = $c->get_param('search')) {
        $search = $self->trim($search);

        # In case an email address, wrapped in <...>
        if ($search =~ /^<(.*)>$/) {
            my $possible_email = $1;
            my $parsed = FixMyStreet::SMS->parse_username($possible_email);
            $search = $possible_email if $parsed->{email};
        }

        $c->stash->{searched} = $search;

        my $search_n = 0;
        $search_n = int($search) if $search =~ /^\d+$/;

        my $like_search = "%$search%";

        my $parsed = FixMyStreet::SMS->parse_username($search);
        my $valid_phone = $parsed->{phone};
        my $valid_email = $parsed->{email};

        if ($valid_email) {
            $query->{'-or'} = [
                'user.email' => { ilike => $like_search },
            ];
        } elsif ($valid_phone) {
            $query->{'-or'} = [
                'user.phone' => { ilike => $like_search },
            ];
        } elsif ($search =~ /^id:(\d+)$/) {
            $query->{'-or'} = [
                'me.id' => int($1),
            ];
        } elsif ($search =~ /^area:(\d+)$/) {
            $query->{'-or'} = [
                'me.areas' => { like => "%,$1,%" }
            ];
        } elsif ($search =~ /^ref:(\d+)$/) {
            $query->{'-or'} = [
                'me.external_id' => { like => "%$1%" }
            ];
        } else {
            $query->{'-or'} = [
                'me.id' => $search_n,
                'user.email' => { ilike => $like_search },
                'user.phone' => { ilike => $like_search },
                'me.external_id' => { ilike => $like_search },
                'me.name' => { ilike => $like_search },
                'me.title' => { ilike => $like_search },
                detail => { ilike => $like_search },
                bodies_str => { like => $like_search },
                cobrand_data => { like => $like_search },
            ];
        }

        my $problems = $c->cobrand->problems->search(
            $query,
            {
                join => 'user',
                '+columns' => 'user.email',
                rows => 50,
                order_by => $order,
            }
        )->page( $p_page );

        $c->stash->{problems} = [ $problems->all ];
        $c->stash->{problems_pager} = $problems->pager;

        if ($valid_email) {
            $query = [
                'user.email' => { ilike => $like_search },
            ];
        } elsif ($valid_phone) {
            $query = [
                'user.phone' => { ilike => $like_search },
            ];
        } elsif ($search =~ /^id:(\d+)$/) {
            $query = [
                'me.id' => int($1),
                'me.problem_id' => int($1),
            ];
        } elsif ($search =~ /^area:(\d+)$/) {
            $query = [];
        } else {
            $query = [
                'me.id' => $search_n,
                'problem.id' => $search_n,
                'user.email' => { ilike => $like_search },
                'user.phone' => { ilike => $like_search },
                'me.name' => { ilike => $like_search },
                text => { ilike => $like_search },
                'me.cobrand_data' => { ilike => $like_search },
            ];
        }

        if (@$query) {
            my $updates = $c->cobrand->updates->search(
                {
                    -or => $query,
                },
                {
                    '+columns' => ['user.email'],
                    join => 'user',
                    prefetch => [qw/problem/],
                    rows => 50,
                    order_by => { -desc => 'me.id' }
                }
            )->page( $u_page );
            $c->stash->{updates} = [ $updates->all ];
            $c->stash->{updates_pager} = $updates->pager;
        }

    } else {

        my $problems = $c->cobrand->problems->search(
            $query,
            { order_by => $order, rows => 50 }
        )->page( $p_page );
        $c->stash->{problems} = [ $problems->all ];
        $c->stash->{problems_pager} = $problems->pager;
    }
}

sub edit_display : Private {
    my ( $self, $c ) = @_;

    my $problem = $c->stash->{problem};

    $c->stash->{page} = 'admin';
    FixMyStreet::Map::display_map(
        $c,
        latitude  => $problem->latitude,
        longitude => $problem->longitude,
        pins      => $problem->used_map
        ? [ {
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            colour    => $c->cobrand->pin_colour($problem, 'admin'),
            type      => 'big',
            draggable => 1,
          } ]
        : [],
        print_report => 1,
    );
}

sub edit : Path('/admin/report_edit') : Args(1) {
    my ( $self, $c, $id ) = @_;

    my $problem = $c->cobrand->problems->search( { id => $id } )->first;

    $c->detach( '/page_error_404_not_found', [] )
      unless $problem;

    unless (
        $c->cobrand->moniker eq 'zurich'
        || $c->user->has_permission_to(report_edit => $problem->bodies_str_ids)
    ) {
        $c->detach( '/page_error_403_access_denied', [] );
    }

    $c->stash->{problem} = $problem;
    if ( $problem->extra ) {
        my @fields;
        if ( my $fields = $problem->get_extra_fields ) {
            for my $field ( @{$fields} ) {
                my $name = $field->{description} ?
                    "$field->{description} ($field->{name})" :
                    "$field->{name}";
                push @fields, { name => $name, val => $field->{value} };
            }
        }
        my $extra = $problem->get_extra_metadata;
        if ( $extra->{duplicates} ) {
            push @fields, { name => 'Duplicates', val => join( ',', @{ $problem->get_extra_metadata('duplicates') } ) };
            delete $extra->{duplicates};
        }
        for my $key ( keys %$extra ) {
            push @fields, { name => $key, val => $extra->{$key} };
        }

        $c->stash->{extra_fields} = \@fields;
    }

    $c->forward('/auth/get_csrf_token');

    $c->forward('categories_for_point');

    $c->forward('alerts_for_report');

    $c->forward('/admin/check_username_for_abuse', [ $problem->user ] );

    $c->stash->{updates} =
      [ $c->model('DB::Comment')
          ->search( { problem_id => $problem->id }, { order_by => [ 'created', 'id' ] } )
          ->all ];

    if (my $rotate_photo_param = $c->forward('/admin/_get_rotate_photo_param')) {
        $c->forward('/admin/rotate_photo', [$problem, @$rotate_photo_param]);
        $c->detach('edit_display');
    }

    if ( $c->cobrand->moniker eq 'zurich' ) {
        my $done = $c->cobrand->admin_report_edit();
        $c->detach('edit_display') if $done;
    }

    if ( $c->get_param('resend') && !$c->cobrand->call_hook('disable_resend_button') ) {
        $c->forward('/auth/check_csrf_token');

        $problem->resend;
        $problem->update();
        $c->stash->{status_message} = _('That problem will now be resent.');

        $c->forward( '/admin/log_edit', [ $id, 'problem', 'resend' ] );
    }
    elsif ( $c->get_param('mark_sent') ) {
        $c->forward('/auth/check_csrf_token');
        $problem->update({ whensent => \'current_timestamp' })->discard_changes;
        $c->stash->{status_message} = _('That problem has been marked as sent.');
        $c->forward( '/admin/log_edit', [ $id, 'problem', 'marked sent' ] );
    }
    elsif ( $c->get_param('flaguser') ) {
        $c->forward('/admin/users/flag');
        $c->stash->{problem}->discard_changes;
    }
    elsif ( $c->get_param('removeuserflag') ) {
        $c->forward('/admin/users/flag_remove');
        $c->stash->{problem}->discard_changes;
    }
    elsif ( $c->get_param('banuser') ) {
        $c->forward('/admin/users/ban');
    }
    elsif ( $c->get_param('submit') ) {
        $c->forward('/auth/check_csrf_token');

        my $old_state = $problem->state;

        my %columns = (
            flagged => $c->get_param('flagged') ? 1 : 0,
            non_public => $c->get_param('non_public') ? 1 : 0,
        );
        foreach (qw/state anonymous title detail name external_id external_body external_team/) {
            $columns{$_} = $c->get_param($_);
        }

        # Look this up here for moderation line to use
        my $remove_photo_param = $c->forward('/admin/_get_remove_photo_param');

        if ($columns{title} ne $problem->title || $columns{detail} ne $problem->detail ||
                $columns{anonymous} ne $problem->anonymous || $remove_photo_param) {
            $problem->create_related( moderation_original_data => {
                title => $problem->title,
                detail => $problem->detail,
                photo => $problem->photo,
                anonymous => $problem->anonymous,
                category => $problem->category,
                $problem->extra ? (extra => $problem->extra) : (),
            });
        }

        $problem->set_inflated_columns(\%columns);

        if ($c->get_param('closed_updates')) {
            $problem->set_extra_metadata(closed_updates => 1);
        } else {
            $problem->unset_extra_metadata('closed_updates');
        }

        $c->forward( '/admin/reports/edit_category', [ $problem, $problem->state ne $old_state ] );
        $c->forward('/admin/update_user', [ $problem ]);

        # Deal with photos
        if ($remove_photo_param) {
            $c->forward('/admin/remove_photo', [ $problem, $remove_photo_param ]);
        }

        if ($problem->state eq 'hidden' || $problem->non_public) {
            $problem->get_photoset->delete_cached(plus_updates => 1);
        }

        if ( $problem->is_visible() and $old_state eq 'unconfirmed' ) {
            $problem->confirmed( \'current_timestamp' );
        }

        $problem->lastupdate( \'current_timestamp' );
        $problem->update;

        if ( $problem->state ne $old_state ) {
            $c->forward( '/admin/log_edit', [ $id, 'problem', 'state_change' ] );

            my $name = $c->user->moderating_user_name;
            my $extra = { is_superuser => 1 };
            if ($c->user->from_body) {
                delete $extra->{is_superuser};
                $extra->{is_body_user} = $c->user->from_body->id;
            }
            my $timestamp = \'current_timestamp';
            $problem->add_to_comments( {
                text => $c->stash->{update_text} || '',
                created => $timestamp,
                confirmed => $timestamp,
                user_id => $c->user->id,
                name => $name,
                mark_fixed => 0,
                anonymous => 0,
                state => 'confirmed',
                problem_state => $problem->state,
                extra => $extra
            } );
        }
        $c->forward( '/admin/log_edit', [ $id, 'problem', 'edit' ] );

        $c->stash->{status_message} = _('Updated!');

        # do this here otherwise lastupdate and confirmed times
        # do not display correctly
        $problem->discard_changes;
    }

    $c->detach('edit_display');
}

=head2 edit_category

Handles changing a problem's category and the complexity that comes with it.
Returns 1 if category changed, 0 if no change.

=cut

sub edit_category : Private {
    my ($self, $c, $problem, $no_comment) = @_;

    if ((my $category = $c->get_param('category')) ne $problem->category) {
        my $force_resend = $c->cobrand->call_hook('category_change_force_resend', $problem->category, $category);
        my $disable_resend = $c->cobrand->call_hook('disable_resend');
        my $category_old = $problem->category;
        $problem->category($category);
        my @contacts = grep { $_->category eq $problem->category } @{$c->stash->{contacts}};
        my @new_body_ids = map { $_->body_id } @contacts;
        # If the report has changed bodies (and not to a subset!) we need to resend it
        my %old_map = map { $_ => 1 } @{$problem->bodies_str_ids};
        if (!$disable_resend && grep !$old_map{$_}, @new_body_ids) {
            $problem->resend;
        }
        # If the send methods of the old/new contacts differ we need to resend the report
        my @new_send_methods = uniq map {
            ( $_->body->can_be_devolved && $_->send_method ) ?
            $_->send_method : $_->body->send_method
                ? $_->body->send_method
                : $c->cobrand->_fallback_body_sender()->{method};
        } @contacts;
        my %old_send_methods = map { $_ => 1 } split /,/, ($problem->send_method_used || "Email");
        if (!$disable_resend && grep !$old_send_methods{$_}, @new_send_methods) {
            $problem->resend;
        }
        if ($force_resend) {
            $problem->resend;
        }

        $problem->bodies_str(join( ',', @new_body_ids ));
        my $update_text = '*' . sprintf(_('Category changed from ‘%s’ to ‘%s’'), $category_old, $category) . '*';
        if ($no_comment) {
            $c->stash->{update_text} = $update_text;
        } else {
            $problem->add_to_comments({
                text => $update_text,
                created => \'current_timestamp',
                confirmed => \'current_timestamp',
                user_id => $c->user->id,
                name => $c->user->from_body ? $c->user->from_body->name : $c->user->name,
                state => 'confirmed',
                mark_fixed => 0,
                anonymous => 0,
            });
        }
        $c->forward( '/admin/log_edit', [ $problem->id, 'problem', 'category_change' ] );
        return 1;
    }
    return 0;
}

=head2 edit_location

Handles changing a problem's location and the complexity that comes with it.
For now, we reject the new location if the new location and old locations aren't
covered by the same body.

Returns 2 if the new position (if any) is acceptable and changed,
1 if acceptable and unchanged, undef otherwise.

NB: This must be called before edit_category, as that might modify
$problem->bodies_str.

=cut

sub edit_location : Private {
    my ($self, $c, $problem) = @_;

    return 1 unless $c->forward('/location/determine_location_from_coords');

    my ($lat, $lon) = map { Utils::truncate_coordinate($_) } $problem->latitude, $problem->longitude;
    if ( $c->stash->{latitude} != $lat || $c->stash->{longitude} != $lon ) {
        # The two actions below change the stash, setting things up for e.g. a
        # new report. But here we're only doing it in order to check the found
        # bodies match; we don't want to overwrite the existing report data if
        # this lookup is bad. So let's save the stash and restore it after the
        # comparison.
        my $safe_stash = { %{$c->stash} };
        $c->stash->{fetch_all_areas} = 1;
        $c->stash->{area_check_action} = 'admin';
        $c->forward('/council/load_and_check_areas', []);
        $c->forward('/report/new/setup_categories_and_bodies');
        my %allowed_bodies = map { $_ => 1 } @{$problem->bodies_str_ids};
        my @new_bodies = keys %{$c->stash->{bodies_to_list}};
        my $bodies_match = grep { exists( $allowed_bodies{$_} ) } @new_bodies;
        $c->stash($safe_stash);
        return unless $bodies_match;
        $problem->latitude($c->stash->{latitude});
        $problem->longitude($c->stash->{longitude});
        my $areas = $c->stash->{all_areas_mapit};
        $problem->areas( ',' . join( ',', sort keys %$areas ) . ',' );
        return 2;
    }
    return 1;
}

sub categories_for_point : Private {
    my ($self, $c) = @_;

    $c->stash->{report} = $c->stash->{problem};
    # We have a report, stash its location
    $c->forward('/report/new/determine_location_from_report');
    # Look up the areas for this location
    my $prefetched_all_areas = [ grep { $_ } split ',', $c->stash->{report}->areas ];
    $c->forward('/around/check_location_is_acceptable', [ $prefetched_all_areas ]);
    # As with a new report, fetch the bodies/categories
    $c->stash->{categories_for_point} = 1;
    $c->forward('/report/new/setup_categories_and_bodies');

    # Remove the "Pick a category" option
    shift @{$c->stash->{category_options}} if @{$c->stash->{category_options}};

    $c->stash->{categories_hash} = { map { $_->category => 1 } @{$c->stash->{category_options}} };

    $c->forward('/admin/triage/setup_categories');

}

sub alerts_for_report : Private {
    my ($self, $c) = @_;

    $c->stash->{alert_count} = $c->model('DB::Alert')->search({
        alert_type => 'new_updates',
        parameter => $c->stash->{report}->id,
        confirmed => 1,
        whendisabled => undef,
    })->count();
}

sub trim {
    my $self = shift;
    my $e = shift;
    $e =~ s/^\s+//;
    $e =~ s/\s+$//;
    return $e;
}

__PACKAGE__->meta->make_immutable;

1;
