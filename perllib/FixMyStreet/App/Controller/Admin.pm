package FixMyStreet::App::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Path::Class;
use POSIX qw(strftime strcoll);
use Digest::SHA qw(sha1_hex);
use mySociety::EmailUtil qw(is_valid_email is_valid_email_list);
use DateTime::Format::Strptime;
use List::Util 'first';
use List::MoreUtils 'uniq';
use mySociety::ArrayUtils;
use Text::CSV;
use Try::Tiny;

use FixMyStreet::SendReport;
use FixMyStreet::SMS;
use Utils;

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

    if ($c->cobrand->moniker eq 'zurich' && $c->stash->{admin_type} ne 'super') {
        return $c->cobrand->admin();
    }

    $c->forward('/admin/stats/state');

    my @unsent = $c->cobrand->problems->search( {
        state => [ FixMyStreet::DB::Result::Problem::open_states() ],
        whensent => undef,
        bodies_str => { '!=', undef },
    } )->all;
    $c->stash->{unsent_reports} = \@unsent;

    my $alerts = $c->model('DB::Alert')->summary_report_alerts( $c->cobrand->restriction );

    my %alert_counts =
      map { $_->confirmed => $_->get_column('confirmed_count') } $alerts->all;

    $alert_counts{0} ||= 0;
    $alert_counts{1} ||= 0;

    $c->stash->{alerts} = \%alert_counts;

    my $contacts = $c->model('DB::Contact')->summary_count();

    my %contact_counts =
      map { $_->state => $_->get_column('state_count') } $contacts->all;

    $contact_counts{confirmed} ||= 0;
    $contact_counts{unconfirmed} ||= 0;
    $contact_counts{total} = $contact_counts{confirmed} + $contact_counts{unconfirmed};

    $c->stash->{contacts} = \%contact_counts;

    my $questionnaires = $c->model('DB::Questionnaire')->summary_count( $c->cobrand->restriction );

    my %questionnaire_counts = map {
        $_->get_column('answered') => $_->get_column('questionnaire_count')
    } $questionnaires->all;
    $questionnaire_counts{1} ||= 0;
    $questionnaire_counts{0} ||= 0;

    $questionnaire_counts{total} =
      $questionnaire_counts{0} + $questionnaire_counts{1};
    $c->stash->{questionnaires_pc} =
      $questionnaire_counts{total}
      ? sprintf( '%.1f',
        $questionnaire_counts{1} / $questionnaire_counts{total} * 100 )
      : _('n/a');
    $c->stash->{questionnaires} = \%questionnaire_counts;

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

    try {
        $c->model('DB')->schema->storage->sql_maker->quote_char( '"' );
        $c->model('DB')->schema->storage->sql_maker->name_sep( '.' );

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
    } catch {
       die $_;
    } finally {
        $c->model('DB')->schema->storage->sql_maker->quote_char( '' );
    };

    $c->stash->{time} = \%time;

    return 1;
}

