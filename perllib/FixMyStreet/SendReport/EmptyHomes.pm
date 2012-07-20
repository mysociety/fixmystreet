package FixMyStreet::SendReport::EmptyHomes;

use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;
    my %recips;

    my $all_confirmed = 1;
    foreach my $council ( keys %{ $self->councils } ) {
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            area_id => $council,
            category => 'Empty property',
        } );

        my ($council_email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );

        unless ($confirmed) {
            $all_confirmed = 0;
            #$note = 'Council ' . $row->council . ' deleted'
                #unless $note;
            $council_email = 'N/A' unless $council_email;
            #$notgot{$council_email}{$row->category}++;
            #$note{$council_email}{$row->category} = $note;
        }

        push @{ $self->to }, [ $council_email, $self->councils->{ $council }->{name} ];
        $recips{$council_email} = 1;

        my $country = $self->councils->{$council}->{country};
        if ($country eq 'W') {
            $recips{ 'shelter@' . mySociety::Config::get('EMAIL_DOMAIN') } = 1;
        } else {
            $recips{ 'eha@' . mySociety::Config::get('EMAIL_DOMAIN') } = 1;
        }
    }

    return () unless $all_confirmed;
    return keys %recips;
}

sub get_template {
    my ( $self, $row ) = @_;
    return Utils::read_file( FixMyStreet->path_to( "templates", "email", "emptyhomes", $row->lang, "submit.txt" )->stringify );
}

1;
