package FixMyStreet::Test;

use parent qw(Exporter);

use strict;
use warnings FATAL => 'all';
use utf8;
use Data::Dumper::Concise::Sugar;
use Test::More;
use mySociety::Locale;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
    mySociety::Locale::gettext_domain('FixMyStreet', 1);
}

use FixMyStreet::DB;

my $db = FixMyStreet::DB->schema->storage;

sub import {
    strict->import;
    warnings->import(FATAL => 'all');
    utf8->import;
    Data::Dumper::Concise::Sugar->export_to_level(1);
    binmode Test::More->builder->output, ':utf8';
    Test::More->export_to_level(1);
    $db->txn_begin;
}

END {
    $db->txn_rollback if $db;
}

BEGIN {
    # The following block patches Open311, so that any sent requests store the
    # request and return either an injected response or a default response (for
    # a posted report). Injected responses are only used once, and the stored
    # request is removed after being read.

    use Open311;
    my $test_req_used;
    my %injected;

    my $default_response = HTTP::Response->new();
    $default_response->code(200);
    $default_response->content('<?xml version="1.0" encoding="utf-8"?><service_requests><request><service_request_id>248</service_request_id></request></service_requests>');

    package Open311;
    use Class::Method::Modifiers;

    around _make_request => sub {
        my ($orig, $self) = (shift, shift);
        my ($req) = @_;
        $test_req_used = $req;
        my $path = $req->uri->path;
        my $ret = $injected{$path} || $default_response;
        delete $injected{$path};
        return $ret;
    };

    sub test_req_used {
        my $ret = $test_req_used;
        $test_req_used = undef;
        return $ret;
    }

    sub _inject_response {
        my ($self, $path, $content, $code) = @_;
        my $test_res = HTTP::Response->new();
        $test_res->code($code || 200);
        $test_res->content(encode_utf8($content));
        $injected{$path} = $test_res;
    }
}

1;
