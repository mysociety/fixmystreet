package FixMyStreet::App::Controller::Admin::Reports;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use utf8;
use List::MoreUtils 'uniq';
use JSON::MaybeXS;
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

    my $problems = $c->cobrand->problems;

    $c->stash->{assignees} = $c->cobrand->call_hook('get_list_of_report_assignees' => $problems);

    if (my $search = $c->get_param('search')) {
        $search = $self->trim($search);

        # In case an email address, wrapped in <...>
        if ($search =~ /^<(.*)>$/) {
            my $possible_email = $1;
            my $parsed = FixMyStreet::SMS->parse_username($possible_email);
            $search = $possible_email if $parsed->{email};
        }

        $c->stash->{searched} = $search;

        my $like_search = "%$search%";

        my $parsed = FixMyStreet::SMS->parse_username($search);
        my $valid_phone = $parsed->{phone};
        my $valid_email = $parsed->{email};

        if ($search =~ /^id:(\d+)$/) {
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
        } elsif ($search =~ /^uprn:(\d+)$/) {
            $query = {
                'me.uprn' => $1,
            };
        } elsif ($valid_email) {
            $query->{'-or'} = [
                'user.email' => { ilike => $like_search },
            ];
        } elsif ($valid_phone) {
            $query->{'-or'} = [
                'user.phone' => { ilike => $like_search },
            ];
        } else {
            $problems = $problems->search_text($search);
            # The below is added so that PostgreSQL does not try and use other indexes
            # besides the full text search. It should have no impact on results shown.
            $order = [ $order, { -desc => "me.id" }, { -desc => "me.created" } ];
        }

        $problems = $problems->search(
            $query,
            {
                join => 'user',
                '+columns' => 'user.email',
                prefetch => 'contact',
                rows => 50,
                order_by => $order,
            }
        )->page( $p_page );

        $c->stash->{problems} = [ $problems->all ];
        $c->stash->{problems_pager} = $problems->pager;

        my $updates = $c->cobrand->updates;
        $order = { -desc => 'me.id' };
        if ($valid_email) {
            # If you naively put: 'user.email' => { ilike => $like_search },
            # in the query, PostgreSQL 13 will perform a backwards primary key
            # index scan and check each user as it goes, rather than looking up
            # the users and using the comment's user_id index.
            my $subselect = FixMyStreet::DB->resultset("User")->search(
                { email => { ilike => $like_search } }, { columns => ['id'] });
            $query = [
                'user.id' => { -in => $subselect->as_query },
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
            $query = 0;
        } elsif ($search =~ /^uprn:(\d+)$/) {
            $query = 0;
        } else {
            $updates = $updates->search_text($search);
            $order = [ $order, { -desc => "me.created" } ];
            $query = 1;
        }

        $query = { -or => $query } if ref $query;

        if ($query) {
            $query = undef unless ref $query;
            $updates = $updates->search(
                $query,
                {
                    '+columns' => ['user.email'],
                    join => 'user',
                    prefetch => [qw/problem/],
                    rows => 50,
                    order_by => $order,
                }
            )->page( $u_page );
            $c->stash->{updates} = [ $updates->all ];
            $c->stash->{updates_pager} = $updates->pager;
        }
    } elsif (my $assignee = $c->get_param('assignee')) {
        my $problems = $c->cobrand->call_hook('filter_problems_by_assignee' => $problems, $assignee, $order, $p_page);
        $c->stash->{selected_assignee} = $assignee;
        $c->stash->{problems} = [ $problems->all ] if $problems;
        $c->stash->{problems_pager} = $problems->pager if $problems;
    } else {

        $problems = $problems->search(
            $query,
            {
                '+columns' => ['user.email'],
                join => 'user',
                prefetch => 'contact',
                order_by => $order,
                rows => 50
            }
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
        $problem->mark_as_sent;
        $problem->update->discard_changes;
        $c->stash->{status_message} = _('That problem has been marked as sent.');
        $c->forward( '/admin/log_edit', [ $id, 'problem', 'marked sent' ] );
    }
    elsif ( $c->get_param('submit') ) {
        $c->forward('/auth/check_csrf_token');

        my $old_state = $problem->state;
        my %columns;

        my $non_public = $c->get_param('non_public') ? 1 : 0;
        if ($non_public != $problem->non_public) {
            my $change = $non_public ? _('Marked private') : _('Marked public');
            $c->forward( '/admin/log_edit', [ $id, 'problem', $change ] );
            $columns{non_public} = $non_public;
        }

        # Only superusers can flag / unflag a report
        if ($c->user->is_superuser) {
            $columns{flagged} = $c->get_param('flagged') ? 1 : 0;
        }
        foreach (qw/state anonymous title detail name external_id/) {
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
        if ($c->get_param('send_state') && ($c->get_param('send_state') ne $problem->send_state)) {
            $problem->send_state($c->get_param('send_state'));
        };

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

            $problem->add_to_comments( {
                text => $c->stash->{update_text} || '',
                user => $c->user->obj,
                problem_state => $problem->state,
            } );
        }
        $c->forward( '/admin/log_edit', [ $id, 'problem', 'edit' ] );

        $c->stash->{status_message} = _('Updated!');

        # do this here otherwise lastupdate and confirmed times
        # do not display correctly
        $problem->discard_changes;
    }

    # Handle display of extra data.
    # This should be handled *after* any edits to extra data.
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

        if ( $extra->{contributed_by} ) {
            my $u = $c->cobrand->users->find({id => $extra->{contributed_by}});
            if ( $u ) {
                my $uri = $c->uri_for_action('admin/users/index', { search => $u->email } );
                push @fields, {
                    name => _('Created By'),
                    code => 'contributed_by',
                    val => FixMyStreet::Template::SafeString->new( "<a href=\"$uri\">@{[$u->name]} (@{[$u->email]})</a>" )
                };
                if ( $u->from_body ) {
                    push @fields, { name => _('Created Body'), val => $u->from_body->name };
                } elsif ( $u->is_superuser ) {
                    push @fields, { name => _('Created Body'), val => _('Superuser') };
                }
            } else {
                push @fields, { name => 'contributed_by', code => 'contributed_by', val => $extra->{contributed_by} };
            }
            delete $extra->{contributed_by};
        }

        for my $key ( keys %$extra ) {
            next if $key =~ /^(whensent_previous|rdi_processed|gender|variant|CyclingUK)/;
            push @fields, { name => $key, val => $extra->{$key} };
        }

        $c->stash->{extra_fields_display} = \@fields;
    }

    $c->detach('edit_display');
}

