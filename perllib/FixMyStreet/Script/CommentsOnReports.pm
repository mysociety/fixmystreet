package FixMyStreet::Script::CommentsOnReports;

use Path::Tiny;
use strict;
use warnings;
use FixMyStreet::DB;
use DateTime;
use FixMyStreet::Email;

sub send {
    my $args = shift;

    my $dir = $args->{dir};
    my $file_name = $args->{file};
    my $file = path($dir)->child($file_name);

    my $body = FixMyStreet::DB->resultset("Body")->search({ name => $args->{council_name} })->first;

    my $parser = FixMyStreet::DB->schema->storage->datetime_parser;
    my $start = $parser->format_datetime(DateTime->today);
    my $end = $parser->format_datetime(DateTime->today->subtract( days => 8));

    my $params = {
                  'me.bodies_str' => $body->id,
                  'me.cobrand_data' => '',
                  'comments.text' => { '!=' => '' },
                  'comments.state' => 'confirmed',
                  '-or' => [
                            'comments.extra' => undef,
                            '-not' => { 'comments.extra' => { '\?' => 'is_body_user'} },
                           ],
                  '-and' => [
                          'comments.confirmed' => { '<' => $start },
                          'comments.confirmed' => { '>' => $end },
                         ],
                 };

    my $rs = FixMyStreet::DB->resultset("Problem")->search( $params, { prefetch => 'comments' } );

    my $handle = $file->openw_utf8;
    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    $csv->print($handle, [ 'URL', 'Category', 'Current report state', 'Commenter name', 'Comment Confirmed', 'Comment text']);

    my @row;
    while (my $report = $rs->next) {
        for my $comment ($report->comments) {
            push @row, 'https://report.brent.gov.uk/report/' . $report->id;
            push @row, $report->category;
            push @row, $report->state;
            push @row, $comment->name;
            push @row, $comment->confirmed;
            push @row, $comment->text;
            $csv->print($handle, \@row);
            @row = ();
        };
    };

    $handle->close;
    my $data = path($dir, $file_name)->slurp_raw;
    my $email_message = $args->{subject} . "\n\n" . $args->{message_body};
    my $headers = { 'To' => $args->{send_to}, 'From' => $args->{send_from}, '_body_' => "Subject: " . $email_message, '_attachments_' => [{
        body => $data,
        attributes => {
            filename => $file_name,
            content_type => 'text/csv',
            encoding => 'base64',
            name => $file_name,
        }}]};

    my $email = FixMyStreet::Email::construct_email($headers);
    my $result = FixMyStreet::Email::Sender->try_to_send($email);
    $file->remove;
}

1;
