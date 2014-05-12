use strict; use warnings;
use Test::More;
use Plack::Test;
use Plack::App::WrapCGI;
use HTTP::Request::Common;
use DateTime;

use FindBin;

{
    $INC{"DBI.pm"} = 'DUMMY';
    $INC{"DBD/Oracle.pm"} = 'DUMMY';
    package DBD::Oracle;

    sub import {
        warn "RARR";
    }

    package DBI;
    use Test::MockObject;
    use Test::More;

    my @sth;
    sub mock_sth {
        my ($class, %params) = @_;

        my $sth = Test::MockObject->new({ 
            re        => $params{re}  || qr/.*/,
            param_out => $params{out} || {},
            param_in  => $params{in} || {},
        });
        $sth->mock( bind_param => sub {
            my ($self, $name, @data) = @_;
            $self->{bind_in}{$name} = \@data;
        });
        $sth->mock( bind_param_inout => sub {
            my ($self, $name, $ref, @data) = @_;
            $$ref = $self->{param_out}->{$name};
            $self->{bind_out}{$name} = \@data;
        });
        $sth->mock( execute => sub {
            my $self = shift;
            is_deeply $self->{bind_in}, $self->{param_in}, 'Bind vars correct';
        });
        push @sth, $sth;
    }

    sub connect {
        my $dbh = Test::MockObject->new();
        $dbh->mock(prepare => sub {
            my ($self, $statement) = @_;
            my $sth = shift @sth;
            $sth->{statement} = $statement;
            like $statement, $sth->{re}, "Statement matches regex";
            $sth;
        });
        $dbh->mock(disconnect => sub {});
    }
}

subtest 'post a request' => sub {
    my $app = Plack::App::WrapCGI->new(
        script => "$FindBin::Bin/../../bin/oxfordshire/open311_service_request.cgi"
    )->to_app;

    my $test = Plack::Test->create( $app );
    my $req = POST '/', [
            'account_id'=> 1000,
            'address_id'=> 1234,
            'address_string'=> '22 Acacia Avenue',
            'api_key'=> 'superseekrit',
            'attribute[closest_address]'=> '22 Acacia Avenue',
            'description'=> 'Enormous pothole',
            'device_id'=> 100,
            'attribute[easting]'=> 100,
            'email'=> 'hakim@mysociety.org',
            'first_name'=> 'Hakim',
            'attribute[external_id]'=> 500,
            'last_name'=> 'Cassimally',
            'lat'=> 100,
            'long'=> 100,
            'media_url'=> 'http://en.wikipedia.org/wiki/File:Large_pot_hole_on_2nd_Avenue_in_New_York_City.JPG',
            'attribute[northing]'=> 100,
            'phone'=> '01234 567890',
            'requested_datetime'=> DateTime->now->datetime,
            'service_code'=> 123,
            'status'=> 'new',
            ];
    diag $req->as_string;

    DBI->mock_sth(
        in => {
            ':ce_surname' => [ 'CASSIMALLY', 'ORA_VARCHAR2' ],
            ':ce_y' => [ 100, 'ORA_NUMBER' ],
            ':ce_x' => [ 100, 'ORA_NUMBER' ],
            ':ce_work_phone' => [ '01234 567890', 'ORA_VARCHAR2' ],
            ':ce_source' => [ 'FMS', 'ORA_VARCHAR2' ],
            ':ce_contact_type' => [ 'ENQUIRER', 'ORA_VARCHAR2' ],
            ':ce_doc_reference' => [ 500, 'ORA_VARCHAR2' ],
            ':ce_description' => [ 'Enormous pothole  Photo: http://en.wikipedia.org/wiki/File:Large_pot_hole_on_2nd_Avenue_in_New_York_City.JPG', 'ORA_VARCHAR2' ],
            ':ce_email' => [ 'HAKIM@MYSOCIETY.ORG', 'ORA_VARCHAR2' ],
            ':ce_enquiry_type' => [ 123, 'ORA_VARCHAR2' ],
            ':ce_location' => [ '22 Acacia Avenue', 'ORA_VARCHAR2' ],
            ':ce_incident_datetime' => [ '22 Acacia Avenue', 'ORA_VARCHAR2' ],
        },
    );

    my $res = $test->request($req);
    diag $res->content;
};
