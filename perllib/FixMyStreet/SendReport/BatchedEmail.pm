package FixMyStreet::SendReport::BatchedEmail;

use Moose;
use Email::MIME;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

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
    my $incidents_people_count = $incidents->search({}, { group_by => 'user_id' })->count;
    my $misses_people_count = $incidents->search({}, { group_by => 'user_id' })->count;

    my $period = 'month'; # XXX hardcoded for now

    my $vars = {
        period => $period,
        body => $body,
        reports => $rs,
        cobrand => $cobrand,
        incidents => $incidents,
        misses => $misses,
        incidents_people_count => $incidents_people_count,
        misses_people_count => $misses_people_count,
        additional_template_paths => [
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker, $c->stash->{lang_code} )->stringify,
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker )->stringify,
        ]
    };

    my $content = $c->view('Email')->render( $c, 'batched-report.html', $vars );

    my $email = Email::MIME->new($content);
    # NB: using parse here rather than ->create just so we can simply template the subject line.

    $email->header_set(From => mySociety::Config::get('CONTACT_EMAIL'));
    $email->header_set(To => $recipient);
    $email->content_type_set('text/html');

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
