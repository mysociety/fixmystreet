#!/usr/bin/perl
#
# common stuff used by Oxfordshire Open311 glue scripts
#
# mySociety: http://fixmystreet.org/
#-----------------------------------------------------------------

use strict;
use CGI;
use Encode qw(from_to);
use DBI;
use Time::Piece;
use Time::Local qw(timelocal);
use POSIX qw(strftime);


###################################################################
# Config file: values in the config file override any values set 
#              in the code below for the following things:
#
#     host: SXX-SAN-FOO_BAR
#     sid: FOOBAR
#     port: 1531
#     username: foo
#     password: FooBar
#     testing: 0
#     encode-to-win1252: 1
#
# Absence of the config file fails silently in case you really are
# using values directly set in this script.
#------------------------------------------------------------------
our $CONFIG_FILENAME       = "/usr/local/etc/fixmystreet.config";

use constant {
    GENERAL_SERVICE_ERROR   => 400,
    CODE_OR_ID_NOT_FOUND    => 404,
    CODE_OR_ID_NOT_PROVIDED => 400,
    BAD_METHOD              => 405,
    FATAL_ERROR             => 500
};

our $DB_SERVER_NAME    = 'FOO';
our $DB_HOST           = $DB_SERVER_NAME; # did this just in case we need to add more to the name (e.g, domain)
our $DB_PORT           = '1531';
our $ORACLE_SID        = 'FOOBAR';
our $USERNAME          = 'FIXMYSTREET';
our $PASSWORD          = 'XXX';
our $STORED_PROC_NAME  = 'PEM.create_enquiry';

# NB can override these settings in the config file!

# Strip control chars:
#   'ruthless' removes everything (i.e. all POSIX control chars)
#   'desc'     removes everything, but keeps tabs and newlines in the 'description' field, where they matter
#   'normal'   keeps tabs and newlines 
our $STRIP_CONTROL_CHARS   = 'ruthless';  

our $ENCODE_TO_WIN1252      = 1; # force encoding to Win-1252 for PEM data
our $DECODE_FROM_WIN1252    = 1; # force encoding from Win-1252 for PEM data

our $TESTING_WRITE_TO_FILE  = 0;  # write to file instead of DB or (get_service_request_update) don't really read the db
our $OUT_FILENAME           = "fms-test.txt"; # dump data here if TESTING_WRITE_TO_FILE is true
our $TEST_SERVICE_DISCOVERY = 0;  # switch to 1 to run service discovery, which confirms the DB connection at least
our $RUN_FAKE_INSERT_TEST   = 0;  # command-line execution attempts insert with fake data (mimics a POST request)

# Config file overrides existing values for these, if present:
if ($CONFIG_FILENAME && open(CONF, $CONFIG_FILENAME)) {
    while (<CONF>) {
        next if /^#/;
        if (/^\s*password:\s*(\S+)\s*$/i) {
            $PASSWORD = $1;
        } elsif (/^\s*sid:\s*(\S+)\s*$/i) {
            $ORACLE_SID = $1;
        } elsif (/^\s*username:\s*(\S+)\s*$/i) {
            $USERNAME = $1;
        } elsif (/^\s*port:\s*(\S+)\s*$/i) {
            $DB_PORT = $1;
        } elsif (/^\s*host:\s*(\S+)\s*$/i) {
            $DB_HOST = $1;
        } elsif (/^\s*testing:\s*(\S+)\s*$/i) {
            $TESTING_WRITE_TO_FILE = $1;
        } elsif (/^\s*test-service-discovery:\s*(\S+)\s*$/i) {
            $TEST_SERVICE_DISCOVERY = $1;
        } elsif (/^\s*strip-control-chars:\s*(\S+)\s*$/i) {
            $STRIP_CONTROL_CHARS = lc $1;
        } elsif (/^\s*encode-to-win1252:\s*(\S+)\s*$/i) {
            $ENCODE_TO_WIN1252 = $1;
        } elsif (/^\s*decode-from-win1252:\s*(\S+)\s*$/i) {
            $DECODE_FROM_WIN1252 = $1;
        } elsif (/^\s*run-fake-insert-test:\s*(\S+)\s*$/i) {
            $RUN_FAKE_INSERT_TEST = $1;
        }
    }
}

our $YESTERDAY = localtime() - Time::Seconds::ONE_DAY; # yesterday
$YESTERDAY = $YESTERDAY->strftime('%Y-%m-%d');

#------------------------------------------------------------------
# error_and_exit 
# args: HTTP status code, error message
# Sends out the HTTP status code and message
# and temrinates execution
#------------------------------------------------------------------
sub error_and_exit {
    my ($status, $msg) = @_;
    print "Status: $status $msg\n\n$msg\n";
    exit;
}


#------------------------------------------------------------------
# get_db_connection
# no args: uses globals, possibly read from config
# returns handle for the connection (otherwise terminates)
#------------------------------------------------------------------
sub get_db_connection {
    return DBI->connect( "dbi:Oracle:host=$DB_HOST;sid=$ORACLE_SID;port=$DB_PORT", $USERNAME, $PASSWORD )
        or error_and_exit(FATAL_ERROR, "failed to connect to database: " . $DBI::errstr, "");   
}

#------------------------------------------------------------------
# get_date_or_nothing {
# parse date from incoming request, fail silently
# expected format: 2003-02-15T13:50:05
# These are coming from FMS for Oxford so don't expect to need
# need to parse anyway
#------------------------------------------------------------------
sub get_date_or_nothing {
    my $d = shift;
    my $want_date_only = shift;
    if ($d=~s/^(\d{4}-\d\d-\d\d)(T\d\d:\d\d(:\d\d)?)?.*/$1$2/) {
        return $1 if $want_date_only;
        $d="$1 00:00" unless $2; # no time provided
        $d.=":00" unless $3; # no seconds
        $d=~s/[TZ]/ /g;
        # no point doing any parsing if regexp has done the work
            # eval {
            #     $d=~s/(\d\d:\d\d).*/$1/; # bodge if we can't get DateTime installed
            #     $d = Time::Piece->strptime( $d, '%Y-%m-%dT%H:%M:%S');
            #     $d = $d->strftime('%Y-%m-%d %H:%M:%S');
            # };
            # return '' if $@;
    } else {
        return '';
    }
    return $d;
}

#------------------------------------------------------------------
# get_utc_iso8601_string
# Takes a local date/time string and converts it to UTC, returning
# a ISO8601-format string.
# expected format: YYYY-MM-DD HH:MM:SS
# e.g.: 2016-04-01 13:37:42 -> 2016-04-01T12:37:42Z
#------------------------------------------------------------------
sub get_utc_iso8601_string {
    my $datetime = shift;
    $datetime =~ s{(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)}{
        strftime "%Y-%m-%dT%H:%M:%SZ", gmtime(timelocal($6, $5, $4, $3, int($2)-1, int($1)-1900));
    }e;
    return $datetime;
}


1;
