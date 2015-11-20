package FixMyStreet::SendReport::EmptyHomes;

use Moo;
use namespace::autoclean;

use mySociety::MaPit;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    my $all_confirmed = 1;
    foreach my $body ( @{ $self->bodies } ) {
        my $contact = $row->result_source->schema->resultset("Contact")->find( {
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

        my $area_info = mySociety::MaPit::call('area', $body->body_areas->first->area_id);
        my $country = $area_info->{country};
        if ($country eq 'W') {
            push @{$self->bcc}, 'wales@' . FixMyStreet->config('EMAIL_DOMAIN');
        } elsif ($country eq 'S') {
            push @{$self->bcc}, 'scotland@' . FixMyStreet->config('EMAIL_DOMAIN');
        } else {
            push @{$self->bcc}, 'eha@' . FixMyStreet->config('EMAIL_DOMAIN');
        }
    }

    # Set address email parameter from added data
    $h->{address} = $row->extra->{address};

    return $all_confirmed && @{$self->to};
}

sub get_template {
    my ( $self, $row ) = @_;
    return Utils::read_file( FixMyStreet->path_to( "templates", "email", "emptyhomes", $row->lang, "submit.txt" )->stringify );
}

1;