sub fetch_contacts : Private {
    my ( $self, $c ) = @_;

    my $contacts = $c->stash->{body}->contacts->search(undef, { order_by => [ 'category' ] } );
    $c->stash->{contacts} = $contacts;
    $c->stash->{live_contacts} = $contacts->not_deleted;
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

sub reports : Path('reports') {
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

    my $order = $c->get_param('o') || 'created';
    my $dir = defined $c->get_param('d') ? $c->get_param('d') : 1;
    $c->stash->{order} = $order;
    $c->stash->{dir} = $dir;
    $order .= ' desc' if $dir;

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

        # when DBIC creates the join it does 'JOIN users user' in the
        # SQL which makes PostgreSQL unhappy as user is a reserved
        # word. So look up user ID for email separately.
        my @user_ids = $c->model('DB::User')->search({
            email => { ilike => $like_search },
        }, { columns => [ 'id' ] } )->all;
        @user_ids = map { $_->id } @user_ids;

        my @user_ids_phone = $c->model('DB::User')->search({
            phone => { ilike => $like_search },
        }, { columns => [ 'id' ] } )->all;
        @user_ids_phone = map { $_->id } @user_ids_phone;

        if ($valid_email) {
            $query->{'-or'} = [
                'me.user_id' => { -in => \@user_ids },
            ];
        } elsif ($valid_phone) {
            $query->{'-or'} = [
                'me.user_id' => { -in => \@user_ids_phone },
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
                'me.user_id' => { -in => [ @user_ids, @user_ids_phone ] },
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
                rows => 50,
                order_by => [ \"(state='hidden')", \$order ]
            }
        )->page( $p_page );

        $c->stash->{problems} = [ $problems->all ];
        $c->stash->{problems_pager} = $problems->pager;

        if ($valid_email) {
            $query = [
                'me.user_id' => { -in => \@user_ids },
            ];
        } elsif ($valid_phone) {
            $query = [
                'me.user_id' => { -in => \@user_ids_phone },
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
                'me.user_id' => { -in => [ @user_ids, @user_ids_phone ] },
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
                    -select   => [ 'me.*', qw/problem.bodies_str problem.state/ ],
                    prefetch => [qw/problem/],
                    rows => 50,
                    order_by => [ \"(me.state='hidden')", \"(problem.state='hidden')", { -desc => 'me.created' } ]
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

sub report_edit_display : Private {
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

sub report_edit : Path('report_edit') : Args(1) {
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

    $c->forward('check_username_for_abuse', [ $problem->user ] );

    $c->stash->{updates} =
      [ $c->model('DB::Comment')
          ->search( { problem_id => $problem->id }, { order_by => [ 'created', 'id' ] } )
          ->all ];

    if (my $rotate_photo_param = $self->_get_rotate_photo_param($c)) {
        $self->rotate_photo($c, $problem, @$rotate_photo_param);
        $c->detach('report_edit_display');
    }

    if ( $c->cobrand->moniker eq 'zurich' ) {
        my $done = $c->cobrand->admin_report_edit();
        $c->detach('report_edit_display') if $done;
    }

    if ( $c->get_param('resend') ) {
        $c->forward('/auth/check_csrf_token');

        $problem->resend;
        $problem->update();
        $c->stash->{status_message} =
          '<p><em>' . _('That problem will now be resent.') . '</em></p>';

        $c->forward( 'log_edit', [ $id, 'problem', 'resend' ] );
    }
    elsif ( $c->get_param('mark_sent') ) {
        $c->forward('/auth/check_csrf_token');
        $problem->update({ whensent => \'current_timestamp' })->discard_changes;
        $c->stash->{status_message} = '<p><em>' . _('That problem has been marked as sent.') . '</em></p>';
        $c->forward( 'log_edit', [ $id, 'problem', 'marked sent' ] );
    }
    elsif ( $c->get_param('flaguser') ) {
        $c->forward('users/flag');
        $c->stash->{problem}->discard_changes;
    }
    elsif ( $c->get_param('removeuserflag') ) {
        $c->forward('users/flag_remove');
        $c->stash->{problem}->discard_changes;
    }
    elsif ( $c->get_param('banuser') ) {
        $c->forward('users/ban');
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
        $problem->set_inflated_columns(\%columns);

        if ($c->get_param('closed_updates')) {
            $problem->set_extra_metadata(closed_updates => 1);
        } else {
            $problem->unset_extra_metadata('closed_updates');
        }

        $c->forward( '/admin/report_edit_category', [ $problem, $problem->state ne $old_state ] );
        $c->forward('update_user', [ $problem ]);

        # Deal with photos
        my $remove_photo_param = $self->_get_remove_photo_param($c);
        if ($remove_photo_param) {
            $self->remove_photo($c, $problem, $remove_photo_param);
        }

        if ($problem->state eq 'hidden') {
            $problem->get_photoset->delete_cached;
        }

        if ( $problem->is_visible() and $old_state eq 'unconfirmed' ) {
            $problem->confirmed( \'current_timestamp' );
        }

        $problem->lastupdate( \'current_timestamp' );
        $problem->update;

        if ( $problem->state ne $old_state ) {
            $c->forward( 'log_edit', [ $id, 'problem', 'state_change' ] );

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
        $c->forward( 'log_edit', [ $id, 'problem', 'edit' ] );

        $c->stash->{status_message} =
          '<p><em>' . _('Updated!') . '</em></p>';

        # do this here otherwise lastupdate and confirmed times
        # do not display correctly
        $problem->discard_changes;
    }

    $c->detach('report_edit_display');
}

=head2 report_edit_category

Handles changing a problem's category and the complexity that comes with it.
Returns 1 if category changed, 0 if no change.

=cut

sub report_edit_category : Private {
    my ($self, $c, $problem, $no_comment) = @_;

    if ((my $category = $c->get_param('category')) ne $problem->category) {
        my $category_old = $problem->category;
        $problem->category($category);
        my @contacts = grep { $_->category eq $problem->category } @{$c->stash->{contacts}};
        my @new_body_ids = map { $_->body_id } @contacts;
        # If the report has changed bodies (and not to a subset!) we need to resend it
        my %old_map = map { $_ => 1 } @{$problem->bodies_str_ids};
        if (grep !$old_map{$_}, @new_body_ids) {
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
        if (grep !$old_send_methods{$_}, @new_send_methods) {
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
        return 1;
    }
    return 0;
}

=head2 report_edit_location

Handles changing a problem's location and the complexity that comes with it.
For now, we reject the new location if the new location and old locations aren't
covered by the same body.

Returns 2 if the new position (if any) is acceptable and changed,
1 if acceptable and unchanged, undef otherwise.

NB: This must be called before report_edit_category, as that might modify
$problem->bodies_str.

=cut

sub report_edit_location : Private {
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
    $c->forward('/report/new/setup_categories_and_bodies');

    # Remove the "Pick a category" option
    shift @{$c->stash->{category_options}} if @{$c->stash->{category_options}};

    $c->stash->{categories_hash} = { map { $_->category => 1 } @{$c->stash->{category_options}} };
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

sub templates : Path('templates') : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->forward('fetch_all_bodies');
        $c->stash->{template} = 'admin/templates_index.html';
    } elsif ( $user->from_body ) {
        $c->forward('load_template_body', [ $user->from_body->id ]);
        $c->res->redirect( $c->uri_for( 'templates', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found', [] );
    }
}

sub templates_view : Path('templates') : Args(1) {
    my ($self, $c, $body_id) = @_;

    $c->forward('load_template_body', [ $body_id ]);

    my @templates = $c->stash->{body}->response_templates->search(
        undef,
        {
            order_by => 'title'
        }
    );

    $c->stash->{response_templates} = \@templates;

    $c->stash->{template} = 'admin/templates.html';
}

sub template_edit : Path('templates') : Args(2) {
    my ( $self, $c, $body_id, $template_id ) = @_;

    $c->forward('load_template_body', [ $body_id ]);

    my $template;
    if ($template_id eq 'new') {
        $template = $c->stash->{body}->response_templates->new({});
    }
    else {
        $template = $c->stash->{body}->response_templates->find( $template_id )
            or $c->detach( '/page_error_404_not_found', [] );
    }

    $c->forward('fetch_contacts');
    my @contacts = $template->contacts->all;
    my @live_contacts = $c->stash->{live_contacts}->all;
    my %active_contacts = map { $_->id => 1 } @contacts;
    my @all_contacts = map { {
        id => $_->id,
        category => $_->category_display,
        active => $active_contacts{$_->id},
        email => $_->email,
    } } @live_contacts;
    $c->stash->{contacts} = \@all_contacts;

    # bare block to use 'last' if form is invalid.
    if ($c->req->method eq 'POST') { {
        if ($c->get_param('delete_template') && $c->get_param('delete_template') eq _("Delete template")) {
            $template->contact_response_templates->delete_all;
            $template->delete;
        } else {
            my @live_contact_ids = map { $_->id } @live_contacts;
            my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @live_contact_ids;
            my %new_contacts = map { $_ => 1 } @new_contact_ids;
            for my $contact (@all_contacts) {
                $contact->{active} = $new_contacts{$contact->{id}};
            }

            $template->title( $c->get_param('title') );
            $template->text( $c->get_param('text') );
            $template->state( $c->get_param('state') );
            $template->external_status_code( $c->get_param('external_status_code') );

            if ( $template->state && $template->external_status_code ) {
                $c->stash->{errors} ||= {};
                $c->stash->{errors}->{state} = _("State and external status code cannot be used simultaneously.");
                $c->stash->{errors}->{external_status_code} = _("State and external status code cannot be used simultaneously.");
            }

            $template->auto_response( $c->get_param('auto_response') && ( $template->state || $template->external_status_code ) ? 1 : 0 );
            if ($template->auto_response) {
                my @check_contact_ids = @new_contact_ids;
                # If the new template has not specific categories (i.e. it
                # applies to all categories) then we need to check each of those
                # category ids for existing auto-response templates.
                if (!scalar @check_contact_ids) {
                    @check_contact_ids = @live_contact_ids;
                }
                my $query = {
                    'auto_response' => 1,
                    'contact.id' => [ @check_contact_ids, undef ],
                    -or => {
                        $template->state ? ('me.state' => $template->state) : (),
                        $template->external_status_code ? ('me.external_status_code' => $template->external_status_code) : (),
                    },
                };
                if ($template->in_storage) {
                    $query->{'me.id'} = { '!=', $template->id };
                }
                if ($c->stash->{body}->response_templates->search($query, {
                    join => { 'contact_response_templates' => 'contact' },
                })->count) {
                    $c->stash->{errors} ||= {};
                    $c->stash->{errors}->{auto_response} = _("There is already an auto-response template for this category/state.");
                }
            }

            last if $c->stash->{errors};

            $template->update_or_insert;
            $template->contact_response_templates->search({
                contact_id => { '!=' => \@new_contact_ids },
            })->delete;
            foreach my $contact_id (@new_contact_ids) {
                $template->contact_response_templates->find_or_create({
                    contact_id => $contact_id,
                });
            }
        }

        $c->res->redirect( $c->uri_for( 'templates', $c->stash->{body}->id ) );
    } }

    $c->stash->{response_template} = $template;

    $c->stash->{template} = 'admin/template_edit.html';
}

sub load_template_body : Private {
    my ($self, $c, $body_id) = @_;

    my $zurich_user = $c->user->from_body && $c->cobrand->moniker eq 'zurich';
    my $has_permission = $c->user->has_body_permission_to('template_edit', $body_id);

    unless ( $zurich_user || $has_permission ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    # Regular users can only view their own body's templates
    if ( !$c->user->is_superuser && $body_id ne $c->user->from_body->id ) {
        $c->res->redirect( $c->uri_for( 'templates', $c->user->from_body->id ) );
    }

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found', [] );
}

sub update_edit : Path('update_edit') : Args(1) {
    my ( $self, $c, $id ) = @_;

    my $update = $c->cobrand->updates->search({ 'me.id' => $id })->first;

    $c->detach( '/page_error_404_not_found', [] )
      unless $update;

    $c->forward('/auth/get_csrf_token');

    $c->stash->{update} = $update;

    if (my $rotate_photo_param = $self->_get_rotate_photo_param($c)) {
        $self->rotate_photo($c, $update, @$rotate_photo_param);
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

        my $remove_photo_param = $self->_get_remove_photo_param($c);
        if ($remove_photo_param) {
            $self->remove_photo($c, $update, $remove_photo_param);
        }

        $c->stash->{status_message} = '<p><em>' . _('Updated!') . '</em></p>';

        # Must call update->hide while it's not hidden (so is_latest works)
        if ($new_state eq 'hidden') {
            my $outcome = $update->hide;
            $c->stash->{status_message} .=
              '<p><em>' . _('Problem marked as open.') . '</em></p>'
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

    my $user = $c->req->remote_user();
    $user ||= ($c->user && $c->user->name);
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
sub _get_rotate_photo_param {
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
sub _get_remove_photo_param {
    my ($self, $c) = @_;

    return 'ALL' if $c->get_param('remove_photo');

    my @keys = map { /(\d+)$/ } grep { /^remove_photo_/ } keys %{ $c->req->params } or return;
    return \@keys;
}

sub remove_photo : Private {
    my ($self, $c, $object, $keys) = @_;
    if ($keys eq 'ALL') {
        $object->photo(undef);
        $object->get_photoset->delete_cached;
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
        $meta->{datatype} = $c->get_param("metadata[$i].datatype");
        my $required = $c->get_param("metadata[$i].required") && $c->get_param("metadata[$i].required") eq 'on';
        $meta->{required} = $required ? 'true' : 'false';
        my $notice = $c->get_param("metadata[$i].notice") && $c->get_param("metadata[$i].notice") eq 'on';
        $meta->{variable} = $notice ? 'false' : 'true';
        $meta->{description} = $c->get_param("metadata[$i].description");
        $meta->{datatype_description} = $c->get_param("metadata[$i].datatype_description");
        $meta->{automated} = $c->get_param("metadata[$i].automated")
            if $c->get_param("metadata[$i].automated");

        if ( $meta->{datatype} eq "singlevaluelist" ) {
            $meta->{values} = [];
            my $re = qr{^metadata\[$i\]\.values\[\d+\]\.key};
            my @vindices = grep { /$re/ } keys %{ $c->req->params };
            @vindices = sort map { /values\[(\d+)\]/ } @vindices;
            foreach my $j (@vindices) {
                my $name = $c->get_param("metadata[$i].values[$j].name");
                my $key = $c->get_param("metadata[$i].values[$j].key");
                push(@{$meta->{values}}, {
                    name => $name,
                    key => $key,
                }) if $name;
            }
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
