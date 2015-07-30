package FixMyStreet::App::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Path::Class;
use POSIX qw(strftime strcoll);
use Digest::SHA qw(sha1_hex);
use mySociety::EmailUtil qw(is_valid_email);
use if !$ENV{TRAVIS}, 'Image::Magick';
use DateTime::Format::Strptime;


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

    if ( $c->cobrand->moniker eq 'zurich' || $c->cobrand->moniker eq 'seesomething' ) {
        $c->detach( '/auth/redirect' ) unless $c->user_exists;
        $c->detach( '/auth/redirect' ) unless $c->user->from_body;
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

    my $site_restriction = $c->cobrand->site_restriction();

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

    my $comments = $c->model('DB::Comment')->summary_count( $site_restriction );

    my %comment_counts =
      map { $_->state => $_->get_column('state_count') } $comments->all;

    $c->stash->{comments} = \%comment_counts;

    my $alerts = $c->model('DB::Alert')->summary_count( $c->cobrand->restriction );

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

    $c->stash->{categories} = $c->cobrand->problems->categories_summary();

    $c->stash->{total_bodies} = $c->model('DB::Body')->count();

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

    my $site_restriction = $c->cobrand->site_restriction();
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

    my $updates = $c->model('DB::Comment')->timeline( $site_restriction );

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

sub questionnaire : Path('questionnaire') : Args(0) {
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

    $c->forward( 'get_token' );

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
        $c->forward('check_token');

        my $params = $c->forward('body_params');
        my $body = $c->model('DB::Body')->create( $params );
        my @area_ids = $c->get_param_list('area_ids');
        foreach (@area_ids) {
            $c->model('DB::BodyArea')->create( { body => $body, area_id => $_ } );
        }

        $c->stash->{updated} = _('New body added');
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

    $c->forward( 'check_for_super_user' );
    $c->forward( 'get_token' );
    $c->forward( 'lookup_body' );
    $c->forward( 'fetch_all_bodies' );
    $c->forward( 'body_form_dropdowns' );

    if ( $c->get_param('posted') ) {
        $c->log->debug( 'posted' );
        $c->forward('update_contacts');
    }

    $c->forward('display_contacts');

    return 1;
}

sub check_for_super_user : Private {
    my ( $self, $c ) = @_;
    if ( $c->cobrand->moniker eq 'zurich' && $c->stash->{admin_type} ne 'super' ) {
        $c->detach('/page_error_404_not_found', []);
    }
}

sub update_contacts : Private {
    my ( $self, $c ) = @_;

    my $posted = $c->get_param('posted');
    my $editor = $c->forward('get_user');

    if ( $posted eq 'new' ) {
        $c->forward('check_token');

        my %errors;

        my $category = $self->trim( $c->get_param('category') );
        $errors{category} = _("Please choose a category") unless $category;
        my $email = $self->trim( $c->get_param('email') );
        $errors{email} = _('Please enter a valid email') unless is_valid_email($email) || $email eq 'REFUSED';
        $errors{note} = _('Please enter a message') unless $c->get_param('note');

        $category = 'Empty property' if $c->cobrand->moniker eq 'emptyhomes';

        my $contact = $c->model('DB::Contact')->find_or_new(
            {
                body_id => $c->stash->{body_id},
                category => $category,
            }
        );

        $contact->email( $email );
        $contact->confirmed( $c->get_param('confirmed') ? 1 : 0 );
        $contact->deleted( $c->get_param('deleted') ? 1 : 0 );
        $contact->non_public( $c->get_param('non_public') ? 1 : 0 );
        $contact->note( $c->get_param('note') );
        $contact->whenedited( \'ms_current_timestamp()' );
        $contact->editor( $editor );
        $contact->endpoint( $c->get_param('endpoint') );
        $contact->jurisdiction( $c->get_param('jurisdiction') );
        $contact->api_key( $c->get_param('api_key') );
        $contact->send_method( $c->get_param('send_method') );

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
        $c->forward('check_token');

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
                whenedited => \'ms_current_timestamp()',
                note => 'Confirmed',
                editor => $editor,
            }
        );

        $c->stash->{updated} = _('Values updated');
    } elsif ( $posted eq 'body' ) {
        $c->forward('check_for_super_user');
        $c->forward('check_token');

        my $params = $c->forward( 'body_params' );
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
    return \%params;
}

