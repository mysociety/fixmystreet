#!/usr/bin/perl -w
#
# index.cgi
#
# Administration interface for FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: index.cgi,v 1.88 2010-01-20 12:55:46 louise Exp $
#

my $rcsid = ''; $rcsid .= '$Id: index.cgi,v 1.88 2010-01-20 12:55:46 louise Exp $';

use strict;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";
use POSIX qw(strftime);
use Digest::MD5 qw(md5_hex);

use Page;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);
use mySociety::MaPit;
use mySociety::VotingArea;
use mySociety::Web qw(NewURL ent);

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
    mySociety::DBHandle::configure(
        Name => mySociety::Config::get('BCI_DB_NAME'),
        User => mySociety::Config::get('BCI_DB_USER'),
        Password => mySociety::Config::get('BCI_DB_PASS'),
        Host => mySociety::Config::get('BCI_DB_HOST', undef),
        Port => mySociety::Config::get('BCI_DB_PORT', undef)
    );
}


=item get_token Q

Generate a token based on user and secret

=cut
sub get_token {
    my ($q) = @_;
    my $secret = scalar(dbh()->selectrow_array('select secret from secret'));
    my $token = md5_hex(($q->remote_user() . $secret));
    return $token;
}
	
=item allowed_pages Q

Return a hash of allowed pages, keyed on page param. The values of the hash
are arrays of the form [link_text, link_order]. Pages without link_texts
are not to be included in the main admin menu.
=cut
sub allowed_pages($) {
    my ($q) = @_;
    my $cobrand = Page::get_cobrand($q);
    my $pages = Cobrand::admin_pages($cobrand);
    if (!$pages) {
        $pages = {
             'summary' => ['Summary', 0],
             'councilslist' => ['Council contacts', 1],
             'reports' => ['Reports', 2],
             'timeline' => ['Timeline', 3],
             'councilcontacts' => [undef, undef],        
             'counciledit' => [undef, undef], 
             'report_edit' => [undef, undef], 
             'update_edit' => [undef, undef], 
        };
    }
    return $pages;
}

sub html_head($$) {
    my ($q, $title) = @_;
    my $ret = $q->header(-type => 'text/html', -charset => 'utf-8');
    $ret .= <<END;
<html>
<head>
<title>$title - FixMyStreet administration</title>
<style type="text/css">
dt { clear: left; float: left; font-weight: bold; }
dd { margin-left: 8em; }
</style>
</head>
<body>
END
    my $pages = allowed_pages($q);    
    my @links = sort {$pages->{$a}[1] <=> $pages->{$b}[1]}  grep {$pages->{$_}->[0] } keys %$pages;
    $ret .= $q->p(
        $q->strong("FixMyStreet admin:"), 
        map { $q->a( { href => NewURL($q, page => $_) }, $pages->{$_}->[0]) } @links
    ); 

    return $ret;
}

sub html_tail($) {
    my ($q) = @_;
    return <<END;
</body>
</html>
END
}

sub fetch_data {
}

# admin_summary CGI
# Displays general summary of counts.
sub admin_summary ($) {
    my ($q) = @_;
    my $cobrand = Page::get_cobrand($q);
    print html_head($q, "Summary");
    print $q->h1("Summary");

    my $contacts = Problems::contact_counts($cobrand);
    my %contacts = @$contacts;
    $contacts{0} ||= 0;
    $contacts{1} ||= 0;
    $contacts{total} = $contacts{0} + $contacts{1};

    my $comments = Problems::update_counts();
    my %comments = @$comments;

    my $problems = Problems::problem_counts();
    my %problems = @$problems;
    %problems = map { $_ => $problems{$_} || 0 } qw(confirmed fixed unconfirmed hidden partial);
    my $total_problems_live = $problems{confirmed} + $problems{fixed};
    my $total_problems = 0;
    map { $total_problems += $_ } values %problems;

    my $alerts = Problems::alert_counts($cobrand);
    my %alerts = @$alerts; $alerts{0} ||= 0; $alerts{1} ||= 0;

    my $questionnaires = Problems::questionnaire_counts($cobrand);
    my %questionnaires = @$questionnaires;
    $questionnaires{0} ||= 0;
    $questionnaires{1} ||= 0;
    $questionnaires{total} = $questionnaires{0} + $questionnaires{1};
    my $questionnaires_pc = $questionnaires{total} ? $questionnaires{1} / $questionnaires{total} * 100 : 'na';
    
    print $q->ul(
        $q->li("<strong>$total_problems_live</strong> live problems"),
        $q->li("$comments{confirmed} live updates"),
        $q->li("$alerts{1} confirmed alerts, $alerts{0} unconfirmed"),
        $q->li("$questionnaires{total} questionnaires sent &ndash; $questionnaires{1} answered ($questionnaires_pc%)"),
        $q->li("$contacts{total} council contacts &ndash; $contacts{1} confirmed, $contacts{0} unconfirmed"),
    );

    if (Cobrand::admin_show_creation_graph($cobrand)) {
         print $q->p( $q->a({ href => mySociety::Config::get('BASE_URL') . "/bci-live-creation.png" }, 
                 "Graph of problem creation by status over time" ));

    }
    print $q->h2("Problem breakdown by state");
    print $q->ul(
        map { $q->li("$problems{$_} $_") } sort keys %problems 
    );

    print $q->h2("Update breakdown by state");
    print $q->ul(
        map { $q->li("$comments{$_} $_") } sort keys %comments
    );

    print html_tail($q);
}

