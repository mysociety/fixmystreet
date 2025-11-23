use Test::More;
use LWP::UserAgent;
use HTTP::Request;
use JSON::MaybeXS;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $comment_user = $mech->create_user_ok('comment@example.org', email_verified => 1, name => 'Brent');
my $brent = $mech->create_body_ok( 2483, 'Brent Council', { cobrand => 'brent', comment_user_id => $comment_user->id });

my $camden = $mech->create_body_ok( 2505, 'Camden Council', { cobrand => 'camden', comment_user_id => $comment_user->id });

my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'New Problem');
my ($camden_problem) = $mech->create_problems_for_body(1, $camden->id, 'Camden Problem');

subtest 'Authentication' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['brent'],
        COBRAND_FEATURES => {
            MSS_api_details => {
                brent => {
                    username => 'mss',
                    password => 'secret',
                }
            }
        }
    }, sub {
        for my $test (
            {
                header => {'Content-Type' => 'application/json; charset=UTF-8', 'username' => 'ms', 'password' => 'secret'},
                text => 'wrong username'
            },
            {
                header => {'Content-Type' => 'application/json; charset=UTF-8', 'username' => 'mss', 'password' => 'secrett'},
                text => 'wrong password'
            },
        ) {
            $mech->add_header( %{$test->{header}} );
            $mech->post('http://localhost/api/mss/update/brent', Content => _json_data('good data'));
            is $mech->res->code, 401, 'Unauthorised for ' . $test->{text};
        };
    };
};

subtest 'Bad data' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['brent'],
        COBRAND_FEATURES => {
            MSS_api_details => {
                brent => {
                    username => 'mss',
                    password => 'secret',
                    update_status_mapping => {
                        'Closed - Completed' => 'fixed',
                    },
                }
            }
        }
    }, sub {
        $mech->add_header('Content-Type' => 'application/json; charset=UTF-8', 'username' => 'mss', 'password' => 'secret');
        $mech->post('http://localhost/api/mss/update/brent');
        is $mech->res->code, 406, 'Not acceptable response for no body';
        $mech->post('http://localhost/api/mss/update/brent', Content => '');
        is $mech->res->code, 406, 'Not acceptable response for empty body';
        $mech->post('http://localhost/api/mss/update/brent', Content => '{}');
        is $mech->res->code, 400, 'Bad request response for json in wrong format';
        for my $test (
            'extra field', 'malformed date', 'string for id', 'unmapped external status code',
            'empty update id'
        ) {
            $mech->post('http://localhost/api/mss/update/brent', Content => _json_data($test));
            is $mech->res->code, 400, "Bad request response for " . $test;
        }
    };
};

subtest 'Good data' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => ['brent'],
        COBRAND_FEATURES => {
            MSS_api_details => {
                brent => {
                    username => 'mss',
                    password => 'secret',
                    update_status_mapping => {
                        'Closed - Completed' => 'fixed',
                    },
                }
            }
        }
    }, sub {
        $mech->add_header('Content-Type' => 'application/json; charset=UTF-8', 'username' => 'mss', 'password' => 'secret');
        $mech->post('http://localhost/api/mss/update/brent', Content => '{"updates": []}');
        is $mech->res->code, 200, "Successful post with no updates";
        $mech->post('http://localhost/api/mss/update/brent', Content => _json_data('good data'));
        is $mech->res->code, 200, "Successful post with update";
        my $comment = $problem->comments->search()->first;
        is $comment->text, 'This has been fixed', 'Comment added to report';
        is $comment->state, 'confirmed', 'Comment confirmed';
        is $comment->get_extra_metadata('external_status_code'), 'Closed - Completed', 'Comment metadata added';
        $problem->discard_changes;
        is $problem->state, 'fixed - council', 'Report updated by comment';
        $mech->post('http://localhost/api/mss/update/brent', Content => _json_data('camden report'));
        is $mech->res->code, 200, "Successful post for wrong FMS ID";
        $comment = $camden_problem->comments->search()->first;
        is $comment, undef, "Comment not added to Camden report";
        $camden_problem->discard_changes;
        is $camden_problem->state, 'confirmed', "Camden report state unchanged";
    };
};


sub _json_data {
    my $choice = shift;

    my %json_data = (
        'good data' => {
            updates => [
                {
                    description  => 'This has been fixed',
                    update_id => 'brent-1',
                    external_status_code => 'Closed - Completed',
                    fixmystreet_id => $problem->id,
                    updated_datetime => '2025-09-03T10:00:00'
                }
            ]
        },
    );

    my $data = $json_data{'good data'};

    if ($choice eq 'extra field') {
        $data->{updates}->[0]->{unexpected_field} = 'Unexpected field';
    } elsif ($choice eq 'malformed date') {
        $data->{updates}->[0]->{updated_datetime} = '2025-09-03T10:00:0';
    } elsif ($choice eq 'string for id') {
        $data->{updates}->[0]->{fixmystreet_id} = 'FMS-1';
    } elsif ($choice eq 'unmapped external status code') {
        $data->{updates}->[0]->{external_status_code} = 'Closed - Unknown';
    } elsif ($choice eq 'empty update id') {
        $data->{updates}->[0]->{update_id} = '';
    } elsif ($choice eq 'camden report') {
        $data->{updates}->[0]->{fixmystreet_id} = $camden_problem->id;
    };

    return encode_json($data);
}

done_testing;
