package FixMyStreet::SendReport::EastHants;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport'; }

use Try::Tiny;
use Encode;
use HTML::Entities;

sub construct_message {
    my %h = @_;
    my $message = '';
    $message .= "[ This report was also sent to the district council covering the location of the problem, as the user did not categorise it; please ignore if you're not the correct council to deal with the issue. ]\n\n"
        if $h{multiple};
    $message .= <<EOF;
Subject: $h{title}

Details: $h{detail}

$h{fuzzy}, or to provide an update on the problem, please visit the following link:

$h{url}

$h{closest_address}
EOF
    return $message;
}

sub send {
    return if FixMyStreet->config('STAGING_SITE');

    my ( $self, $row, $h ) = @_;

    # FIXME: should not recreate this each time
    my $eh_service;

    require Integrations::EastHantsWSDL;

    $h->{category} = 'Customer Services' if $h->{category} eq 'Other';
    $h->{message} = construct_message( %$h );
    my $return = 1;
    $eh_service ||= Integrations::EastHantsWSDL->on_fault(sub { my($soap, $res) = @_; die ref $res ? $res->faultstring : $soap->transport->status, "\n"; });
    try {
        # ServiceName, RemoteCreatedBy, Salutation, FirstName, Name, Email, Telephone, HouseNoName, Street, Town, County, Country, Postcode, Comments, FurtherInfo, ImageURL
        my $message = encode_entities(encode_utf8($h->{message}));
        my $name = encode_entities(encode_utf8($h->{name}));
        my $result = $eh_service->INPUTFEEDBACK(
            $h->{category}, 'FixMyStreet', '', '', $name, $h->{email}, $h->{phone},
            '', '', '', '', '', '', $message, 'Yes', $h->{image_url}
        );
        $return = 0 if $result eq 'Report received';
    } catch {
        my $e = $_;
        $self->error( "Error sending to East Hants: $e" );
    };
    $self->success( !$return );
    return $return;
}

1;
