#!/usr/bin/perl -w -I../perllib -I../../perllib 
#
# index.cgi
#
# Administration interface for Neighbourhood Fix-It
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: index.cgi,v 1.2 2007-03-08 16:14:48 francis Exp $
#

my $rcsid = ''; $rcsid .= '$Id: index.cgi,v 1.2 2007-03-08 16:14:48 francis Exp $';

use strict;

use CGI::Fast qw(-no_xhtml);
#use CGI::Pretty;
#$CGI::Pretty::AutoloadClass = 'CGI::Fast';
#@CGI::Pretty::ISA = qw( CGI::Fast );

use CGI::Carp;
use HTML::Entities;
use Error qw(:try);
use Data::Dumper;
use POSIX;
use DBI;

use mySociety::WatchUpdate;
use mySociety::Config;
use mySociety::MaPit;
use mySociety::VotingArea;

mySociety::Config::set_file("../conf/general");
my $W = new mySociety::WatchUpdate();

# Connect to database
my $host = mySociety::Config::get('BCI_DB_HOST', undef);
my $port = mySociety::Config::get('BCI_DB_PORT', undef);
my $connstr = 'dbi:Pg:dbname=' . mySociety::Config::get('BCI_DB_NAME');
$connstr .= ";host=$host" if (defined($host));
$connstr .= ";port=$port" if (defined($port));
my $dbh = DBI->connect($connstr,
                    mySociety::Config::get('BCI_DB_USER'),
                    mySociety::Config::get('BCI_DB_PASS'),
                    { RaiseError => 1, AutoCommit => 0 });


sub html_head($$) {
    my ($q, $title) = @_;
    my $ret = $q->header(-type => 'text/html', -charset => 'utf-8');
    $ret .= <<END;
<html>
<head>
<title>$title - Neighbourhood Fix-it administration</title>
<style type="text/css"><!--
input { font-size: 9pt; margin: 0px; padding: 0px  }
table { margin: 0px; padding: 0px }
tr { margin: 0px; padding: 0px }
td { margin: 0px; padding: 0px; padding-right: 2pt; }
//--></style>
</head>
<body>
END
    
    my $pages = {
        'summary' => 'Summary',
        'councilcontacts' => 'Council contacts'
    };
    $ret .= $q->p(
        $q->strong("Neighbourhood Fix-it admin:"), 
        map { $q->a( {href=>build_url($q, $q->url('relative'=>1), { page => $_ })}, $pages->{$_}) } keys %$pages
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

# build_url CGI BASE HASH AMPERSAND
# Makes an escaped URL, whose main part is BASE, and
# whose parameters are the key value pairs in the hash.
# AMPERSAND is optional, set to 1 to use & rather than ;.
sub build_url($$$;$) {
    my ($q, $base, $hash, $ampersand) = @_;
    my $url = $base;
    my $first = 1;
    foreach my $k (keys %$hash) {
        $url .= $first ? '?' : ($ampersand ? '&' : ';');
        $url .= $q->escape($k);
        $url .= "=";
        $url .= $q->escape($hash->{$k});
        $first = 0;
    }
    return $url;
}

# do_summary CGI
# Displays general summary of counts.
sub do_summary ($) {
    my ($q) = @_;

    print html_head($q, "Summary");
    print $q->h2("Summary");

    print $q->p(join($q->br(), 
        map { $dbh->selectrow_array($_->[0]) . " " . $_->[1] } ( 
            ['select count(*) from contacts', 'contacts'],
            ['select count(*) from problem', 'problems'],
            ['select count(*) from comment', 'comments'],
            ['select count(*) from alert', 'alerts']
    )));

    print $q->h3("Council contacts status");
    my $statuses = $dbh->selectall_arrayref("select count(*) as c, confirmed from contacts group by confirmed order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . ($_->[1] ? 'confirmed' : 'unconfirmed') } @$statuses 
    ));

    print $q->h3("Problem status");
    $statuses = $dbh->selectall_arrayref("select count(*) as c, state from problem group by state order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . $_->[1] } @$statuses 
    ));

    print $q->h3("Comment status");
    $statuses = $dbh->selectall_arrayref("select count(*) as c, state from comment group by state order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . $_->[1] } @$statuses 
    ));

    print $q->h3("Alert status");
    $statuses = $dbh->selectall_arrayref("select count(*) as c, confirmed from alert group by confirmed order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . ($_->[1] ? 'confirmed' : 'unconfirmed') } @$statuses 
    ));

    print html_tail($q);
}

