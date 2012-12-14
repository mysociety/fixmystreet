#!/usr/bin/perl

# script for absobring incoming Open311 service request POSTs and
# passing them into Bentley EXOR backend via create_enquiry stored
# procedure.
#-----------------------------------------------------------------

# try:
# $ perl -e 'use DBD::Oracle; print $DBD::Oracle::VERSION,"\n";'
# to see what we've got :-)
# $dsn = "dbi:type:database_name:host_name:port";

use strict;
use CGI;
use DBI;
use DBD::Oracle qw(:ora_types);

use constant {
    GENERAL_SERVICE_ERROR   => 400,
    CODE_OR_ID_NOT_FOUND    => 404,
    CODE_OR_ID_NOT_PROVIDED => 400,
    BAD_METHOD              => 405,
    FATAL_ERROR             => 500
};

my $DB_SQL_TYPE       = '';
my $DB_SERVER_NAME    = 'S12-SAN-ORA-L18';
my $DB_HOST           = $DB_SERVER_NAME; # did this just in case we need to add more to the name (e.g, domain)
my $DB_PORT           = '1531';
my $ORACLE_SID        = "EXORTEST";
my $USERNAME          = 'FIXMYSTREET';
my $PASSWORD          = 'XXX';
my $STORED_PROC_NAME  = 'PEM.create_enquiry';

my $STRIP_CONTROL_CHARS   = 1;
my $TESTING_WRITE_TO_FILE = 0;  # write to file instead of DB
my $CONFIG_FILENAME       = "fms-conf.cgi"; # .pl to prevent http access in this dir, oh dear. Or set to blank.
my $OUT_FILENAME          = "fms-test.txt";

my $TEST_SERVICE_DISCOVERY=0;  # switch to 1 to run service discovery, which confirms the DB connection at least

my %PEM_BOUND_VAR_TYPES;
my @PEM_BOUND_VAR_NAMES;
foreach (get_pem_field_names()) {
    if (s/__(NUMBER|DATE)$//) {
        push @PEM_BOUND_VAR_NAMES, $_;
        $PEM_BOUND_VAR_TYPES{$_} = $1 || ''; # empty for varchar2 
    } else {
        push @PEM_BOUND_VAR_NAMES, $_;
    }
    
}
my $PEM_BOUND_VARS_DECLARATION = ""; # not used

# if there's a config file, pull the password from it
#     (as a courtesy: not be keeping the config (e.g. password) in this script, 
#     to allow insecure file transfer onto occ dev environment and to ease deployment).
# Overrides existing values for these, if present:
#
#     host: SXX-SAN-FOO_BAR
#     sid: FOOBAR
#     port: 1531
#     username: foo
#     password: FooBar
#     testing: 0

if ($CONFIG_FILENAME && open(CONF, $CONFIG_FILENAME)) {
    while (<CONF>) {
        if (/^\s*password:\s*(.*?)\s*$/i) {
            $PASSWORD = $1;
        } elsif (/^\s*sid:\s*(.*?)\s*$/i) {
            $ORACLE_SID = $1;
        } elsif (/^\s*username:\s*(.*?)\s*$/i) {
            $USERNAME = $1;
        } elsif (/^\s*port:\s*(.*?)\s*$/i) {
            $DB_PORT = $1;
        } elsif (/^\s*host:\s*(.*?)\s*$/i) {
            $DB_HOST = $1;
        } elsif (/^\s*testing:\s*(.*?)\s*$/i) {
            $TESTING_WRITE_TO_FILE = $1;
        } elsif (/^\s*test-service-discovery:\s*(.*?)\s*$/i) {
            $TEST_SERVICE_DISCOVERY = $1;
        }
    }
}

# assuming Oracle environment is happily set already, don't need these:
# my $ORACLE_HOME       = "/app/oracle/product/11.2.0/db_1";
# $ENV{ORACLE_HOME}    = $ORACLE_HOME;
# $ENV{ORACLE_SID}     = $ORACLE_SID;
# $ENV{PATH}           ="$ORACLE_HOME/bin";
# $ENV{LD_LIBRARY_PATH}="$ORACLE_HOME/lib";

my $ERR_MSG            = 'error'; # unique key in data hash

