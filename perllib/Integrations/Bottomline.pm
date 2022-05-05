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
    my ($self, $method, $data) = @_;
    my $ua = $self->auth_details;

    my $req = HTTP::Request::Common::POST(
        $self->endpoint . $method,
        %{ $self->headers },
    );
    $req->content(encode_json($data));

    my $resp = $ua->request($req);

    return {} if $resp->code == 204;

    return decode_json( $resp->content );
}

sub one_off_payment {
    my ($self, $args) = @_;

    return [];
}

sub amend_plan {
    my ($self, $args) = @_;

    return [];
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

sub cancel_plan {
    my ($self, $args) = @_;

    return [];
}

1;
