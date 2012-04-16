package FixMyStreet::SendReport::CRMOnDemand;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

use SOAP::Lite;
use WebService::CRMOnDemand;

sub construct_message {
    my $self    = shift;
    my %h       = @_;
    my $message = $h{details};

    return $message;
}

sub send {
    my ( $self, $row, $h, $to, $template, $recips, $nomail ) = @_;

    my $return = 1;

    foreach my $council ( keys %{ $self->councils } ) {
        my $conf =
          FixMyStreet::App->model("DB::Open311conf")
          ->search( { area_id => $council, endpoint => { '!=', '' } } )->first;

        my $username = $conf->username;
        my $password = $conf->decrypted_password( mySociety::Config::get('FMS_PASSPHRASE') );

        my $security = SOAP::Header->name("wsse:Security")->attr(
            {
                'soapenv:mustUnderstand' => 1,
                'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
            }
        );
        my $userToken = SOAP::Header->name(
            "wsse:UsernameToken" => \SOAP::Header->value(
                SOAP::Header->name('wsse:Username')->value($username)->type(''),
                SOAP::Header->name('wsse:Password')->value($password)->type('')
                  ->attr(
                    {
                        'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText'
                    }
                  )
            )
          )->attr(
            {
                'xmlns:wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
            }
          );

        my $sr = WebService::CRMOnDemand->on_fault(
            sub {
                my ( $soap, $res ) = @_;
                die ref $res
                  ? 'faultstring: ' . $res->faultstring . ', faultcode: ' . $res->faultcode
                  : 'transport status: ' . $soap->transport->status, "\n";
            }
        );
        $sr->{endpoint} = $conf->endpoint;

        eval {
            my $data = SOAP::Data->name(
                "ListOfServiceRequest" => \SOAP::Data->value(
                    SOAP::Data->name(
                        'ServiceRequest' => \SOAP::Data->value(
                            SOAP::Data->name( 'ststext8' => $h->{longitude} )->type('string'),    # long
                            SOAP::Data->name( 'ststext9' => $h->{latitude} )->type('string'),    # lat
                            SOAP::Data->name( 'Area'     => 'Highways' ),
                            SOAP::Data->name( 'Type'     => $h->{category} ),
                            SOAP::Data->name( 'Subject'  => $h->{title} ),
                            SOAP::Data->name(
                                'Description' => $self->construct_message(%$h)
                            ),
                        )
                    )
                  )->type('xsdLocal1:ListOfServiceRequestData')
            );

            my $res =
              $sr->ServiceRequestInsert_Input( $data,
                $security->value( \$userToken ),
              );

            $return *= 0;
        };
        if ($@) {
            my $error = "Error sending WebService::CRMOnDemand for report @{[ $row->id ]}: $@";
            print $error;
            $self->error($error);
            $return *= 1;
        }
    }

    $self->success($return);
    return $return;
}

1;