# incoming (Open311, from FMS) field names
my %F = (
    'ACCOUNT_ID'         => 'account_id',
    'ADDRESS_ID'         => 'address_id',
    'ADDRESS_STRING'     => 'address_string',
    'API_KEY'            => 'api_key',
    'DESCRIPTION'        => 'description',
    'DEVICE_ID'          => 'device_id',
    'EASTING'            => 'attribute[easting]',
    'EMAIL'              => 'email',
    'FIRST_NAME'         => 'first_name',
    'FMS_ID'             => 'attribute[external_id]',
    'LAST_NAME'          => 'last_name',
    'LAT'                => 'lat',
    'LONG'               => 'long',
    'MEDIA_URL'          => 'media_url',
    'NORTHING'           => 'attribute[northing]',
    'PHONE'              => 'phone',
    'REQUESTED_DATETIME' => 'requested_datetime',
    'SERVICE_CODE'       => 'service_code',
    'STATUS'             => 'status',
);

my $req = new CGI;

# normally, POST requests are inserting service requests
# and GET requests are for returning service requests, although OCC aren't planning on
# using that (it's part of the Open311 spec).
# So actually the service discovery is more useful, so send in a 'services' param
# to see that.
# 
#  But for testing the db connection, set $TEST_SERVICE_DISCOVERY so that
#  *all* requests simply do a service discovery by setting  (possibly via the config file)

if ($TEST_SERVICE_DISCOVERY) {
    get_service_discovery($req);    # to test
}elsif ($ENV{'REQUEST_METHOD'} eq "POST") {
    post_service_request($req);
} elsif ($req -> param('services')) {
    get_service_discovery($req);
} else {
    get_FAKE_INSERT($req); # allow a GET to make an insert, for testing (from the commandnd line!)
    # get_service_requests($req);
}