# admin_councils_list CGI
sub admin_councils_list ($) {
    my ($q) = @_;

    print html_head($q, "Council contacts");
    print $q->h1("Council contacts");

    # Table of editors
    print $q->h2("Diligency prize league table");
    my $edit_activity = dbh()->selectall_arrayref("select count(*) as c, editor from contacts_history group by editor order by c desc");
    print $q->ul(
        map { $q->li($_->[0] . " edits by " . $_->[1]) } @$edit_activity 
    );

    # Table of councils
    print $q->h2("Councils");
    my @councils;
    my $ignore = 'LGD';
    $ignore .= '|CTY' if $q->{site} eq 'emptyhomes';
    my @types = grep { !/$ignore/ } @$mySociety::VotingArea::council_parent_types; # LGD are NI councils
    foreach my $type (@types) {
        my $areas = mySociety::MaPit::get_areas_by_type($type);
        push @councils, @$areas;
    }
    my $councils = mySociety::MaPit::get_voting_areas_info(\@councils);
    my @councils_ids = keys %$councils;
    @councils_ids = sort { $councils->{$a}->{name} cmp $councils->{$b}->{name} } @councils_ids;
    my $bci_info = dbh()->selectall_hashref("
        select area_id, count(*) as c, count(case when deleted then 1 else null end) as deleted,
            count(case when confirmed then 1 else null end) as confirmed
        from contacts group by area_id", 'area_id');

    my $list_part = sub {
        my @ids = @_;
        if (!scalar(@ids)) {
            print "None";
            return;
        }
        print $q->p(join($q->br(), 
            map { 
                $q->a({ href => NewURL($q, area_id => $_, page => 'councilcontacts') }, 
                  $councils->{$_}->{name}) . " " .
                    ($bci_info->{$_} && $q->{site} ne 'emptyhomes' ?
                        $bci_info->{$_}->{c} . ' addresses'
                    : '')
            } @ids));
    };

    print $q->h3('No info at all');
    &$list_part(grep { !$bci_info->{$_} } @councils_ids);
    print $q->h3('Currently has 1+ deleted');
    &$list_part(grep { $bci_info->{$_} && $bci_info->{$_}->{deleted} } @councils_ids);
    print $q->h3('Some unconfirmeds');
    &$list_part(grep { $bci_info->{$_} && !$bci_info->{$_}->{deleted} && $bci_info->{$_}->{confirmed} != $bci_info->{$_}->{c} } @councils_ids);
    print $q->h3('All confirmed');
    &$list_part(grep { $bci_info->{$_} && !$bci_info->{$_}->{deleted} && $bci_info->{$_}->{confirmed} == $bci_info->{$_}->{c} } @councils_ids);
    print html_tail($q);
}

# admin_council_contacts CGI AREA_ID
sub admin_council_contacts ($$) {
    my ($q, $area_id) = @_;

    # Submit form
    my $updated = '';
    my $posted = $q->param('posted') || '';
    if ($posted eq 'new') {
        return not_found($q) if $q->param('token') ne get_token($q);
        my $email = trim($q->param('email'));
        my $category = trim($q->param('category'));
        $category = 'Empty property' if $q->{site} eq 'emptyhomes';
        # History is automatically stored by a trigger in the database
        my $update = dbh()->do("update contacts set
            email = ?,
            confirmed = ?,
            deleted = ?,
            editor = ?,
            whenedited = ms_current_timestamp(),
            note = ?
            where area_id = ?
            and category = ?
            ", {}, 
            $email, ($q->param('confirmed') ? 1 : 0),
            ($q->param('deleted') ? 1 : 0),
            ($q->remote_user() || "*unknown*"), $q->param('note'),
            $area_id, $category
            );
        $updated = $q->p($q->em("Values updated"));
        unless ($update > 0) {
            dbh()->do('insert into contacts
                (area_id, category, email, editor, whenedited, note, confirmed, deleted)
                values
                (?, ?, ?, ?, ms_current_timestamp(), ?, ?, ?)', {},
                $area_id, $category, $email,
                ($q->remote_user() || '*unknown*'), $q->param('note'),
                ($q->param('confirmed') ? 1 : 0), ($q->param('deleted') ? 1 : 0)
            );
            $updated = $q->p($q->em("New category contact added"));
        }
        dbh()->commit();
    } elsif ($posted eq 'update') {
        return not_found($q) if $q->param('token') ne get_token($q);
        my @cats = $q->param('confirmed');
        foreach my $cat (@cats) {
            dbh()->do("update contacts set
                confirmed = 't', editor = ?,
                whenedited = ms_current_timestamp(),
                note = 'Confirmed'
                where area_id = ?
                and category = ?
                ", {},
                ($q->remote_user() || "*unknown*"),
                $area_id, $cat
            );
        }
        $updated = $q->p($q->em("Values updated"));
        dbh()->commit();
    }

    my $bci_data = select_all("select * from contacts where area_id = ? order by category", $area_id);

    if ($q->param('text')) {
        print $q->header(-type => 'text/plain', -charset => 'utf-8');
        foreach my $l (@$bci_data) {
            next if $l->{deleted} || !$l->{confirmed};
            print $l->{category} . "\t" . $l->{email} . "\n";
        }
        return;
    }

    $q->delete_all(); # No need for state!

    # Title
    my $mapit_data = mySociety::MaPit::get_voting_area_info($area_id);
    my $title = 'Council contacts for ' . $mapit_data->{name};
    print html_head($q, $title);
    print $q->h1($title);
    print $updated;

    # Example postcode, link to list of problem reports
    my $links_html;
    my $example_postcode = mySociety::MaPit::get_example_postcode($area_id);
    if ($example_postcode) {
        $links_html .= $q->a({ href => mySociety::Config::get('BASE_URL') . '/?pc=' . $q->escape($example_postcode) }, 
                "Example postcode " . $example_postcode) . " | ";
    }
    $links_html .= ' '  . 
            $q->a({ href => mySociety::Config::get('BASE_URL') . "/reports?council=" . $area_id }, " List all reported problems");
    $links_html .= ' ' .
            $q->a({ href => NewURL($q, area_id => $area_id, page => 'councilcontacts', text => 1) }, 'Text only version');
    print $q->p($links_html);

    # Display of addresses / update statuses form
    print $q->start_form(-method => 'POST', -action => './');
    print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
    print $q->Tr({}, $q->th({}, ["Category", "Email", "Confirmed", "Deleted", "Last editor", "Note", "When edited", 'Confirm']));
    foreach my $l (@$bci_data) {
        print $q->Tr($q->td([
            $q->a({ href => NewURL($q, area_id => $area_id, category => $l->{category}, page => 'counciledit') },
                $l->{category}), $l->{email}, $l->{confirmed} ? 'Yes' : 'No',
            $l->{deleted} ? 'Yes' : 'No', $l->{editor}, ent($l->{note}),
            $l->{whenedited} =~ m/^(.+)\.\d+$/,
            $q->checkbox(-name => 'confirmed', -value => $l->{category}, -label => '')
        ]));
    }
    print $q->end_table();
    # XXX
    print $q->p(
        $q->hidden('area_id', $area_id),
        $q->hidden('posted', 'update'),
        $q->hidden('token', get_token($q)),
        $q->hidden('page', 'councilcontacts'),
        $q->submit('Update statuses')
    );
    print $q->end_form();

    # Display form for adding new category
    print $q->h2('Add new category');
    print $q->start_form(-method => 'POST', -action => './');
    if ($q->{site} ne 'emptyhomes') {
        print $q->p($q->strong("Category: "),
            $q->textfield(-name => "category", -size => 30));
    }
    print $q->p($q->strong("Email: "),
        $q->textfield(-name => "email", -size => 30));
    $q->autoEscape(0);
    print $q->p(
        $q->checkbox(-id => 'confirmed', -name => "confirmed", -value => 1, -label => ' ' . $q->label({-for => 'confirmed'}, 'Confirmed')),
        ' ',
        $q->checkbox(-id => 'deleted', -name => "deleted", -value => 1, -label => ' ' . $q->label({-for => 'deleted'}, 'Deleted'))
    );
    $q->autoEscape(1);
    print $q->p($q->strong("Note: "),
        $q->textarea(-name => "note", -rows => 3, -columns=>40));
    print $q->p(
        $q->hidden('area_id', $area_id),
        $q->hidden('posted', 'new'),
        $q->hidden('token', get_token($q)),
        $q->hidden('page', 'councilcontacts'),
        $q->submit('Create category')
    );
    print $q->end_form();

    print html_tail($q);
}

# admin_council_edit CGI AREA_ID CATEGORY
sub admin_council_edit ($$$) {
    my ($q, $area_id, $category) = @_;

    # Get all the data
    my $bci_data = select_all("select * from contacts where area_id = ? and category = ?", $area_id, $category);
    $bci_data = $bci_data->[0];
    my $bci_history = select_all("select * from contacts_history where area_id = ? and category = ? order by contacts_history_id", $area_id, $category);
    my $mapit_data = mySociety::MaPit::get_voting_area_info($area_id);
    
    # Title
    my $title = 'Council contacts for ' . $mapit_data->{name};
    print html_head($q, $title);
    print $q->h1($title);

    # Example postcode
    my $example_postcode = mySociety::MaPit::get_example_postcode($area_id);
    if ($example_postcode) {
        print $q->p("Example postcode: ",
            $q->a({ href => mySociety::Config::get('BASE_URL') . '/?pc=' . $q->escape($example_postcode) }, 
                $example_postcode));
    }

    # Display form for editing details
    print $q->start_form(-method => 'POST', -action => './');
    map { $q->param($_, $bci_data->{$_}) } qw/category email confirmed deleted/;
    $q->param('page', 'councilcontacts');
    $q->param('posted', 'new');
    print $q->strong("Category: ") . $bci_data->{category};
    print $q->hidden('token', get_token($q)),
    print $q->hidden("category");
    print $q->strong(" Email: ");
    print $q->textfield(-name => "email", -size => 30) . " ";
    $q->autoEscape(0);
    print $q->checkbox(-id => 'confirmed', -name => "confirmed", -value => 1, -label => ' ' . $q->label({-for => 'confirmed'}, 'Confirmed'));
    print ' ';
    print $q->checkbox(-id => 'deleted', -name => "deleted", -value => 1, -label => ' ' . $q->label({-for => 'deleted'}, 'Deleted'));
    $q->autoEscape(1);
    print $q->br();
    print $q->strong("Note: ");
    print $q->textarea(-name => "note", -rows => 3, -columns=>40) . " ";
    print $q->br();
    print $q->hidden('area_id');
    print $q->hidden('posted');
    print $q->hidden('page');
    print $q->submit('Save changes');
    print $q->end_form();

    # Display history of changes
    print $q->h2('History');
    print $q->start_table({border=>1});
    print $q->Tr({}, $q->th({}, ["When edited", "Email", "Confirmed", "Deleted", "Editor", "Note"]));
    my $html = '';
    my $prev = undef;
    foreach my $h (@$bci_history) {
        $h->{confirmed} = $h->{confirmed} ? "yes" : "no",
        $h->{deleted} = $h->{deleted} ? "yes" : "no",
        my $emailchanged = ($prev && $h->{email} ne $prev->{email}) ? 1 : 0;
        my $confirmedchanged = ($prev && $h->{confirmed} ne $prev->{confirmed}) ? 1 : 0;
        my $deletedchanged = ($prev && $h->{deleted} ne $prev->{deleted}) ? 1 : 0;
        $html .= $q->Tr({}, $q->td([ 
                $h->{whenedited} =~ m/^(.+)\.\d+$/,
                $emailchanged ? $q->strong($h->{email}) : $h->{email},
                $confirmedchanged ? $q->strong($h->{confirmed}) : $h->{confirmed},
                $deletedchanged ? $q->strong($h->{deleted}) : $h->{deleted},
                $h->{editor},
                $h->{note}
            ]));
        $prev = $h;
    }
    print $html;
    print $q->end_table();
    print html_tail($q);
}

sub admin_reports {
    my $q = shift;
    my $title = 'Reports';
    my $cobrand = Page::get_cobrand($q);
    my $pages = allowed_pages($q);
    print html_head($q, $title);
    print $q->h1($title);
    print $q->start_form(-method => 'GET', -action => './');
    print $q->label({-for => 'search'}, 'Search:'), ' ', $q->textfield(-id => 'search', -name => "search", -size => 30);
    print $q->hidden('page');
    print $q->end_form;

    if (my $search = $q->param('search')) {
        my $results = Problems::problem_search($search);
        print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
        print $q->Tr({}, $q->th({}, ['ID', 'Title', 'Name', 'Email', 'Council', 'Category', 'Anonymous', 'Cobrand', 'Created', 'State', 'When sent', '*']));
        my $cobrand_data;         
        foreach (@$results) {
            my $url = $_->{id};
            if ($_->{state} eq 'confirmed' || $_->{state} eq 'fixed') {
                # if this is a cobranded admin interface, but we're looking at a generic problem, figure out enough information
                # to create a URL to the cobranded version of the problem
                if ($_->{cobrand}) {
                    $cobrand_data = $_->{cobrand_data};
                } else {	
                    $cobrand_data = Cobrand::cobrand_data_for_generic_problem($cobrand, $_);
                }
                $url = $q->a({ -href => Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/report/' . $_->{id} }, $url);
            }
            my $council = $_->{council} || '&nbsp;';
            my $category = $_->{category} || '&nbsp;';
            (my $confirmed = $_->{confirmed} || '-') =~ s/ (.*?)\..*/&nbsp;$1/;
            (my $created = $_->{created}) =~ s/\..*//;
            (my $lastupdate = $_->{lastupdate}) =~ s/ (.*?)\..*/&nbsp;$1/;
            (my $whensent = $_->{whensent} || '&nbsp;') =~ s/\..*//;
            my $state = $_->{state};
            $state .= '<small>';
            $state .= "<br>Confirmed:&nbsp;$confirmed" if $_->{state} eq 'confirmed' || $_->{state} eq 'fixed';
            $state .= '<br>Fixed: ' . $lastupdate if $_->{state} eq 'fixed';
            $state .= "<br>Last&nbsp;update:&nbsp;$lastupdate" if $_->{state} eq 'confirmed';
            $state .= '</small>';
            my $anonymous = $_->{anonymous} ? 'Yes' : 'No';
            my $cobrand = $_->{cobrand};
            $cobrand .= "<br>" . $_->{cobrand_data};
            my $counciltext = '';
            if (grep {$_ eq 'councilcontacts'} keys %{$pages}) {  
                 $counciltext = $q->a({ -href => NewURL($q, page=>'councilcontacts', area_id=>$council)}, $council);
            } else {
                 $counciltext = $council;
            }
            print $q->Tr({}, $q->td([ $url, ent($_->{title}), ent($_->{name}), ent($_->{email}),
            $counciltext,
            $category, $anonymous, $cobrand, $created, $state, $whensent,
            $q->a({ -href => NewURL($q, page=>'report_edit', id=>$_->{id}) }, 'Edit')
            ]));
        }
        print $q->end_table;

        print $q->h2('Updates');
        my $updates = Problems::update_search($search);
        admin_show_updates($q, $updates);
    }

    print html_tail($q);
}

sub admin_edit_report {
    my ($q, $id) = @_;
    my $row = Problems::admin_fetch_problem($id);
    my $cobrand = Page::get_cobrand($q);
    return not_found($q) if ! $row->[0];
    my %row = %{$row->[0]};
    my $status_message = '';
    if ($q->param('resend')) {
        return not_found($q) if $q->param('token') ne get_token($q);
        dbh()->do('update problem set whensent=null where id=?', {}, $id);
        admin_log_edit($q, $id, 'problem', 'resend');
        dbh()->commit();
        $status_message = '<p><em>That problem will now be resent.</em></p>';
    } elsif ($q->param('submit')) {
        return not_found($q) if $q->param('token') ne get_token($q);
        my $new_state = $q->param('state');
        my $done = 0;
        if ($new_state eq 'confirmed' && $row{state} eq 'unconfirmed' && $q->{site} eq 'emptyhomes') {
            $status_message = '<p><em>I am afraid you cannot confirm unconfirmed reports.</em></p>';
            $done = 1;
        }
        my $query = 'update problem set anonymous=?, state=?, name=?, email=?, title=?, detail=?';
        if ($q->param('remove_photo')) {
            $query .= ', photo=null';
        }
        if ($new_state ne $row{state}) {
            $query .= ', lastupdate=current_timestamp';
        }
        if ($new_state eq 'confirmed' and $row{state} eq 'unconfirmed') {
            $query .= ', confirmed=current_timestamp';
        }
        $query .= ' where id=?';
        unless ($done) {
            dbh()->do($query, {}, $q->param('anonymous') ? 't' : 'f', $new_state,
                $q->param('name'), $q->param('email'), $q->param('title'), $q->param('detail'), $id);
            if ($new_state ne $row{state}) {	
                admin_log_edit($q, $id, 'problem', 'state_change');
            }
            if ($q->param('anonymous') ne $row{anonymous} || 
                $q->param('name') ne $row{name} ||
                $q->param('email') ne $row{email} || 
                $q->param('title') ne $row{title} ||
                $q->param('detail') ne $row{detail}) {
               admin_log_edit($q, $id, 'problem', 'edit');
            } 
            dbh()->commit();
            map { $row{$_} = $q->param($_) } qw(anonymous state name email title detail);
            $status_message = '<p><em>Updated!</em></p>';
        }
    }
    my %row_h = map { $_ => $row{$_} ? ent($row{$_}) : '' } keys %row;
    my $title = "Editing problem $id";
    print html_head($q, $title);
    print $q->h1($title);
    print $status_message;

    my $council = $row{council} || '<em>None</em>';
    (my $areas = $row{areas}) =~ s/^,(.*),$/$1/;
    my $easting = int($row{easting}+0.5);
    my $northing = int($row{northing}+0.5);
    my $questionnaire = $row{send_questionnaire} ? 'Yes' : 'No';
    my $used_map = $row{used_map} ? 'used map' : "didn't use map";
    (my $whensent = $row{whensent} || '&nbsp;') =~ s/\..*//;
    (my $confirmed = $row{confirmed} || '-') =~ s/ (.*?)\..*/&nbsp;$1/;
    my $photo = '';
    my $cobrand_data;
    if ($row{cobrand}) {
        $cobrand_data = $row{cobrand_data};
    } else {
        $cobrand_data = Cobrand::cobrand_data_for_generic_problem($cobrand, \%row);
    }
    $photo = '<li><img align="top" src="' . Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/photo?id=' . $row{id} . '">
<input type="checkbox" id="remove_photo" name="remove_photo" value="1">
<label for="remove_photo">Remove photo (can\'t be undone!)</label>' if $row{photo};
    
    my $url_base = Cobrand::base_url_for_emails($cobrand, $cobrand_data);
    my $url = $url_base . '/report/' . $row{id};

    my $anon = $q->label({-for=>'anonymous'}, 'Anonymous:') . ' ' . $q->popup_menu(-id => 'anonymous', -name => 'anonymous', -values => { 1=>'Yes', 0=>'No' }, -default => $row{anonymous});
    my $state = $q->label({-for=>'state'}, 'State:') . ' ' . $q->popup_menu(-id => 'state', -name => 'state', -values => { confirmed => 'Open', fixed => 'Fixed', hidden => 'Hidden', unconfirmed => 'Unconfirmed', partial => 'Partial' }, -default => $row{state});

    my $resend = '';
    $resend = ' <input onclick="return confirm(\'You really want to resend?\')" type="submit" name="resend" value="Resend report">' if $row{state} eq 'confirmed';

    print $q->start_form(-method => 'POST', -action => './');
    print $q->hidden('page');
    print $q->hidden('id');
    print $q->hidden('token', get_token($q));
    print $q->hidden('submit', 1);
    print <<EOF;
<ul>
<li><a href="$url">View report on site</a>
<li><label for="title">Subject:</label> <input size=60 type="text" id="title" name="title" value="$row_h{title}">
<li><label for="detail">Details:</label><br><textarea name="detail" id="detail" cols=60 rows=10>$row_h{detail}</textarea>
<li>Co-ordinates: $easting,$northing (originally entered $row_h{postcode}, $used_map)
<li>For council(s): $council (other areas: $areas)
<li>$anon
<li>$state
<li>Category: $row{category}
<li>Name: <input type="text" name="name" id="name" value="$row_h{name}">
<li>Email: <input type="text" id="email" name="email" value="$row_h{email}">
<li>Phone: $row_h{phone}
<li>Created: $row{created}
<li>Confirmed: $confirmed
<li>Sent: $whensent $resend
<li>Last update: $row{lastupdate}
<li>Service: $row{service}
<li>Cobrand: $row{cobrand}
<li>Cobrand data: $row{cobrand_data}
<li>Going to send questionnaire? $questionnaire
$photo
</ul>
EOF
    print $q->submit('Submit changes');
    print $q->end_form;

    print $q->h2('Updates');
    my $updates = select_all('select * from comment where problem_id=? order by created', $id);
    admin_show_updates($q, $updates);
    print html_tail($q);
}

sub admin_show_updates {
    my ($q, $updates) = @_;
    my $cobrand = Page::get_cobrand($q);
    print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
    print $q->Tr({}, $q->th({}, ['ID', 'State', 'Name', 'Email', 'Created', 'Cobrand', 'Text', '*']));
    my $base_url = ''; 
    my $cobrand_data;
    foreach (@$updates) {
        my $url = $_->{id};
        if ( $_->{state} eq 'confirmed' ) {
            if ($_->{cobrand}) {
                $cobrand_data = $_->{cobrand_data};
            } else {
                $cobrand_data = Cobrand::cobrand_data_for_generic_update($cobrand, $_);
            }
            $url = $q->a({ -href => Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/report/' . $_->{problem_id} . '#update_' . $_->{id} },
                $url);
        }
        my $cobrand = $_->{cobrand} . '<br>' . $_->{cobrand_data};
        print $q->Tr({}, $q->td([ $url, $_->{state}, ent($_->{name} || ''),
        ent($_->{email}), $_->{created}, $cobrand, ent($_->{text}),
        $q->a({ -href => NewURL($q, page=>'update_edit', id=>$_->{id}) }, 'Edit')
        ]));
    }
    print $q->end_table;
}

sub admin_edit_update {
    my ($q, $id) = @_;
    my $row = Problems::admin_fetch_update($id);
    return not_found($q) if ! $row->[0];
    my $cobrand = Page::get_cobrand($q);

    my %row = %{$row->[0]};
    my $status_message;
    if ($q->param('submit')) {
        return not_found($q) if $q->param('token') ne get_token($q);
        my $query = 'update comment set state=?, name=?, email=?, text=?';
        if ($q->param('remove_photo')) {
            $query .= ', photo=null';
        }
        $query .= ' where id=?';
        dbh()->do($query, {}, $q->param('state'), $q->param('name'), $q->param('email'), $q->param('text'), $id);
        if ($q->param('state') ne $row{state}) {
            admin_log_edit($q, $id, 'update', 'state_change');
        } 
        if ($q->param('name') ne $row{name} || $q->param('email') ne $row{email} || $q->param('text') ne $row{text}) {
            admin_log_edit($q, $id, 'update', 'edit');
        }
        dbh()->commit();
        map { $row{$_} = $q->param($_) } qw(state name email text);
        $status_message = '<p><em>Updated!</em></p>';
    }
   my %row_h = map { $_ => $row{$_} ? ent($row{$_}) : '' } keys %row;
    my $title = "Editing update $id";
    print html_head($q, $title);
    print $q->h1($title);
    print $status_message;
    my $name = $row_h{name};
    $name = '' unless $name;
    my $cobrand_data;
    if ($row{cobrand}) {
        $cobrand_data = $row{cobrand_data};
    } else {
        $cobrand_data = Cobrand::cobrand_data_for_generic_update($cobrand, \%row);
    }
    my $photo = '';
    $photo = '<li><img align="top" src="' . Cobrand::base_url_for_emails($cobrand, $cobrand_data)  . '/photo?c=' . $row{id} . '">
<input type="checkbox" id="remove_photo" name="remove_photo" value="1">
<label for="remove_photo">Remove photo (can\'t be undone!)</label>' if $row{photo};

    my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data) . '/report/' . $row{problem_id} . '#update_' . $row{id};

    my $state = $q->label({-for=>'state'}, 'State:') . ' ' . $q->popup_menu(-id => 'state', -name => 'state', -values => { confirmed => 'Confirmed', hidden => 'Hidden', unconfirmed => 'Unconfirmed' }, -default => $row{state});

    print $q->start_form(-method => 'POST', -action => './');
    print $q->hidden('page');
    print $q->hidden('id');
    print $q->hidden('token', get_token($q));
    print $q->hidden('submit', 1);
    print <<EOF;
<ul>
<li><a href="$url">View update on site</a>
<li><label for="text">Text:</label><br><textarea name="text" id="text" cols=60 rows=10>$row_h{text}</textarea>
<li>$state
<li>Name: <input type="text" name="name" id="name" value="$name"> (blank to go anonymous)
<li>Email: <input type="text" id="email" name="email" value="$row_h{email}">
<li>Cobrand: $row{cobrand}
<li>Cobrand data: $row{cobrand_data} 
<li>Created: $row{created}
$photo
</ul>
EOF
    print $q->submit('Submit changes');
    print $q->end_form;
    print html_tail($q);
}

sub get_cobrand_data_from_hash {
    my ($cobrand, $data) = @_;
    my $cobrand_data;
    if ($data->{cobrand}) {
        $cobrand_data = $data->{cobrand_data};
    } else {
        $cobrand_data = Cobrand::cobrand_data_for_generic_problem($cobrand, $data);
    }
    return $cobrand_data;
}

sub admin_log_edit {
   my ($q, $id, $object_type, $action) = @_;
   my $query = "insert into admin_log (admin_user, object_type, object_id, action)
                values (?, ?, ?, ?);";
   dbh()->do($query, {}, $q->remote_user(), $object_type, $id, $action);
}

sub admin_timeline {
    my $q = shift;
    my $cobrand = Page::get_cobrand($q);
    print html_head($q, 'Timeline');
    print $q->h1('Timeline');

    my %time;
    #my $backto_unix = time() - 60*60*24*7;

    my $probs = Problems::timeline_problems();
    foreach (@$probs) {
        push @{$time{$_->{created}}}, { type => 'problemCreated', %$_ };
        push @{$time{$_->{confirmed}}}, { type => 'problemConfirmed', %$_ } if $_->{confirmed};
        push @{$time{$_->{whensent}}}, { type => 'problemSent', %$_ } if $_->{whensent};
    }

    my $questionnaire = Problems::timeline_questionnaires($cobrand);
    foreach (@$questionnaire) {
        push @{$time{$_->{whensent}}}, { type => 'quesSent', %$_ };
        push @{$time{$_->{whenanswered}}}, { type => 'quesAnswered', %$_ } if $_->{whenanswered};
    }

    my $updates = Problems::timeline_updates();
    foreach (@$updates) {
        push @{$time{$_->{created}}}, { type => 'update', %$_} ;
    }

    my $alerts = Problems::timeline_alerts($cobrand);

   
    foreach (@$alerts) {
        push @{$time{$_->{whensubscribed}}}, { type => 'alertSub', %$_ };
    }
    $alerts = Problems::timeline_deleted_alerts($cobrand);
    foreach (@$alerts) {
        push @{$time{$_->{whendisabled}}}, { type => 'alertDel', %$_ };
    }

    my $date = '';
    my $cobrand_data;
    foreach (reverse sort keys %time) {
        my $curdate = strftime('%A, %e %B %Y', localtime($_));
        if ($date ne $curdate) {
            print '</dl>' if $date;
            print "<h2>$curdate</h2> <dl>";
            $date = $curdate;
        }
        print '<dt><b>', strftime('%H:%M:%S', localtime($_)), ':</b></dt> <dd>';
        foreach (@{$time{$_}}) {
            my $type = $_->{type};
            if ($type eq 'problemCreated') {
                print "Problem $_->{id} created; by " . ent($_->{name}) . " &lt;" . ent($_->{email}) . "&gt;, '" . ent($_->{title}) . "'";
            } elsif ($type eq 'problemConfirmed') {
                $cobrand_data = get_cobrand_data_from_hash($cobrand, $_);
                my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data)  . "/report/$_->{id}";
                print "Problem <a href='$url'>$_->{id}</a> confirmed; by " . ent($_->{name}) ." &lt;" . ent($_->{email}) . "&gt;, '" . ent($_->{title}) ."'";
            } elsif ($type eq 'problemSent') {
                $cobrand_data = get_cobrand_data_from_hash($cobrand, $_);
                my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data) . "/report/$_->{id}";
                print "Problem <a href='$url'>$_->{id}</a> sent to council $_->{council}; by " . ent($_->{name}) . " &lt;" . ent($_->{email}) . "&gt;, '" . ent($_->{title}) . "'";
            } elsif ($type eq 'quesSent') {
                print "Questionnaire $_->{id} sent for problem $_->{problem_id}";
            } elsif ($type eq 'quesAnswered') {
                print "Questionnaire $_->{id} answered for problem $_->{problem_id}, $_->{old_state} to $_->{new_state}";
            } elsif ($type eq 'update') {
                $cobrand_data = get_cobrand_data_from_hash($cobrand, $_);
                my $url = Cobrand::base_url_for_emails($cobrand, $cobrand_data) . "/report/$_->{problem_id}#$_->{id}";
                my $name = ent($_->{name} || 'anonymous');
                print "Update <a href='$url'>$_->{id}</a> created for problem $_->{problem_id}; by $name &lt;" . ent($_->{email}) . "&gt;";
            } elsif ($type eq 'alertSub') {
                my $param = $_->{parameter} || '';
                my $param2 = $_->{parameter2} || '';
                print "Alert $_->{id} created for " . ent($_->{email}) . ", type $_->{alert_type}, parameters $param / $param2";
            } elsif ($type eq 'alertDel') {
                my $sub = strftime('%H:%M:%S %e %B %Y', localtime($_->{whensubscribed}));
                print "Alert $_->{id} disabled (created $sub)";
            }
            print '<br>';
        }
        print "</dd>\n";
    }
    print html_tail($q);

}

sub not_found {
    my ($q) = @_;
    print $q->header(-status=>'404 Not Found',-type=>'text/html');
    print "<h1>Not Found</h1>The requested URL was not found on this server.";
}

sub main {
    my $q = shift;
    my $page = $q->param('page');
    $page = "summary" if !$page;

    my $area_id = $q->param('area_id');
    my $category = $q->param('category');
    my $pages = allowed_pages($q);
    my @allowed_actions = keys %$pages;
 
    if (!grep {$_ eq $page} @allowed_actions) {
        not_found($q);
        return; 
    }

    if ($page eq "councilslist") {
        admin_councils_list($q);
    } elsif ($page eq "councilcontacts") {
        admin_council_contacts($q, $area_id);
    } elsif ($page eq "counciledit") {
        admin_council_edit($q, $area_id, $category);
    } elsif ($page eq 'reports') {
        admin_reports($q);
    } elsif ($page eq 'report_edit') {
        my $id = $q->param('id');
        admin_edit_report($q, $id);
    } elsif ($page eq 'update_edit') {
        my $id = $q->param('id');
        admin_edit_update($q, $id);
    } elsif ($page eq 'timeline') {
        admin_timeline($q);
    } else {
        admin_summary($q);
    }
}
Page::do_fastcgi(\&main);

sub trim {
    my $e = shift;
    $e =~ s/^\s+//;
    $e =~ s/\s+$//;
    return $e;
}
