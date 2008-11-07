#!/usr/bin/perl -w
#
# index.cgi
#
# Administration interface for FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: index.cgi,v 1.55 2008-11-07 10:35:54 matthew Exp $
#

my $rcsid = ''; $rcsid .= '$Id: index.cgi,v 1.55 2008-11-07 10:35:54 matthew Exp $';

use strict;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

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

sub html_head($$) {
    my ($q, $title) = @_;
    my $ret = $q->header(-type => 'text/html', -charset => 'utf-8');
    $ret .= <<END;
<html>
<head>
<title>$title - FixMyStreet administration</title>
</head>
<body>
END
    
    my $pages = {
        'summary' => 'Summary',
        'reports' => 'Reports',
        'councilslist' => 'Council contacts'
    };
    $ret .= $q->p(
        $q->strong("FixMyStreet admin:"), 
        map { $q->a( { href => NewURL($q, page => $_) }, $pages->{$_}) } keys %$pages
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

    print html_head($q, "Summary");
    print $q->h1("Summary");

    my $contacts = dbh()->selectcol_arrayref("select confirmed, count(*) as c from contacts group by confirmed", { Columns => [1,2] });
    my %contacts = @$contacts;
    $contacts{0} ||= 0;
    $contacts{1} ||= 0;
    $contacts{total} = $contacts{0} + $contacts{1};

    my $comments = dbh()->selectcol_arrayref("select state, count(*) as c from comment group by state", { Columns => [1,2] });
    my %comments = @$comments;

    my $problems = dbh()->selectcol_arrayref("select state, count(*) as c from problem group by state", { Columns => [1,2] });
    my %problems = @$problems;
    %problems = map { $_ => $problems{$_} || 0 } qw(confirmed fixed unconfirmed hidden partial);
    my $total_problems_live = $problems{confirmed} + $problems{fixed};
    my $total_problems = 0;
    map { $total_problems += $_ } values %problems;

    my $alerts = dbh()->selectcol_arrayref("select confirmed, count(*) as c from alert group by confirmed", { Columns => [1,2] });
    my %alerts = @$alerts; $alerts{0} ||= 0; $alerts{1} ||= 0;

    my $questionnaires = dbh()->selectcol_arrayref("select (whenanswered is not null), count(*) as c from questionnaire group by (whenanswered is not null)", { Columns => [1,2] });
    my %questionnaires = @$questionnaires;
    $questionnaires{0} ||= 0;
    $questionnaires{1} ||= 0;
    $questionnaires{total} = $questionnaires{0} + $questionnaires{1};
    my $questionnaires_pc = $questionnaires{1} / $questionnaires{total} * 100;
    
    print $q->ul(
        $q->li("<strong>$total_problems_live</strong> live problems"),
        $q->li("$comments{confirmed} live updates"),
        $q->li("$alerts{1} confirmed alerts, $alerts{0} unconfirmed"),
        $q->li("$questionnaires{total} questionnaires sent &ndash; $questionnaires{1} answered ($questionnaires_pc%)"),
        $q->li("$contacts{total} council contacts &ndash; $contacts{1} confirmed, $contacts{0} unconfirmed"),
    );

    print $q->p( $q->a({ href => mySociety::Config::get('BASE_URL') . "/bci-live-creation.png" }, 
            "Graph of problem creation by status over time" ));

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
    my @types = grep { !/LGD/ } @$mySociety::VotingArea::council_parent_types; # LGD are NI councils
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
        my $email = trim($q->param('email'));
        my $category = trim($q->param('category'));
        $category = 'Empty Property' if $q->{site} eq 'emptyhomes';
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
    $q->delete_all(); # No need for state!

    my $bci_data = select_all("select * from contacts where area_id = ? order by category", $area_id);
    my $mapit_data = mySociety::MaPit::get_voting_area_info($area_id);

    # Title
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
    print $q->p($links_html);

    # Display of addresses / update statuses form
    print $q->start_form(-method => 'POST', -action => $q->url('relative'=>1));
    print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
    print $q->th({}, ["Category", "Email", "Confirmed", "Deleted", "Last editor", "Note", "When edited", 'Confirm']);
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
        $q->hidden('page', 'councilcontacts'),
        $q->submit('Update statuses')
    );
    print $q->end_form();

    # Display form for adding new category
    print $q->h2('Add new category');
    print $q->start_form(-method => 'POST', -action => $q->url('relative'=>1));
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
    print $q->start_form(-method => 'POST', -action => $q->url('relative'=>1));
    map { $q->param($_, $bci_data->{$_}) } qw/category email confirmed deleted/;
    $q->param('page', 'councilcontacts');
    $q->param('posted', 'new');
    print $q->strong("Category: ") . $bci_data->{category};
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
    print $q->th({}, ["When edited", "Email", "Confirmed", "Deleted", "Editor", "Note"]);
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
    print html_head($q, $title);
    print $q->h1($title);

    print $q->start_form(-method => 'GET', -action => './');
    print $q->label({-for => 'search'}, 'Search:'), ' ', $q->textfield(-id => 'search', -name => "search", -size => 30);
    print $q->hidden('page');
    print $q->end_form;

    if (my $search = $q->param('search')) {
        my $results = select_all("select id, council, category, title, name,
            email, anonymous, created, confirmed, state, service, lastupdate,
            whensent, send_questionnaire from problem where id=? or email ilike
            '%'||?||'%' or name ilike '%'||?||'%' or title ilike '%'||?||'%' or
            detail ilike '%'||?||'%' or council like '%'||?||'%'", $search+0,
            $search, $search, $search, $search, $search);
        print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
        print $q->th({}, ['ID', 'Title', 'Name', 'Email', 'Council', 'Category', 'Anonymous', 'Created', 'State', 'When sent', '*']);
        foreach (@$results) {
            my $url = mySociety::Config::get('BASE_URL') . '/report/' . $_->{id};
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
            print $q->Tr({}, $q->td([ $q->a({ -href => $url }, $_->{id}), $_->{title}, $_->{name}, $_->{email},
            $q->a({ -href => NewURL($q, page=>'councilcontacts', area_id=>$council)}, $council),
            $category, $anonymous, $created, $state, $whensent,
            $q->a({ -href => NewURL($q, page=>'report_edit', id=>$_->{id}) }, 'Edit')
            ]));
        }
        print $q->end_table;

        print $q->h2('Updates');
        my $updates = select_all("select * from comment where id=? or
        problem_id=? or email ilike '%'||?||'%' or name ilike '%'||?||'%' or
        text ilike '%'||?||'%'", $search+0, $search+0, $search, $search,
        $search);
        admin_show_updates($q, $updates);
    }

    print html_tail($q);
}