=head2 edit_category

Handles changing a problem's category and the complexity that comes with it.
Returns 1 if category changed, 0 if no change.

=cut

sub edit_category : Private {
    my ($self, $c, $problem, $no_comment, $contact, $group_new) = @_;

    my ($group, $category);
    my ($group_changed, $category_changed);
    my $category_display;
    my $group_old = $problem->get_extra_metadata('group') // '';
    my $category_old = $problem->category;

    if ($contact) {
        $group = $group_new;
        $category = $contact->category;

        $group_changed = $group ne $group_old;
        $category_changed = $contact->id != $problem->contact->id;

        return 0
            if !$group_changed && !$category_changed;

        $category_display = $contact->category_display;
    } else {
        my $group_and_category = $c->get_param('category');

        my $rgx = qr/__/;
        ( $group, $category )
            = $group_and_category =~ $rgx
            ? ( split $rgx, $group_and_category )
            : ( '', $group_and_category );

        $group_changed = $group ne $group_old;
        $category_changed = $category ne $category_old;

        # No changes
        return 0
            if !$group_changed && !$category_changed;

        $category_display = $category;
    }

    my @contacts;
    if ($contact) {
        @contacts = ($contact);
    } else {
        @contacts = grep { $_->category eq $category } @{$c->stash->{contacts}};

        # See if we have one matching contact and use its display name if we do.
        if (@contacts == 1) {
            $category_display = $contacts[0]->category_display;
        }
    }

    # @contacts may be empty if form has been submitted with a deleted
    # category. If we don't return here, it will lead to an empty bodies_str
    # below. We also don't want to update group or category on the problem.
    return 0 unless @contacts;

    my $category_old_display = $problem->category_display;
    $problem->category($category);
    $group
        ? $problem->set_extra_metadata( group => $group )
        : $problem->unset_extra_metadata('group');


    # TODO Do we ever want to do this if only group has changed?
    check_resend($c, $category_old, $problem, \@contacts);

    my @new_body_ids = map { $_->body_id } @contacts;
    $problem->bodies_str(join( ',', @new_body_ids ));

    my ($update_text, $action);
    if ($category_changed) {
        $update_text = '*'
            . sprintf( _('Category changed from ‘%s’ to ‘%s’'),
            $category_old_display, $category_display ) . '*';

        $action = 'category_change';

    } else {
        $update_text = '*'
            . sprintf( _('Category group changed from ‘%s’ to ‘%s’'),
            $group_old, $group ) . '*';

        $action = 'group_change';
    }

    if ($no_comment) {
        $c->stash->{update_text} = $update_text;
    } else {
        $problem->add_to_comments({
            text => $update_text,
            user => $c->user->obj,
        });
    }

    $c->forward( '/admin/log_edit', [ $problem->id, 'problem', $action ] );
    return 1;
}

sub check_resend {
    my ($c, $category_old, $problem, $contacts) = @_;

    my $force_resend = $c->cobrand->call_hook('category_change_force_resend', $category_old, $problem->category);
    if ($force_resend) {
        $problem->resend;
        return;
    }

    my $disable_resend = $c->cobrand->call_hook('disable_resend');
    return if $disable_resend;

    # If the report has changed bodies (and not to a subset!) we need to resend it
    my %old_map = map { $_ => 1 } @{$problem->bodies_str_ids};
    my @new_body_ids = map { $_->body_id } @$contacts;
    if (grep !$old_map{$_}, @new_body_ids) {
        $problem->resend;
        return;
    }

    # If the send methods of the old/new contacts differ we need to resend the report
    my @new_send_methods = uniq map {
        ( $_->body->can_be_devolved && $_->send_method ) ?
        $_->send_method : $_->body->send_method
            ? $_->body->send_method
            : $c->cobrand->_fallback_body_sender()->{method};
    } @$contacts;
    my %old_send_methods = map { $_ => 1 } split /,/, ($problem->send_method_used || "Email");
    if (grep !$old_send_methods{$_}, @new_send_methods) {
        $problem->resend;
        return;
    }
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
        $c->forward('/report/new/setup_categories_and_bodies', []);
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
    $c->forward('/report/new/setup_categories_and_bodies', []);

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
