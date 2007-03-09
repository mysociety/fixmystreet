#!/usr/bin/perl -w
#
# index.cgi
#
# Administration interface for Neighbourhood Fix-It
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: index.cgi,v 1.8 2007-03-09 15:24:34 matthew Exp $
#

my $rcsid = ''; $rcsid .= '$Id: index.cgi,v 1.8 2007-03-09 15:24:34 matthew Exp $';

use strict;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use CGI::Carp;
use Error qw(:try);
use POSIX;
use DBI;

use Page;
use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::MaPit;
use mySociety::VotingArea;

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
        map { dbh()->selectrow_array($_->[0]) . " " . $_->[1] } ( 
            ['select count(*) from contacts', 'contacts'],
            ['select count(*) from problem', 'problems'],
            ['select count(*) from comment', 'comments'],
            ['select count(*) from alert', 'alerts']
    )));

    print $q->h3("Council contacts status");
    my $statuses = dbh()->selectall_arrayref("select count(*) as c, confirmed from contacts group by confirmed order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . ($_->[1] ? 'confirmed' : 'unconfirmed') } @$statuses 
    ));

    print $q->h3("Problem status");
    $statuses = dbh()->selectall_arrayref("select count(*) as c, state from problem group by state order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . $_->[1] } @$statuses 
    ));

    print $q->h3("Comment status");
    $statuses = dbh()->selectall_arrayref("select count(*) as c, state from comment group by state order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . $_->[1] } @$statuses 
    ));

    print $q->h3("Alert status");
    $statuses = dbh()->selectall_arrayref("select count(*) as c, confirmed from alert group by confirmed order by c desc");
    print $q->p(join($q->br(), 
        map { $_->[0] . " " . ($_->[1] ? 'confirmed' : 'unconfirmed') } @$statuses 
    ));

    print html_tail($q);
}

sub canonicalise_council {
    my $c = shift;
    $c =~ s/City of //;
    $c =~ s/N\. /North /;
    $c =~ s/E\. /East /;
    $c =~ s/W\. /West /;
    $c =~ s/S\. /South /;
    return $c;
}

# do_council_contacts CGI
sub do_council_contacts ($) {
    my ($q) = @_;

    print html_head($q, "Council contacts");
    print $q->h2("Council contacts");

    # Table of editors
    print $q->h3("Diligency prize league table");
    my $edit_activity = dbh()->selectall_arrayref("select count(*) as c, editor from contacts_history group by editor order by c desc");
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
    @councils_ids = sort { canonicalise_council($councils->{$a}->{name}) cmp canonicalise_council($councils->{$b}->{name}) } @councils_ids;
    my $bci_info = dbh()->selectall_hashref("select * from contacts", 'area_id');
    print $q->p(join($q->br(), 
        map { 
            $q->a({href=>build_url($q, $q->url('relative'=>1), 
              {'area_id' => $_, 'page' => 'counciledit',})}, 
              canonicalise_council($councils->{$_}->{name})) . " " .  
                ($bci_info->{$_} ? ($bci_info->{$_}->{email} . " " .
                    ($bci_info->{$_}->{confirmed} ? 'confirmed' : $q->strong('unconfirmed'))
                ) : $q->strong('no info at all'))
        } @councils_ids));

    print html_tail($q);
}


# do_council_edit CGI AREA_ID
sub do_council_edit ($$) {
    my ($q, $area_id) = @_;

    # Submit form
    my $updated = '';
    if ($q->param('posted')) {
        # History is automatically stored by a trigger in the database
        my $update = dbh()->do("update contacts set
            email = ?,
            confirmed = ?,
            editor = ?,
            whenedited = ms_current_timestamp(),
            note = ?
            where area_id = ?
            ", {}, 
            $q->param('email'), ($q->param('confirmed') ? 1 : 0),
            ($q->remote_user() || "*unknown*"), $q->param('note'),
            $area_id
            );
        unless ($update > 0) {
            dbh()->do('insert into contacts
                (area_id, email, editor, whenedited, note, confirmed)
                values
                (?, ?, ?, ms_current_timestamp(), ?, ?)', {},
                $area_id, $q->param('email'), ($q->remote_user() || '*unknown*'),
                $q->param('note'), ($q->param('confirmed') ? 1 : 0)
            );
        }
        dbh()->commit();

        $updated = $q->p($q->em("Values updated"));
    }
 
    # Get all the data
    my $bci_data = dbh()->selectall_hashref("select * from contacts where area_id = ?", 'area_id', {}, $area_id)->{$area_id};
    my $bci_history = dbh()->selectall_arrayref("select * from contacts_history where area_id = ? order by contacts_history_id", {}, $area_id);
    my $mapit_data = mySociety::MaPit::get_voting_area_info($area_id);
    
    # Title
    my $title = 'Council contact for ' . $mapit_data->{name};
    print html_head($q, $title);
    print $q->h2($title);
    print $updated;

    # Display form for editing details
    print $q->start_form(-method => 'POST', -action => $q->url('relative'=>1));
    print $q->strong("Email: ");
    $q->param("email", $bci_data->{email});
    $q->param("confirmed", $bci_data->{confirmed});
    print $q->textfield(-name => "email", -size => 30) . " ";
    print $q->checkbox(-name => "confirmed", -value => 1, -label => "Confirmed") . " ";
    print $q->br();
    print $q->strong("Note: ");
    print $q->textarea(-name => "note", -rows => 3, -columns=>40) . " ";
    print $q->br();
    print $q->hidden('area_id');
    print $q->hidden('posted', 'true');
    print $q->hidden('page', 'counciledit');
    print $q->submit('Save changes');
    print $q->end_form();

    # Example postcode
    my $example_postcode = mySociety::MaPit::get_example_postcode($area_id);
    if ($example_postcode) {
        print $q->p("Example postcode to test on NeighbourHoodFixit.com: ",
            $q->a({href => build_url($q, "http://www.neighbourhoodfixit.com/",
                    { 'pc' => $example_postcode}) }, 
                $example_postcode));
    }

    # Display history of changes
    print $q->h3('History');
    print $q->start_table({border=>1});
    print $q->th({}, ["whenedited", "email", "confirmed", "editor", "note"]);
    my $html = '';
    my $prev = undef;
    foreach my $h (@$bci_history) {
        $h->[6] = $h->[6] ? "yes" : "no",
        my $emailchanged = ($prev && $h->[2] ne $prev->[2]) ? 1 : 0;
        my $confirmedchanged = ($prev && $h->[6] ne $prev->[6]) ? 1 : 0;
        $html .= $q->Tr({}, $q->td([ 
                $h->[4] =~ m/^(.+)\.\d+$/,
                $emailchanged ? $q->strong($h->[2]) : $h->[2],
                $confirmedchanged ? $q->strong($h->[6]) : $h->[6],
                $h->[3],
                $h->[5]
            ]));
        $prev = $h;
    }
    print $html;
    print $q->end_table();

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

    print html_tail($q);
}

sub main {
    my $q = shift;
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
}
Page::do_fastcgi(\&main);