# do_council_contacts CGI
sub do_council_contacts ($) {
    my ($q) = @_;

    print html_head($q, "Council contacts");
    print $q->h2("Council contacts");

    # Table of editors
    print $q->h3("Diligency prize league table");
    my $edit_activity = $dbh->selectall_arrayref("select count(*) as c, editor from contacts_history group by editor order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " edits by " . $_->[1] } @$edit_activity 
    ));

    # Table of councils
    print $q->h3("Councils");
    my @councils;
    foreach my $type (@$mySociety::VotingArea::council_parent_types) {
        my $areas = mySociety::MaPit::get_areas_by_type($type);
        push @councils, @$areas;
    }
    my $councils = mySociety::MaPit::get_voting_areas_info(\@councils);
    my @councils_ids = keys %$councils;
    @councils_ids = sort { $councils->{$a}->{name} cmp $councils->{$b}->{name} } @councils_ids;
    my $bci_info = $dbh->selectall_hashref("select * from contacts", 'area_id');
    print $q->p(join($q->br(), 
        map { 
            $q->a({href=>build_url($q, $q->url('relative'=>1), 
              {'area_id' => $_, 'page' => 'counciledit',})}, 
              $councils->{$_}->{name}) . " " .  
                ($bci_info->{$_} ? ($bci_info->{$_}->{email} . " " .
                    ($bci_info->{$_}->{confirmed} ? 'confirmed' : $q->strong('unconfirmed'))
                ) : $q->strong('no info at all'))
        } @councils_ids));

    print html_tail($q);
}


# do_council_edit CGI AREA_ID
sub do_council_edit ($$) {
    my ($q, $area_id) = @_;

    # Altered URL
    if ($q->param('posted_extra_data') and $q->param) {
#        $d_dbh->do(q#delete
#            from raw_council_extradata where council_id = ?#, {}, $area_id);
#        $d_dbh->do(q#insert
#            into raw_council_extradata (council_id, councillors_url, make_live) values (?,?,?)#, 
#            {}, $area_id, $q->param('councillors_url'), defined($q->param('make_live')) ? 't' : 'f');
#        $d_dbh->commit();
#        print $q->redirect($q->param('r'));
#        return;
    }
 
    #if ($status_data->{status} eq "made-live") {
    #    my $example_postcode = MaPit::get_example_postcode($area_id);
    #    if ($example_postcode) {
    #        print $q->p("Example postcode to test on WriteToThem.com: ",
    #            $q->a({href => build_url($q, "http://www.writetothem.com/",
    #                    { 'pc' => $example_postcode}) }, 
    #                $example_postcode));
    #    }
    #}

    my $bci_data = $dbh->selectall_arrayref("select * from contacts where area_id = ?", {}, $area_id);
    my $bci_history = $dbh->selectall_arrayref("select * from contacts_history where area_id = ?", {}, $area_id);
    my $mapit_data = mySociety::MaPit::get_voting_area_info($area_id);

    print html_head($q, 'Council edit');
    print $q->h2("Council edit");
    print $q->pre(Dumper($mapit_data));
    print $q->pre(Dumper($bci_data));
    print $q->pre(Dumper($bci_history));

=comment
    # Google links
    print $q->p(
        $q->a({href => build_url($q, $q->url('relative'=>1), 
              {'area_id' => $area_id, 'page' => 'counciledit', 'r' => $q->url(-query=>1, -path=>1, -relative=>1)}) }, 
              "Edit councils and wards"),
        " |",
        $q->a({href => build_url($q, $q->url('relative'=>1), 
              {'area_id' => $area_id, 'page' => 'mapitnamesedit', 'r' => $q->url(-query=>1, -path=>1, -relative=>1)}) }, 
              "Edit ward aliases"),
        " |",
        map { ( $q->a({href => build_url($q, "http://www.google.com/search", 
                    {'q' => "$_"}, 1)},
                  "Google" . ($_ eq "" ? " alone" : " '$_'")),
            " (",
            $q->a({href => build_url($q, "http://www.google.com/search", 
                    {'q' => "$_",'btnI' => "I'm Feeling Lucky"}, 1)},
                  "IFL"),
            ")" ) } ("$name", "$name councillors ward", $name_data->{'name'} . " councillors")
    );
=cut

    # History
    #print $q->h2("Change History");
    #my @cols = qw#editor key alteration ward_name rep_first rep_last rep_party rep_email rep_fax#;
    #$sth = $d_dbh->prepare(q#select * from raw_input_data_edited where council_id = ? 
    #        order by order_id#);
    #$sth->execute($area_id);
    #while (my $row = $sth->fetchrow_hashref()) { 
    #    push @history, $row;
    #} 
    #print $q->start_table({border=>1});
    #print $q->th({}, ["whenedited", @cols]);
    #print $q->end_table();
 
    print html_tail($q);
}

