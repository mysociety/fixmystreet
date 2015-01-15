package FixMyStreet::SendReport::London;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

use Digest::MD5;
use FindBin;
use LWP::UserAgent;
use LWP::Simple;

use Utils;

sub construct_message {
    my %h = @_;
    return <<EOF,
A user of FixMyStreet has submitted the following report of a local
problem that they believe might require your attention.

Subject: $h{title}

Details: $h{detail}

$h{fuzzy}, or to provide an update on the problem, please visit the
following link:

$h{url}

$h{closest_address}
Yours,
The FixMyStreet team
EOF
}

sub send {
    return if mySociety::Config::get('STAGING_SITE');
    my ( $self, $row, $h ) = @_;

    $h->{message} = construct_message( %$h );
    my $phone = $h->{phone};
    my $mobile = '';
    if ($phone && $phone =~ /^\s*07/) {
        $mobile = $phone;
        $phone = '';
    }
    my ($first, $last) = $h->{name} =~ /^(\S*)(?: (.*))?$/;
    my %params = (
        Key => mySociety::Config::get('LONDON_REPORTIT_KEY'),
        Signature => Digest::MD5::md5_hex( $h->{confirmed} . mySociety::Config::get('LONDON_REPORTIT_SECRET') ),
        Type => Utils::london_categories()->{$h->{category}},
        RequestDate => $h->{confirmed},
        RequestMethod => 'Web',
        ExternalId => $h->{url},
        'Customer.Title' => '',
        'Customer.FirstName' => $first,
        'Customer.Surname' => $last,
        'Customer.Email' => $h->{email},
        'Customer.Phone' => $phone,
        'Customer.Mobile' => $mobile,
        'ProblemDescription' => $h->{message},
    );
    if ($h->{used_map}) {
        $params{'Location.Latitude'} = $h->{latitude};
        $params{'Location.Longitude'} = $h->{longitude};
    } elsif (mySociety::PostcodeUtil::is_valid_postcode($h->{query})) {
        # Didn't use map, and entered postcode, so use that.
        $params{'Location.Postcode'} = $h->{query};
    } else {
        # Otherwise, lat/lon is all we have, even if it's wrong.
        $params{'Location.Latitude'} = $h->{latitude};
        $params{'Location.Longitude'} = $h->{longitude};
    }
    if ($h->{has_photo}) {
        $params{'Document1.Name'} = 'Photograph';
        $params{'Document1.MimeType'} = 'image/jpeg';
        $params{'Document1.URL'} = $h->{image_url};
        $params{'Document1.URLPublic'} = 'true';
    }
    my $browser = LWP::UserAgent->new;
    my $response = $browser->post( mySociety::Config::get('LONDON_REPORTIT_URL'), \%params );
    my $out = $response->content;
    if ($response->code ne 200) {
        $self->error( "Failed to post $h->{id} to London API, response was " . $response->code . " $out" );
        return 1;
    }
    my ($id) = $out =~ /<caseid>(.*?)<\/caseid>/;
    my ($org) = $out =~ /<organisation>(.*?)<\/organisation>/;
    my ($team) = $out =~ /<team>(.*?)<\/team>/;

    $org = london_lookup($org);
    $row->external_id( $id );
    $row->external_body( $org );
    $row->external_team( $team );
    $self->success(1);
    return 0;
}

sub london_lookup {
    my $org = shift || '';
    my $str = "Unknown ($org)";
    open(FP, "$FindBin::Bin/../data/dft.csv");
    while (<FP>) {
        /^(.*?),(.*)/;
        if ($org eq $1) {
            $str = $2;
            last;
        }
    }
    close FP;
    return $str;
}

1;
