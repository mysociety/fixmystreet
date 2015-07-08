package FixMyStreet::SendReport::BatchedEmail;

use Moose;
use Email::MIME;
use LWP::UserAgent;
use URI;
use mySociety::Random qw(random_bytes);

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

has user_agent => (
    is => 'ro',
    lazy => 1,
    default => sub {
        LWP::UserAgent->new();
    },
);

=head1 should_skip

Instead of I<send>ing the reports, we always skip, using C<should_skip>,
just as C<::Noop> does.

=cut

sub should_skip {
    1
}

=head1 send_batch

    $sender->send_batch($c, $body, $recipient, $rs);

=cut

sub send_batch {
    my ($self, $c, $body, $recipient, $rs) = @_;

    my $cobrand = $rs->first->cobrand_object($c);

    # TODO, these should be extracted into Collideoscope specific sender
    my $incidents = $rs->search({ category => { -not_like => '%miss%'} });
    my $misses    = $rs->search({ category => { -like     => '%miss%'} });
    # When getting the counts for the number of people reporting incidents and
    # near-misses, we must consider all anonymous reports to come from
    # different users otherwise it's possible to associate multiple anonymous
    # reports with a single person.
    my $incidents_people_count = $incidents->search({ anonymous => 0 }, { group_by => 'user_id' })->count;
    $incidents_people_count += $incidents->search({ anonymous => 1 })->count;
    my $misses_people_count = $misses->search({ anonymous => 0 }, { group_by => 'user_id' })->count;
    $misses_people_count += $misses->search({ anonymous => 1 })->count;

    my $period = 'month'; # XXX hardcoded for now

    my @latlon = map { sprintf '%0.3f,%0.3f', $_->latitude, $_->longitude } $rs->all;

    my $map_data = do {
        my $url = 'https://maps.googleapis.com/maps/api/staticmap?size=598x300&markers=size:mid|'
            . join '|' => @latlon;
        my $ua = $self->user_agent;
        my $resp = $ua->get($url);
        if ($resp->is_success) {
            $resp->decoded_content;
        }
        else {
            warn sprintf "Error fetching %s (%s)\n", $url, $resp->status_line;
        }
    };

    # TODO refactor ID generation, see also FMS::App
    my $map_cid = $map_data && 
        sprintf('fms-map-%s-%s@%s',
            time(), unpack('h*', random_bytes(5, 1)), $c->config->{EMAIL_DOMAIN});

    my $vars = {
        period => $period,
        body => $body,
        reports => $rs,
        cobrand => $cobrand,
        incidents => $incidents,
        misses => $misses,
        has_map => $map_data ? 1 : 0,
        map_cid => $map_cid,
        incidents_people_count => $incidents_people_count,
        misses_people_count => $misses_people_count,
        additional_template_paths => [
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker, $c->stash->{lang_code} )->stringify,
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker )->stringify,
        ]
    };

    my $content = $c->view('Email')->render( $c, 'batched-report.html', $vars );
    my $text_content = $c->view('Email')->render( $c, 'batched-report.txt', $vars );

    my $html = Email::MIME->new($content);
    # NB: using parse here rather than ->create just so we can simply template the subject line.
    
    $html->content_type_set('text/html');

    if ($map_data) {
        my $map_part = Email::MIME->create(
            body => $map_data,
            attributes => {
                content_type => 'image/gif',
                encoding => 'base64',
                filename => 'map.gif',
                name => 'map.gif',
                content_disposition => 'inline',
            });
        $map_part->header_raw_set('Content-ID' => "<$map_cid>"); # bracketed version in header

        $html->parts_add([ $map_part ]);
    }

    my $text = Email::MIME->create(
        body => $text_content,
        attributes => {
            content_type => 'text/plain',
            encoding => 'quoted-printable',
        },
    );

    my $email = Email::MIME->create(
        attributes => {
            content_type => 'multipart/alternative',
        },
        parts => [ $text, $html ],
    );

    $email->header_set(From => mySociety::Config::get('CONTACT_EMAIL'));
    $email->header_set(To => $recipient);
    $email->header_set(Subject => $html->header('Subject'));

    $c->send_email_simple($email)
        or die "Couldn't send email $email";
}

=head2 build_recipient_list_from_body_category

Simplified, and feature-reduced version of ::Email's C<build_recipient_list>.
We're not currently honouring the 'confirmed' logic.

=cut

sub build_recipient_list_from_body_category {
    my ($self, $body, $category) = @_;

    my $contact = FixMyStreet::App->model("DB::Contact")->find( {
        deleted => 0,
        body_id => $body->id,
        category => $category
    } ) or return;

    my @emails = split /,/ => $contact->email;
    return @emails;
}

1;

__END__
consider following for future?

create table batch (
    id serial not null primary key,
    created timestamp not null default ms_current_timestamp(),
    body_id int references body(id) not null,
    embargo_date timestamp not null,
);

create table batched_report (
    id serial not null primary key,
    batch_id int references batch ON DELETE CASCADE not null,
    problem_id int references problem(id) ON DELETE CASCADE not null
);