=comment
# do_council_edit CGI 
# Form for editing all councillors in a council.
sub do_council_edit ($) {
    my ($q) = @_;
    my $newreptext = "Edit this for new rep";

    if ($q->param('posted')) {
        if ($q->param('Cancel')) {
            print $q->redirect($q->param('r'));
            return;
        }
        
        # Construct complete dataset of council
        my @newdata;
        my $c = 1;
        while ($q->param("key$c")) {
            if ($q->param("ward_name$c")) {
                my $rep;
                foreach my $fieldname qw(key ward_name rep_first rep_last rep_party rep_email rep_fax) {
                    $rep->{$fieldname}= $q->param($fieldname . $c);
                }
                push @newdata, $rep;
            } else { print "MOOOO"; }
            $c++;
        }
        # ... add new ward
        if ($q->param("ward_namenew") ne $newreptext) {
            my $rep;
            foreach my $fieldname qw(key ward_name rep_first rep_last rep_party rep_email rep_fax) {
                $rep->{$fieldname}= $q->param($fieldname . "new");
            }
            push @newdata, $rep;
        }
    
        # Make alteration
        CouncilMatch::edit_raw_data($area_id, 
                $name_data->{'name'}, $area_data->{'type'}, $area_data->{'ons_code'},
                \@newdata, $q->remote_user() || "*unknown*");
        $d_dbh->commit();

        # Regenerate stuff
        my $result = CouncilMatch::process_ge_data($area_id, 0);

        # Redirect if it's Save and Done
        if ($q->param('Save and Done')) {
            print $q->redirect($q->param('r'));
            return;
        }
    } 
    
    # Fetch data from database
    my @reps = CouncilMatch::get_raw_data($area_id);
    my $sort_by = $q->param("sort_by") || "ward_name";
    @reps = sort { $a->{$sort_by} cmp $b->{$sort_by}  } @reps;
    my $c = 1;
    foreach my $rep (@reps) {
        foreach my $fieldname qw(key ward_name rep_first rep_last rep_party rep_email rep_fax) {
            $q->param($fieldname . $c, $rep->{$fieldname});
        }
        $c++;
    }
    $q->delete("key$c");
    my $reps_count = $c-1;

    # Display header
    my $name = $name_data->{'name'};
    print html_head($q, $name . " - Edit");
    print $q->h1($name . " $area_id &mdash; Edit $reps_count Reps");
    print $q->p($q->b("Note:"), "Data entered here", $q->b("will"), "be
        returned to GovEval (if we ever get round to writing the script).
        Please do not enter information which a councillor wishes to remain
        private.  Leave email and fax blank and the councillor
        will be contacted via Democratic Services.");

    # Large form for editing council details
    print $q->start_form(-method => 'POST', -action => $q->url('relative'=>1));
    print $q->submit('Save and Done'); 
    print $q->submit('Save');
    print "&nbsp;";
    print $q->submit('Cancel');

    print $q->start_table();
    my $r = $q->param('r') || '';
    print $q->Tr({}, $q->th({}, [map 
        { $_->[1] eq $sort_by ? $_->[0] :
                    $q->a({href=>build_url($q, $q->url('relative'=>1), 
                      {'area_id' => $area_id, 'page' => 'counciledit',
                      'r' => $r, 'sort_by' => $_->[1]})}, $_->[0]) 
        } 
        (['Key', 'key'],
        ['Ward (erase to del rep)', 'ward_name'],
        ['First', 'rep_first'],
        ['Last', 'rep_last'],
        ['Party', 'rep_party'],
        ['Email', 'rep_email'],
        ['Fax', 'rep_fax'])
    ]));

    my $printrow = sub {
        my $c = shift;
        print $q->hidden(-name => "key$c", -size => 30);
        print $q->Tr({}, $q->td([ 
            $q->param("key$c"),
            $q->textfield(-name => "ward_name$c", -size => 30),
            $q->textfield(-name => "rep_first$c", -size => 15),
            $q->textfield(-name => "rep_last$c", -size => 15),
            $q->textfield(-name => "rep_party$c", -size => 10),
            $q->textfield(-name => "rep_email$c", -size => 20),
            $q->textfield(-name => "rep_fax$c", -size => 15)
        ]));
    };

    $q->param("ward_namenew", $newreptext);
    $q->param("keynew", "");
    &$printrow("new");
    $c = 1;
    while ($q->param("key$c")) {
        &$printrow($c);
        $c++;
    }
    
    print $q->end_table();
    print $q->hidden('page', 'counciledit');
    print $q->hidden('area_id');
    print $q->hidden('r');
    print $q->hidden('posted', 'true');

    print $q->submit('Save and Done'); 
    print $q->submit('Save');
    print "&nbsp;";
    print $q->submit('Cancel');

    print $q->end_form();

    print html_tail($q);
}
=cut

# Main loop, handles FastCGI requests
my $q;
try {
    while ($q = new CGI::Fast()) {
        #print Dumper($q->Vars);

        my $page = $q->param('page');
        $page = "summary" if !$page;
        my $area_id = $q->param('area_id');

        if ($page eq "councilcontacts") {
            do_council_contacts($q);
        } elsif ($page eq "counciledit") {
            do_council_edit($q, $area_id);
        } else {
            do_summary($q);
        }

        $W->exit_if_changed();
    }
} catch Error::Simple with {
    my $E = shift;
    my $msg = sprintf('%s:%d: %s', $E->file(), $E->line(), $E->text());
    warn "caught fatal exception: $msg";
    warn "aborting";
    encode_entities($msg);
    print "Status: 500\nContent-Type: text/html; charset=iso-8859-1\n\n",
            html_head($q, 'Error'),
            q(<p>Unfortunately, something went wrong. The text of the error
                    was:</p>),
            qq(<blockquote class="errortext">$msg</blockquote>),
            q(<p>Please try again later.),
            html_tail($q);
};

#$dbh->disconnect();

