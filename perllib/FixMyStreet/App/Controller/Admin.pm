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

=head2 index

Display contact us page

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

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
    # this is for norway only - put in cobrand
    @councils_ids = grep { $_ ne 301 } @councils_ids;

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

# use Encode;
# 
# use Page;
# use mySociety::Config;
# use mySociety::DBHandle qw(dbh select_all);
# use mySociety::MaPit;
# use mySociety::VotingArea;
# use mySociety::Web qw(NewURL ent);
# 
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

sub check_token : Private {
    my ( $self, $c ) = @_;

    if ( $c->req->param('token' ) ne $c->stash->{token} ) {
        $c->detach( '/page_error_404_not_found', [ _('The requested URL was not found on this server.') ] );
    }

    return 1;
}
# 	
# =item allowed_pages Q
# 
# Return a hash of allowed pages, keyed on page param. The values of the hash
# are arrays of the form [link_text, link_order]. Pages without link_texts
# are not to be included in the main admin menu.
# =cut
# sub allowed_pages($) {
#     my ($q) = @_;
#     my $cobrand = Page::get_cobrand($q);
#     my $pages = Cobrand::admin_pages($cobrand);
#     if (!$pages) {
#         $pages = {
#              'summary' => [_('Summary'), 0],
#              'councilslist' => [_('Council contacts'), 1],
#              'reports' => [_('Search Reports'), 2],
#              'timeline' => [_('Timeline'), 3],
#              'questionnaire' => [_('Survey Results'), 4],
#              'councilcontacts' => [undef, undef],        
#              'counciledit' => [undef, undef], 
#              'report_edit' => [undef, undef], 
#              'update_edit' => [undef, undef], 
#         };
#     }
#     return $pages;
# }
# 
# sub html_head($$) {
#     my ($q, $title) = @_;
#     my $ret = $q->header(-type => 'text/html', -charset => 'utf-8');
#     my $site_title = _('FixMyStreet administration');
#     $ret .= <<END;
# <html>
# <head>
# <title>$title - $site_title</title>
# <style type="text/css">
# dt { clear: left; float: left; font-weight: bold; }
# dd { margin-left: 8em; }
# .hidden { color: #666666; }
# </style>
# </head>
# <body>
# END
#     my $pages = allowed_pages($q);    
#     my @links = sort {$pages->{$a}[1] <=> $pages->{$b}[1]}  grep {$pages->{$_}->[0] } keys %$pages;
#     $ret .= $q->p(
#         $q->strong(_("FixMyStreet admin:")), 
#         map { $q->a( { href => NewURL($q, page => $_) }, $pages->{$_}->[0]) } @links
#     ); 
# 
#     return $ret;
# }
# 
# sub fetch_data {
# }
# 
# 
# # admin_council_edit CGI AREA_ID CATEGORY
# sub admin_council_edit ($$$) {
#     my ($q, $area_id, $category) = @_;
# 
#     # Get all the data
#     my $bci_data = select_all("select * from contacts where area_id = ? and category = ?", $area_id, $category);
#     $bci_data = $bci_data->[0];
#     my $bci_history = select_all("select * from contacts_history where area_id = ? and category = ? order by contacts_history_id", $area_id, $category);
#     my $mapit_data = mySociety::MaPit::call('area', $area_id);
#     
#     # Title
#     my $title = sprintf(_('Council contacts for %s'), $mapit_data->{name});
#     print html_head($q, $title);
#     print $q->h1($title);
# 
#     # Example postcode
#     my $example_postcode = mySociety::MaPit::call('area/example_postcode', $area_id);
#     if ($example_postcode && ! ref $example_postcode) {
#         print $q->p("Example postcode: ",
#             $q->a({ href => mySociety::Config::get('BASE_URL') . '/?pc=' . $q->escape($example_postcode) }, 
#                 $example_postcode));
#     }
# 
#     # Display form for editing details
#     print $q->start_form(-method => 'POST', -action => './');
#     map { $q->param($_, $bci_data->{$_}) } qw/category email confirmed deleted/;
#     $q->param('page', 'councilcontacts');
#     $q->param('posted', 'new');
#     print $q->strong(_("Category: ")) . $bci_data->{category};
#     print $q->hidden('token', get_token($q)),
#     print $q->hidden("category");
#     print $q->strong(' ' . _("Email: "));
#     print $q->textfield(-name => "email", -size => 30) . " ";
#     $q->autoEscape(0);
#     print $q->checkbox(-id => 'confirmed', -name => "confirmed", -value => 1, -label => ' ' . $q->label({-for => 'confirmed'}, _('Confirmed')));
#     print ' ';
#     print $q->checkbox(-id => 'deleted', -name => "deleted", -value => 1, -label => ' ' . $q->label({-for => 'deleted'}, _('Deleted')));
#     $q->autoEscape(1);
#     print $q->br();
#     print $q->strong(_("Note: "));
#     print $q->textarea(-name => "note", -rows => 3, -columns=>40) . " ";
#     print $q->br();
#     print $q->hidden('area_id');
#     print $q->hidden('posted');
#     print $q->hidden('page');
#     print $q->submit(_('Save changes'));
#     print $q->end_form();
# 
#     # Display history of changes
#     print $q->h2(_('History'));
#     print $q->start_table({border=>1});
#     print $q->Tr({}, $q->th({}, [_("When edited"), _("Email"), _("Confirmed"), _("Deleted"), _("Editor"), _("Note")]));
#     my $html = '';
#     my $prev = undef;
#     foreach my $h (@$bci_history) {
#         $h->{confirmed} = $h->{confirmed} ? _("yes") : _("no"),
#         $h->{deleted} = $h->{deleted} ? _("yes") : _("no"),
#         my $emailchanged = ($prev && $h->{email} ne $prev->{email}) ? 1 : 0;
#         my $confirmedchanged = ($prev && $h->{confirmed} ne $prev->{confirmed}) ? 1 : 0;
#         my $deletedchanged = ($prev && $h->{deleted} ne $prev->{deleted}) ? 1 : 0;
#         $html .= $q->Tr({}, $q->td([ 
#                 $h->{whenedited} =~ m/^(.+)\.\d+$/,
#                 $emailchanged ? $q->strong($h->{email}) : $h->{email},
#                 $confirmedchanged ? $q->strong($h->{confirmed}) : $h->{confirmed},
#                 $deletedchanged ? $q->strong($h->{deleted}) : $h->{deleted},
#                 $h->{editor},
#                 $h->{note}
#             ]));
#         $prev = $h;
#     }
#     print $html;
#     print $q->end_table();
#     print html_tail($q);
# }
# 
# sub admin_reports {
#     my $q = shift;
#     my $title = _('Search Reports');
#     my $cobrand = Page::get_cobrand($q);
#     my $pages = allowed_pages($q);
#     print html_head($q, $title);
#     print $q->h1($title);
#     print $q->start_form(-method => 'GET', -action => './');
#     print $q->label({-for => 'search'}, _('Search:')), ' ', $q->textfield(-id => 'search', -name => "search", -size => 30);
#     print $q->hidden('page');
#     print $q->end_form;
# 
#     if (my $search = $q->param('search')) {
#         my $results = Problems::problem_search($search);
#         print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
#         print $q->Tr({}, $q->th({}, [_('ID'), _('Title'), _('Name'), _('Email'), _('Council'), _('Category'), _('Anonymous'), _('Cobrand'), _('Created'), _('State'), _('When sent'), _('*') ]));
#         my $cobrand_data;         
#         foreach (@$results) {
#             my $url = $_->{id};
#             if ($_->{state} eq 'confirmed' || $_->{state} eq 'fixed') {
#                 # if this is a cobranded admin interface, but we're looking at a generic problem, figure out enough information
#                 # to create a URL to the cobranded version of the problem
#                 if ($_->{cobrand}) {
#                     $cobrand_data = $_->{cobrand_data};
#                 } else {	
#                     $cobrand_data = Cobrand::cobrand_data_for_generic_problem($cobrand, $_);
#                 }
#                 $url = $q->a({ -href => Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/report/' . $_->{id} }, $url);
#             }
#             my $council = $_->{council} || '&nbsp;';
#             my $category = $_->{category} || '&nbsp;';
#             (my $confirmed = $_->{confirmed} || '-') =~ s/ (.*?)\..*/&nbsp;$1/;
#             (my $created = $_->{created}) =~ s/\..*//;
#             (my $lastupdate = $_->{lastupdate}) =~ s/ (.*?)\..*/&nbsp;$1/;
#             (my $whensent = $_->{whensent} || '&nbsp;') =~ s/\..*//;
#             my $state = $_->{state};
#             $state .= '<small>';
#             $state .= "<br>" . _('Confirmed:') . "&nbsp;$confirmed" if $_->{state} eq 'confirmed' || $_->{state} eq 'fixed';
#             $state .= '<br>' . _('Fixed:') . ' ' . $lastupdate if $_->{state} eq 'fixed';
#             $state .= "<br>" . _('Last&nbsp;update:') . "&nbsp;$lastupdate" if $_->{state} eq 'confirmed';
#             $state .= '</small>';
#             my $anonymous = $_->{anonymous} ? _('Yes') : _('No');
#             my $cobrand = $_->{cobrand};
#             $cobrand .= "<br>" . $_->{cobrand_data};
#             my $counciltext = '';
#             if (grep {$_ eq 'councilcontacts'} keys %{$pages}) {  
#                  $counciltext = $q->a({ -href => NewURL($q, page=>'councilcontacts', area_id=>$council)}, $council);
#             } else {
#                  $counciltext = $council;
#             }
#             my $attr = {};
#             $attr->{-class} = 'hidden' if $_->{state} eq 'hidden';
#             print $q->Tr($attr, $q->td([ $url, ent($_->{title}), ent($_->{name}), ent($_->{email}),
#             $counciltext,
#             $category, $anonymous, $cobrand, $created, $state, $whensent,
#             $q->a({ -href => NewURL($q, page=>'report_edit', id=>$_->{id}) }, _('Edit'))
#             ]));
#         }
#         print $q->end_table;
# 
#         print $q->h2(_('Updates'));
#         my $updates = Problems::update_search($search);
#         admin_show_updates($q, $updates);
#     }
# 
#     print html_tail($q);
# }
# 
# sub admin_edit_report {
#     my ($q, $id) = @_;
#     my $row = Problems::admin_fetch_problem($id);
#     my $cobrand = Page::get_cobrand($q);
#     return not_found($q) if ! $row->[0];
#     my %row = %{$row->[0]};
#     my $status_message = '';
#     if ($q->param('resend')) {
#         return not_found($q) if $q->param('token') ne get_token($q);
#         dbh()->do('update problem set whensent=null where id=?', {}, $id);
#         admin_log_edit($q, $id, 'problem', 'resend');
#         dbh()->commit();
#         $status_message = '<p><em>' . _('That problem will now be resent.') . '</em></p>';
#     } elsif ($q->param('submit')) {
#         return not_found($q) if $q->param('token') ne get_token($q);
#         my $new_state = $q->param('state');
#         my $done = 0;
#         if ($new_state eq 'confirmed' && $row{state} eq 'unconfirmed' && $q->{site} eq 'emptyhomes') {
#             $status_message = '<p><em>' . _('I am afraid you cannot confirm unconfirmed reports.') . '</em></p>';
#             $done = 1;
#         }
#         my $query = 'update problem set anonymous=?, state=?, name=?, email=?, title=?, detail=?';
#         if ($q->param('remove_photo')) {
#             $query .= ', photo=null';
#         }
#         if ($new_state ne $row{state}) {
#             $query .= ', lastupdate=current_timestamp';
#         }
#         if ($new_state eq 'confirmed' and $row{state} eq 'unconfirmed') {
#             $query .= ', confirmed=current_timestamp';
#         }
#         $query .= ' where id=?';
#         unless ($done) {
#             dbh()->do($query, {}, $q->param('anonymous') ? 't' : 'f', $new_state,
#                 $q->param('name'), $q->param('email'), $q->param('title'), $q->param('detail'), $id);
#             if ($new_state ne $row{state}) {	
#                 admin_log_edit($q, $id, 'problem', 'state_change');
#             }
#             if ($q->param('anonymous') ne $row{anonymous} || 
#                 $q->param('name') ne $row{name} ||
#                 $q->param('email') ne $row{email} || 
#                 $q->param('title') ne $row{title} ||
#                 $q->param('detail') ne $row{detail}) {
#                admin_log_edit($q, $id, 'problem', 'edit');
#             } 
#             dbh()->commit();
#             map { $row{$_} = $q->param($_) } qw(anonymous state name email title detail);
#             $status_message = '<p><em>' . _('Updated!') . '</em></p>';
#         }
#     }
#     my %row_h = map { $_ => $row{$_} ? ent($row{$_}) : '' } keys %row;
#     my $title = sprintf(_("Editing problem %d"), $id);
#     print html_head($q, $title);
#     print $q->h1($title);
#     print $status_message;
# 
#     my $council = $row{council} || '<em>' . _('None') . '</em>';
#     (my $areas = $row{areas}) =~ s/^,(.*),$/$1/;
#     my $latitude  = $row{latitude};
#     my $longitude = $row{longitude};
#     my $questionnaire = $row{send_questionnaire} ? _('Yes') : _('No');
#     my $used_map = $row{used_map} ? _('used map') : _("didn't use map");
#     (my $whensent = $row{whensent} || '&nbsp;') =~ s/\..*//;
#     (my $confirmed = $row{confirmed} || '-') =~ s/ (.*?)\..*/&nbsp;$1/;
#     my $photo = '';
#     my $cobrand_data;
#     if ($row{cobrand}) {
#         $cobrand_data = $row{cobrand_data};
#     } else {
#         $cobrand_data = Cobrand::cobrand_data_for_generic_problem($cobrand, \%row);
#     }
#     $photo = '<li><img align="top" src="' . Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/photo?id=' . $row{id} . '">
# <input type="checkbox" id="remove_photo" name="remove_photo" value="1">
# <label for="remove_photo">' . _("Remove photo (can't be undone!)") . '</label>' if $row{photo};
#     
#     my $url_base = Cobrand::base_url_for_emails($cobrand, $cobrand_data);
#     my $url = $url_base . '/report/' . $row{id};
# 
#     my $anon = $q->label({-for=>'anonymous'}, _('Anonymous:')) . ' ' . $q->popup_menu(-id => 'anonymous', -name => 'anonymous', -values => { 1=>_('Yes'), 0=>_('No') }, -default => $row{anonymous});
#     my $state = $q->label({-for=>'state'}, _('State:')) . ' ' . $q->popup_menu(-id => 'state', -name => 'state', -values => { confirmed => _('Open'), fixed => _('Fixed'), hidden => _('Hidden'), unconfirmed => _('Unconfirmed'), partial => _('Partial') }, -default => $row{state});
# 
#     my $resend = '';
#     $resend = ' <input onclick="return confirm(\'' . _('You really want to resend?') . '\')" type="submit" name="resend" value="' . _('Resend report') . '">' if $row{state} eq 'confirmed';
# 
#     print $q->start_form(-method => 'POST', -action => './');
#     print $q->hidden('page');
#     print $q->hidden('id');
#     print $q->hidden('token', get_token($q));
#     print $q->hidden('submit', 1);
#     print "
# <ul>
# <li><a href='$url'>" . _('View report on site') . "</a>
# <li><label for='title'>" . _('Subject:') . "</label> <input size=60 type='text' id='title' name='title' value='$row_h{title}'>
# <li><label for='detail'>" . _('Details:') . "</label><br><textarea name='detail' id='detail' cols=60 rows=10>$row_h{detail}</textarea>
# <li>" . _('Co-ordinates:') . " $latitude,$longitude (" . _('originally entered') . " $row_h{postcode}, $used_map)
# <li>" . _('For council(s):') . " $council (" . _('other areas:') . " $areas)
# <li>$anon
# <li>$state
# <li>" . _('Category:') . " $row{category}
# <li>" . _('Name:') . " <input type='text' name='name' id='name' value='$row_h{name}'>
# <li>" . _('Email:') . " <input type='text' id='email' name='email' value='$row_h{email}'>
# <li>" . _('Phone:') . " $row_h{phone}
# <li>" . _('Created:') . " $row{created}
# <li>" . _('Confirmed:') . " $confirmed
# <li>" . _('Sent:') . " $whensent $resend
# <li>" . _('Last update:') . " $row{lastupdate}
# <li>" . _('Service:') . " $row{service}
# <li>" . _('Cobrand:') . " $row{cobrand}
# <li>" . _('Cobrand data:') . " $row{cobrand_data}
# <li>" . _('Going to send questionnaire?') . " $questionnaire
# $photo
# </ul>
# ";
#     print $q->submit(_('Submit changes'));
#     print $q->end_form;
# 
#     print $q->h2(_('Updates'));
#     my $updates = select_all('select * from comment where problem_id=? order by created', $id);
#     admin_show_updates($q, $updates);
#     print html_tail($q);
# }
# 
# sub admin_show_updates {
#     my ($q, $updates) = @_;
#     my $cobrand = Page::get_cobrand($q);
#     print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
#     print $q->Tr({}, $q->th({}, [ _('ID'), _('State'), _('Name'), _('Email'), _('Created'), _('Cobrand'), _('Text'), _('*') ]));
#     my $base_url = ''; 
#     my $cobrand_data;
#     foreach (@$updates) {
#         my $url = $_->{id};
#         if ( $_->{state} eq 'confirmed' ) {
#             if ($_->{cobrand}) {
#                 $cobrand_data = $_->{cobrand_data};
#             } else {
#                 $cobrand_data = Cobrand::cobrand_data_for_generic_update($cobrand, $_);
#             }
#             $url = $q->a({ -href => Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/report/' . $_->{problem_id} . '#update_' . $_->{id} },
#                 $url);
#         }
#         my $cobrand = $_->{cobrand} . '<br>' . $_->{cobrand_data};
#         my $attr = {};
#         $attr->{-class} = 'hidden' if $_->{state} eq 'hidden' || ($_->{problem_state} && $_->{problem_state} eq 'hidden');
#         print $q->Tr($attr, $q->td([ $url, $_->{state}, ent($_->{name} || ''),
#         ent($_->{email}), $_->{created}, $cobrand, ent($_->{text}),
#         $q->a({ -href => NewURL($q, page=>'update_edit', id=>$_->{id}) }, _('Edit'))
#         ]));
#     }
#     print $q->end_table;
# }
# 
# sub admin_edit_update {
#     my ($q, $id) = @_;
#     my $row = Problems::admin_fetch_update($id);
#     return not_found($q) if ! $row->[0];
#     my $cobrand = Page::get_cobrand($q);
# 
#     my %row = %{$row->[0]};
#     my $status_message = '';
#     if ($q->param('submit')) {
#         return not_found($q) if $q->param('token') ne get_token($q);
#         my $query = 'update comment set state=?, name=?, email=?, text=?';
#         if ($q->param('remove_photo')) {
#             $query .= ', photo=null';
#         }
#         $query .= ' where id=?';
#         dbh()->do($query, {}, $q->param('state'), $q->param('name'), $q->param('email'), $q->param('text'), $id);
#         $status_message = '<p><em>' . _('Updated!') . '</em></p>';
# 
#         # If we're hiding an update, see if it marked as fixed and unfix if so
#         if ($q->param('state') eq 'hidden' && $row{mark_fixed}) {
#             dbh()->do("update problem set state='confirmed' where state='fixed' and id=?", {}, $row{problem_id});
#             $status_message .= '<p><em>' . _('Problem marked as open.') . '</em></p>';
#         }
# 
#         if ($q->param('state') ne $row{state}) {
#             admin_log_edit($q, $id, 'update', 'state_change');
#         } 
#         if (!defined($row{name})){
#            $row{name} = "";   
#         }
#         if ($q->param('name') ne $row{name} || $q->param('email') ne $row{email} || $q->param('text') ne $row{text}) {
#             admin_log_edit($q, $id, 'update', 'edit');
#         }
#         dbh()->commit();
#         map { $row{$_} = $q->param($_) } qw(state name email text);
#     }
#     my %row_h = map { $_ => $row{$_} ? ent($row{$_}) : '' } keys %row;
#     my $title = sprintf(_("Editing update %d"), $id);
#     print html_head($q, $title);
#     print $q->h1($title);
#     print $status_message;
#     my $name = $row_h{name};
#     $name = '' unless $name;
#     my $cobrand_data;
#     if ($row{cobrand}) {
#         $cobrand_data = $row{cobrand_data};
#     } else {
#         $cobrand_data = Cobrand::cobrand_data_for_generic_update($cobrand, \%row);
#     }
#     my $photo = '';
#     $photo = '<li><img align="top" src="' . Cobrand::base_url_for_emails($cobrand, $cobrand_data)  . '/photo?c=' . $row{id} . '">
# <input type="checkbox" id="remove_photo" name="remove_photo" value="1">
# <label for="remove_photo">' . _("Remove photo (can't be undone!)") . '</label>' if $row{photo};
# 
#     my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/report/' . $row{problem_id} . '#update_' . $row{id};
# 
#     my $state = $q->label({-for=>'state'}, _('State:')) . ' ' . $q->popup_menu(-id => 'state', -name => 'state', -values => { confirmed => _('Confirmed'), hidden => _('Hidden'), unconfirmed => _('Unconfirmed') }, -default => $row{state});
# 
#     print $q->start_form(-method => 'POST', -action => './');
#     print $q->hidden('page');
#     print $q->hidden('id');
#     print $q->hidden('token', get_token($q));
#     print $q->hidden('submit', 1);
#     print "
# <ul>
# <li><a href='$url'>" . _('View update on site') . "</a>
# <li><label for='text'>" . _('Text:') . "</label><br><textarea name='text' id='text' cols=60 rows=10>$row_h{text}</textarea>
# <li>$state
# <li>" . _('Name:') . " <input type='text' name='name' id='name' value='$name'> " . _('(blank to go anonymous)') . "
# <li>" . _('Email:') . " <input type='text' id='email' name='email' value='$row_h{email}'>
# <li>" . _('Cobrand:') . " $row{cobrand}
# <li>" . _('Cobrand data:') . " $row{cobrand_data} 
# <li>" . _('Created:') . " $row{created}
# $photo
# </ul>
# ";
#     print $q->submit(_('Submit changes'));
#     print $q->end_form;
#     print html_tail($q);
# }
# 
# sub get_cobrand_data_from_hash {
#     my ($cobrand, $data) = @_;
#     my $cobrand_data;
#     if ($data->{cobrand}) {
#         $cobrand_data = $data->{cobrand_data};
#     } else {
#         $cobrand_data = Cobrand::cobrand_data_for_generic_problem($cobrand, $data);
#     }
#     return $cobrand_data;
# }
# 
# sub admin_log_edit {
#    my ($q, $id, $object_type, $action) = @_;
#    my $query = "insert into admin_log (admin_user, object_type, object_id, action)
#                 values (?, ?, ?, ?);";
#    dbh()->do($query, {}, $q->remote_user(), $object_type, $id, $action);
# }
# 
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
# sub not_found {
#     my ($q) = @_;
#     print $q->header(-status=>'404 Not Found',-type=>'text/html');
#     print "<h1>Not Found</h1>The requested URL was not found on this server.";
# }
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
