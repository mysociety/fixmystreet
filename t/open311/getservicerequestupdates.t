#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

use_ok( 'Open311' );
use DateTime;


my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
<service_requests_updates>
<request_update>
<update_id>638344</update_id>
<service_request_id>1</service_request_id>
<service_request_id_ext>1</service_request_id_ext>
<status>open</status>
<description>This is a note</description>
UPDATED_DATETIME
</request_update>
</service_requests_updates>
};


my $dt = DateTime->now;

# basic xml -> perl object tests
for my $test (
    {
        desc => 'element missing',
        updated_datetime => '',
        res => { update_id => 638344, service_request_id => 1, service_request_id_ext => 1, 
                status => 'open', description => 'This is a note' },
    },
    {
        desc => 'empty element',
        updated_datetime => '<updated_datetime />',
        res =>  { update_id => 638344, service_request_id => 1, service_request_id_ext => 1, 
                status => 'open', description => 'This is a note', updated_datetime => {} } ,
    },
    {
        desc => 'element with no content',
        updated_datetime => '<updated_datetime></updated_datetime>',
        res =>  { update_id => 638344, service_request_id => 1, service_request_id_ext => 1, 
                status => 'open', description => 'This is a note', updated_datetime => {} } ,
    },
    {
        desc => 'element with content',
        updated_datetime => sprintf( '<updated_datetime>%s</updated_datetime>', $dt ),
        res =>  { update_id => 638344, service_request_id => 1, service_request_id_ext => 1, 
                status => 'open', description => 'This is a note', updated_datetime => $dt } ,
    },
) {
    subtest $test->{desc} => sub {
        my $local_requests_xml = $requests_xml;
        $local_requests_xml =~ s/UPDATED_DATETIME/$test->{updated_datetime}/;

        my $o = Open311->new( jurisdiction => 'mysociety', endpoint => 'http://example.com', test_mode => 1, test_get_returns => { 'update.xml' => $local_requests_xml } );

        my $res = $o->get_service_request_updates;
        is_deeply $res->{ request_update }, $test->{ res }, 'result looks correct';

    };
}
