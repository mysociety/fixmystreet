#!/usr/bin/perl

# script for absobring incoming Open311 service request POSTs and
# passing them into Bentley EXOR backend via create_enquiry stored
# procedure.
#
# mySociety: http://fixmystreet.org/
#-----------------------------------------------------------------

require 'open311_services.pm';
use DBD::Oracle qw(:ora_types);
### for local testing (no Oracle):
### use constant { ORA_VARCHAR2=>1, ORA_DATE=>1, ORA_NUMBER=>1};

my %PEM_BOUND_VAR_TYPES = get_pem_field_types();

my $ERR_MSG            = 'error'; # unique key in data hash

# incoming (Open311, from FMS) field names
# note: attribute[*] are being sent by FMS explicitly as attributes for Oxfordshire
my %F = (
    'ACCOUNT_ID'         => 'account_id',
    'ADDRESS_ID'         => 'address_id',
    'ADDRESS_STRING'     => 'address_string',
    'API_KEY'            => 'api_key',
    'CLOSEST_ADDRESS'    => 'attribute[closest_address]',
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
} elsif ($RUN_FAKE_INSERT_TEST) {
    # allow a GET to make an insert, for testing (from the commandnd line!)
    print "Running fake insert test... returned: " . get_FAKE_INSERT();
    print "\nSee $OUT_FILENAME for data" if $TESTING_WRITE_TO_FILE;
    print "\n";
} else {
    get_service_requests($req);
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
    }

    error_and_exit(CODE_OR_ID_NOT_PROVIDED, "missing service code (Open311 requires one)") 
        unless $data{$F{SERVICE_CODE}};
    error_and_exit(GENERAL_SERVICE_ERROR, "the service code you provided ($data{$F{SERVICE_CODE}}) was not recognised by this server") 
        unless service_exists($data{$F{SERVICE_CODE}});
    error_and_exit(GENERAL_SERVICE_ERROR, "no address or long-lat provided")
        unless ( (is_longlat($data{$F{LONG}}) && is_longlat($data{$F{LAT}})) || $data{$F{ADDRESS_STRING}} );

    $pem_id = insert_into_pem(\%data);
    
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
# is_longlat
# returns true if this looks like a long/lat value
#------------------------------------------------------------------
sub is_longlat {
    return $_[0] =~ /^-?\d+(\.\d+)?$/o ? 1 : 0;
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

    my $pem_id;
    my $error_value;
    my $error_product;

    # set specifc vars up where further processing on them might be needed:
    my $undef = undef;
    my $status = $$h{$F{STATUS}}; 
    my $service_code = $$h{$F{SERVICE_CODE}}; 
    my $description = $$h{$F{DESCRIPTION}};
    my $media_url = $$h{$F{MEDIA_URL}};
    if ($media_url) {
        # don't put URL for full images into the database (because they're too big to see on a Blackberry)
        $media_url =~ s/\.full(\.jpe?g)$/$1/;
        $description .= ($STRIP_CONTROL_CHARS ne 'ruthless'? "\n\n":"  ") . "Photo: $media_url";
    }
    my $location = $$h{$F{CLOSEST_ADDRESS}};
    if ($location) {
        # strip out everything apart from "Nearest" preamble
        $location=~s/(Nearest road)[^:]+:/$1:/;
        $location=~s/(Nearest postcode)[^:]+:(.*?)(\(\w+ away\))?\s*(\n|$)/$1: $2/;
    }
    
    my %bindings;
                                                     # comments here are suggested values
                                                     # field lengths are from OCC's Java portlet
    # fixed values    
    $bindings{":ce_cat"}            = 'REQS';         # or REQS ?
    $bindings{":ce_class"}          = 'SERV';        # 'FRML' ?
    $bindings{":ce_contact_type"}   = 'ENQUIRER';    # 'ENQUIRER' 
    $bindings{":ce_status_code"}    = 'RE';          # RE=received (?)
    $bindings{":ce_compl_user_type"}= 'USER';        # 'USER'

    # ce_incident_datetime is *not* an optional param, but FMS isn't sending it at the moment
    $bindings{":ce_incident_datetime"}=$$h{$F{REQUESTED_DATETIME}} || Time::Piece->new->strftime('%Y-%m-%d %H:%M');

    # especially FMS-specific:
    $bindings{":ce_source"}        = "FMS";           # important, and specific to this script!
    $bindings{":ce_doc_reference"} = $$h{$F{FMS_ID}}; # FMS id
    $bindings{":ce_enquiry_type"}  = $service_code;

    # incoming data
    $bindings{":ce_x"}             = $$h{$F{EASTING}};
    $bindings{":ce_y"}             = $$h{$F{NORTHING}};
    $bindings{":ce_forename"}      = uc strip($$h{$F{FIRST_NAME}}, 30);     # 'CLIFF'
    $bindings{":ce_surname"}       = uc strip($$h{$F{LAST_NAME}}, 30);      # 'STEWART'
    $bindings{":ce_work_phone"}    = strip($$h{$F{PHONE}}, 25);             # '0117 600 4200'
    $bindings{":ce_email"}         = uc strip($$h{$F{EMAIL}}, 50);          # 'info@exor.co.uk'
    $bindings{":ce_description"}   = strip($description, 1970, $F{DESCRIPTION});          # 'Large Pothole'

    # nearest address guesstimate
    $bindings{":ce_location"}      = strip($location, 254);
    
    if ($TESTING_WRITE_TO_FILE) {
        return dump_to_file(\%bindings);
    }
    
    # everything ready: now put it into the database
    my $dbh = get_db_connection();

    my $sth = $dbh->prepare(q#
        BEGIN
        PEM.create_enquiry(
            ce_cat => :ce_cat,
            ce_class => :ce_class,
            ce_forename => :ce_forename,
            ce_surname => :ce_surname,
            ce_contact_type => :ce_contact_type,
            ce_location => :ce_location,
            ce_work_phone => :ce_work_phone,
            ce_email => :ce_email,
            ce_description => :ce_description,
            ce_enquiry_type => :ce_enquiry_type,
            ce_source => :ce_source,
            ce_incident_datetime => to_Date(:ce_incident_datetime,'YYYY-MM-DD HH24:MI'),
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

    foreach my $name (sort keys %bindings) {
        next if grep {$name eq $_} (':error_value', ':error_product', ':ce_doc_id'); # return values (see below)
        $sth->bind_param(
            $name, 
            $bindings{$name}, 
            $PEM_BOUND_VAR_TYPES{$name} || ORA_VARCHAR2
        );  
    }
    # return values are bound explicitly here:
    $sth->bind_param_inout(":error_value",   \$error_value, 12);   #> l_ERROR_VALUE # number
    $sth->bind_param_inout(":error_product", \$error_product, 10); #> l_ERROR_PRODUCT (will always be 'DOC')
    $sth->bind_param_inout(":ce_doc_id",     \$pem_id, 12);        #> l_ce_doc_id # number

    # not used, but from the example docs, for reference
    # $sth->bind_param(":ce_contact_title",     $undef);      # 'MR'
    # $sth->bind_param(":ce_postcode",          $undef);      # 'BS11EJ'   NB no spaces, upper case
    # $sth->bind_param(":ce_building_no",       $undef);      # '1'
    # $sth->bind_param(":ce_building_name",     $undef);      # 'CLIFTON HEIGHTS'
    # $sth->bind_param(":ce_street",            $undef);      # 'HIGH STREET'
    # $sth->bind_param(":ce_town",              $undef);      # 'BRSITOL'
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

    $sth->execute();
    $dbh->disconnect;

    # if error, maybe need to look it up:
    # error_value is the index HER_NO in table HIG_ERRORS, which has messages
    # actually err_product not helpful (wil always be "DOC")
    $$h{$ERR_MSG} = "$error_value $error_product" if ($error_value || $error_product); 

    return $pem_id;
}

#------------------------------------------------------------------
# strip
# args: data, max-length, field-name
# Trims, strips control chars, truncates to max-length
# Field-name only matters for description field
#------------------------------------------------------------------
sub strip {
    my ($s, $max_len, $field_name) = @_;
    if ($STRIP_CONTROL_CHARS) {
        if ($STRIP_CONTROL_CHARS eq 'ruthless') {
            $s =~ s/[[:cntrl:]]/ /g; # strip all control chars, simples
        } elsif ($STRIP_CONTROL_CHARS eq 'desc') {
            if ($field_name eq $F{DESCRIPTION}) {
                $s =~ s/[^\t\n[:^cntrl:]]/ /g; # leave tabs and newlines
            } else {
                $s =~ s/[[:cntrl:]]/ /g; # strip all control chars, simples
            }
        } else {
            $s =~ s/[^\t\n[:^cntrl:]]/ /g; # leave tabs and newlines
        }
    }
    from_to($s, 'utf8', 'Windows-1252') if $ENCODE_TO_WIN1252;
    return $max_len? substr($s, 0, $max_len) : $s;
}

#------------------------------------------------------------------
# get_service_requests
# Strictly speaking, Open311 would expect the GET request for service
# requests to respond with all service requests (within a specified
# period). But as we're not using that, do a service discovery 
# instead.
#------------------------------------------------------------------
sub get_service_requests {
    # error_and_exit(BAD_METHOD, "sorry, currently only handling incoming Open311 service requests: use POST method");
    get_service_discovery(); # for now
}

#------------------------------------------------------------------
# get_FAKE_INSERT
# for testing off command line, force the data
#------------------------------------------------------------------
sub get_FAKE_INSERT {
    my %fake_data = (
            $F{'DESCRIPTION'}        => 'Testing, description: A acute (requires Latin-1): [á] ' 
                                         . ' pound sign (requires WinLatin-1): [£] omega tonos (requires UTF-8): [ώ]',
            $F{'EASTING'}            => '45119',
            $F{'EMAIL'}              => 'email@example.com',
            $F{'FIRST_NAME'}         => 'Dave',
            $F{'FMS_ID'}             => '1012',
            $F{'LAST_NAME'}          => 'Test',
            $F{'LAT'}                => '51.756741605999',
            $F{'LONG'}               => '-1.2596387532192',
            $F{'NORTHING'}           => '206709',
            $F{'SERVICE_CODE'}       => 'OT',
            $F{'MEDIA_URL'}          => 'http://www.example.com/pothole.jpg',
            $F{'CLOSEST_ADDRESS'}     => <<TEXT
Nearest road to the pin placed on the map (automatically generated by Bing Maps): St Giles, Oxford, OX1 3

Nearest postcode to the pin placed on the map (automatically generated): OX1 2LA (46m away)
TEXT
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
}

#------------------------------------------------------------------
# get_pem_field_types
# return hash of types by field name: any not explicitly set here
# can be defaulted to VARCHAR2
#------------------------------------------------------------------
sub get_pem_field_types {
    return (
        ':ce_incident_datetime' => ORA_DATE,
        ':ce_x' => ORA_NUMBER,
        ':ce_y' => ORA_NUMBER,
        ':ce_date_expires' => ORA_DATE,
        ':ce_issue_number' => ORA_NUMBER,
        ':ce_status_date' => ORA_DATE,
        ':ce_compl_ack_date' => ORA_DATE,
        ':ce_compl_peo_date' => ORA_DATE,
        ':ce_compl_target' => ORA_DATE,
        ':ce_compl_complete' => ORA_DATE,
        ':ce_compl_from' => ORA_DATE,
        ':ce_compl_to' => ORA_DATE,
        ':ce_compl_corresp_date' => ORA_DATE,
        ':ce_compl_corresp_deliv_date' => ORA_DATE,
        ':ce_compl_no_of_petitioners' => ORA_NUMBER,
        ':ce_compl_est_cost' => ORA_NUMBER,
        ':ce_compl_adv_cost' => ORA_NUMBER,
        ':ce_compl_act_cost' => ORA_NUMBER,
        ':ce_compl_follow_up1' => ORA_DATE,
        ':ce_compl_follow_up2' => ORA_DATE,
        ':ce_compl_follow_uo3' => ORA_DATE,
        ':ce_date_time_arrived' => ORA_DATE,
        ':error_value' => ORA_NUMBER,
        ':ce_doc_id' => ORA_NUMBER,
    )
}

