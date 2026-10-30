package FixMyStreet::Script::UsersInRoleAndBoundary;

use Path::Tiny;
use FixMyStreet::Reporting;
use FixMyStreet::Cobrand;
use strict;
use warnings;

sub send {
    my $args = shift;

    my $dir = $args->{dir};
    my $file_name = $args->{file};
    my $geo_file_name = $args->{geo_file};
    my $out = FixMyStreet->path_to($dir, $file_name);

    my $body = FixMyStreet::DB->resultset("Body")->search({ name => $args->{council_name} })->first;
    my $role = FixMyStreet::DB->resultset("Role")->search({ body_id => $body->id, name => $args->{role_name} })->single;
    my $user_roles = FixMyStreet::DB->resultset("UserRole")->search({ role_id => $role->id });

    my $params = {
        bodies_str => $body->id,
        user_id => [ $user_roles->get_column('user_id')->all ],
    };

    my $geofile = path($dir, $geo_file_name)->slurp_raw;

    my $coord = 'ST_SetSRID(ST_Point(longitude, latitude), 4326)::geography';
    my $area = 'ST_GeomFromText(?, 4326)::geography';
    push @{$params->{'-and'}}, \[ "ST_CoveredBy( $coord, $area )", $geofile ];

    my $problems = FixMyStreet::DB->resultset("Problem")->search( $params )->order_by('id');

    my $cobrand = $body->get_cobrand_handler;
    $cobrand->set_lang_and_domain('en-gb', 1);
    FixMyStreet::DB->schema->cobrand($cobrand);

    my $reporting = FixMyStreet::Reporting->new({body => $body, type => 'problems'});

    $reporting->_set_objects_rs($problems);
    $reporting->_set_csv_headers($reporting->_default_headers('group'));
    $reporting->_set_csv_columns($reporting->_default_columns('group'));
    $reporting->csv_extra_data($cobrand->dashboard_export_problems_add_columns($reporting));

    my $file = path("$out");
    my $handle = $file->openw_utf8;

    $reporting->generate_csv($handle);
    $handle->close;

    my $data = path($dir, $file_name)->slurp_raw;
    my $headers = { 'To' => $args->{send_to}, 'From' => $args->{send_from}, '_body_' => "Subject: " . $args->{subject_body}, '_attachments_' => [{
        body => $data,
        attributes => {
            filename => $file_name,
            content_type => 'text/csv',
            encoding => 'base64',
            name => $file_name,
        }}]};

    my $email = FixMyStreet::Email::construct_email($headers);
    my $result = FixMyStreet::Email::Sender->try_to_send($email);
    path("$out")->remove;
}

1;
