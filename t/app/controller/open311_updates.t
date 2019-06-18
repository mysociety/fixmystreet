use XML::Simple;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $user = $mech->create_user_ok('commentuser@example.com');
my $body = $mech->create_body_ok(2237, 'Oxfordshire County Council', {
    comment_user => $user,
    api_key => 'sending-key',
    jurisdiction => 'none',
    endpoint => 'endpoint',
});
my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Open311 updates', { external_id => 'p123' });

subtest 'bad requests do not get through' => sub {
    $mech->get('/open311/v2/servicerequestupdates.xml');
    is $mech->response->code, 400, 'Is bad request';
    $mech->content_contains('<description>Bad request: POST</description>');

    $mech->post('/open311/v2/servicerequestupdates.xml');
    is $mech->response->code, 400, 'Is bad request';
    my $xml = _get_xml_object($mech->content);
    is $xml->{error}[0]{description}, 'Bad request: jurisdiction_id';
};

subtest 'cobrand gets jurisdiction, but needs a token' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
    }, sub {
        $mech->post('/open311/v2/servicerequestupdates.xml');
        is $mech->response->code, 400, 'Is bad request';
        my $xml = _get_xml_object($mech->content);
        is $xml->{error}[0]{description}, 'Bad request: api_key';
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
        COBRAND_FEATURES => { open311_token => { oxfordshire => 'wrong-token' } },
    }, sub {
        $mech->post('/open311/v2/servicerequestupdates.xml');
        is $mech->response->code, 400, 'Is bad request';
        my $xml = _get_xml_object($mech->content);
        is $xml->{error}[0]{description}, 'Bad request: api_key';
    };
};

subtest 'With all data, an update is added' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'oxfordshire',
        COBRAND_FEATURES => { open311_token => { oxfordshire => 'receiving-token' } },
    }, sub {
        $mech->post_ok('/open311/v2/servicerequestupdates.xml', {
            api_key => 'receiving-token',
            service_request_id => $problem->external_id,
            update_id => 'c123',
            updated_datetime => $problem->confirmed->clone->add(hours => 2),
            status => 'CLOSED',
            description => 'This report has been fixed',
        });
    };

    $problem->discard_changes;
    is $problem->state, 'fixed - council', 'problem updated';
    is $problem->comments->count, 1, 'One comment created';

    my $comment = $problem->comments->first;
    is $comment->text, 'This report has been fixed', 'correct text';
    is $comment->user_id, $user->id, 'correct user';
    is $comment->problem_state, 'fixed - council', 'correct state';
    is $comment->external_id, 'c123', 'correct external id';

    my $xml = _get_xml_object($mech->content);
    my $response = $xml->{request_update};
    is $response->[0]->{update_id}, $comment->id, 'correct id in response';
};

done_testing();

sub _get_xml_object {
    my ($xml) = @_;

    # Of these, services/service_requests/service_request_updates are root
    # elements, so GroupTags has no effect, but this is used in ForceArray too.
    my $group_tags = {
        services => 'service',
        attributes => 'attribute',
        values => 'value',
        service_requests => 'request',
        errors => 'error',
        service_request_updates => 'request_update',
    };
    my $simple = XML::Simple->new(
        ForceArray => [ values %$group_tags ],
        KeyAttr => {},
        GroupTags => $group_tags,
        SuppressEmpty => undef,
    );
    my $obj = $simple->parse_string($xml);
    return $obj;
}
