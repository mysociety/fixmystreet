package Integrations::Bottomline;

use Moo;

use Data::Dumper;
use DateTime::Format::W3CDTF;
use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTTP::Headers;
use HTTP::Request;
use HTTP::Request::Common;
use JSON::MaybeXS;
use Sys::Syslog;
use Tie::IxHash;

has config => (
    is => 'ro'
);

has url => ( is => 'ro' );

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        return $self->config->{endpoint}
    }
);

has log_open => (
    is => 'ro',
    lazy => 1,
    builder => '_syslog_open',
);

sub _syslog_open {
    my $self = shift;
    my $ident = $self->config->{log_ident} or return 0;
    my $opts = 'pid,ndelay';
    my $facility = 'local6';
    my $log;
    eval {
        Sys::Syslog::setlogsock('unix');
        openlog($ident, $opts, $facility);
        $log = $ident;
    };
    $log;
}

sub DEMOLISH {
    my $self = shift;
    closelog() if $self->log_open;
}

sub log {
    my ($self, $str) = @_;
    $self->log_open or return;
    $str = Dumper($str) if ref $str;
    syslog('debug', '%s', $str);
}

has csrf => (
    is => 'rw',
    default => undef,
);

has token => (
    is => 'rw',
    default => undef,
);

has page_size => (
    is => 'rw',
    default => 50,
);

sub headers {
    my $self = shift;

    #die "no CRSF set for Bottomline API call\n" unless $self->csrf;

    my $headers = {
        User_Agent => "api-v2.5",
        Content_Type => "application/json",
        ":X-CSRF" => $self->csrf,
        "Cache_Control" => "no-cache",
    };

    if ( $self->token ) {
        $headers->{":com.bottomline.auth.token"} = $self->token;
    }

    return $headers;
}

has auth_details => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $jar = HTTP::CookieJar::LWP->new;
        my $ua = LWP::UserAgent->new( cookie_jar => $jar );

        my $handshake_req = HTTP::Request::Common::GET(
            $self->endpoint . "security/handshake"
        );

        my $handshake_resp = $ua->request($handshake_req);
        my $csrf = $handshake_resp->header("X-CSRF");

        $self->csrf($csrf);

        my $login_data = {
            loginTokens => [
                {
                    key => "com.bottomline.security.provider.login.email",
                    value => $self->config->{username},
                },
                {
                    key => "com.bottomline.security.provider.login.password",
                    value => $self->config->{password},
                },
            ],
            apiVersion => {
                major => 1,
                minor => 0,
                patch => 0,
                build => 0
            },
            purpose => "cpay-auth",
            tokenLocation => "HEADER",
        };

        my $login_req = HTTP::Request::Common::POST(
            $self->endpoint . "security/login",
            %{ $self->headers },
        );

        $login_req->content(encode_json($login_data));

        my $login_resp = $ua->request($login_req);
        my $token = $login_resp->header("com.bottomline.auth.token");

        $self->token($token);
        $csrf = $login_resp->header("X-CSRF");

        $self->csrf($csrf);

        return $ua;
    },
);

sub call_paged {
    my ($self, $path, $data, $method) = @_;

    my $first_result = $self->call($path, $data, $method);

    if ( ref $first_result eq 'HASH' and $first_result->{error} ) {
        return $first_result;
    }

    my $count = $self->parse_results("long", $first_result);

    return $first_result unless @$count;

    my $rows = $count->[0]->{'$value'};
    if ( $rows > $self->page_size ) {
        my $start = $self->page_size;
        while ( $start < $rows ) {
            $data->{resultsPage}->{firstResult} = $start;
            my $res = $self->call($path, $data, $method);
            push @{ $first_result->{rows } }, @{ $res->{rows} };
            $start += $self->page_size;
        }
    }

    return $first_result;
}


