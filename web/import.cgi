#!/usr/bin/perl -w -I../perllib

# import.cgi
# Script to which things like iPhones can POST new data
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: import.cgi,v 1.9 2008-12-11 15:18:44 matthew Exp $

use strict;
use Error qw(:try);
use Standard;
use mySociety::AuthToken;
use mySociety::EmailUtil;
use mySociety::EvEl;

sub main {
    my $q = shift;

    my @vars = qw(service subject detail name email phone easting northing lat lon id phone_id);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my @errors;

    unless ($ENV{REQUEST_METHOD} eq 'POST') {
        print Page::header($q, title=>'External import');
        docs();
        print Page::footer($q);
        return;
    }

    print $q->header(-charset => 'utf-8', -content_type => 'text/plain');

    my $fh = $q->upload('photo');
    if ($fh) {
        my $err = Page::check_photo($q, $fh);
        push @errors, $err if $err;
    }

    push @errors, 'You must supply a service' unless $input{service};
    push @errors, 'Please enter a subject' unless $input{subject} && $input{subject} =~ /\S/;
    push @errors, 'Please enter your name' unless $input{name} && $input{name} =~ /\S/;

    if (!$input{email} || $input{email} !~ /\S/) {
        push @errors, 'Please enter your email';
    } elsif (!mySociety::EmailUtil::is_valid_email($input{email})) {
        push @errors, 'Please enter a valid email';
    }

    if ($input{lat}) {
        try {
            ($input{easting}, $input{northing}) = mySociety::GeoUtil::wgs84_to_national_grid($input{lat}, $input{lon}, 'G');
        } catch Error::Simple with { 
            my $e = shift;
            push @errors, "We had a problem with the supplied co-ordinates - outside the UK?";
        };
    }
    # TODO: Get location from photo if present in EXIF data?

    my $photo;
    if ($fh) {
        try {
            $photo = Page::process_photo($fh, 1);
        } catch Error::Simple with {
            my $e = shift;
            push @errors, "That photo doesn't appear to have uploaded correctly ($e), please try again.";
        };
    }

    unless ($photo || ($input{easting} && $input{northing})) {
        push @errors, 'Either a location or a photo must be provided.';
    }

    if (@errors) {
        print map { "ERROR:$_\n" } @errors;
        return;
    }

    # Store for possible future use
    if ($input{id} || $input{phone_id}) {
        my $id = $input{id} || $input{phone_id};
        my $already = dbh()->selectrow_array('select id from partial_user where service=? and nsid=?', {}, $input{service}, $id);
        unless ($already) {
            dbh()->do('insert into partial_user (service, nsid, name, email, phone) values (?, ?, ?, ?, ?)',
                {}, $input{service}, $id, $input{name}, $input{email}, $input{phone});
        }
    }

    # Store what we have so far in the database
    my $id = dbh()->selectrow_array("select nextval('problem_id_seq')");
    Utils::workaround_pg_bytea("insert into problem
        (id, postcode, easting, northing, title, detail, name, service,
         email, phone, photo, state, used_map, anonymous, category, areas)
        values
        (?, '', ?, ?, ?, ?, ?, ?, ?, ?, ?, 'partial', 't', 'f', '', '')", 10,
        $id, $input{easting}, $input{northing}, $input{subject},
        $input{detail}, $input{name}, $input{service}, $input{email}, $input{phone}, $photo);

    # Send checking email
    my $template = File::Slurp::read_file("$FindBin::Bin/../templates/emails/partial");
    my $token = mySociety::AuthToken::store('partial', $id);
    my %h = (
        name => $input{name} ? ' ' . $input{name} : '',
        url => mySociety::Config::get('BASE_URL') . '/L/' . $token,
        service => $input{service},
    );

    my $sender = mySociety::Config::get('CONTACT_EMAIL');
    $sender =~ s/team/fms-DO-NOT-REPLY/;
    mySociety::EvEl::send({
        _template_ => $template,
        _parameters_ => \%h,
        To => $input{name} ? [ [ $input{email}, $input{name} ] ] : $input{email},
        From => [ $sender, 'FixMyStreet' ],
    }, $input{email});

    dbh()->commit();
    print 'SUCCESS';
}

Page::do_fastcgi(\&main);

sub docs {
    print <<EOF;
<p>You may inject problem reports into FixMyStreet programatically using this
simple interface. Upon receipt, an email will be sent to the address given,
with a link the user must click in order to check the details of their report,
add any other information they wish, and then submit to the council.

<p>This interface returns a plain text response; either <samp>SUCCESS</samp> if
the report has been successfully received, or if not, a list of errors, one per
line each starting with <samp>ERROR:</samp>.

<p>You may submit the following information by POST to this URL
(i.e. <samp>http://www.fixmystreet.com/import</samp> ):</p>
<dl>
<dt>service
<dd>
<em>Required</em>.
Name of application/service using this interface.
<dt>id
<dd>Unique ID of a user/device, for possible future use.
<br><small>(e.g. used by Flickr import to know which accounts to look at)</small>
<dt>subject
<dd>
<em>Required</em>. Subject of problem report.
<dt>detail
<dd>Main body and details of problem report.
<dt>name
<dd>
<em>Required</em>. Name of problem reporter.
<dt>email
<dd>
<em>Required</em>. Email address of problem reporter.
<dt>phone
<dd>Telephone number of problem reporter.
<dt>easting / northing
<dt>lat / lon
<dd>Location of problem report. You can either supply eastings/northings, or WGS84 latitude/longitude.
<dt>photo
<dd>Photo of problem (JPEG only).
</dl>
EOF
}

