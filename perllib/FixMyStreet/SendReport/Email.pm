package FixMyStreet::SendReport::Email;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    my $all_confirmed = 1;
    foreach my $body ( @{ $self->bodies } ) {

        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            body_id => $body->id,
            category => $row->category
        } );

        my ($body_email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );

        $body_email = essex_contact($row->latitude, $row->longitude) if $body->areas->{2225};
        $body_email = oxfordshire_contact($row->latitude, $row->longitude) if $body->areas->{2237} && $body_email eq 'SPECIAL';

        unless ($confirmed) {
            $all_confirmed = 0;
            $note = 'Body ' . $row->bodies_str . ' deleted'
                unless $note;
            $body_email = 'N/A' unless $body_email;
            $self->unconfirmed_counts->{$body_email}{$row->category}++;
            $self->unconfirmed_notes->{$body_email}{$row->category} = $note;
        }

        my $body_name = $body->name;
        # see something uses council areas but doesn't send to councils so just use a
        # generic name here to minimise confusion
        if ( $row->cobrand eq 'seesomething' ) {
            $body_name = 'See Something, Say Something';
        }

        my @emails;
        # allow multiple emails per contact
        if ( $body_email =~ /,/ ) {
            @emails = split(/,/, $body_email);
        } else {
            @emails = ( $body_email );
        }
        for my $email ( @emails ) {
            push @{ $self->to }, [ $email, $body_name ];
        }
    }

    return $all_confirmed && @{$self->to};
}

sub get_template {
    my ( $self, $row ) = @_;

    my $template = 'submit.txt';

    if ($row->cobrand eq 'fixmystreet') {
        $template = 'submit-oxfordshire.txt' if $row->bodies_str eq 2237;
    }

    $template = FixMyStreet->get_email_template($row->cobrand, $row->lang, $template);
    return $template;
}

sub send_from {
    my ( $self, $row ) = @_;
    return [ $row->user->email, $row->name ];
}

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    my $recips = $self->build_recipient_list( $row, $h );

    # on a staging server send emails to ourselves rather than the bodies
    if (mySociety::Config::get('STAGING_SITE') && !mySociety::Config::get('SEND_REPORTS_ON_STAGING') && !FixMyStreet->test_mode) {
        $recips = 1;
        @{$self->to} = [ $row->user->email, $self->to->[0][1] || $row->name ];
    }

    unless ($recips) {
        $self->error( 'No recipients' );
        return 1;
    }

    my ($verbose, $nomail) = CronFns::options();
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->cobrand)->new();
    my $params = {
        _template_ => $self->get_template( $row ),
        _parameters_ => $h,
        To => $self->to,
        From => $self->send_from( $row ),
    };
    $params->{Bcc} = $self->bcc if @{$self->bcc};
    my $result = FixMyStreet::App->send_email_cron(
        $params,
        mySociety::Config::get('CONTACT_EMAIL'),
        $nomail,
        $cobrand
    );

    unless ($result) {
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
