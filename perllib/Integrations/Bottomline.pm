package Integrations::Bottomline;

use Moo;

use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTTP::Headers;
use HTTP::Request;
use HTTP::Request::Common;
use JSON::MaybeXS;

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

has csrf => (
    is => 'rw',
    default => undef,
);

has token => (
    is => 'rw',
    default => undef,
);

sub headers {
    my $self = shift;

    #die "no CRSF set for Bottomline API call\n" unless $self->csrf;

    my $headers = {
        User_Agent => "api-v2.5",
        Content_Type => "application/json",
        ":X-CSRF" => $self->csrf,
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


sub call {
    my ($self, $path, $data, $method) = @_;
    my $ua = $self->auth_details;

    my $req;
    if ( $method eq 'PUT' ) {
        $req = HTTP::Request::Common::PUT (
            $self->endpoint . $path,
            %{ $self->headers },
        );
        $req->content(encode_json($data));
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

    my $resp = $ua->request($req);

    return {} if $resp->code == 204;

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

    my $data = {
        amount => $args->{amount},
        dueDate => $args->{date},
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
    my $plan = $self->get_plan_for_mandate($sub->get_extra_metadata('dd_mandate_id'));

    $plan->{regularAmount} = $args->{amount};

    my $path = sprintf(
        "ddm/contacts/%s/mandates/%s/payment-plans/%s",
        $sub->get_extra_metadata('dd_contact_id'),
        $sub->get_extra_metadata('dd_mandate_id'),
        $plan->{id},
    );

    my $resp = $self->call($path, { "YearlyPaymentPlan" => $plan }, 'PUT');

    if ( ref $resp eq 'HASH' and $resp->{error} ) {
        return 0;
    } else {
        return 1;
    }
}

sub get_plan_for_mandate {
    my ($self, $mandate_id) = @_;

    my $data = $self->build_query({
        entity => {
           "name" => "PaymentPlans",
           "symbol" => "com.bottomline.ddm.model.base.plan.payment.PaymentPlan",
           "key" => "com.bottomline.ddm.model.base.plan.payment.PaymentPlan"
       },
       field => {
            name => "PaymentPlan",
            symbol => "com.bottomline.ddm.model.payment.CommonPaymentPlan",
        },
        query => [{
             '@type' => "QueryParameter",
             "field" => {
               "name" => "id",
               "symbol" => "com.bottomline.ddm.model.base.plan.payment.PaymentPlan.mandate.modelId",
               "fieldType" => "LONG",
               "key" => JSON()->false,
             },
             "operator" => {
               "symbol" => "="
             },
             "queryValues" => [
               {
                   '@type' => "long",
                   '$value' => $mandate_id,
               }
             ]
       }]
    });

    my $resp = $self->call("query/execute#planForMandateId", $data);

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

    my $data = {
       "entity" => $params->{entity},
       "criteria" => {
           "searchCriteria" => [ @{$params->{query}} ]
       },
       "resultFields" => [
           {
             "name" => $params->{field}->{name},
             "symbol" => $params->{field}->{symbol},
             "fieldType" => "OBJECT",
             "key" => JSON()->false,
           },
           {
             "name" => "rowCount",
             "symbol" => "com.bottomline.query.count",
             "fieldType" => "LONG",
             "key" => JSON()->false,
           }
       ],
       "resultsPage" => {
           "firstResult" => 0,
           "maxResults" => 50
       }
    };

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

    my $data = $self->build_query({
        entity => {
           "name" => "Instructions",
           "symbol" => "com.bottomline.ddm.model.instruction",
           "key" => "com.bottomline.ddm.model.instruction"
       },
       field => {
            name => "Instruction",
            symbol => "com.bottomline.ddm.model.instruction.Instruction",
        },
        query => [{
             '@type' => "QueryParameter",
             "field" => {
               "name" => "paymentDate",
               "symbol" => "com.bottomline.ddm.model.instruction.Instruction.paymentDate",
               "fieldType" => "DATE",
               "key" => JSON()->false,
             },
             "operator" => {
               "symbol" => "BETWEEN"
             },
             "queryValues" => [
               {
                   '@type' => "date",
                   '$value' => $args->{start}->datetime,
               },               {
                   '@type' => "date",
                   '$value' => $args->{end}->datetime,
               }
             ]
       }]
   });

    my $resp = $self->call("query/execute#CollectionHistoryDates", $data);

    return $self->parse_results("Instruction", $resp);
}

sub get_payments_with_status {
    my ($self, $args) = @_;

    my $data = $self->build_query({
        entity => {
           "name" => "Instructions",
           "symbol" => "com.bottomline.ddm.model.instruction",
           "key" => "com.bottomline.ddm.model.instruction"
       },
       field => {
            name => "Instruction",
            symbol => "com.bottomline.ddm.model.instruction.Instruction",
        },
        query =>[
         {
             '@type' => "QueryParameter",
             "field" => {
               "name" => "status",
               "symbol" => "com.bottomline.ddm.model.instruction.Instruction.status",
               "fieldType" => "STRING",
               "key" => JSON()->false,
             },
             "operator" => {
               "symbol" => "="
             },
             "queryValues" => [
               {
                   '@type' => "string",
                   '$value' => $args->{status},
               }
             ]
       }
   ]});

    my $resp = $self->call("query/execute#CollectionHistoryStatus", $data);
    return $self->parse_results("Instruction", $resp);
}

sub get_cancelled_payers {
    my ($self, $args) = @_;

    my $data = $self->build_query({
        entity => {
           "name" => "Mandates",
           "symbol" => "com.bottomline.ddm.model.mandate",
           "key" => "com.bottomline.ddm.model.mandate"
       },
       field => {
            name => "Mandates",
            symbol => "com.bottomline.ddm.model.mandate.Mandates",
        },
        query => [
         {
             '@type' => "QueryParameter",
             "field" => {
               "name" => "status",
               "symbol" => "com.bottomline.ddm.model.mandate.Mandate.status",
               "fieldType" => "STRING",
               "key" => JSON()->false,
             },
             "operator" => {
               "symbol" => "="
             },
             "queryValues" => [
               {
                   '@type' => "string",
                   '$value' => "CANCELLED",
               }
             ]
       }
   ]});

    my $resp = $self->call("query/execute#getCancelledPayers", $data);
    return $self->parse_results("MandateDTO", $resp);
}

sub get_contact_from_email {
    my ($self, $email) = @_;

    my $data = $self->build_query({
        entity => {
           "name" => "Contacts",
           "symbol" => "com.bottomline.ddm.model.contact",
           "key" => "com.bottomline.ddm.model.contact"
       },
       field => {
            name => "Contacts",
            symbol => "com.bottomline.ddm.model.contact.Contact",
        },
        query => [ {
            '@type' => "QueryParameter",
            "field" => {
                "name" => "email",
                "symbol" => "com.bottomline.ddm.model.contact.Contact.email",
                "fieldType" => "STRING",
                "key" => JSON()->false,
            },
            "operator" => {
                "symbol" => "="
            },
            "queryValues" => [ {
               '@type' => "string",
               '$value' => $email,
            } ]
        } ]
    });

    my $resp = $self->call("query/execute#getContactFromEmail", $data);
    my $contacts = $self->parse_results("ContactDTO", $resp);

    if ( ref $resp eq 'HASH' and $resp->{error} ) {
        return $resp;
    } elsif ( @$contacts ) {
        return $contacts->[0];
    }

    return undef;
}

sub cancel_plan {
    my ($self, $args) = @_;

    return [];
}

1;
