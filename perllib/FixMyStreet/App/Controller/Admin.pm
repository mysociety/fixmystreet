package FixMyStreet::App::Controller::Admin;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use POSIX qw(strftime strcoll);
use Digest::MD5 qw(md5_hex);

=head1 NAME

FixMyStreet::App::Controller::Admin- Catalyst Controller

=head1 DESCRIPTION

Admin pages

=head1 METHODS

=cut

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

    $c->forward('set_allowed_pages');

    my ( $sql_resttriction, $id, $site_restriction ) = $c->cobrand->site_restriction();
    my $cobrand_restriction = $c->cobrand->moniker eq 'fixmystreet' ? {} : { cobrand => $c->cobrand->moniker };

    my $problems = $c->model('DB::Problem')->search(
        $site_restriction,
        {
            group_by => ['state'],
            select   => [ 'state', { count => 'id' } ],
            as       => [qw/state state_count/]
        }
    );

    my %prob_counts =
      map { $_->state => $_->get_column('state_count') } $problems->all;

    %prob_counts =
      map { $_ => $prob_counts{$_} || 0 }
      qw(confirmed fixed unconfirmed hidden partial);
    $c->stash->{problems} = \%prob_counts;
    $c->stash->{total_problems_live} =
      $prob_counts{confirmed} + $prob_counts{fixed};

    my $comments = $c->model('DB::Comment')->search(
        $site_restriction,
        {
            group_by => ['me.state'],
            select   => [ 'me.state', { count => 'me.id' } ],
            as       => [qw/state state_count/],
            join     => 'problem'
        }
    );

    my %comment_counts =
      map { $_->state => $_->get_column('state_count') } $comments->all;

    $c->stash->{comments} = \%comment_counts;

    my $alerts = $c->model('DB::Alert')->search(
        $cobrand_restriction,
        {
            group_by => ['confirmed'],
            select   => [ 'confirmed', { count => 'id' } ],
            as       => [qw/confirmed confirmed_count/]
        }
    );

    my %alert_counts =
      map { $_->confirmed => $_->get_column('confirmed_count') } $alerts->all;

    $alert_counts{0} ||= 0;
    $alert_counts{1} ||= 0;

    $c->stash->{alerts} = \%alert_counts;

    my $contacts = $c->model('DB::Contact')->search(
        undef,
        {
            group_by => ['confirmed'],
            select   => [ 'confirmed', { count => 'id' } ],
            as       => [qw/confirmed confirmed_count/]
        }
    );

    my %contact_counts =
      map { $_->confirmed => $_->get_column('confirmed_count') } $contacts->all;

    $contact_counts{0} ||= 0;
    $contact_counts{1} ||= 0;
    $contact_counts{total} = $contact_counts{0} + $contact_counts{1};

    $c->stash->{contacts} = \%contact_counts;

    my $questionnaires = $c->model('DB::Questionnaire')->search(
        $cobrand_restriction,
        {
            group_by => [ \'whenanswered is not null' ],
            select   => [ \'(whenanswered is not null)', { count => 'me.id' } ],
            as       => [qw/answered questionnaire_count/],
            join     => 'problem'
        }
    );

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
      : 'na';
    $c->stash->{questionnaires} = \%questionnaire_counts;

    return 1;
}

sub questionnaire : Path('questionnaire') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('set_allowed_pages');

    my $questionnaires = $c->model('DB::Questionnaire')->search(
        { whenanswered => \'is not null' }, { group_by => [ 'ever_reported' ], select => [ 'ever_reported', { count => 'me.id' } ], as => [qw/reported questionnaire_count/] }
    );


    my %questionnaire_counts = map { $_->get_column( 'reported' ) => $_->get_column( 'questionnaire_count' ) } $questionnaires->all;

    $questionnaire_counts{1} ||= 0;
    $questionnaire_counts{0} ||= 0;

    $questionnaire_counts{total} = $questionnaire_counts{0} + $questionnaire_counts{1};
    $c->stash->{reported_pc} = ( 100 * $questionnaire_counts{1} ) / $questionnaire_counts{total};
    $c->stash->{not_reported_pc} = ( 100 * $questionnaire_counts{0} ) / $questionnaire_counts{total};
    $c->stash->{questionnaires} = \%questionnaire_counts;

    return 1;
}

