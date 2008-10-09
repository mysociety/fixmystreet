#!/usr/bin/perl -w -I../perllib

# import.cgi
# Script to which things like iPhones can POST new data
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: import.cgi,v 1.1 2008-10-09 17:18:03 matthew Exp $

use strict;
use Standard;
use mySociety::AuthToken;
use mySociety::Email;
use mySociety::EmailUtil;

sub main {
    my $q = shift;
    print $q->header(-charset => 'utf-8', -content_type => 'text/plain');

    my @vars = qw(service title detail name email phone easting northing lat lon);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my @errors;

    my $fh = $q->upload('photo');
    if ($fh) {
        my $err = Page::check_photo($q, $fh);
        push @errors, $err if $err;
    }

    push @errors, 'You must supply a service' unless $input{service};
    push @errors, 'Please enter a subject' unless $input{title} && $input{title} =~ /\S/;
    push @errors, 'Please enter your name' unless $input{name} && $input{name} =~ /\S/;

    if (!$input{email} || $input{email} !~ /\S/) {
        push @errors, 'Please enter your email';
    } elsif (!mySociety::EmailUtil::is_valid_email($input{email})) {
        push @errors, 'Please enter a valid email';
    }

    if ($input{lat}) {
        ($input{easting}, $input{northing}) = mySociety::GeoUtil::wgs84_to_national_grid($input{lat}, $input{lon}, 'G');
    }
    # TODO: Get location from photo if present in EXIF data?

    my $photo;
    if ($fh) {
        try {
            $photo = Page::process_photo($fh);
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

    # Store what we have so far in the database
    my $id = dbh()->selectrow_array("select nextval('problem_id_seq')");
    Utils::workaround_pg_bytea("insert into problem
        (id, postcode, easting, northing, title, detail, name,
         email, phone, photo, state, used_map, anonymous, category, areas)
        values
        (?, '', ?, ?, ?, ?, ?, ?, ?, ?, 'partial', 't', 'f', '', '')", 9,
        $id, $input{easting}, $input{northing}, $input{title},
        $input{detail}, $input{name}, $input{email}, $input{phone}, $photo);

    # Send checking email
    my $template = File::Slurp::read_file("$FindBin::Bin/../templates/emails/partial");
    my $token = mySociety::AuthToken::store('partial', $id);
    my %h = (
        name => $input{name} ? ' ' . $input{name} : '',
        url => mySociety::Config::get('BASE_URL') . '/L/' . $token,
        service => $input{service},
    );

    my $body = mySociety::Email::construct_email({
        _template_ => $template,
        _parameters_ => \%h,
        To => $input{name} ? [ [ $input{email}, $input{name} ] ] : $input{email},
        From => [ mySociety::Config::get('CONTACT_EMAIL'), 'FixMyStreet' ],
    });

    my $result = mySociety::EmailUtil::send_email($body, mySociety::Config::get('CONTACT_EMAIL'), $input{email});
    if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
        dbh()->commit();
        print 'SUCCESS';
    } else {
        dbh()->rollback();
        print 'ERROR:Could not send email';
    }
}

Page::do_fastcgi(\&main);