sub call {
    my ($self, $path, $data, $method) = @_;
    $method ||= '';
    my $ua = $self->auth_details;

    my $req;
    if ( $method eq 'PUT' ) {
        $req = HTTP::Request::Common::PUT (
            $self->endpoint . $path,
            %{ $self->headers },
        );
        $req->content(encode_json($data));
    } elsif ( $method eq 'DELETE' ) {
        $req = HTTP::Request::Common::DELETE (
            $self->endpoint . $path,
            %{ $self->headers },
        );
    } elsif ( $data ) {
        $req = HTTP::Request::Common::POST(
            $self->endpoint . $path,
            %{ $self->headers },
        );
        $req->content(encode_json($data));
    } else {
        $req = HTTP::Request::Common::GET(
            $self->endpoint . $path,
            %{ $self->headers },
        );
    }

    $self->log($path);
    $self->log($data);
    my $resp = $ua->request($req);

    return {} if $resp->code == 204;

    $self->log($resp->content);
    if ( $resp->code == 200 ) {
        return decode_json( $resp->content );
    }

    return {
        error => "unknown error",
        code => $resp->code,
        content => $resp->content,
    };
}

sub one_off_payment {
    my ($self, $args) = @_;

    my $sub = $args->{orig_sub};

    if ( $sub->get_extra_metadata('dd_contact_id') ) {
        $args->{dd_contact_id} = $sub->get_extra_metadata('dd_contact_id');
    } else {
        my $contact = $self->get_contact_from_email($sub->user->email);
        if ( $contact and !$contact->{error} ) {
            $args->{dd_contact_id} = $contact->{id};
        }
    }

    $args->{date}->set_time_zone('UTC');
    my $dueDate = DateTime::Format::W3CDTF->format_datetime($args->{date});
    my $data = {
        amount => $args->{amount},
        dueDate => $dueDate,
        comments => $args->{reference},
        paymentType => "DEBIT",
    };

    my $path = sprintf(
        "ddm/contacts/%s/mandates/%s/transaction",
        $args->{dd_contact_id},
        $sub->get_extra_metadata('dd_mandate_id'),
    );
    my $resp = $self->call($path, $data);

    if ( ref $resp eq 'HASHREF' and $resp->{error} ) {
        return 0;
    } else {
        return 1;
    }
}

sub amend_plan {
    my ($self, $args) = @_;

    my $sub = $args->{orig_sub};
    my $current_plan = $self->get_plan_for_mandate(
        $sub->get_extra_metadata('dd_mandate_id')
    );

    return 0 unless $current_plan->{regularAmount};

    $current_plan->{description} =~ s/$current_plan->{regularAmount}/$args->{amount}/g;

    my $plan = ixhash(
        '@type' => $current_plan->{'@type'},
        amountType => $current_plan->{amountType},
        regularAmount => $args->{amount},
        firstAmount => $current_plan->{firstAmount},
        lastAmount => $current_plan->{lastAmount},
        totalAmount => $current_plan->{totalAmount},
        id => $current_plan->{id},
        mandateId => $current_plan->{mandateId},
        profileId => $current_plan->{profileId},
        status => $current_plan->{status},
        extracted => $current_plan->{extracted},
        description => $current_plan->{description},
        schedule => ixhash(
            numberOfOccurrences => $current_plan->{schedule}->{numberOfOccurrences},
            schedulePattern => $current_plan->{schedule}->{schedulePattern},
            frequencyEnd => $current_plan->{schedule}->{frequencyEnd},
            comments => $current_plan->{schedule}->{comments},
            startDate => $current_plan->{schedule}->{startDate},
            endDate => $current_plan->{schedule}->{endDate},
        ),
        monthOfYear => $current_plan->{monthOfYear},
        monthDays => $current_plan->{monthDays},
    );

    my $path = sprintf(
        "ddm/contacts/%s/mandates/%s/payment-plans/%s",
        $sub->get_extra_metadata('dd_contact_id'),
        $sub->get_extra_metadata('dd_mandate_id'),
        $plan->{id},
    );

    my $resp = $self->call($path, $plan, 'PUT');

    if ( ref $resp eq 'HASH' and $resp->{error} ) {
        return 0;
    } else {
        return 1;
    }
}