sub council_list : Path('council_list') : Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('set_allowed_pages');

    my $edit_activity = $c->model('DB::ContactsHistory')->search(
        undef,
        {
            select => [ 'editor', { count => 'contacts_history_id', -as => 'c' } ],
            group_by => ['editor'],
            order_by => { -desc => 'c' }
        }
    );

    $c->stash->{edit_activity} = $edit_activity;

    my @area_types = $c->cobrand->area_types;
    my $areas = mySociety::MaPit::call('areas', \@area_types);

    my @councils_ids = sort { strcoll($areas->{$a}->{name}, $areas->{$b}->{name}) } keys %$areas;
    @councils_ids = $c->cobrand->filter_all_council_ids_list( @councils_ids );

    my $contacts = $c->model('DB::Contact')->search(
        undef,
        {
            select => [ 'area_id', { count => 'id' }, { count => \'case when deleted then 1 else null end' },
            { count => \'case when confirmed then 1 else null end' } ],
            as => [qw/area_id c deleted confirmed/],
            group_by => [ 'area_id' ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator'
        }
    );

    my %council_info = map { $_->{area_id} => $_ } $contacts->all;

    my @no_info = grep { !$council_info{$_} } @councils_ids;
    my @one_plus_deleted = grep { $council_info{$_} && $council_info{$_}->{deleted} } @councils_ids;
    my @unconfirmeds = grep { $council_info{$_} && !$council_info{$_}->{deleted} && $council_info{$_}->{confirmed} != $council_info{$_}->{c} } @councils_ids;
    my @all_confirmed = grep { $council_info{$_} && !$council_info{$_}->{deleted} && $council_info{$_}->{confirmed} == $council_info{$_}->{c} } @councils_ids;

    $c->stash->{areas} = $areas;
    $c->stash->{counts} = \%council_info;
    $c->stash->{no_info} = \@no_info;
    $c->stash->{one_plus_deleted} = \@one_plus_deleted;
    $c->stash->{unconfirmeds} = \@unconfirmeds;
    $c->stash->{all_confirmed} = \@all_confirmed;

    return 1;
}

sub council_contacts : Path('council_contacts') : Args(1) {
    my ( $self, $c, $area_id ) = @_;

    $c->forward('set_allowed_pages');

    my $posted = $c->req->param('posted') || '';
    $c->stash->{area_id} = $area_id;

    $c->forward( 'get_token' );

    if ( $posted ) {
        $c->log->debug( 'posted' );
        $c->forward('update_contacts');
    }

    $c->forward('display_contacts');

    return 1;
}

