package FixMyStreet::SendReport::EmptyHomes;

use Moose;
use namespace::autoclean;

use mySociety::MaPit;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;
    my %recips;

    my $all_confirmed = 1;
    foreach my $body ( @{ $self->bodies } ) {
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            body_id => $body->id,
            category => 'Empty property',
        } );

        my ($body_email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );

        unless ($confirmed) {
            $all_confirmed = 0;
            #$note = 'Council ' . $row->body . ' deleted'
                #unless $note;
            $body_email = 'N/A' unless $body_email;
            #$notgot{$body_email}{$row->category}++;
            #$note{$body_email}{$row->category} = $note;
        }

        push @{ $self->to }, [ $body_email, $body->name ];
        $recips{$body_email} = 1;

        my $area_info = mySociety::MaPit::call('area', $body->body_areas->first->area_id);
        my $country = $area_info->{country};
        if ($country eq 'W') {
            $recips{ 'wales@' . mySociety::Config::get('EMAIL_DOMAIN') } = 1;
        } elsif ($country eq 'S') {
            $recips{ 'scotland@' . mySociety::Config::get('EMAIL_DOMAIN') } = 1;
        } else {
            $recips{ 'eha@' . mySociety::Config::get('EMAIL_DOMAIN') } = 1;
        }
    }

    # Set address email parameter from added data
    $h->{address} = $row->extra->{address};

    return () unless $all_confirmed;
    return keys %recips;
}

sub get_template {
    my ( $self, $row ) = @_;
    return Utils::read_file( FixMyStreet->path_to( "templates", "email", "emptyhomes", $row->lang, "submit.txt" )->stringify );
}

1;
