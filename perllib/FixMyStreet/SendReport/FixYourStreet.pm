package FixMyStreet::SendReport::FixYourStreet;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

use Digest::MD5;
use LWP::UserAgent;
use LWP::Simple;
use DateTime::Format::Strptime;


sub fixyourstreet_categories {         # NB: This will die on its arse if they change so much as the capitalisation 
    return {
        'Graffiti'                      => 1,
        'Road or path defects'          => 2,
        'Street Lighting'               => 3,
        'Leaks and Drainage'            => 5,
        'Litter and Illegal Dumping'    => 6,            
        'Tree and Grass Maintenance'    => 7,
    };
}


sub construct_message {
    my %h = @_;
    return <<EOF,
$h{detail}
<br /><br />
----<br />
This report was originally submitted at FixMyStreet.ie. You can find it at this alternate address:<br />
$h{url}<br />
----<br />
<br />
$h{closest_address}
EOF
}

sub send {
    return if mySociety::Config::get('STAGING_SITE');
    my ( $self, $row, $h ) = @_;

    $h->{message} = construct_message( %$h );
    my $phone = $h->{phone};
    my $mobile = '';
    if ($phone && $phone =~ /^\s*08/) {
        $mobile = $phone;
        $phone = '';
    }
    my $timestamp = substr $h->{confirmed} ,0,19; # Chop pointless nanoseconds
    my $parser    = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %H:%M:%S' );
    my $dt        = $parser->parse_datetime($timestamp);

    my ($first, $last) = $h->{name} =~ /^(\S*)(?: (.*))?$/;
    my %params = (
        'task'                  => 'report',
        'incident_title'        => $h->{title},
        'incident_description'  => $h->{message},
        'incident_date'         => $dt->strftime("%m/%d/%Y"),  # eg 29/02/2012
        'incident_hour'         => $dt->strftime("%I"),
        'incident_minute'       => $dt->strftime("%M"),
        'incident_ampm'         => $dt->strftime("%P"),
        'incident_category'     => fixyourstreet_categories()->{$h->{category}},
        'location_name'         => $h->{closest_address},
        'person_first'          => $first,
        'person_last'           => $last,
        'person_email'          => $h->{email},
        'resp'                  => 'xml',
    );
    
    $params{'category'} = $h->{category};
    
    if ($h->{used_map}) {
        $params{'latitude'} = $h->{latitude};
        $params{'longitude'} = $h->{longitude};
    } else {
        # Otherwise, lat/lon is all we have, even if it's wrong.
        $params{'latitude'} = $h->{latitude};
        $params{'longitude'} = $h->{longitude};
    }
    
    #TODO fix this broken thing; needs multipart mime submission
    
    #if ($h->{has_photo}) {
    #    $params{'incident_photo'} = $h->{image_url};
    #}
    
    my $browser = LWP::UserAgent->new;
    my $response = $browser->post( mySociety::Config::get('FIXYOURSTREET_REPORT_URL'), \%params );
    my $out = $response->content;
    my ($win) = $out =~ /<success>(.*?)<\/success>/;


    my $input = JSON->new->utf8(1)->encode( {
        params => \%params,
    } );

    
    if ($win ne "true") {
        print "Failed to post $h->{id} to FixYourStreet API, response was " . $response->code . " $out\n";
        $self->error( "Failed to post $h->{id} to FixYourStreet API, response was " . $response->code . " $out. Input was:" . $input );
        return 1;
    }

    my ($org) = 'the council via FixYourStreet.ie';
    $row->external_body( $org );
    $row->send_method_used('fixyourstreet');
    $self->success(1);
    return 0;
}





1;