sub display_contacts : Private {
    my ( $self, $c ) = @_;

    my $contacts = $c->stash->{body}->contacts->search(undef, { order_by => [ 'category' ] } );
    $c->stash->{contacts} = $contacts;
    $c->stash->{live_contacts} = $contacts->search({ deleted => 0 });

    if ( $c->get_param('text') && $c->get_param('text') == 1 ) {
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
    $c->detach( '/page_error_404_not_found' )
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

    $c->forward( 'get_token' );
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

        my $site_restriction = $c->cobrand->site_restriction;

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
            my $updates = $c->model('DB::Comment')->search(
                {
                    %{ $site_restriction },
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

    my $site_restriction = $c->cobrand->site_restriction;

    my $problem = $c->cobrand->problems->search( { id => $id } )->first;

    $c->detach( '/page_error_404_not_found' )
      unless $problem;

    $c->stash->{problem} = $problem;

    $c->forward('get_token');

    if ( $c->cobrand->moniker eq 'zurich' ) {
        $c->stash->{page} = 'admin';
        FixMyStreet::Map::display_map(
            $c,
            latitude  => $problem->latitude,
            longitude => $problem->longitude,
            pins      => $problem->used_map
            ? [ {
                latitude  => $problem->latitude,
                longitude => $problem->longitude,
                colour    => $c->cobrand->pin_colour($problem),
                type      => 'big',
              } ]
            : [],
        );
    }

    if ( $c->get_param('rotate_photo') ) {
        $c->forward('rotate_photo');
        return 1;
    }

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
        $c->forward('check_token');

        $problem->whensent(undef);
        $problem->update();
        $c->stash->{status_message} =
          '<p><em>' . _('That problem will now be resent.') . '</em></p>';

        $c->forward( 'log_edit', [ $id, 'problem', 'resend' ] );
    }
    elsif ( $c->get_param('mark_sent') ) {
        $c->forward('check_token');
        $problem->whensent(\'ms_current_timestamp()');
        $problem->update();
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
        $c->forward('check_token');

        my $done   = 0;
        my $edited = 0;

        my $new_state = $c->get_param('state');
        my $old_state = $problem->state;
        if (   $new_state eq 'confirmed'
            && $problem->state eq 'unconfirmed'
            && $c->cobrand->moniker eq 'emptyhomes' )
        {
            $c->stash->{status_message} =
                '<p><em>'
              . _('I am afraid you cannot confirm unconfirmed reports.')
              . '</em></p>';
            $done = 1;
        }

        my $flagged = $c->get_param('flagged') ? 1 : 0;
        my $non_public = $c->get_param('non_public') ? 1 : 0;

        # do this here so before we update the values in problem
        if ( $c->get_param('anonymous') ne $problem->anonymous
            || $c->get_param('name') ne $problem->name
            || $c->get_param('email') ne $problem->user->email
            || $c->get_param('title') ne $problem->title
            || $c->get_param('detail') ne $problem->detail
            || ($c->get_param('body') && $c->get_param('body') ne $problem->bodies_str)
            || $flagged != $problem->flagged
            || $non_public != $problem->non_public )
        {
            $edited = 1;
        }

        $problem->anonymous( $c->get_param('anonymous') );
        $problem->title( $c->get_param('title') );
        $problem->detail( $c->get_param('detail') );
        $problem->state( $new_state );
        $problem->name( $c->get_param('name') );
        $problem->bodies_str( $c->get_param('body') ) if $c->get_param('body');

        $problem->flagged( $flagged );
        $problem->non_public( $non_public );

        if ( $c->get_param('email') ne $problem->user->email ) {
            my $user = $c->model('DB::User')->find_or_create(
                { email => $c->get_param('email') }
            );

            $user->insert unless $user->in_storage;
            $problem->user( $user );
        }

        # Deal with photos
        if ( $c->get_param('remove_photo') ) {
            $problem->photo(undef);
        }

        if ( $c->get_param('remove_photo') || $new_state eq 'hidden' ) {
            unlink glob FixMyStreet->path_to( 'web', 'photo', $problem->id . '.*' );
        }

        if ( $problem->is_visible() and $old_state eq 'unconfirmed' ) {
            $problem->confirmed( \'ms_current_timestamp()' );
        }

        if ($done) {
            $problem->discard_changes;
        }
        else {
            $problem->lastupdate( \'ms_current_timestamp()' ) if $edited || $new_state ne $old_state;
            $problem->update;

            if ( $new_state ne $old_state ) {
                $c->forward( 'log_edit', [ $id, 'problem', 'state_change' ] );
            }
            if ($edited) {
                $c->forward( 'log_edit', [ $id, 'problem', 'edit' ] );
            }

            $c->stash->{status_message} =
              '<p><em>' . _('Updated!') . '</em></p>';

            # do this here otherwise lastupdate and confirmed times
            # do not display correctly
            $problem->discard_changes;
        }
    }

    return 1;
}

sub users: Path('users') : Args(0) {
    my ( $self, $c ) = @_;

    if (my $search = $c->get_param('search')) {
        $c->stash->{searched} = $search;

        my $isearch = '%' . $search . '%';
        my $search_n = 0;
        $search_n = int($search) if $search =~ /^\d+$/;

        my $users = $c->model('DB::User')->search(
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

        my $emails = $c->model('DB::Abuse')->search(
            {
                email => { ilike => $isearch }
            }
        );
        foreach my $email ($emails->all) {
            # Slight abuse of the boolean flagged value
            if ($email2user{$email->email}) {
                $email2user{$email->email}->flagged( 2 );
            } else {
                push @{$c->stash->{users}}, { email => $email->email, flagged => 2 };
            }
        }

    } else {
        $c->forward('get_token');
        $c->forward('fetch_all_bodies');

        # Admin users by default
        my $users = $c->model('DB::User')->search(
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

    my $site_restriction = $c->cobrand->site_restriction;
    my $update = $c->model('DB::Comment')->search(
        {
            id => $id,
            %{$site_restriction},
        }
    )->first;

    $c->detach( '/page_error_404_not_found' )
      unless $update;

    $c->forward('get_token');

    $c->stash->{update} = $update;

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
        $c->forward('check_token');

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

        if ( $c->get_param('remove_photo') ) {
            $update->photo(undef);
        }

        if ( $c->get_param('remove_photo') || $new_state eq 'hidden' ) {
            unlink glob FixMyStreet->path_to( 'web', 'photo', 'c', $update->id . '.*' );
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
            $update->confirmed( \'ms_current_timestamp()' );
            if ( $update->problem_state && $update->created > $update->problem->lastupdate ) {
                $update->problem->state( $update->problem_state );
                $update->problem->lastupdate( \'ms_current_timestamp()' );
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
    $c->forward('get_token');
    $c->forward('fetch_all_bodies');

    return 1 unless $c->get_param('submit');

    $c->forward('check_token');

    if ( $c->cobrand->moniker eq 'zurich' and $c->get_param('email') eq '' ) {
        $c->stash->{field_errors}->{email} = _('Please enter a valid email');
        return 1;
    }

    return unless $c->get_param('name') && $c->get_param('email');

    my $user = $c->model('DB::User')->find_or_create( {
        name => $c->get_param('name'),
        email => $c->get_param('email'),
        from_body => $c->get_param('body') || undef,
        flagged => $c->get_param('flagged') || 0,
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

    $c->forward('get_token');

    my $user = $c->model('DB::User')->find( { id => $id } );
    $c->stash->{user} = $user;

    $c->forward('fetch_all_bodies');

    if ( $c->get_param('submit') ) {
        $c->forward('check_token');

        my $edited = 0;

        if ( $user->email ne $c->get_param('email') ||
            $user->name ne $c->get_param('name') ||
            ($user->from_body && $user->from_body->id ne $c->get_param('body')) ||
            (!$user->from_body && $c->get_param('body'))
        ) {
                $edited = 1;
        }

        $user->name( $c->get_param('name') );
        $user->email( $c->get_param('email') );
        $user->from_body( $c->get_param('body') || undef );
        $user->flagged( $c->get_param('flagged') || 0 );

        if ( $c->cobrand->moniker eq 'zurich' and $user->email eq '' ) {
            $c->stash->{field_errors}->{email} = _('Please enter a valid email');
            return 1;
        }
        $user->update;

        if ($edited) {
            $c->forward( 'log_edit', [ $id, 'user', 'edit' ] );
        }

        $c->stash->{status_message} =
          '<p><em>' . _('Updated!') . '</em></p>';
    }

    return 1;
}

sub flagged : Path('flagged') : Args(0) {
    my ( $self, $c ) = @_;

    my $problems = $c->model('DB::Problem')->search( { flagged => 1 } );

    # pass in as array ref as using same template as search_reports
    # which has to use an array ref for sql quoting reasons
    $c->stash->{problems} = [ $problems->all ];

    my $users = $c->model('DB::User')->search( { flagged => 1 } );
    my @users = $users->all;
    my %email2user = map { $_->email => $_ } @users;
    $c->stash->{users} = [ @users ];

    my @abuser_emails = $c->model('DB::Abuse')->all();

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

sub stats : Path('stats') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('fetch_all_bodies');

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
        my ( %body, %dates );
        $body{bodies_str} = { like => $c->get_param('body') }
            if $c->get_param('body');

        $c->stash->{selected_body} = $c->get_param('body');

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

        my $p = $c->model('DB::Problem')->search(
            {
                -AND => [
                    $field => { '>=', $start_date},
                    $field => { '<=', $end_date + $one_day },
                ],
                %body,
                %dates,
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

    if( !$pages ) {
        $pages = {
             'summary' => [_('Summary'), 0],
             'bodies' => [_('Bodies'), 1],
             'reports' => [_('Reports'), 2],
             'timeline' => [_('Timeline'), 3],
             'questionnaire' => [_('Survey'), 4],
             'users' => [_('Users'), 5],
             'flagged'  => [_('Flagged'), 6],
             'stats'  => [_('Stats'), 7],
             'config' => [ _('Configuration'), 8],
             'user_edit' => [undef, undef], 
             'body' => [undef, undef],
             'report_edit' => [undef, undef],
             'update_edit' => [undef, undef],
             'abuse_edit'  => [undef, undef],
        }
    }

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

=item get_token

Generate a token based on user and secret

=cut

sub get_token : Private {
    my ( $self, $c ) = @_;

    my $secret = $c->model('DB::Secret')->search()->first;
    my $user = $c->forward('get_user');
    my $token = sha1_hex($user . $secret->secret);
    $c->stash->{token} = $token;

    return 1;
}

=item check_token

Check that a token has been set on a request and it's the correct token. If
not then display 404 page

=cut

sub check_token : Private {
    my ( $self, $c ) = @_;

    if ( !$c->get_param('token') || $c->get_param('token') ne $c->stash->{token} ) {
        $c->detach( '/page_error_404_not_found' );
    }

    return 1;
}

=item log_edit

    $c->forward( 'log_edit', [ $object_id, $object_type, $action_performed ] );

Adds an entry into the admin_log table using the current user.

=cut

sub log_edit : Private {
    my ( $self, $c, $id, $object_type, $action ) = @_;
    $c->model('DB::AdminLog')->create(
        {
            admin_user => $c->forward('get_user'),
            object_type => $object_type,
            action => $action,
            object_id => $id,
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

    my $user = $c->model('DB::User')->find({ email => $email });

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

    my $user = $c->model('DB::User')->find({ email => $email });

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

sub rotate_photo : Private {
    my ( $self, $c ) =@_;

    my $direction = $c->get_param('rotate_photo');
    return unless $direction eq _('Rotate Left') or $direction eq _('Rotate Right');

    my $photo = $c->stash->{problem}->photo;
    my $file;

    # If photo field contains a hash
    if ( length($photo) == 40 ) {
        $file = file( $c->config->{UPLOAD_DIR}, "$photo.jpeg" );
        $photo = $file->slurp;
    }

    $photo = _rotate_image( $photo, $direction eq _('Rotate Left') ? -90 : 90 );
    return unless $photo;

    # Write out to new location
    my $fileid = sha1_hex($photo);
    $file = file( $c->config->{UPLOAD_DIR}, "$fileid.jpeg" );

    my $fh = $file->open('w');
    print $fh $photo;
    close $fh;

    unlink glob FixMyStreet->path_to( 'web', 'photo', $c->stash->{problem}->id . '.*' );

    $c->stash->{problem}->photo( $fileid );
    $c->stash->{problem}->update();

    return 1;
}

=head2 check_page_allowed

Checks if the current catalyst action is in the list of allowed pages and
if not then redirects to 404 error page.

=cut

sub check_page_allowed : Private {
    my ( $self, $c ) = @_;

    $c->forward('set_allowed_pages');

    (my $page = $c->req->action) =~ s#admin/?##;

    $page ||= 'summary';

    if ( !grep { $_ eq $page } keys %{ $c->stash->{allowed_pages} } ) {
        $c->detach( '/page_error_404_not_found' );
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

sub trim {
    my $self = shift;
    my $e = shift;
    $e =~ s/^\s+//;
    $e =~ s/\s+$//;
    return $e;
}

sub _rotate_image {
    my ($photo, $direction) = @_;
    my $image = Image::Magick->new;
    $image->BlobToImage($photo);
    my $err = $image->Rotate($direction);
    return 0 if $err;
    my @blobs = $image->ImageToBlob();
    undef $image;
    return $blobs[0];
}


=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