sub get_plan_for_mandate {
    my ($self, $mandate_id) = @_;

    my $data = $self->build_query(ixhash(
        entity => ixhash(
           "name" => "PaymentPlans",
           "symbol" => "com.bottomline.ddm.model.base.plan.payment.PaymentPlan",
           "key" => "com.bottomline.ddm.model.base.plan.payment.PaymentPlan"
       ),
       field => ixhash(
            name => "PaymentPlan",
            symbol => "com.bottomline.ddm.model.plan.payment.CommonPaymentPlan",
        ),
        query => [ixhash(
             '@type' => "QueryParameter",
             "field" => ixhash(
               "name" => "id",
               "symbol" => "com.bottomline.ddm.model.plan.payment.PaymentPlan.mandate.modelId",
               "fieldType" => "LONG",
               "key" => JSON()->false,
             ),
             "operator" => {
               "symbol" => "="
             },
             "queryValues" => [
               ixhash(
                   '@type' => "long",
                   '$value' => $mandate_id,
               )
             ]
       )]
    ));

    my $resp = $self->call("query/execute#planForMandateId", $data, "POST");
    my $plans =  $self->parse_results("YearlyPaymentPlan", $resp);

    if ( ref $plans eq 'HASH' and $plans->{error} ) {
        return $plans;
    } elsif ( @$plans ) {
        return $plans->[0];
    }

    return undef;
}

sub build_query {
    my ( $self, $params ) = @_;

    my $data = ixhash(
       "entity" => $params->{entity},
       "resultFields" => [
           ixhash(
             "name" => $params->{field}->{name},
             "symbol" => $params->{field}->{symbol},
             "fieldType" => "OBJECT",
             "key" => JSON()->false,
           ),
           ixhash(
             "name" => "rowCount",
             "symbol" => "com.bottomline.query.count",
             "fieldType" => "LONG",
             "key" => JSON()->false,
           )
       ],
       $params->{query} ? ( criteria => { searchCriteria => [ @{$params->{query}} ] } ) : (),
       "resultsPage" => ixhash(
           "firstResult" => 0,
           "maxResults" => $self->page_size
       )
    );

    return $data;
}


sub parse_results {
    my ($self, $type, $results) = @_;

    # do not try and process an error, just return the error
    if ( ref $results eq 'HASH' and $results->{error} ) {
        return $results;
    }

    my $payments = [];

    if (keys %$results) {
        my $rows = $results->{rows};
        for my $row (@$rows) {
            my $value = $row->{values}->[0]->{resultValues}->[0]->{value};
            next unless $value->{'@type'} eq $type;
            push @$payments, $value;
        }
    }

    return $payments;
}


sub get_recent_payments {
    my ($self, $args) = @_;

    my $data = $self->build_query(ixhash(
        entity => ixhash(
           "name" => "Instructions",
           "symbol" => "com.bottomline.ddm.model.instruction",
           "key" => "com.bottomline.ddm.model.instruction"
       ),
       field => ixhash(
            name => "Instruction",
            symbol => "com.bottomline.ddm.model.instruction.Instruction",
        ),
        query => [ixhash(
             '@type' => "QueryParameter",
             "field" => ixhash(
               "name" => "paymentDate",
               "symbol" => "com.bottomline.ddm.model.instruction.Instruction.paymentDate",
               "fieldType" => "DATE",
               "key" => JSON()->false,
             ),
             "operator" => {
               "symbol" => "BETWEEN"
             },
             "queryValues" => [
               ixhash(
                   '@type' => "date",
                   '$value' => $args->{start}->datetime,
               ),
               ixhash(
                   '@type' => "date",
                   '$value' => $args->{end}->datetime,
               )
             ]
       )]
   ));

    my $resp = $self->call_paged("query/execute#CollectionHistoryDates", $data);

    return $self->parse_results("Instruction", $resp);
}

sub get_payments_with_status {
    my ($self, $args) = @_;

    my $data = $self->build_query(ixhash(
        entity => ixhash(
           "name" => "Instructions",
           "symbol" => "com.bottomline.ddm.model.instruction",
           "key" => "com.bottomline.ddm.model.instruction"
       ),
       field => ixhash(
            name => "Instruction",
            symbol => "com.bottomline.ddm.model.instruction.Instruction",
        ),
        query =>[
         ixhash(
             '@type' => "QueryParameter",
             "field" => ixhash(
               "name" => "status",
               "symbol" => "com.bottomline.ddm.model.instruction.Instruction.status",
               "fieldType" => "ENUM",
               "key" => JSON()->false,
             ),
             "operator" => {
               "symbol" => "="
             },
             "queryValues" => [
               ixhash(
                   '@type' => "string",
                   '$value' => $args->{status},
               )
             ]
       )
   ]));

    my $resp = $self->call_paged("query/execute#CollectionHistoryStatus", $data);
    return $self->parse_results("Instruction", $resp);
}

