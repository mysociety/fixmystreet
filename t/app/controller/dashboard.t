use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;

my $mech = FixMyStreet::TestMech->new;

my $test_user = 'council_user@example.com';
my $test_pass = 'password';
my $test_council = 2651;

$mech->delete_user( $test_user );
my $user = FixMyStreet::App->model('DB::User')->create( {
    email => $test_user,
    password => $test_pass,
} );

$mech->not_logged_in_ok;
$mech->get_ok('/dashboard');

$mech->content_contains( 'sign in' );

$mech->submit_form(
    with_fields => { email => $test_user, password_sign_in => $test_pass }
);

is $mech->status, '404', 'If not council user get 404';

$user->from_council( $test_council );
$user->update;

$mech->log_out_ok;
$mech->get_ok('/dashboard');
$mech->submit_form_ok( {
    with_fields => { email => $test_user, password_sign_in => $test_pass }
} );

$mech->content_contains( 'Summary Statistics for City of Edinburgh' );

FixMyStreet::App->model('DB::Contact')->search( { area_id => $test_council } )
  ->delete;

my $eight_weeks_ago = DateTime->now->subtract( weeks => 8 );

FixMyStreet::App->model('DB::Problem')->search( { council => $test_council } )
  ->update( { confirmed => $eight_weeks_ago } );

my @cats = qw( Grafitti Litter Potholes );
for my $contact ( @cats ) {
    FixMyStreet::App->model('DB::Contact')->create(
        {
            area_id    => $test_council,
            category   => $contact,
            email      => "$contact\@example.org",
            confirmed  => 1,
            whenedited => DateTime->now,
            deleted    => 0,
            editor     => 'test',
            note       => 'test',
        }
    );
}

$mech->get_ok('/dashboard');

my $categories = scraper {
    process "select[name=category] > option", 'cats[]' => 'TEXT',
    process "select[name=ward] > option", 'wards[]' => 'TEXT',
    process "table[id=overview] > tr", 'rows[]' => scraper {
        process 'td', 'cols[]' => 'TEXT'
    }
};

my $expected_cats = [ 'All', '-- Pick a category --', @cats, 'Other' ];
my $res = $categories->scrape( $mech->content );
is_deeply( $res->{cats}, $expected_cats, 'correct list of categories' );

foreach my $row ( @{ $res->{rows} }[1 .. 11] ) {
    foreach my $col ( @{ $row->{cols} } ) {
        is $col, 0;
    }
}

done_testing;
