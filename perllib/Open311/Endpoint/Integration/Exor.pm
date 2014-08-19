package Open311::Endpoint::Integration::Exor;
use Web::Simple;
extends 'Open311::Endpoint';
with 'Open311::Endpoint::Role::mySociety';
with 'Open311::Endpoint::Role::ConfigFile';
use DBI;
use MooX::HandlesVia;
use DateTime::Format::Oracle; # default format 'YYYY-MM-DD HH24:MI:SS' # NB: hh24 (not hh)
use Encode qw(from_to);

# declare our constants, as we may not be able to easily install DBD::Oracle
# on a development system!
# t/open311/endpoint/warwick.t disables DBD::Oracle from loading, so the default
# stubbed values will be used instead:
sub ORA_DATE ();
sub ORA_NUMBER ();
sub ORA_VARCHAR2 ();
use DBD::Oracle qw(:ora_types);
BEGIN {
*ORA_DATE = *ORA_NUMBER = *ORA_VARCHAR2 = sub () { 1 }
    unless $DBD::Oracle::VERSION;
}

has ora_dt => (
    is => 'lazy',
    default => sub { 'DateTime::Format::Oracle' }, 
        # NB: we just return the class name. This is to smooth over odd API,
        # for consistency with w3_dt
);

sub parse_ora_date {
    my ($self, $date_string) = @_;

    my $date = $self->ora_dt->parse_datetime( $date_string );

    # will be in floating time_zone so set
    $date->set_time_zone( $self->time_zone );

    return $date;
}

has max_limit => (
    is => 'ro',
    default => 1000,
);

has encode_to_win1252 => (
    is => 'ro',
    default => 1,
);

has _connection_details => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $DB_HOST = $self->db_host;
        my $ORACLE_SID = $self->oracle_sid;
        my $DB_PORT = $self->db_port;
        my $USERNAME = $self->db_username;
        my $PASSWORD = $self->db_password;
        return [ "dbi:Oracle:host=$DB_HOST;sid=$ORACLE_SID;port=$DB_PORT", $USERNAME, $PASSWORD ]
    },
    handles_via => 'Array',
    handles => {
        connection_details => 'elements',
        dsn => [ get => 0 ],
    },
);

has dbh => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        return DBI->connect( $self->connection_details );
    }
);

has db_host => (
    is => 'ro',
    default => 'localhost',
);

has oracle_sid => (
    is => 'ro',
    default => '1000',  # DUMMY
);

has db_port => (
    is => 'ro',
    default => 1531,
);

has db_username => (
    is => 'ro',
    default => 'FIXMYSTREET',
);

has db_password => (
    is => 'ro',
    default => 'SUPERSEEKRIT', # DUMMY
);

has strip_control_characters => (
    is => 'ro',
    default => 'ruthless',
);

has testing => (
    is => 'ro',
    default => 0,
);

#------------------------------------------------------------------
# pem_field_types
# return hash of types by field name: any not explicitly set here
# can be defaulted to VARCHAR2
#------------------------------------------------------------------
has get_pem_field_types => (
    is => 'ro',
    handles_via => 'Hash',
    default => sub {
        {
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
        }
    },
    handles => {
        get_pem_field_type => 'get',

    },
);

sub pem_field_type {
    my ($self, $field) = @_;
    return $self->get_pem_field_type($field) || ORA_VARCHAR2;
}


sub services {
    # not currently used as Warwick.pm uses a hardcoded list.
    die "TODO";
}

sub _strip_ruthless {
    my $text = shift or return '';
    $text =~ s/[[:cntrl:]]/ /g; # strip all control chars, simples
    return $text;
}

sub _strip_non_ruthless {
    my $text = shift or return '';
    # slightly odd doubly negated character class
    $text =~ s/[^\t\n[:^cntrl:]]/ /g; # leave tabs and newlines
    return $text;
}
sub strip {
    my ($self, $text, $max_len, $prefer_non_ruthless) = @_;
    use Carp 'confess';
    confess 'EEEK' unless $self;
    if (my $scc = $self->strip_control_characters) {
        if ($scc eq 'ruthless') {
            $text = _strip_ruthless($text);
        }
        elsif ($prefer_non_ruthless) {
            $text = _strip_non_ruthless($text);
        }
        else {
            $text = _strip_ruthless($text);
        }
    }
    return $max_len ? substr($text, 0, $max_len) : $text;
}