#----------------------------------------------------
# post_service_request
# accepts an incoming service request
# If everything goes well, it puts it in the database and
# returns the PEM ID to the caller
#----------------------------------------------------
sub post_service_request {
    my $req = shift;
    my %data;
    my $pem_id = 0;

    foreach (values %F) {
        $data{$_} = $req -> param($_);
        $data{$_} =~ s/^\s+|\s+$//g; # trim
        
        $data{$_} =~ s/[^\t\n[:^cntrl:]]/ /g if $STRIP_CONTROL_CHARS;
    }
    
    error_and_exit(CODE_OR_ID_NOT_PROVIDED, "missing service code (Open311 requires one)") 
        unless $data{$F{SERVICE_CODE}};
    error_and_exit(GENERAL_SERVICE_ERROR, "the service code you provided ($data{$F{SERVICE_CODE}}) was not recognised by this server") 
        unless service_exists($data{$F{SERVICE_CODE}});
    error_and_exit(GENERAL_SERVICE_ERROR, "no address or long-lat provided")
        unless ( (is_longlat($data{$F{LONG}}) && is_longlat($data{$F{LAT}})) || $data{$F{ADDRESS_STRING}} );

    if ($TESTING_WRITE_TO_FILE) {
        $pem_id = dump_to_file(\%data);
    } else {
        $pem_id = insert_into_pem(\%data);
    }
    
    if (! $pem_id) {
        error_and_exit(FATAL_ERROR, $data{$ERR_MSG} || "failed to get PEM ID");
    } else {
        print <<XML;
Content-type: text/xml

<?xml version="1.0" encoding="utf-8"?>
<service_requests>
	<request>
		<service_request_id>$pem_id</service_request_id>
	</request>
</service_requests>
XML
    }    
}

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
# is_longlat
# returns true if this looks like a long/lat value
#------------------------------------------------------------------
sub is_longlat {
    return $_[0] =~ /^-?\d+\.\d+$/o? 1 : 0;
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
# service_exists
# lookup the service code, to check that it exists
#   SELECT det_code, det_name FROM higatlas.doc_enquiry_types WHERE
#   det_dtp_code = 'REQS' AND det_dcl_code ='SERV' AND det_con_id=1
# Actually, FMS is expected to be sending good codes because they 
# come from here anyway, and are expected to be stable. But could
# cache and check... probably overkill since DB insert will probably
# throw the error anyway.
#------------------------------------------------------------------
sub service_exists {
    my $service_code = shift;
    return 1;
}

#------------------------------------------------------------------
# dump_to_file
# args: ref to hash of data
# for testing, log the incoming data into a local file
# NB throws a fatal error
#------------------------------------------------------------------
sub dump_to_file {
    my $h = shift; # href to data hash
    if (open (OUTFILE, ">$OUT_FILENAME")) {
        print OUTFILE "Data dump: " . gmtime() . "\n" . '-' x 64 . "\n\n";
        foreach (sort keys %$h) {
            print OUTFILE "$_ => " . $$h{$_} . "\n";
        }
        print OUTFILE "\n\n" . '-' x 64 . "\n[end]\n";
        close OUTFILE;
        $$h{$ERR_MSG} = "NB did not write to DB (see $OUT_FILENAME instead: switch off \$TESTING_WRITE_TO_FILE to stop this)";
    } else {
        $$h{$ERR_MSG} = "failed to write to outfile ($!)";
    }
    return 0; # test always throws an error so no risk of production confusion!
}

#------------------------------------------------------------------
# insert_into_pem
# args: hashref to data hash
# returns PEM id of the new record (or passes an error message
# into the data hash if no id is available)
#------------------------------------------------------------------
sub insert_into_pem {
    my $h = shift; # href to data hash

    my $dbh = get_db_connection();

    my $pem_id;
    my $error_value;
    my $error_product;

    # set specifc vars up where further processing on them might be needed:
    my $undef = undef;
    my $address = $$h{$F{ADDRESS_STRING}};
    my $status = $$h{$F{STATUS}}; 

    my $service_code = $$h{$F{SERVICE_CODE}}; 
    my $sth = $dbh->prepare(q#
        BEGIN
        PEM.create_enquiry(
            ce_cat => :ce_cat,
            ce_class => :ce_class,
            ce_forename => :ce_forename,
            ce_surname => :ce_surname,
            ce_contact_type => :ce_contact_type,
            ce_work_phone => :ce_work_phone,
            ce_email => :ce_email,
            ce_description => :ce_description,
            ce_enquiry_type => :ce_enquiry_type,
            ce_source => :ce_source,
            ce_x => :ce_x,
            ce_y => :ce_y,
            ce_doc_reference => :ce_doc_reference,
            ce_status_code => :ce_status_code,
            ce_compl_user_type => :ce_compl_user_type,
            error_value => :error_value,
            error_product => :error_product,
            ce_doc_id => :ce_doc_id);
        END;
#);
    #ce_incident_datetime => to_Date(:ce_incident_datetime,'DD-MON-YYYY HH24:MI'),

    my %bindings;
                                                     # comments here are suggested values
    # fixed values    
    $bindings{":ce_cat"}            = 'ENQ';         # or REQS ?
    $bindings{":ce_class"}          = 'SERV';        # 'FRML' ?
    $bindings{":ce_contact_type"}   = 'ENQUIRER';    # 'ENQUIRER' 
    $bindings{":ce_status_code"}    = 'RE';          # RE=received (?)
    $bindings{":ce_compl_user_type"}= 'USER';        # 'USER'

    # especially FMS-specific:
    $bindings{":ce_source"}        = "FMS";           # important, and specific to this script!
    $bindings{":ce_doc_reference"} = $$h{$F{FMS_ID}}; # FMS id
    $bindings{":ce_enquiry_type"}  = $service_code;

    # incoming data
    $bindings{":ce_x"}             = $$h{$F{EASTING}};
    $bindings{":ce_y"}             = $$h{$F{NORTHING}};
    $bindings{":ce_forename"}      = substr($$h{$F{FIRST_NAME}}, 0, 30);     # 'CLIFF'
    $bindings{":ce_surname"}       = substr($$h{$F{LAST_NAME}}, 0, 30);      # 'STEWART'
    $bindings{":ce_work_phone"}    = substr($$h{$F{PHONE}}, 0, 25);          # '0117 600 4200'
    $bindings{":ce_email"}         = substr($$h{$F{EMAIL}}, 0, 50);          # 'info@exor.co.uk'
    $bindings{":ce_description"}   = substr($$h{$F{DESCRIPTION}}, 0, 2000);  # 'Large Pothole'

    foreach my $name (sort keys %bindings) {
        next if grep {$name eq $_} (':error_value', ':error_product', ':ce_doc_id'); # return values
        my $type = $PEM_BOUND_VAR_TYPES{$name} || 'VARCHAR2';
        
        print "DEBUG: $name -> $bindings{$name} -> $type\n";
        $sth->bind_param(
            $name, 
            $bindings{$name}, 
            $type eq 'NUMBER'? ORA_NUMBER : ($type eq 'DATE'? ORA_DATE : ORA_VARCHAR2 )
        );  
    }

    # NB FMS Open311 not sending this by default
    # > to_Date('01-JAN-2004 11:00','DD-MON-YYYY HH24:MI') 
    # $sth->bind_param(":ce_incident_datetime", $$h{$F{REQUESTED_DATETIME}});

    # not used, but from the example docs
    # $sth->bind_param(":ce_contact_title",     $undef);      # 'MR'
    # $sth->bind_param(":ce_postcode",          $undef);      # 'BS11EJ'   NB no spaces, upper case
    # $sth->bind_param(":ce_building_no",       $undef);      # '1'
    # $sth->bind_param(":ce_building_name",     $undef);      # 'CLIFTON HEIGHTS'
    # $sth->bind_param(":ce_street",            $undef);      # 'HIGH STREET'
    # $sth->bind_param(":ce_town",              $undef);      # 'BRSITOL'
    # $sth->bind_param(":ce_location",          $undef);      # 'Outside Flying Horse Public House'
    # $sth->bind_param(":ce_enquiry_type",      $undef);      # 'CD' , ce_source => 'T'
    # $sth->bind_param(":ce_cpr_id",            $undef);      # '5' (priority)
    # $sth->bind_param(":ce_rse_he_id",         $undef);      #> nm3net.get_ne_id('1200D90970/09001','L')
    # $sth->bind_param(":ce_compl_target",      $undef);      # '08-JAN-2004'
    # $sth->bind_param(":ce_compl_corresp_date",$undef);      # '02-JAN-2004'
    # $sth->bind_param(":ce_compl_corresp_deliv_date", $undef); # '02-JAN-2004'
    # $sth->bind_param(":ce_resp_of",           $undef);      # 'GBOWLER'
    # $sth->bind_param(":ce_hct_vip",           $undef);      # 'CO'
    # $sth->bind_param(":ce_hct_home_phone",    $undef);      # '0117 900 6201'
    # $sth->bind_param(":ce_hct_mobile_phone",  $undef);      # '07111 1111111'
    # $sth->bind_param(":ce_compl_remarks",     $undef);      # remarks (notes) max 254 char
    
    # return values:
    $sth->bind_param_inout(":error_value",   \$error_value, 12);   #> l_ERROR_VALUE # number
    $sth->bind_param_inout(":error_product", \$error_product, 10); #> l_ERROR_PRODUCT (will always be 'DOC')
    $sth->bind_param_inout(":ce_doc_id",     \$pem_id, 12);        #> l_ce_doc_id # number

    $sth->execute();
    $dbh->disconnect;

    # if error, maybe need to look it up:
    # error_value is the index HER_NO in table HIG_ERRORS, which has messages
    # actually err_product not helpful (wil always be "DOC")
    $$h{$ERR_MSG} = "$error_value $error_product" if ($error_value || $error_product); 

    return $pem_id;
}

#------------------------------------------------------------------
# get_service_requests
# Strictly speaking, Open311 would expect the GET request for service
# requests to respond with all service requests (within a specified
# period). But as we're not using that, do a service discovery 
# instead.
#------------------------------------------------------------------
sub get_service_requests {
    get_service_discovery(); # for now
}

#------------------------------------------------------------------
# get_FAKE_INSERT
# for testing off command line, force the data
#------------------------------------------------------------------
sub get_FAKE_INSERT {
    my %fake_data = (
            $F{'DESCRIPTION'}        => 'Testing, description',
            $F{'EASTING'}            => '45119',
            $F{'EMAIL'}              => 'email@example.com',
            $F{'FIRST_NAME'}         => 'Dave',
            $F{'FMS_ID'}             => '1012',
            $F{'LAST_NAME'}          => 'Test',
            $F{'LAT'}                => '51.756741605999',
            $F{'LONG'}               => '-1.2596387532192',
            $F{'NORTHING'}           => '206709',
            $F{'SERVICE_CODE'}       => 'OT',
        );
    return insert_into_pem(\%fake_data)
}

#------------------------------------------------------------------
# get_service_discovery
# Although not really implementing this, use it as a test to read the 
# db and confirm connectivity.
#------------------------------------------------------------------
sub get_service_discovery {
    my $dbh = get_db_connection();
    my $ary_ref = $dbh->selectall_arrayref(qq(select det_code, det_name from higatlas.doc_enquiry_types where det_dtp_code = 'REQS' AND det_dcl_code='SERV' and det_con_id=1));
    # rough and ready XML dump now (should use XML Simple to build/escape properly!)
    my $xml = "";
    foreach my $row(@{$ary_ref})  {
        if (defined $row) {
            my ($code, $name) = @$row;
            $xml.= <<XML;
    <service>
      <service_code>$code</service_code>
      <metadata>false</metadata>
      <type>realtime</type>
      <keywords/>
      <group/>
      <service_name>$name</service_name>
      <description/>
    </service>
XML
        }
    }
    print <<XML;
Content-type: text/xml

<?xml version="1.0" encoding="utf-8"?>
<services>
$xml
</services>
XML
    # error_and_exit(BAD_METHOD, "sorry, currently only handling incoming Open311 service requests: use POST method");
}

#------------------------------------------------------------------
# get_pem_field_names
# return list of params for the stored procedure *in the correct order*
# Also: __NUMBER and __DATE suffixes for anything that isn't a VARCHAR2
# This also adds the colon prefix to all names.
# Note the last three of these are inout params, and are handled
# as a special (hardcoded) case when used (see above).
#------------------------------------------------------------------
sub get_pem_field_names {
    return map {":$_"} qw(
ce_cat
ce_class
ce_title
ce_contact_title
ce_forename
ce_surname
ce_contact_type
ce_flag
ce_pcode_id
ce_postcode
ce_building_no
ce_building_name
ce_street
ce_locality
ce_town
ce_county
ce_organisation
ce_work_phone
ce_email
ce_location
ce_description
ce_enquiry_type
ce_source
ce_incident_datetime__DATE
ce_cpr_id
ce_asset_id
ce_rse_he_id
ce_x__NUMBER
ce_y__NUMBER
ce_date_expires__DATE
ce_doc_reference
ce_issue_number__NUMBER
ce_category
ce_status_date__DATE
ce_resp_of
ce_compl_ack_flag
ce_compl_ack_date__DATE
ce_compl_flag
ce_compl_peo_date__DATE
ce_compl_target__DATE
ce_compl_complete__DATE
ce_compl_referred_to
ce_compl_police_notif_flag
ce_compl_date_police_notif
ce_compl_from__DATE
ce_compl_to__DATE
ce_compl_claim
ce_compl_corresp_date__DATE
ce_compl_corresp_deliv_date__DATE
ce_compl_no_of_petitioners__NUMBER
ce_compl_remarks
ce_compl_cause
ce_compl_injuries
ce_compl_damgae
ce_compl_action
ce_compl_litigation_flag
ce_compl_litigation_reason
ce_compl_claim_no
ce_compl_determination
ce_compl_est_cost__NUMBER
ce_compl_adv_cost__NUMBER
ce_compl_act_cost__NUMBER
ce_compl_follow_up1__DATE
ce_compl_follow_up2__DATE
ce_compl_follow_uo3__DATE
ce_compl_insurance_claim
ce_compl_summons_received
ce_compl_user_type
ce_hct_vip
ce_hct_home_phone
ce_hct_mobile_phone
ce_hct_fax
ce_had_sub_build_name
ce_had_property_type
ce_status_code
ce_date_time_arrived__DATE
ce_reason_late
error_value__NUMBER
error_product
ce_doc_id__NUMBER
    )
}
