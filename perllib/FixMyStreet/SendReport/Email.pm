package FixMyStreet::SendReport::Email;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

use mySociety::EmailUtil;

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

        my ($council_email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );

        $council_email = essex_contact($row->latitude, $row->longitude) if $council == 2225;
        $council_email = oxfordshire_contact($row->latitude, $row->longitude) if $council == 2237 && $council_email eq 'SPECIAL';

        unless ($confirmed) {
            $all_confirmed = 0;
            $note = 'Council ' . $row->council . ' deleted'
                unless $note;
            $council_email = 'N/A' unless $council_email;
            $self->unconfirmed_counts->{$council_email}{$row->category}++;
            $self->unconfirmed_notes->{$council_email}{$row->category} = $note;
        }

        push @{ $self->to }, [ $council_email, $self->councils->{ $council }->{info}->{name} ];
        $recips{$council_email} = 1;
    }

    return () unless $all_confirmed;
    return keys %recips;
}

sub get_template {
    my ( $self, $row ) = @_;

    my $template = 'submit.txt';
    $template = 'submit-brent.txt' if $row->council eq 2488 || $row->council eq 2237;
    my $template_path = FixMyStreet->path_to( "templates", "email", $row->cobrand, $template )->stringify;
    $template_path = FixMyStreet->path_to( "templates", "email", "default", $template )->stringify
        unless -e $template_path;
    $template = Utils::read_file( $template_path );
    return $template;
}

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    my @recips = $self->build_recipient_list( $row, $h );

    # on a staging server send emails to ourselves rather than the councils
    if (mySociety::Config::get('STAGING_SITE') && !FixMyStreet->test_mode) {
        @recips = ( mySociety::Config::get('CONTACT_EMAIL') );
    }

    unless ( @recips ) {
        $self->error( 'No recipients' );
        return 1;
    }

    my ($verbose, $nomail) = CronFns::options();
    my $result = FixMyStreet::App->send_email_cron(
        {
            _template_ => $self->get_template( $row ),
            _parameters_ => $h,
            To => $self->to,
            From => [ $row->user->email, $row->name ],
        },
        mySociety::Config::get('CONTACT_EMAIL'),
        \@recips,
        $nomail
    );

    if ( $result == mySociety::EmailUtil::EMAIL_SUCCESS ) {
        $self->success(1);
    } else {
        $self->error( 'Failed to send email' );
    }

    return $result;
}

# Essex has different contact addresses depending upon the district
# Might be easier if we start storing in the db all areas covered by a point
# Will do for now :)
sub essex_contact {
    my $district = _get_district_for_contact(@_);
    my $email;
    $email = 'eastarea' if $district == 2315 || $district == 2312;
    $email = 'midarea' if $district == 2317 || $district == 2314 || $district == 2316;
    $email = 'southarea' if $district == 2319 || $district == 2320 || $district == 2310;
    $email = 'westarea' if $district == 2309 || $district == 2311 || $district == 2318 || $district == 2313;
    die "Returned district $district which is not in Essex!" unless $email;
    return "highways.$email\@essexcc.gov.uk";
}

# Oxfordshire has different contact addresses depending upon the district
sub oxfordshire_contact {
    my $district = _get_district_for_contact(@_);
    my $email;
    $email = 'northernarea' if $district == 2419 || $district == 2420 || $district == 2421;
    $email = 'southernarea' if $district == 2417 || $district == 2418;
    die "Returned district $district which is not in Oxfordshire!" unless $email;
    return "$email\@oxfordshire.gov.uk";
}

sub _get_district_for_contact {
    my ( $lat, $lon ) = @_;
    my $district =
      mySociety::MaPit::call( 'point', "4326/$lon,$lat", type => 'DIS' );
    ($district) = keys %$district;
    return $district;
}
1;