sub admin_edit_report {
    my ($q, $id) = @_;
    my $title = "Editing problem $id";
    print html_head($q, $title);
    print $q->h1($title);

    my $row = dbh()->selectall_arrayref('select * from problem where id=?', { Slice=>{} }, $id);
    my %row = %{$row->[0]};

    if ($q->param('resend')) {
        dbh()->do('update problem set whensent=null where id=?', {}, $id);
        dbh()->commit();
        print '<p><em>That problem will now be resent.</em></p>';
    } elsif ($q->param('submit')) {
        my $new_state = $q->param('state');
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
        dbh()->do($query, {}, $q->param('anonymous') ? 't' : 'f', $new_state,
            $q->param('name'), $q->param('email'), $q->param('title'), $q->param('detail'), $id);
        dbh()->commit();
        map { $row{$_} = $q->param($_) } qw(anonymous state name email title detail);
        print '<p><em>Updated!</em></p>';
    }

    my $council = $row{council} || '<em>None</em>';
    (my $areas = $row{areas}) =~ s/^,(.*),$/$1/;
    my $easting = int($row{easting}+0.5);
    my $northing = int($row{northing}+0.5);
    my $questionnaire = $row{send_questionnaire} ? 'Yes' : 'No';
    my $used_map = $row{used_map} ? 'used map' : "didn't use map";

    my $photo = '';
    $photo = '<li><img align="top" src="' . mySociety::Config::get('BASE_URL') . '/photo?id=' . $row{id} . '">
<input type="checkbox" id="remove_photo" name="remove_photo" value="1">
<label for="remove_photo">Remove photo (can\'t be undone!)</label>' if $row{photo};

    my $url = mySociety::Config::get('BASE_URL') . '/report/' . $row{id};

    my $anon = $q->label({-for=>'anonymous'}, 'Anonymous:') . ' ' . $q->popup_menu(-id => 'anonymous', -name => 'anonymous', -values => { 1=>'Yes', 0=>'No' }, -default => $row{anonymous});
    my $state = $q->label({-for=>'state'}, 'State:') . ' ' . $q->popup_menu(-id => 'state', -name => 'state', -values => { confirmed => 'Open', fixed => 'Fixed', hidden => 'Hidden', unconfirmed => 'Unconfirmed', partial => 'Partial' }, -default => $row{state});

    my $resend = '';
    $resend = '<li><input type="submit" name="resend" value="Resend report">' if $row{state} eq 'confirmed';

    print $q->start_form(-method => 'POST', -action => './');
    print $q->hidden('page');
    print $q->hidden('id');
    print $q->hidden('submit', 1);
    print <<EOF;
<ul>
<li><a href="$url">View report on site</a>
<li><label for="title">Subject:</label> <input size=60 type="text" id="title" name="title" value="$row{title}">
<li><label for="detail">Details:</label><br><textarea name="detail" id="detail" cols=60 rows=10>$row{detail}</textarea>
<li>Co-ordinates: $easting,$northing (originally entered $row{postcode}, $used_map)
<li>For council(s): $council (other areas: $areas)
<li>$anon
<li>$state
<li>Category: $row{category}
<li>Name: <input type="text" name="name" id="name" value="$row{name}">
<li>Email: <input type="text" id="email" name="email" value="$row{email}">
<li>Phone: $row{phone}
<li>Created: $row{created}
<li>Confirmed: $row{confirmed}
<li>Sent: $row{whensent}
<li>Last update: $row{lastupdate}
<li>Service: $row{service}
<li>Going to send questionnaire? $questionnaire
$photo
$resend
</ul>
EOF
    print $q->submit('Submit changes');
    print $q->end_form;

    print $q->h2('Updates');
    my $updates = select_all('select * from comment where problem_id=?', $id);
    admin_show_updates($q, $updates);
    print html_tail($q);
}

sub admin_show_updates {
    my ($q, $updates) = @_;
    print $q->start_table({border=>1, cellpadding=>2, cellspacing=>0});
    print $q->th({}, ['ID', 'State', 'Name', 'Email', 'Created', 'Text', '*']);
    foreach (@$updates) {
        my $url = mySociety::Config::get('BASE_URL') . '/report/' . $_->{problem_id} . '#' . $_->{id};
        print $q->Tr({}, $q->td([ $q->a({ -href => $url }, $_->{id}), $_->{state}, $_->{name},
        $_->{email}, $_->{created}, $_->{text},
        $q->a({ -href => NewURL($q, page=>'update_edit', id=>$_->{id}) }, 'Edit')
        ]));
    }
    print $q->end_table;
}

sub admin_edit_update {
    my ($q, $id) = @_;
    my $title = "Editing update $id";
    print html_head($q, $title);
    print $q->h1($title);

    my $row = dbh()->selectall_arrayref('select * from comment where id=?', { Slice=>{} }, $id);
    my %row = %{$row->[0]};

    if ($q->param('submit')) {
        my $query = 'update comment set state=?, name=?, email=?, text=?';
        if ($q->param('remove_photo')) {
            $query .= ', photo=null';
        }
        $query .= ' where id=?';
        dbh()->do($query, {}, $q->param('state'), $q->param('name'), $q->param('email'), $q->param('text'), $id);
        dbh()->commit();
        map { $row{$_} = $q->param($_) } qw(state name email text);
        print '<p><em>Updated!</em></p>';
    }

    my $photo = '';
    $photo = '<li><img align="top" src="' . mySociety::Config::get('BASE_URL') . '/photo?c=' . $row{id} . '">
<input type="checkbox" id="remove_photo" name="remove_photo" value="1">
<label for="remove_photo">Remove photo (can\'t be undone!)</label>' if $row{photo};

    my $url = mySociety::Config::get('BASE_URL') . '/report/' . $row{problem_id} . '#' . $row{id};

    my $state = $q->label({-for=>'state'}, 'State:') . ' ' . $q->popup_menu(-id => 'state', -name => 'state', -values => { confirmed => 'Confirmed', hidden => 'Hidden', unconfirmed => 'Unconfirmed' }, -default => $row{state});

    print $q->start_form(-method => 'POST', -action => './');
    print $q->hidden('page');
    print $q->hidden('id');
    print $q->hidden('submit', 1);
    print <<EOF;
<ul>
<li><a href="$url">View update on site</a>
<li><label for="text">Text:</label><br><textarea name="text" id="text" cols=60 rows=10>$row{text}</textarea>
<li>$state
<li>Name: <input type="text" name="name" id="name" value="$row{name}"> (blank to go anonymous)
<li>Email: <input type="text" id="email" name="email" value="$row{email}">
<li>Created: $row{created}
$photo
</ul>
EOF
    print $q->submit('Submit changes');
    print $q->end_form;
}

sub main {
    my $q = shift;
    my $page = $q->param('page');
    $page = "summary" if !$page;

    my $area_id = $q->param('area_id');
    my $category = $q->param('category');

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
