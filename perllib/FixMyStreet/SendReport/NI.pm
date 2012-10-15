package FixMyStreet::SendReport::NI;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;
    my %recips;

    my $all_confirmed = 1;
    foreach my $council ( keys %{ $self->councils } ) {
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            area_id => $council,
            category => $row->category
        } );

        my ($email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );

        unless ($confirmed) {
            $all_confirmed = 0;
            $email = 'N/A' unless $email;
        }

        my $name = $self->councils->{$council}->{info}->{name};
        if ( $email =~ /^roads.([^@]*)\@drdni/ ) {
            $name = "Roads Service (\u$1)";
            $h->{councils_name} = $name;
            $row->external_body( 'Roads Service' );
        }
        push @{ $self->to }, [ $email, $name ];
        $recips{$email} = 1;
    }

    return () unless $all_confirmed;
    return keys %recips;
}

1;