sub update_contacts : Private {
    my ( $self, $c ) = @_;

    my $posted = $c->req->param('posted');
    my $editor = $c->req->remote_user || _('*unknown*');

    if ( $posted eq 'new' ) {
        $c->forward('check_token');

        my $category = $self->trim( $c->req->param( 'category' ) );
        my $email = $self->trim( $c->req->param( 'email' ) );

        $category = 'Empty property' if $c->cobrand->moniker eq 'emptyhomes';

        my $contact = $c->model('DB::Contact')->find_or_new(
            {
                area_id => $c->stash->{area_id},
                category => $category,
            }
        );

        $contact->email( $email );
        $contact->confirmed( $c->req->param('confirmed') ? 1 : 0 );
        $contact->deleted( $c->req->param('deleted') ? 1 : 0 );
        $contact->note( $c->req->param('note') );
        $contact->whenedited( \'ms_current_timestamp()' );
        $contact->editor( $editor );

        if ( $contact->in_storage ) {
            $c->stash->{updated} = _('Values updated');

            # NB: History is automatically stored by a trigger in the database
            $contact->update;
        } else {
            $c->stash->{updated} = _('New category contact added');
            $contact->insert;
        }

    } elsif ( $posted eq 'update' ) {
        $c->forward('check_token');

        my @categories = $c->req->param('confirmed');

        my $contacts = $c->model('DB::Contact')->search(
            {
                area_id => $c->stash->{area_id},
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
    }
}

sub display_contacts : Private {
    my ( $self, $c ) = @_;

    $c->forward('setup_council_details');

    my $area_id = $c->stash->{area_id};

    my $contacts = $c->model('DB::Contact')->search(
        { area_id => $area_id },
        { order_by => ['category'] }
    );

    $c->stash->{contacts} = $contacts;

    if ( $c->req->param('text') && $c->req->param('text') == 1 ) {
        $c->stash->{template} = 'admin/council_contacts.txt';
        $c->res->content_encoding('text/plain');
        return 1;
    }

    return 1;
}

sub setup_council_details : Private {
    my ( $self, $c ) = @_;

    my $area_id = $c->stash->{area_id};

    my $mapit_data = mySociety::MaPit::call('area', $area_id);

    $c->stash->{council_name} = $mapit_data->{name};

    my $example_postcode = mySociety::MaPit::call('area/example_postcode', $area_id);

    if ($example_postcode && ! ref $example_postcode) {
        $c->stash->{example_pc} = $example_postcode;
    }

    return 1;
}

sub council_edit : Path('council_edit') : Args(2) {
    my ( $self, $c, $area_id, $category ) = @_;

    $c->forward('set_allowed_pages');

    $c->stash->{area_id} = $area_id;

    $c->forward( 'get_token' );
    $c->forward('setup_council_details');

    my $contact = $c->model('DB::Contact')->search(
        {
            area_id => $area_id,
            category => $category
        }
    )->first;

    $c->stash->{contact} = $contact;

    my $history = $c->model('DB::ContactsHistory')->search(
        {
            area_id => $area_id,
            category => $category
        },
        {
            order_by => ['contacts_history_id']
        },
    );

    $c->stash->{history} = $history;

    return 1;
}

sub search_reports : Path('search_reports') {
    my ( $self, $c ) = @_;

    $c->forward('set_allowed_pages');

    if (my $search = $c->req->param('search')) {
        $c->stash->{searched} = 1;

        my ( $site_res_sql, $site_key, $site_restriction ) = $c->cobrand->site_restriction;

        my $search_n = 0;
        $search_n = int($search) if $search =~ /^\d+$/;

        my $like_search = "%$search%";

        # when DBIC creates the join it does 'JOIN users user' in the
        # SQL which makes PostgreSQL unhappy as user is a reserved
        # word, hence we need to quote this SQL. However, the quoting
        # makes PostgreSQL unhappy elsewhere so we only want to do
        # it for this query and then switch it off afterwards.
        $c->model('DB')->schema->storage->sql_maker->quote_char( '"' );

        my $problems = $c->model('DB::Problem')->search(
            {
                -or => [
                    'me.id' => $search_n,
                    'user.email' => { ilike => $like_search },
                    'me.name' => { ilike => $like_search },
                    title => { ilike => $like_search },
                    detail => { ilike => $like_search },
                    council => { like => $like_search },
                    cobrand_data => { like => $like_search },
                    %{ $site_restriction },
                ]
            },
            {
                prefetch => 'user',
                order_by => [\"(state='hidden')",'created']
            }
        );

        $c->stash->{problems} = [ $problems->all ];


        $c->stash->{edit_council_contacts} = 1
            if ( grep {$_ eq 'councilcontacts'} keys %{$c->stash->{allowed_pages}});

        my $updates = $c->model('DB::Comment')->search(
            {
                -or => [
                    'me.id' => $search_n,
                    'problem.id' => $search_n,
                    'user.email' => { ilike => $like_search },
                    'me.name' => { ilike => $like_search },
                    text => { ilike => $like_search },
                    'me.cobrand_data' => { ilike => $like_search },
                    %{ $site_restriction },
                ]
            },
            {
                -select   => [ 'me.*', qw/problem.council problem.state/ ],
                prefetch => [qw/user problem/],
                order_by => [\"(me.state='hidden')",\"(problem.state='hidden')",'me.created']
            }
        );

        $c->stash->{updates} = [ $updates->all ];

        # Switch quoting back off. See above for explanation of this.
        $c->model('DB')->schema->storage->sql_maker->quote_char( '' );
    }
}

sub report_edit : Path('report_edit') : Args(1) {
    my ( $self, $c, $id ) = @_;

    my ( $site_res_sql, $site_key, $site_restriction ) = $c->cobrand->site_restriction;

    my $problem = $c->model('DB::Problem')->search(
        {
            id => $id,
            %{ $site_restriction },
        }
    )->first;

    $c->detach( '/page_error_404_not_found',
        [ _('The requested URL was not found on this server.') ] )
      unless $problem;

    $c->stash->{problem} = $problem;

    $c->forward('get_token');
    $c->forward('set_allowed_pages');

    $c->stash->{updates} =
      [ $c->model('DB::Comment')
          ->search( { problem_id => $problem->id }, { order_by => 'created' } )
          ->all ];

    if ( $c->req->param('resend') ) {
        $c->forward('check_token');

        $problem->whensent(undef);
        $problem->update();
        $c->stash->{status_message} =
          '<p><em>' . _('That problem will now be resent.') . '</em></p>';

        $c->forward( 'log_edit', [ $id, 'problem', 'resend' ] );
    }
    elsif ( $c->req->param('submit') ) {
        $c->forward('check_token');

        my $done   = 0;
        my $edited = 0;

        my $new_state = $c->req->param('state');
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

        # do this here so before we update the values in problem
        if (   $c->req->param('anonymous') ne $problem->anonymous
            || $c->req->param('name')   ne $problem->name
            || $c->req->param('email')  ne $problem->user->email
            || $c->req->param('title')  ne $problem->title
            || $c->req->param('detail') ne $problem->detail )
        {
            $edited = 1;
        }

        $problem->anonymous( $c->req->param('anonymous') );
        $problem->title( $c->req->param('title') );
        $problem->detail( $c->req->param('detail') );
        $problem->state( $c->req->param('state') );
        $problem->name( $c->req->param('name') );

        if ( $c->req->param('email') ne $problem->user->email ) {
            my $user = $c->model('DB::User')->find_or_create(
                { email => $c->req->param('email') }
            );

            $user->insert unless $user->in_storage;
            $problem->user( $user );
        }

        if ( $c->req->param('remove_photo') ) {
            $problem->photo(undef);
        }

        if ( $new_state ne $old_state ) {
            $problem->lastupdate( \'ms_current_timestamp()' );
        }

        if ( $new_state eq 'confirmed' and $old_state eq 'unconfirmed' ) {
            $problem->confirmed( \'ms_current_timestamp()' );
        }

        if ($done) {
            $problem->discard_changes;
        }
        else {
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
             'council_list' => [_('Council contacts'), 1],
             'search_reports' => [_('Search Reports'), 2],
             'timeline' => [_('Timeline'), 3],
             'questionnaire' => [_('Survey Results'), 4],
             'council_contacts' => [undef, undef],        
             'council_edit' => [undef, undef], 
             'report_edit' => [undef, undef], 
             'update_edit' => [undef, undef], 
        }
    }

    my @allowed_links = sort {$pages->{$a}[1] <=> $pages->{$b}[1]}  grep {$pages->{$_}->[0] } keys %$pages;

    $c->stash->{allowed_pages} = $pages;
    $c->stash->{allowed_links} = \@allowed_links;

    return 1;
}

=item get_token

Generate a token based on user and secret

=cut

sub get_token : Private {
    my ( $self, $c ) = @_;

    my $secret = $c->model('DB::Secret')->search()->first;

    my $user = $c->req->remote_user();
    $user ||= '';

    my $token = md5_hex(($user . $secret->secret));

    $c->stash->{token} = $token;

    return 1;
}

=item check_token

Check that a token has been set on a request and it's the correct token. If
not then display 404 page

=cut

sub check_token : Private {
    my ( $self, $c ) = @_;

    if ( $c->req->param('token' ) ne $c->stash->{token} ) {
        $c->detach( '/page_error_404_not_found', [ _('The requested URL was not found on this server.') ] );
    }

    return 1;
}

=item log_edit

    $c->forward( 'log_edit', [ $object_id, $object_type, $action_performed ] );

Adds an entry into the admin_log table using the current remote_user.

=cut

sub log_edit : Private {
    my ( $self, $c, $id, $object_type, $action ) = @_;
    $c->model('DB::AdminLog')->create(
        {
            admin_user => ( $c->req->remote_user() || '' ),
            object_type => $object_type,
            action => $action,
            object_id => $id,
        }
    )->insert();
}

sub update_edit : Path('update_edit') : Args(1) {
    my ( $self, $c, $id ) = @_;

    my ( $site_res_sql, $site_key, $site_restriction ) =
      $c->cobrand->site_restriction;
    my $update = $c->model('DB::Comment')->search(
        {
            id => $id,
            %{$site_restriction},
        }
    )->first;

    $c->detach( '/page_error_404_not_found',
        [ _('The requested URL was not found on this server.') ] )
      unless $update;

    $c->forward('get_token');
    $c->forward('set_allowed_pages');

    $c->stash->{update} = $update;

    my $status_message = '';
    if ( $c->req->param('submit') ) {
        $c->forward('check_token');

        my $old_state = $update->state;
        my $new_state = $c->req->param('state');

        my $edited = 0;

        if (   $c->req->param('name') ne $update->name
            || $c->req->param('email')     ne $update->user->email
            || $c->req->param('anonymous') ne $update->anonymous
            || $c->req->param('text')      ne $update->text )
        {
            $edited = 1;
        }

        if ( $c->req->param('remove_photo') ) {
            $update->photo(undef);
        }

        $update->name( $c->req->param('name') || '' );
        $update->text( $c->req->param('text') );
        $update->anonymous( $c->req->param('anonymous') );
        $update->state( $c->req->param('state') );

        if ( $c->req->param('email') ne $update->user->email ) {
            my $user =
              $c->model('DB::User')
              ->find_or_create( { email => $c->req->param('email') } );

            $user->insert unless $user->in_storage;
            $update->user($user);
        }

        $update->update;

        $status_message = '<p><em>' . _('Updated!') . '</em></p>';

        # If we're hiding an update, see if it marked as fixed and unfix if so
        if ( $new_state eq 'hidden' && $update->mark_fixed ) {
            if ( $update->problem->state eq 'fixed' ) {
                $update->problem->state('confirmed');
                $update->problem->update;
            }

            $status_message .=
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
    $c->stash->{status_message} = $status_message;

    return 1;
}

# sub admin_timeline {
#     my $q = shift;
#     my $cobrand = Page::get_cobrand($q);
#     print html_head($q, _('Timeline'));
#     print $q->h1(_('Timeline'));
# 
#     my %time;
#     #my $backto_unix = time() - 60*60*24*7;
# 
#     my $probs = Problems::timeline_problems();
#     foreach (@$probs) {
#         push @{$time{$_->{created}}}, { type => 'problemCreated', %$_ };
#         push @{$time{$_->{confirmed}}}, { type => 'problemConfirmed', %$_ } if $_->{confirmed};
#         push @{$time{$_->{whensent}}}, { type => 'problemSent', %$_ } if $_->{whensent};
#     }
# 
#     my $questionnaire = Problems::timeline_questionnaires($cobrand);
#     foreach (@$questionnaire) {
#         push @{$time{$_->{whensent}}}, { type => 'quesSent', %$_ };
#         push @{$time{$_->{whenanswered}}}, { type => 'quesAnswered', %$_ } if $_->{whenanswered};
#     }
# 
#     my $updates = Problems::timeline_updates();
#     foreach (@$updates) {
#         push @{$time{$_->{created}}}, { type => 'update', %$_} ;
#     }
# 
#     my $alerts = Problems::timeline_alerts($cobrand);
# 
#    
#     foreach (@$alerts) {
#         push @{$time{$_->{whensubscribed}}}, { type => 'alertSub', %$_ };
#     }
#     $alerts = Problems::timeline_deleted_alerts($cobrand);
#     foreach (@$alerts) {
#         push @{$time{$_->{whendisabled}}}, { type => 'alertDel', %$_ };
#     }
# 
#     my $date = '';
#     my $cobrand_data;
#     foreach (reverse sort keys %time) {
#         my $curdate = decode_utf8(strftime('%A, %e %B %Y', localtime($_)));
#         if ($date ne $curdate) {
#             print '</dl>' if $date;
#             print "<h2>$curdate</h2> <dl>";
#             $date = $curdate;
#         }
#         print '<dt><b>', decode_utf8(strftime('%H:%M:%S', localtime($_))), ':</b></dt> <dd>';
#         foreach (@{$time{$_}}) {
#             my $type = $_->{type};
#             if ($type eq 'problemCreated') {
#                 my $name_str = '; ' . sprintf(_("by %s"), ent($_->{name})) . " &lt;" . ent($_->{email}) . "&gt;, '" . ent($_->{title}) . "'";
#                 print sprintf(_("Problem %d created"), $_->{id}) . $name_str;
#             } elsif ($type eq 'problemConfirmed') {
#                 my $name_str = '; ' . sprintf(_("by %s"), ent($_->{name})) . " &lt;" . ent($_->{email}) . "&gt;, '" . ent($_->{title}) . "'";
#                 $cobrand_data = get_cobrand_data_from_hash($cobrand, $_);
#                 my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data)  . "/report/$_->{id}";
#                 print sprintf(_("Problem %s confirmed"), "<a href='$url'>$_->{id}</a>") . $name_str;
#             } elsif ($type eq 'problemSent') {
#                 $cobrand_data = get_cobrand_data_from_hash($cobrand, $_);
#                 my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data) . "/report/$_->{id}";
#                 print sprintf(_("Problem %s sent to council %s"), "<a href='$url'>$_->{id}</a>", $_->{council});
#             } elsif ($type eq 'quesSent') {
#                 print sprintf(_("Questionnaire %d sent for problem %d"), $_->{id}, $_->{problem_id});
#             } elsif ($type eq 'quesAnswered') {
#                 print sprintf(_("Questionnaire %d answered for problem %d, %s to %s"), $_->{id}, $_->{problem_id}, $_->{old_state}, $_->{new_state});
#             } elsif ($type eq 'update') {
#                 $cobrand_data = get_cobrand_data_from_hash($cobrand, $_);
#                 my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data) . "/report/$_->{problem_id}#$_->{id}";
#                 my $name = ent($_->{name} || 'anonymous');
#                 print sprintf(_("Update %s created for problem %d; by %s"), "<a href='$url'>$_->{id}</a>", $_->{problem_id}, $name) . " &lt;" . ent($_->{email}) . "&gt;";
#             } elsif ($type eq 'alertSub') {
#                 my $param = $_->{parameter} || '';
#                 my $param2 = $_->{parameter2} || '';
#                 print sprintf(_("Alert %d created for %s, type %s, parameters %s / %s"), $_->{id}, ent($_->{email}), $_->{alert_type}, $param, $param2);
#             } elsif ($type eq 'alertDel') {
#                 my $sub = decode_utf8(strftime('%H:%M:%S %e %B %Y', localtime($_->{whensubscribed})));
#                 print sprintf(_("Alert %d disabled (created %s)"), $_->{id}, $sub);
#             }
#             print '<br>';
#         }
#         print "</dd>\n";
#     }
#     print html_tail($q);
# 
# }
# 
# 
# sub main {
#     my $q = shift;
# 
#     my $logout = $q->param('logout');
#     my $timeout = $q->param('timeout');
#     if ($logout) {
#         if (!$timeout) {
#             print $q->redirect(-location => '?logout=1;timeout=' . (time() + 7));
#             return;
#         }
#         if (time() < $timeout) {
#             print $q->header(
#                 -status => '401 Unauthorized',
#                 -www_authenticate => 'Basic realm="www.fixmystreet.com admin pages"'
#             );
#             return;
#         }
#     }
# 
#     my $page = $q->param('page');
#     $page = "summary" if !$page;
# 
#     my $area_id = $q->param('area_id');
#     my $category = $q->param('category');
#     my $pages = allowed_pages($q);
#     my @allowed_actions = keys %$pages;
#  
#     if (!grep {$_ eq $page} @allowed_actions) {
#         not_found($q);
#         return; 
#     }
# 
#     if ($page eq "councilslist") {
#         admin_councils_list($q);
#     } elsif ($page eq "councilcontacts") {
#         admin_council_contacts($q, $area_id);
#     } elsif ($page eq "counciledit") {
#         admin_council_edit($q, $area_id, $category);
#     } elsif ($page eq 'reports') {
#         admin_reports($q);
#     } elsif ($page eq 'report_edit') {
#         my $id = $q->param('id');
#         admin_edit_report($q, $id);
#     } elsif ($page eq 'update_edit') {
#         my $id = $q->param('id');
#         admin_edit_update($q, $id);
#     } elsif ($page eq 'timeline') {
#         admin_timeline($q);
#     } elsif ($page eq 'questionnaire') {
#         admin_questionnaire($q);
#     } else {
#         admin_summary($q);
#     }
# }
# Page::do_fastcgi(\&main);
# 
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
