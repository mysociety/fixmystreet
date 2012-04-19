package FixMyStreet::SendReport::CRMOnDemand;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

use SOAP::Lite;
use WebService::CRMOnDemand;
use WebService::CRMOnDemandContact;

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

        my $contact = WebService::CRMOnDemandContact->on_fault(
            sub {
                my ( $soap, $res ) = @_;
                die ref $res
                  ? 'faultstring: ' . $res->faultstring . ', faultcode: ' . $res->faultcode
                  : 'transport status: ' . $soap->transport->status, "\n";
            }
        );
        $contact->{endpoint} = $conf->endpoint;

        eval {
            my $q_data = SOAP::Data->name(
                "ListOfContact" => \SOAP::Data->value(
                    SOAP::Data->name(
                        'Contact' => \SOAP::Data->value(
                            SOAP::Data->name(
                                'ContactEmail' => sprintf( "='%s'", $h->{email} )
                            ),
                            SOAP::Data->name( 'Id' => '' ),
                        )
                    )
                  )->type('xsdLocal1:ContactQueryPage')
            );

            my $q_res = $contact->ContactQueryPage_Input(
                $q_data,
                $security->value( \$userToken ),
            );

            my $contact_id;
            if ( $q_res && $q_res->{Contact} ) {
                if ( ref( $q_res->{Contact} ) eq 'ARRAY' ) {
                    my @contacts = @{ $q_res->{Contact} };
                    print " multiple contacts found \n ";
                }
                else {
                    $contact_id = $q_res->{Contact}->{Id};
                }
            }
            else {
                my ( $firstname, $lastname ) = $h->{name} =~ /^(\S*)(?: (.*))?$/;

                my $insert_data = SOAP::Data->name(
                    "ListOfContact" => \SOAP::Data->value(
                        SOAP::Data->name(
                            'Contact' => \SOAP::Data->value(
                                SOAP::Data->name(
                                    'ContactFirstName' => $firstname
                                ),
                                SOAP::Data->name(
                                    'ContactLastName' => $lastname
                                ),
                                SOAP::Data->name(
                                    'ContactEmail' => $h->{email}
                                ),
                            )
                        )
                      )->type('xsdLocal1:ContactInsert')
                );

                my $insert_res = $contact->ContactInsert_Input(
                    $insert_data,
                    $security->value( \$userToken ),
                );

                $contact_id = $insert_res->{Contact}->{Id};
            }

            die "No contact found or created for CRMOnDemand for $h->{id}" unless $contact_id;

            my $sr_data = SOAP::Data->name(
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
                            SOAP::Data->name( 'ContactId' => $contact_id ),
                        )
                    )
                  )->type('xsdLocal1:ListOfServiceRequestData')
            );

            my $sr_res = $sr->ServiceRequestInsert_Input(
                $sr_data, $security->value( \$userToken )
            );

            my $id = $sr_res->{ServiceRequest}->{Id};

            if ( !$id ) {
                print "Failed to get external id for $h->{id} using WebService::CrmOnDemand";
                $return *= 1;
                next;
            }

            $row->external_id( $id );
            $row->update;

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
