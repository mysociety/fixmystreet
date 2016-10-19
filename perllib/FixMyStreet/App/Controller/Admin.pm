package FixMyStreet::App::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Path::Class;
use POSIX qw(strftime strcoll);
use Digest::SHA qw(sha1_hex);
use mySociety::EmailUtil qw(is_valid_email);
use mySociety::ArrayUtils;
use DateTime::Format::Strptime;
use List::Util 'first';

use FixMyStreet::SendReport;

=head1 NAME

FixMyStreet::App::Controller::Admin- Catalyst Controller

=head1 DESCRIPTION

Admin pages

=head1 METHODS

=cut

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->uri_disposition('relative');

    # User must be logged in to see cobrand, and meet whatever checks the
    # cobrand specifies. Default cobrand just requires superuser flag to be set.
    unless ( $c->user_exists && $c->cobrand->admin_allow_user($c->user) ) {
        $c->detach( '/auth/redirect' );
    }

    if ( $c->cobrand->moniker eq 'zurich' ) {
        $c->cobrand->admin_type();
    }
}

sub auto : Private {
    my ( $self, $c ) = @_;

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

    $c->forward('stats_by_state');

    my @unsent = $c->cobrand->problems->search( {
        state => [ 'confirmed' ],
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
      map { $_->confirmed => $_->get_column('confirmed_count') } $contacts->all;

    $contact_counts{0} ||= 0;
    $contact_counts{1} ||= 0;
    $contact_counts{total} = $contact_counts{0} + $contact_counts{1};

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
    my $dir = $c->stash->{additional_template_paths}->[0];
    my $git_version = `cd $dir && git describe --tags`;
    chomp $git_version;
    $c->stash(
        git_version => $git_version,
    );
}

sub timeline : Path( 'timeline' ) : Args(0) {
    my ($self, $c) = @_;

    my %time;

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

    $c->model('DB')->schema->storage->sql_maker->quote_char( '' );

    $c->stash->{time} = \%time;

    return 1;
}

sub questionnaire : Path('stats/questionnaire') : Args(0) {
    my ( $self, $c ) = @_;

    my $questionnaires = $c->model('DB::Questionnaire')->search(
        { whenanswered => { '!=', undef } },
        { group_by => [ 'ever_reported' ],
            select => [ 'ever_reported', { count => 'me.id' } ],
            as     => [ qw/reported questionnaire_count/ ] }
    );

    my %questionnaire_counts = map {
        ( defined $_->get_column( 'reported' ) ? $_->get_column( 'reported' ) : -1 )
            => $_->get_column( 'questionnaire_count' )
    } $questionnaires->all;
    $questionnaire_counts{1} ||= 0;
    $questionnaire_counts{0} ||= 0;
    $questionnaire_counts{total} = $questionnaire_counts{0} + $questionnaire_counts{1};
    $c->stash->{questionnaires} = \%questionnaire_counts;

    $c->stash->{state_changes_count} = $c->model('DB::Questionnaire')->search(
        { whenanswered => \'is not null' }
    )->count;
    $c->stash->{state_changes} = $c->model('DB::Questionnaire')->search(
        { whenanswered => \'is not null' },
        {
            group_by => [ 'old_state', 'new_state' ],
            columns => [ 'old_state', 'new_state', { c => { count => 'id' } } ],
        },
    );

    return 1;
}

sub bodies : Path('bodies') : Args(0) {
    my ( $self, $c ) = @_;

    if (my $body_id = $c->get_param('body')) {
        return $c->res->redirect( $c->uri_for( 'body', $body_id ) );
    }

    if (!$c->user->is_superuser && $c->user->from_body && $c->cobrand->moniker ne 'zurich') {
        return $c->res->redirect( $c->uri_for( 'body', $c->user->from_body->id ) );
    }

    $c->forward( '/auth/get_csrf_token' );

    my $edit_activity = $c->model('DB::ContactsHistory')->search(
        undef,
        {
            select => [ 'editor', { count => 'contacts_history_id', -as => 'c' } ],
            as     => [ 'editor', 'c' ],
            group_by => ['editor'],
            order_by => { -desc => 'c' }
        }
    );

    $c->stash->{edit_activity} = $edit_activity;

    my $posted = $c->get_param('posted') || '';
    if ( $posted eq 'body' ) {
        $c->forward('check_for_super_user');
        $c->forward('/auth/check_csrf_token');

        my $params = $c->forward('body_params');
        unless ( keys %{$c->stash->{body_errors}} ) {
            my $body = $c->model('DB::Body')->create( $params );
            my @area_ids = $c->get_param_list('area_ids');
            foreach (@area_ids) {
                $c->model('DB::BodyArea')->create( { body => $body, area_id => $_ } );
            }

            $c->stash->{updated} = _('New body added');
        }
    }

    $c->forward( 'fetch_all_bodies' );

    my $contacts = $c->model('DB::Contact')->search(
        undef,
        {
            select => [ 'body_id', { count => 'id' }, { count => \'case when deleted then 1 else null end' },
            { count => \'case when confirmed then 1 else null end' } ],
            as => [qw/body_id c deleted confirmed/],
            group_by => [ 'body_id' ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator'
        }
    );

    my %council_info = map { $_->{body_id} => $_ } $contacts->all;

    $c->stash->{counts} = \%council_info;

    $c->forward( 'body_form_dropdowns' );

    return 1;
}

sub body_form_dropdowns : Private {
    my ( $self, $c ) = @_;

    my $areas;
    my $whitelist = $c->config->{MAPIT_ID_WHITELIST};

    if ( $whitelist && ref $whitelist eq 'ARRAY' && @$whitelist ) {
        $areas = mySociety::MaPit::call('areas', $whitelist);
    } else {
        $areas = mySociety::MaPit::call('areas', $c->cobrand->area_types);
    }
    $c->stash->{areas} = [ sort { strcoll($a->{name}, $b->{name}) } values %$areas ];

    my @methods = map { $_ =~ s/FixMyStreet::SendReport:://; $_ } keys %{ FixMyStreet::SendReport->get_senders };
    $c->stash->{send_methods} = \@methods;
}

sub body : Path('body') : Args(1) {
    my ( $self, $c, $body_id ) = @_;

    $c->stash->{body_id} = $body_id;

    unless ($c->user->has_permission_to('category_edit', $body_id)) {
        $c->forward('check_for_super_user');
    }

    $c->forward( '/auth/get_csrf_token' );
    $c->forward( 'lookup_body' );
    $c->forward( 'fetch_all_bodies' );
    $c->forward( 'body_form_dropdowns' );

    if ( $c->get_param('posted') ) {
        $c->log->debug( 'posted' );
        $c->forward('update_contacts');
    }

    $c->forward('fetch_contacts');

    return 1;
}

sub check_for_super_user : Private {
    my ( $self, $c ) = @_;

    my $superuser = $c->user->is_superuser;
    # Zurich currently has its own way of defining superusers
    $superuser ||= $c->cobrand->moniker eq 'zurich' && $c->stash->{admin_type} eq 'super';

    unless ( $superuser ) {
        $c->detach('/page_error_403_access_denied', []);
    }
}

sub update_contacts : Private {
    my ( $self, $c ) = @_;

    my $posted = $c->get_param('posted');
    my $editor = $c->forward('get_user');

    if ( $posted eq 'new' ) {
        $c->forward('/auth/check_csrf_token');

        my %errors;

        my $category = $self->trim( $c->get_param('category') );
        $errors{category} = _("Please choose a category") unless $category;
        $errors{note} = _('Please enter a message') unless $c->get_param('note');

        my $contact = $c->model('DB::Contact')->find_or_new(
            {
                body_id => $c->stash->{body_id},
                category => $category,
            }
        );

        my $email = $self->trim( $c->get_param('email') );
        my $send_method = $c->get_param('send_method') || $contact->send_method || $contact->body->send_method || "";
        unless ( $send_method eq 'Open311' ) {
            $errors{email} = _('Please enter a valid email') unless is_valid_email($email) || $email eq 'REFUSED';
        }

        $contact->email( $email );
        $contact->confirmed( $c->get_param('confirmed') ? 1 : 0 );
        $contact->deleted( $c->get_param('deleted') ? 1 : 0 );
        $contact->non_public( $c->get_param('non_public') ? 1 : 0 );
        $contact->note( $c->get_param('note') );
        $contact->whenedited( \'current_timestamp' );
        $contact->editor( $editor );
        $contact->endpoint( $c->get_param('endpoint') );
        $contact->jurisdiction( $c->get_param('jurisdiction') );
        $contact->api_key( $c->get_param('api_key') );
        $contact->send_method( $c->get_param('send_method') );

        # Set flags in extra to the appropriate values
        if ( $c->get_param('photo_required') ) {
            $contact->set_extra_metadata_if_undefined(  photo_required => 1 );
        }
        else {
            $contact->unset_extra_metadata( 'photo_required' );
        }
        if ( $c->get_param('inspection_required') ) {
            $contact->set_extra_metadata( inspection_required => 1 );
        }
        else {
            $contact->unset_extra_metadata( 'inspection_required' );
        }
        if ( $c->get_param('reputation_threshold') ) {
            $contact->set_extra_metadata( reputation_threshold => int($c->get_param('reputation_threshold')) );
        }

        if ( %errors ) {
            $c->stash->{updated} = _('Please correct the errors below');
            $c->stash->{contact} = $contact;
            $c->stash->{errors} = \%errors;
        } elsif ( $contact->in_storage ) {
            $c->stash->{updated} = _('Values updated');

            # NB: History is automatically stored by a trigger in the database
            $contact->update;
        } else {
            $c->stash->{updated} = _('New category contact added');
            $contact->insert;
        }

    } elsif ( $posted eq 'update' ) {
        $c->forward('/auth/check_csrf_token');

        my @categories = $c->get_param_list('confirmed');

        my $contacts = $c->model('DB::Contact')->search(
            {
                body_id => $c->stash->{body_id},
                category => { -in => \@categories },
            }
        );

        $contacts->update(
            {
                confirmed => 1,
                whenedited => \'current_timestamp',
                note => 'Confirmed',
                editor => $editor,
            }
        );

        $c->stash->{updated} = _('Values updated');
    } elsif ( $posted eq 'body' ) {
        $c->forward('check_for_super_user');
        $c->forward('/auth/check_csrf_token');

        my $params = $c->forward( 'body_params' );
        unless ( keys %{$c->stash->{body_errors}} ) {
            $c->stash->{body}->update( $params );
            my @current = $c->stash->{body}->body_areas->all;
            my %current = map { $_->area_id => 1 } @current;
            my @area_ids = $c->get_param_list('area_ids');
            foreach (@area_ids) {
                $c->model('DB::BodyArea')->find_or_create( { body => $c->stash->{body}, area_id => $_ } );
                delete $current{$_};
            }
            # Remove any others
            $c->stash->{body}->body_areas->search( { area_id => [ keys %current ] } )->delete;

            $c->stash->{updated} = _('Values updated');
        }
    }
}

sub body_params : Private {
    my ( $self, $c ) = @_;

    my @fields = qw/name endpoint jurisdiction api_key send_method external_url/;
    my %defaults = map { $_ => '' } @fields;
    %defaults = ( %defaults,
        send_comments => 0,
        suppress_alerts => 0,
        comment_user_id => undef,
        send_extended_statuses => 0,
        can_be_devolved => 0,
        parent => undef,
        deleted => 0,
    );
    my %params = map { $_ => $c->get_param($_) || $defaults{$_} } keys %defaults;
    $c->forward('check_body_params', [ \%params ]);
    return \%params;
}

sub check_body_params : Private {
    my ( $self, $c, $params ) = @_;

    $c->stash->{body_errors} ||= {};

    unless ($params->{name}) {
        $c->stash->{body_errors}->{name} = _('Please enter a name for this body');
    }
}

sub fetch_contacts : Private {
    my ( $self, $c ) = @_;

    my $contacts = $c->stash->{body}->contacts->search(undef, { order_by => [ 'category' ] } );
    $c->stash->{contacts} = $contacts;
    $c->stash->{live_contacts} = $contacts->search({ deleted => 0 });
    $c->stash->{any_not_confirmed} = $contacts->search({ confirmed => 0 })->count;

    if ( $c->get_param('text') && $c->get_param('text') eq '1' ) {
        $c->stash->{template} = 'admin/council_contacts.txt';
        $c->res->content_type('text/plain; charset=utf-8');
        return 1;
    }

    return 1;
}

sub lookup_body : Private {
    my ( $self, $c ) = @_;

    my $body_id = $c->stash->{body_id};
    my $body = $c->model('DB::Body')->find($body_id);
    $c->detach( '/page_error_404_not_found', [] )
      unless $body;
    $c->stash->{body} = $body;
    
    if ($body->body_areas->first) {
        my $example_postcode = mySociety::MaPit::call('area/example_postcode', $body->body_areas->first->area_id);
        if ($example_postcode && ! ref $example_postcode) {
            $c->stash->{example_pc} = $example_postcode;
        }
    }

    return 1;
}

# This is for if the category name contains a '/'
sub category_edit_all : Path('body') {
    my ( $self, $c, $body_id, @category ) = @_;
    my $category = join( '/', @category );
    $c->go( 'category_edit', [ $body_id, $category ] );
}

sub category_edit : Path('body') : Args(2) {
    my ( $self, $c, $body_id, $category ) = @_;

    $c->stash->{body_id} = $body_id;

    $c->forward( '/auth/get_csrf_token' );
    $c->forward( 'lookup_body' );

    my $contact = $c->stash->{body}->contacts->search( { category => $category } )->first;
    $c->stash->{contact} = $contact;

    my $history = $c->model('DB::ContactsHistory')->search(
        {
            body_id => $body_id,
            category => $category
        },
        {
            order_by => ['contacts_history_id']
        },
    );
    $c->stash->{history} = $history;

    my @methods = map { $_ =~ s/FixMyStreet::SendReport:://; $_ } keys %{ FixMyStreet::SendReport->get_senders };
    $c->stash->{send_methods} = \@methods;

    return 1;
}

sub reports : Path('reports') {
    my ( $self, $c ) = @_;

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

    if (my $search = $c->get_param('search')) {
        $c->stash->{searched} = $search;

        my $search_n = 0;
        $search_n = int($search) if $search =~ /^\d+$/;

        my $like_search = "%$search%";

        # when DBIC creates the join it does 'JOIN users user' in the
        # SQL which makes PostgreSQL unhappy as user is a reserved
        # word. So look up user ID for email separately.
        my @user_ids = $c->model('DB::User')->search({
            email => { ilike => $like_search },
        }, { columns => [ 'id' ] } )->all;
        @user_ids = map { $_->id } @user_ids;

        if (is_valid_email($search)) {
            $query->{'-or'} = [
                'me.user_id' => { -in => \@user_ids },
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
                'me.user_id' => { -in => \@user_ids },
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

        if (is_valid_email($search)) {
            $query = [
                'me.user_id' => { -in => \@user_ids },
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
                'me.user_id' => { -in => \@user_ids },
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
                    order_by => [ \"(me.state='hidden')", \"(problem.state='hidden')", 'me.created' ]
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

    $c->stash->{edit_body_contacts} = 1
        if ( grep {$_ eq 'body'} keys %{$c->stash->{allowed_pages}});

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

    $c->forward('/auth/get_csrf_token');

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
          } ]
        : [],
        print_report => 1,
    );

    if (my $rotate_photo_param = $self->_get_rotate_photo_param($c)) {
        $self->rotate_photo($c, $problem, @$rotate_photo_param);
        if ( $c->cobrand->moniker eq 'zurich' ) {
            # Clicking the photo rotation buttons should do nothing
            # except for rotating the photo, so return the user
            # to the report screen now.
            $c->res->redirect( $c->uri_for( 'report_edit', $problem->id ) );
            return;
        } else {
            return 1;
        }
    }

    $c->stash->{categories} = $c->forward('categories_for_point');

    if ( $c->cobrand->moniker eq 'zurich' ) {
        my $done = $c->cobrand->admin_report_edit();
        return if $done;
    }

    $c->forward('check_email_for_abuse', [ $problem->user->email ] );

    $c->stash->{updates} =
      [ $c->model('DB::Comment')
          ->search( { problem_id => $problem->id }, { order_by => 'created' } )
          ->all ];

    if ( $c->get_param('resend') ) {
        $c->forward('/auth/check_csrf_token');

        $problem->whensent(undef);
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
        $c->forward('flag_user');
        $c->stash->{problem}->discard_changes;
    }
    elsif ( $c->get_param('removeuserflag') ) {
        $c->forward('remove_user_flag');
        $c->stash->{problem}->discard_changes;
    }
    elsif ( $c->get_param('banuser') ) {
        $c->forward('ban_user');
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

        $c->forward( '/admin/report_edit_category', [ $problem ] );

        if ( $c->get_param('email') ne $problem->user->email ) {
            my $user = $c->model('DB::User')->find_or_create(
                { email => $c->get_param('email') }
            );

            $user->insert unless $user->in_storage;
            $problem->user( $user );
        }

        # Deal with photos
        my $remove_photo_param = $self->_get_remove_photo_param($c);
        if ($remove_photo_param) {
            $self->remove_photo($c, $problem, $remove_photo_param);
        }

        if ( $remove_photo_param || $problem->state eq 'hidden' ) {
            $problem->get_photoset->delete_cached;
        }

        if ( $problem->is_visible() and $old_state eq 'unconfirmed' ) {
            $problem->confirmed( \'current_timestamp' );
        }

        $problem->lastupdate( \'current_timestamp' );
        $problem->update;

        if ( $problem->state ne $old_state ) {
            $c->forward( 'log_edit', [ $id, 'problem', 'state_change' ] );
        }
        $c->forward( 'log_edit', [ $id, 'problem', 'edit' ] );

        $c->stash->{status_message} =
          '<p><em>' . _('Updated!') . '</em></p>';

        # do this here otherwise lastupdate and confirmed times
        # do not display correctly
        $problem->discard_changes;
    }

    return 1;
}

=head2 report_edit_category

Handles changing a problem's category and the complexity that comes with it.

=cut

sub report_edit_category : Private {
    my ($self, $c, $problem) = @_;

    if ((my $category = $c->get_param('category')) ne $problem->category) {
        $problem->category($category);
        my @contacts = grep { $_->category eq $problem->category } @{$c->stash->{contacts}};
        my @new_body_ids = map { $_->body_id } @contacts;
        # If the report has changed bodies we need to resend it
        if (scalar @{mySociety::ArrayUtils::symmetric_diff($problem->bodies_str_ids, \@new_body_ids)}) {
            $problem->whensent(undef);
        }
        $problem->bodies_str(join( ',', @new_body_ids ));
    }
}

=head2 report_edit_location

Handles changing a problem's location and the complexity that comes with it.
For now, we reject the new location if the new location and old locations aren't
covered by the same body.

Returns 1 if the new position (if any) is acceptable, undef otherwise.

NB: This must be called before report_edit_category, as that might modify
$problem->bodies_str.

=cut

sub report_edit_location : Private {
    my ($self, $c, $problem) = @_;

    return 1 unless $c->forward('/location/determine_location_from_coords');

    my ($lat, $lon) = map { Utils::truncate_coordinate($_) } $problem->latitude, $problem->longitude;
    if ( $c->stash->{latitude} != $lat || $c->stash->{longitude} != $lon ) {
        $c->forward('/council/load_and_check_areas', []);
        $c->forward('/report/new/setup_categories_and_bodies');
        my %allowed_bodies = map { $_ => 1 } @{$problem->bodies_str_ids};
        my @new_bodies = @{$c->stash->{bodies_to_list}};
        my $bodies_match = grep { exists( $allowed_bodies{$_} ) } @new_bodies;
        return unless $bodies_match;
        $problem->latitude($c->stash->{latitude});
        $problem->longitude($c->stash->{longitude});
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

    return $c->stash->{category_options};
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
        category => $_->category,
        active => $active_contacts{$_->id},
    } } @live_contacts;
    $c->stash->{contacts} = \@all_contacts;

    if ($c->req->method eq 'POST') {
        if ($c->get_param('delete_template') && $c->get_param('delete_template') eq _("Delete template")) {
            $template->contact_response_templates->delete_all;
            $template->delete;
        } else {
            $template->title( $c->get_param('title') );
            $template->text( $c->get_param('text') );
            $template->auto_response( $c->get_param('auto_response') ? 1 : 0 );
            $template->update_or_insert;

            my @live_contact_ids = map { $_->id } @live_contacts;
            my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @live_contact_ids;
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
    }

    $c->stash->{response_template} = $template;

    $c->stash->{template} = 'admin/template_edit.html';
}

sub load_template_body : Private {
    my ($self, $c, $body_id) = @_;

    my $zurich_user = $c->user->from_body && $c->cobrand->moniker eq 'zurich';
    my $has_permission = $c->user->has_body_permission_to('template_edit') &&
                         $c->user->from_body->id eq $body_id;

    unless ( $c->user->is_superuser || $zurich_user || $has_permission ) {
        $c->detach( '/page_error_404_not_found', [] );
    }

    # Regular users can only view their own body's templates
    if ( !$c->user->is_superuser && $body_id ne $c->user->from_body->id ) {
        $c->res->redirect( $c->uri_for( 'templates', $c->user->from_body->id ) );
    }

    $c->stash->{body} = $c->model('DB::Body')->find($body_id)
        or $c->detach( '/page_error_404_not_found', [] );
}

sub users: Path('users') : Args(0) {
    my ( $self, $c ) = @_;

    if (my $search = $c->get_param('search')) {
        $c->stash->{searched} = $search;

        my $isearch = '%' . $search . '%';
        my $search_n = 0;
        $search_n = int($search) if $search =~ /^\d+$/;

        my $users = $c->cobrand->users->search(
            {
                -or => [
                    email => { ilike => $isearch },
                    name => { ilike => $isearch },
                    from_body => $search_n,
                ]
            }
        );
        my @users = $users->all;
        my %email2user = map { $_->email => $_ } @users;
        $c->stash->{users} = [ @users ];

        if ( $c->user->is_superuser ) {
            my $emails = $c->model('DB::Abuse')->search(
                { email => { ilike => $isearch } }
            );
            foreach my $email ($emails->all) {
                # Slight abuse of the boolean flagged value
                if ($email2user{$email->email}) {
                    $email2user{$email->email}->flagged( 2 );
                } else {
                    push @{$c->stash->{users}}, { email => $email->email, flagged => 2 };
                }
            }
        }

    } else {
        $c->forward('/auth/get_csrf_token');
        $c->forward('fetch_all_bodies');

        # Admin users by default
        my $users = $c->cobrand->users->search(
            { from_body => { '!=', undef } },
            { order_by => 'name' }
        );
        my @users = $users->all;
        my %email2user = map { $_->email => $_ } @users;
        $c->stash->{users} = \@users;

    }

    return 1;
}

sub update_edit : Path('update_edit') : Args(1) {
    my ( $self, $c, $id ) = @_;

    my $update = $c->cobrand->updates->search({ id => $id })->first;

    $c->detach( '/page_error_404_not_found', [] )
      unless $update;

    $c->forward('/auth/get_csrf_token');

    $c->stash->{update} = $update;

    if (my $rotate_photo_param = $self->_get_rotate_photo_param($c)) {
        $self->rotate_photo($c, $update, @$rotate_photo_param);
        return 1;
    }

    $c->forward('check_email_for_abuse', [ $update->user->email ] );

    if ( $c->get_param('banuser') ) {
        $c->forward('ban_user');
    }
    elsif ( $c->get_param('flaguser') ) {
        $c->forward('flag_user');
        $c->stash->{update}->discard_changes;
    }
    elsif ( $c->get_param('removeuserflag') ) {
        $c->forward('remove_user_flag');
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
          || $c->get_param('email') ne $update->user->email
          || $c->get_param('anonymous') ne $update->anonymous
          || $c->get_param('text') ne $update->text ) {
              $edited = 1;
        }

        my $remove_photo_param = $self->_get_remove_photo_param($c);
        if ($remove_photo_param) {
            $self->remove_photo($c, $update, $remove_photo_param);
        }

        if ( $remove_photo_param || $new_state eq 'hidden' ) {
            $update->get_photoset->delete_cached;
        }

        $update->name( $c->get_param('name') || '' );
        $update->text( $c->get_param('text') );
        $update->anonymous( $c->get_param('anonymous') );
        $update->state( $new_state );

        if ( $c->get_param('email') ne $update->user->email ) {
            my $user =
              $c->model('DB::User')
              ->find_or_create( { email => $c->get_param('email') } );

            $user->insert unless $user->in_storage;
            $update->user($user);
        }

        if ( $new_state eq 'confirmed' and $old_state eq 'unconfirmed' ) {
            $update->confirmed( \'current_timestamp' );
            if ( $update->problem_state && $update->created > $update->problem->lastupdate ) {
                $update->problem->state( $update->problem_state );
                $update->problem->lastupdate( \'current_timestamp' );
                $update->problem->update;
            }
        }

        $update->update;

        $c->stash->{status_message} = '<p><em>' . _('Updated!') . '</em></p>';

        # If we're hiding an update, see if it marked as fixed and unfix if so
        if ( $new_state eq 'hidden' && $update->mark_fixed ) {
            if ( $update->problem->state =~ /^fixed/ ) {
                $update->problem->state('confirmed');
                $update->problem->update;
            }

            $c->stash->{status_message} .=
              '<p><em>' . _('Problem marked as open.') . '</em></p>';
        }

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

sub user_add : Path('user_edit') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'admin/user_edit.html';
    $c->forward('/auth/get_csrf_token');
    $c->forward('fetch_all_bodies');

    return unless $c->get_param('submit');

    $c->forward('/auth/check_csrf_token');

    unless ($c->get_param('email')) {
        $c->stash->{field_errors}->{email} = _('Please enter a valid email');
        return;
    }
    unless ($c->get_param('name')) {
        $c->stash->{field_errors}->{name} = _('Please enter a name');
        return;
    }

    my $user = $c->model('DB::User')->find_or_create( {
        name => $c->get_param('name'),
        email => $c->get_param('email'),
        phone => $c->get_param('phone') || undef,
        from_body => $c->get_param('body') || undef,
        flagged => $c->get_param('flagged') || 0,
        # Only superusers can create superusers
        is_superuser => ( $c->user->is_superuser && $c->get_param('is_superuser') ) || 0,
    }, {
        key => 'users_email_key'
    } );
    $c->stash->{user} = $user;

    $c->forward( 'log_edit', [ $user->id, 'user', 'edit' ] );

    $c->stash->{status_message} =
      '<p><em>' . _('Updated!') . '</em></p>';

    return 1;
}

sub user_edit : Path('user_edit') : Args(1) {
    my ( $self, $c, $id ) = @_;

    $c->forward('/auth/get_csrf_token');

    my $user = $c->cobrand->users->find( { id => $id } );
    $c->detach( '/page_error_404_not_found', [] ) unless $user;

    unless ( $c->user->is_superuser || $c->user->has_body_permission_to('user_edit') || $c->cobrand->moniker eq 'zurich' ) {
        $c->detach('/page_error_403_access_denied', []);
    }

    $c->stash->{user} = $user;

    if ( $user->from_body && $c->user->has_permission_to('user_manage_permissions', $user->from_body->id) ) {
        $c->stash->{available_permissions} = $c->cobrand->available_permissions;
    }

    $c->forward('fetch_all_bodies');
    $c->forward('fetch_body_areas', [ $user->from_body ]) if $user->from_body;

    if ( $c->get_param('submit') ) {
        $c->forward('/auth/check_csrf_token');

        my $edited = 0;

        if ( $user->email ne $c->get_param('email') ||
            $user->name ne $c->get_param('name') ||
            ($user->phone || "") ne $c->get_param('phone') ||
            ($user->from_body && $c->get_param('body') && $user->from_body->id ne $c->get_param('body')) ||
            (!$user->from_body && $c->get_param('body'))
        ) {
                $edited = 1;
        }

        $user->name( $c->get_param('name') );
        $user->email( $c->get_param('email') );
        $user->phone( $c->get_param('phone') ) if $c->get_param('phone');
        $user->flagged( $c->get_param('flagged') || 0 );
        # Only superusers can grant superuser status
        $user->is_superuser( ( $c->user->is_superuser && $c->get_param('is_superuser') ) || 0 );
        # Superusers can set from_body to any value, but other staff can only
        # set from_body to the same value as their own from_body.
        if ( $c->user->is_superuser || $c->cobrand->moniker eq 'zurich' ) {
            $user->from_body( $c->get_param('body') || undef );
        } elsif ( $c->user->has_body_permission_to('user_assign_body') &&
                  $c->get_param('body') && $c->get_param('body') eq $c->user->from_body->id ) {
            $user->from_body( $c->user->from_body );
        } else {
            $user->from_body( undef );
        }

        # Has the user's from_body changed since we fetched areas (if we ever did)?
        # If so, we need to re-fetch areas so the UI is up to date.
        if ( $user->from_body && $user->from_body->id ne $c->stash->{fetched_areas_body_id} ) {
            $c->forward('fetch_body_areas', [ $user->from_body ]);
        }

        if (!$user->from_body) {
            # Non-staff users aren't allowed any permissions or to be in an area
            $user->admin_user_body_permissions->delete;
            $user->area_id(undef);
            delete $c->stash->{areas};
            delete $c->stash->{fetched_areas_body_id};
        } elsif ($c->stash->{available_permissions}) {
            my @all_permissions = map { keys %$_ } values %{ $c->stash->{available_permissions} };
            my @user_permissions = grep { $c->get_param("permissions[$_]") ? 1 : undef } @all_permissions;
            $user->admin_user_body_permissions->search({
                body_id => $user->from_body->id,
                permission_type => { '!=' => \@user_permissions },
            })->delete;
            foreach my $permission_type (@user_permissions) {
                $user->user_body_permissions->find_or_create({
                    body_id => $user->from_body->id,
                    permission_type => $permission_type,
                });
            }
        }

        if ( $user->from_body && $c->user->has_permission_to('user_assign_areas', $user->from_body->id) ) {
            my %valid_areas = map { $_->{id} => 1 } @{ $c->stash->{areas} };
            my $new_area = $c->get_param('area_id');
            $user->area_id( $valid_areas{$new_area} ? $new_area : undef );
        }

        # Handle 'trusted' flag(s)
        my @trusted_bodies = $c->get_param_list('trusted_bodies');
        if ( $c->user->is_superuser ) {
            $user->user_body_permissions->search({
                body_id => { '!=' => \@trusted_bodies },
                permission_type => 'trusted',
            })->delete;
            foreach my $body_id (@trusted_bodies) {
                $user->user_body_permissions->find_or_create({
                    body_id => $body_id,
                    permission_type => 'trusted',
                });
            }
        } elsif ( $c->user->from_body ) {
            my %trusted = map { $_ => 1 } @trusted_bodies;
            my $body_id = $c->user->from_body->id;
            if ( $trusted{$body_id} ) {
                $user->user_body_permissions->find_or_create({
                    body_id => $body_id,
                    permission_type => 'trusted',
                });
            } else {
                $user->user_body_permissions->search({
                    body_id => $body_id,
                    permission_type => 'trusted',
                })->delete;
            }
        }

        unless ($user->email) {
            $c->stash->{field_errors}->{email} = _('Please enter a valid email');
            return;
        }
        unless ($user->name) {
            $c->stash->{field_errors}->{name} = _('Please enter a name');
            return;
        }

        my $existing_user = $c->model('DB::User')->search({ email => $user->email, id => { '!=', $user->id } })->first;
        if ($existing_user) {
            $existing_user->adopt($user);
            $c->forward( 'log_edit', [ $id, 'user', 'merge' ] );
            $c->res->redirect( $c->uri_for( 'user_edit', $existing_user->id ) );
        } else {
            $user->update;
            if ($edited) {
                $c->forward( 'log_edit', [ $id, 'user', 'edit' ] );
            }
        }

        $c->stash->{status_message} =
          '<p><em>' . _('Updated!') . '</em></p>';
    }

    return 1;
}

sub flagged : Path('flagged') : Args(0) {
    my ( $self, $c ) = @_;

    my $problems = $c->cobrand->problems->search( { flagged => 1 } );

    # pass in as array ref as using same template as search_reports
    # which has to use an array ref for sql quoting reasons
    $c->stash->{problems} = [ $problems->all ];

    my $users = $c->cobrand->users->search( { flagged => 1 } );
    my @users = $users->all;
    my %email2user = map { $_->email => $_ } @users;
    $c->stash->{users} = [ @users ];

    my @abuser_emails = $c->model('DB::Abuse')->all()
        if $c->user->is_superuser;

    foreach my $email (@abuser_emails) {
        # Slight abuse of the boolean flagged value
        if ($email2user{$email->email}) {
            $email2user{$email->email}->flagged( 2 );
        } else {
            push @{$c->stash->{users}}, { email => $email->email, flagged => 2 };
        }
    }

    return 1;
}

sub stats_by_state : Path('stats/state') : Args(0) {
    my ( $self, $c ) = @_;

    my $problems = $c->cobrand->problems->summary_count;

    my %prob_counts =
      map { $_->state => $_->get_column('state_count') } $problems->all;

    %prob_counts =
      map { $_ => $prob_counts{$_} || 0 }
        ( FixMyStreet::DB::Result::Problem->all_states() );
    $c->stash->{problems} = \%prob_counts;
    $c->stash->{total_problems_live} += $prob_counts{$_} ? $prob_counts{$_} : 0
        for ( FixMyStreet::DB::Result::Problem->visible_states() );
    $c->stash->{total_problems_users} = $c->cobrand->problems->unique_users;

    my $comments = $c->cobrand->updates->summary_count;

    my %comment_counts =
      map { $_->state => $_->get_column('state_count') } $comments->all;

    $c->stash->{comments} = \%comment_counts;
}

sub stats_fix_rate : Path('stats/fix-rate') : Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{categories} = $c->cobrand->problems->categories_summary();
}

sub stats : Path('stats') : Args(0) {
    my ( $self, $c ) = @_;

    my $selected_body;
    if ( $c->user->is_superuser ) {
        $c->forward('fetch_all_bodies');
        $selected_body = $c->get_param('body');
    } else {
        $selected_body = $c->user->from_body->id;
    }

    if ( $c->cobrand->moniker eq 'seesomething' || $c->cobrand->moniker eq 'zurich' ) {
        return $c->cobrand->admin_stats();
    }

    if ( $c->get_param('getcounts') ) {

        my ( $start_date, $end_date, @errors );
        my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' );

        $start_date = $parser-> parse_datetime ( $c->get_param('start_date') );

        push @errors, _('Invalid start date') unless defined $start_date;

        $end_date = $parser-> parse_datetime ( $c->get_param('end_date') ) ;

        push @errors, _('Invalid end date') unless defined $end_date;

        $c->stash->{errors} = \@errors;
        $c->stash->{start_date} = $start_date;
        $c->stash->{end_date} = $end_date;

        $c->stash->{unconfirmed} = $c->get_param('unconfirmed') eq 'on' ? 1 : 0;

        return 1 if @errors;

        my $bymonth = $c->get_param('bymonth');
        $c->stash->{bymonth} = $bymonth;

        $c->stash->{selected_body} = $selected_body;

        my $field = 'confirmed';

        $field = 'created' if $c->get_param('unconfirmed');

        my $one_day = DateTime::Duration->new( days => 1 );


        my %select = (
                select => [ 'state', { 'count' => 'me.id' } ],
                as => [qw/state count/],
                group_by => [ 'state' ],
                order_by => [ 'state' ],
        );

        if ( $c->get_param('bymonth') ) {
            %select = (
                select => [ 
                    { extract => \"year from $field", -as => 'c_year' },
                    { extract => \"month from $field", -as => 'c_month' },
                    { 'count' => 'me.id' }
                ],
                as     => [qw/c_year c_month count/],
                group_by => [qw/c_year c_month/],
                order_by => [qw/c_year c_month/],
            );
        }

        my $p = $c->cobrand->problems->to_body($selected_body)->search(
            {
                -AND => [
                    $field => { '>=', $start_date},
                    $field => { '<=', $end_date + $one_day },
                ],
            },
            \%select,
        );

        # in case the total_report count is 0
        $c->stash->{show_count} = 1;
        $c->stash->{states} = $p;
    }

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

=head2 ban_user

Add the email address in the email param of the request object to
the abuse table if they are not already in there and sets status_message
accordingly

=cut

sub ban_user : Private {
    my ( $self, $c ) = @_;

    my $email = $c->get_param('email');

    return unless $email;

    my $abuse = $c->model('DB::Abuse')->find_or_new({ email => $email });

    if ( $abuse->in_storage ) {
        $c->stash->{status_message} = _('Email already in abuse list');
    } else {
        $abuse->insert;
        $c->stash->{status_message} = _('Email added to abuse list');
    }

    $c->stash->{email_in_abuse} = 1;

    return 1;
}

=head2 flag_user

Sets the flag on a user with the given email

=cut

sub flag_user : Private {
    my ( $self, $c ) = @_;

    my $email = $c->get_param('email');

    return unless $email;

    my $user = $c->cobrand->users->find({ email => $email });

    if ( !$user ) {
        $c->stash->{status_message} = _('Could not find user');
    } else {
        $user->flagged(1);
        $user->update;
        $c->stash->{status_message} = _('User flagged');
    }

    $c->stash->{user_flagged} = 1;

    return 1;
}

=head2 remove_user_flag

Remove the flag on a user with the given email

=cut

sub remove_user_flag : Private {
    my ( $self, $c ) = @_;

    my $email = $c->get_param('email');

    return unless $email;

    my $user = $c->cobrand->users->find({ email => $email });

    if ( !$user ) {
        $c->stash->{status_message} = _('Could not find user');
    } else {
        $user->flagged(0);
        $user->update;
        $c->stash->{status_message} = _('User flag removed');
    }

    return 1;
}


=head2 check_email_for_abuse

    $c->forward('check_email_for_abuse', [ $email ] );

Checks if $email is in the abuse table and sets email_in_abuse accordingly

=cut

sub check_email_for_abuse : Private {
    my ( $self, $c, $email ) =@_;

    my $is_abuse = $c->model('DB::Abuse')->find({ email => $email });

    $c->stash->{email_in_abuse} = 1 if $is_abuse;

    return 1;
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

    my @bodies = $c->model('DB::Body')->all;
    if ( $c->cobrand->moniker eq 'zurich' ) {
        @bodies = $c->cobrand->admin_fetch_all_bodies( @bodies );
    } else {
        @bodies = sort { strcoll($a->name, $b->name) } @bodies;
    }
    $c->stash->{bodies} = \@bodies;

    return 1;
}

sub fetch_body_areas : Private {
    my ($self, $c, $body ) = @_;

    my $body_area = $body->body_areas->first;

    unless ( $body_area ) {
        # Body doesn't have any areas defined.
        delete $c->stash->{areas};
        delete $c->stash->{fetched_areas_body_id};
        return;
    }

    my $areas = mySociety::MaPit::call('area/children', [ $body_area->area_id ],
        type => $c->cobrand->area_types_children,
    );

    $c->stash->{areas} = [ sort { strcoll($a->{name}, $b->{name}) } values %$areas ];
    # Keep track of the areas we've fetched to prevent a duplicate fetch later on
    $c->stash->{fetched_areas_body_id} = $body->id;
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
