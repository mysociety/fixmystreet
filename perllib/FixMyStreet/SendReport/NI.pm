package FixMyStreet::SendReport::NI;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    my $all_confirmed = 1;
    foreach my $body ( @{ $self->bodies } ) {
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            body_id => $body->id,
            category => $row->category
        } );

        my ($email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );

        unless ($confirmed) {
            $all_confirmed = 0;
            $email = 'N/A' unless $email;
        }

        my $name = $body->name;
        if ( $email =~ /^roads.([^@]*)\@drdni/ ) {
            $name = "Roads Service (\u$1)";
            $h->{bodies_name} = $name;
            $row->external_body( 'Roads Service' );
        }
        push @{ $self->to }, [ $email, $name ];
    }

    return $all_confirmed && @{$self->to};
}

1;
