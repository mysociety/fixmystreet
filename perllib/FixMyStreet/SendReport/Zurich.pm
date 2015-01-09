package FixMyStreet::SendReport::Zurich;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    # Only one body ever, most of the time with an email endpoint
    my $body = @{ $self->bodies }[0];
    if ( $row->external_body ) {
        $body = FixMyStreet::App->model("DB::Body")->find( { id => $row->external_body } );
        $h->{bodies_name} = $body->name;
    }
    my $body_email = $body->endpoint;

    my $parent = $body->parent;
    if ($parent && !$parent->parent) {
        # Division, might have an individual contact email address
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            body_id => $body->id,
            category => $row->category
        } );
        $body_email = $contact->email if $contact && $contact->email;
    }

    push @{ $self->to }, [ $body_email, $body->name ];
    return 1;
}

sub get_template {
    my ( $self, $row ) = @_;

    my $template;
    if ( $row->state eq 'unconfirmed' || $row->state eq 'confirmed' ) {
        $template = 'submit.txt';
    } elsif ( $row->state eq 'in progress' ) {
        $template = 'submit-in-progress.txt';
    } elsif ( $row->state eq 'planned' ) {
        $template = 'submit-feedback-pending.txt';
    } elsif ( $row->state eq 'closed' ) {
        $template = 'submit-external.txt';
        if ( $row->extra->{third_personal} ) {
            $template = 'submit-external-personal.txt';
        }
    }

    my $template_path = FixMyStreet->path_to( "templates", "email", "zurich", $template )->stringify;
    $template = Utils::read_file( $template_path );
    return $template;
}

# Zurich emails come from the site itself, unless it's to an external body,
# in which case it's from the category/body
sub send_from {
    my ( $self, $row ) = @_;

    if ( $row->external_body ) {
        my $body = @{ $self->bodies }[0];
        my $body_email = $body->endpoint;
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            body_id => $body->id,
            category => $row->category
        } );
        $body_email = $contact->email if $contact && $contact->email;
        return [ $body_email, FixMyStreet->config('CONTACT_NAME') ];
    }

    return [ FixMyStreet->config('CONTACT_EMAIL'), FixMyStreet->config('CONTACT_NAME') ];
}

1;
