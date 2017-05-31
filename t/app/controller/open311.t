use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Check old .cgi links redirect correctly
$mech->get_ok('/open311.cgi/v2/requests.rss?jurisdiction_id=fiksgatami.no&status=open&agency_responsible=1854');
like $mech->uri, qr[/open311/v2/requests\.rss\?.{65}]; # Don't know order parameters will be in now

done_testing();