sub post_service_request {
    my ($self, $service, $args) = @_;
    die "No such service" unless $service;

    if ($args->{media_url}) {
        # don't put URL for full images into the database (because they're too big to see on a Blackberry)
        $args->{media_url} =~ s/\.full(\.jpe?g)$/$1/;
        $args->{description} .= $self->strip( "\n\n") . 'Photo: ' . $args->{media_url};
    }
    my $attributes = $args->{attributes};
    my $location = $attributes->{closest_address};

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
    $bindings{":ce_incident_datetime"}=$args->{requested_datetime}
        || $self->w3_dt->format_datetime( DateTime->now );

    # especially FMS-specific:
    $bindings{":ce_source"}        = "FMS";           # important, and specific to this script!
    $bindings{":ce_doc_reference"} = $attributes->{external_id}; # FMS ID
    $bindings{":ce_enquiry_type"}  = $args->{service_code};

    # incoming data
    $bindings{":ce_x"}             = $attributes->{easting};
    $bindings{":ce_y"}             = $attributes->{northing};
    $bindings{":ce_forename"}      = uc $self->strip($args->{first_name}, 30);    # 'CLIFF'
    $bindings{":ce_surname"}       = uc $self->strip($args->{last_name}, 30);     # 'STEWART'
    $bindings{":ce_work_phone"}    = $self->strip($args->{phone}, 25);            # '0117 600 4200'
    $bindings{":ce_email"}         = uc $self->strip($args->{email}, 50);         # 'info@exor.co.uk'
    $bindings{":ce_description"}   = $self->strip($args->{description}, 1970, 1); # 'Large Pothole'

    # nearest address guesstimate
    $bindings{":ce_location"}      = $self->strip($location, 254);
    
    if ($self->testing) {
        warn Dumper(\%bindings); use Data::Dumper;
    }

    my ($pem_id, $error_value, $error_product) = $self->insert_into_db(\%bindings);

    # if error, maybe need to look it up:
    # error_value is the index HER_NO in table HIG_ERRORS, which has messages
    # actually err_product not helpful (will always be "DOC")
    die "$error_value $error_product" if $error_value || $error_product; 

    my $request = $self->new_request(

        # NB: possible race condition between next_request_id and _add_request
        # (this is fine for synchronous test-cases)
        
        service => $service,
        service_request_id => $pem_id,
        status => 'open',
        description => $args->{description},
        agency_responsible => '',
        requested_datetime => DateTime->now(),
        updated_datetime => DateTime->now(),
        address => $args->{address_string} // '',
        address_id => $args->{address_id} // '',
        media_url => $args->{media_url} // '',
        zipcode => $args->{zipcode} // '',
        attributes => $attributes,

    );

    return $request;
}

sub insert_into_db {
    my ($self, $bindings) = @_;
    my %bindings = %$bindings;

    my ($pem_id, $error_value, $error_product);
    
    my $dbh = $self->dbh;

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
            $self->pem_field_type( $name ),
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

    return ($pem_id, $error_value, $error_product);
}

sub get_service_request_updates {
    my ($self, $args) = @_;

    # ignore jurisdiction_id for now
    #
    my $start_date = $self->maybe_inflate_datetime( $args->{start_date} );
    my $end_date   = $self->maybe_inflate_datetime( $args->{end_date} );

    unless ($self->testing) {
        $start_date = DateTime->now->subtract( days => 1 )
            unless ($start_date or $end_date);
    }

    my $w3_dt = $self->w3_dt;
    my $ora_dt = $self->ora_dt;
    my $ORA_DT_FORMAT = $ora_dt->nls_date_format;

    my @where;

    push @where, sprintf 
        'updated_timedate >= to_date(%s, %s)',
        $ora_dt->format_datetime($start_date), $ORA_DT_FORMAT
        if $start_date;

    push @where, sprintf 
        'updated_timedate <= to_date(%s, %s)',
        $ora_dt->format_datetime($end_date), $ORA_DT_FORMAT
        if $end_date;

    push @where, "(status='OPEN' OR status='CLOSED')"
        unless $self->testing;

    my $WHERE_CLAUSE = @where ?
        'WHERE ' . join(' AND ', grep {$_} @where)
        : '';

    my $sql = qq(
        SELECT
            row_id,
            service_request_id,
            to_char(updated_timedate, '$ORA_DT_FORMAT'),
            status,
            description
        FROM higatlas.fms_update
        $WHERE_CLAUSE
        ORDER BY updated_timedate DESC);

    my $limit = $self->max_limit; # also allow testing to modify this?
    $sql = "SELECT * FROM ($sql) WHERE ROWNUM <= $limit" if $limit;

    my @data = $self->get_updates_from_sql( $sql );

    my @updates = map {
        Open311::Endpoint::Service::Request::Update->new(
            update_id => $_->{row_id},
            service_request_id => $_->{service_request_id},
            updated_datetime => $self->parse_ora_date( $_->{updated_datetime} ),
            status => $_->{status},
            description => $_->{description}
        )
    } @data;

    return @updates;
}

sub get_updates_from_sql {
    my ($self, $sql) = @_;
    my $dbh = $self->dbh;
    my $ary_ref = $dbh->selectall_arrayref($sql, { Slice => {} } );
    return @$ary_ref;
}

1;
