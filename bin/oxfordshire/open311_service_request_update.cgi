#!/usr/bin/perl

# script for querying the higatlas.fms_update table provided by
# Bentley and offering them up as XML service request updates.
# https://github.com/mysociety/fixmystreet/wiki/Open311-FMS---Proposed-differences-to-Open311
#
# mySociety: http://fixmystreet.org/
#-----------------------------------------------------------------

require 'open311_services.pm';

# incoming query params
my $CGI_VAR_START_DATE = 'start_date';
my $CGI_VAR_END_DATE   = 'end_date';
my $CGI_VAR_NO_DEFAULT_DATE   = 'force_no_default_date'; # for testing scratchy Oracle date stuff
my $CGI_VAR_LIMIT   = 'limit'; # for testing
my $CGI_VAR_ANY_STATUS = 'any_status'; # for testing

my $USE_ONLY_DATES = 0;  # dates not times
my $MAX_LIMIT = 1000;
my $STATUS_CRITERIA = "(status='OPEN' OR status='CLOSED')";
my $req = new CGI;

get_service_request_updates($req);

sub prepare_for_xml {
    my $s = shift;
    foreach ($s) {
        from_to($_, 'utf8', 'Windows-1252') if $DECODE_FROM_WIN1252;
        s/</&lt;/g; # numpty escaping pending XML Simple?
        s/>/&gt;/g;
        s/&/&amp;/g;
    }
    return $s;
}

#------------------------------------------------------------------
# get_service_discovery
# Although not really implementing this, use it as a test to read the 
# db and confirm connectivity.
#
# TABLE "HIGATLAS"."FMS_UPDATE"
# 
#         "ROW_ID"                                NUMBER(9,0) NOT NULL ENABLE,
#         "SERVICE_REQUEST_ID"    NUMBER(9,0) NOT NULL ENABLE,
#         "UPDATED_TIMEDATE"              DATE DEFAULT SYSDATE NOT NULL ENABLE,
#         "STATUS"                                VARCHAR2(10 BYTE) NOT NULL ENABLE,
#         "DESCRIPTION"                   VARCHAR2(254 BYTE) NOT NULL ENABLE,
# 
#          CONSTRAINT "FMS_UPDATE_PK" PRIMARY KEY ("ROW_ID")
#------------------------------------------------------------------
sub get_service_request_updates {
    # by default, we only want last 24 hours
    # also, limit to 1000 records
    
    my $raw_start_date = $req -> param($CGI_VAR_START_DATE);
    my $raw_end_date = $req -> param($CGI_VAR_END_DATE);
    my $start_date = get_date_or_nothing( $raw_start_date, $USE_ONLY_DATES );
    my $end_date = get_date_or_nothing( $raw_end_date, $USE_ONLY_DATES );

    if (! $req -> param($CGI_VAR_NO_DEFAULT_DATE)) {
        $start_date = get_date_or_nothing( $YESTERDAY, $USE_ONLY_DATES ) unless ($start_date or $end_date);
    }

    my $date_format = 'YYYY-MM-DD HH24:MI:SS'; # NB: hh24 (not hh)

    $start_date = "updated_timedate >= to_date('$start_date', '$date_format')" if $start_date;
    $end_date = "updated_timedate <= to_date('$end_date', '$date_format')" if $end_date;

    my $where_clause = '';
    my @criteria = ($start_date, $end_date);
    push @criteria, $STATUS_CRITERIA  unless $req -> param($CGI_VAR_ANY_STATUS);
    $where_clause = join(' AND ', grep {$_} @criteria);
    $where_clause = "WHERE $where_clause" if $where_clause;

    my $sql = qq(SELECT row_id, service_request_id, to_char(updated_timedate, '$date_format'), status, description FROM higatlas.fms_update $where_clause ORDER BY updated_timedate DESC);

    my $limit = $req -> param($CGI_VAR_LIMIT) =~ /^(\d{1,3})$/? $1 : $MAX_LIMIT;
    $sql = "SELECT * FROM ($sql) WHERE ROWNUM <= $limit" if $limit;

    my $debug_str;
    my $ary_ref;

    if ($TESTING_WRITE_TO_FILE) {
        $ary_ref = [
            [97, 1000, '2013-01-05', 'OPEN', 'report was opened'],
            [99, 1000, '2013-01-06', 'CLOSED', 'report was closed']
        ];
        # only add debug now if config says we're testing
        $debug_str = <<XML;
        <!-- DEBUG: from: $raw_start_date => $start_date  -->
        <!-- DEBUG: to:   $raw_end_date => $end_date -->
        <!-- DEBUG: sql:  $sql -->
XML
    } else {
        my $dbh = get_db_connection();
        $ary_ref = $dbh->selectall_arrayref($sql);
    }

    # rough and ready XML dump now (should use XML Simple to build/escape properly!)
    my $xml = "";
    foreach my $row(@{$ary_ref})  {
        if (defined $row) {
            my ($id, $service_req_id, $updated_at, $status, $desc) = map { prepare_for_xml($_) } @$row;
            $updated_at = get_utc_iso8601_string($updated_at); # value from the DB is in server-local time, convert to UTC.
            $xml.= <<XML;
    <request_update>
        <update_id>$id</update_id>
        <service_request_id>$service_req_id</service_request_id>
        <status>$status</status>
        <updated_datetime>$updated_at</updated_datetime>
        <description>$desc</description>
    </request_update>
XML
        }
    }
    print <<XML;
Content-type: text/xml

<?xml version="1.0" encoding="utf-8"?>
<service_request_updates>
$xml
</service_request_updates>
$debug_str
XML
}