sub get_cancelled_payers {
    my ($self, $args) = @_;

    my $data = $self->build_query(ixhash(
        entity => ixhash(
           "name" => "Mandates",
           "symbol" => "com.bottomline.ddm.model.mandate",
           "key" => "com.bottomline.ddm.model.mandate"
       ),
       field => ixhash(
            name => "Mandates",
            symbol => "com.bottomline.ddm.model.mandate.Mandates",
        ),
        query => [
         ixhash(
             '@type' => "QueryParameter",
             "field" => ixhash(
               "name" => "status",
               "symbol" => "com.bottomline.ddm.model.mandate.Mandate.status",
               "fieldType" => "STRING",
               "key" => JSON()->false,
             ),
             "operator" => {
               "symbol" => "="
             },
             "queryValues" => [
               ixhash(
                   '@type' => "string",
                   '$value' => "CANCELLED",
               )
             ]
       )
   ]));

    my $resp = $self->call_paged("query/execute#getCancelledPayers", $data);
    return $self->parse_results("MandateDTO", $resp);
}

sub get_contact_from_email {
    my ($self, $email) = @_;

    my $data = $self->build_query(ixhash(
        entity => ixhash(
           "name" => "Contacts",
           "symbol" => "com.bottomline.ddm.model.contact",
           "key" => "com.bottomline.ddm.model.contact"
       ),
       field => ixhash(
            name => "Contacts",
            symbol => "com.bottomline.ddm.model.contact.Contact",
        ),
        query => [ ixhash(
            '@type' => "QueryParameter",
            "field" => ixhash(
                "name" => "email",
                "symbol" => "com.bottomline.ddm.model.contact.Contact.email",
                "fieldType" => "STRING",
                "key" => JSON()->false,
            ),
            "operator" => {
                "symbol" => "="
            },
            "queryValues" => [ ixhash(
               '@type' => "string",
               '$value' => $email,
            ) ]
        ) ]
    ));

    my $resp = $self->call("query/execute#getContactFromEmail", $data);
    my $contacts = $self->parse_results("ContactDTO", $resp);

    if ( ref $resp eq 'HASH' and $resp->{error} ) {
        return $resp;
    } elsif ( @$contacts ) {
        return $contacts->[0];
    }

    return undef;
}


sub get_mandate_from_reference {
    my ($self, $reference) = @_;

    my $data = $self->build_query(ixhash(
        entity => ixhash(
           "name" => "Mandates",
           "symbol" => "com.bottomline.ddm.model.mandate",
           "key" => "com.bottomline.ddm.model.mandate"
       ),
       field => ixhash(
            name => "Mandate",
            symbol => "com.bottomline.ddm.model.mandate.Mandate",
        ),
        query => [ ixhash(
            '@type' => "QueryParameter",
            "field" => ixhash(
                "name" => "reference",
                "symbol" => "com.bottomline.ddm.model.mandate.Mandate.reference",
                "fieldType" => "STRING",
                "key" => JSON()->false,
            ),
            "operator" => ixhash(
                "symbol" => "CONTAINS"
            ),
            "queryValues" => [ ixhash(
               '@type' => "string",
               '$value' => $reference,
            ) ]
        ) ]
    ));

    my $resp = $self->call("query/execute#getMandateFromReference", $data, "POST");
    my $mandates = $self->parse_results("MandateDTO", $resp);

    if ( ref $resp eq 'HASH' and $resp->{error} ) {
        return $resp;
    } elsif ( @$mandates ) {
        return $mandates->[0];
    }

    return undef;
}

sub cancel_plan {
    my ($self, $args) = @_;

    my $sub = $args->{report};

    my $path = sprintf(
        "ddm/contacts/%s/mandates/%s",
        $sub->get_extra_metadata('dd_contact_id'),
        $sub->get_extra_metadata('dd_mandate_id'),
    );

    my $resp = $self->call($path, undef, 'DELETE');

    # if there's not an error then return success as there's no content
    # returned
    if ( ref $resp eq 'HASH' and $resp->{error} ) {
        return $resp;
    } else {
        return 1;
    }
}

sub ixhash {
    tie (my %data, 'Tie::IxHash', @_);
    return \%data;
}

1;
