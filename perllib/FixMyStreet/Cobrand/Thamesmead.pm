package FixMyStreet::Cobrand::Thamesmead;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub council_area { return 'Thamesmead'; }
sub council_name { return 'Thamesmead'; }
sub council_url { return 'thamesmead'; }

sub admin_user_domain { ( 'thamesmeadnow.org.uk', 'peabody.org.uk' ) }

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->get_column('name') eq 'Thamesmead';
}

sub cut_off_date { '2022-04-25' }
sub problems_restriction { FixMyStreet::Cobrand::UKCouncils::problems_restriction($_[0], $_[1]) }
sub problems_on_map_restriction { $_[0]->problems_restriction($_[1]) }
sub problems_sql_restriction { FixMyStreet::Cobrand::UKCouncils::problems_sql_restriction($_[0], $_[1]) }
sub users_restriction { FixMyStreet::Cobrand::UKCouncils::users_restriction($_[0], $_[1]) }
sub updates_restriction { FixMyStreet::Cobrand::UKCouncils::updates_restriction($_[0], $_[1]) }
sub site_key { FixMyStreet::Cobrand::UKCouncils::site_key($_[0], $_[1]) }
sub all_reports_single_body { FixMyStreet::Cobrand::UKCouncils::all_reports_single_body($_[0], $_[1]) }
sub suggest_duplicates { FixMyStreet::Cobrand::UKCouncils::suggest_duplicates($_[0]) }
sub relative_url_for_report { FixMyStreet::Cobrand::UKCouncils::relative_url_for_report($_[0], $_[1]) }
sub owns_problem { FixMyStreet::Cobrand::UKCouncils::owns_problem($_[0], $_[1]) }
sub base_url { FixMyStreet::Cobrand::UKCouncils::base_url($_[0]) }

sub contact_email {
    my $self = shift;
    return $self->feature('contact_email');
};

sub default_map_zoom { 6 }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _("Enter the road name, postcode or the area closest to the problem");
}

sub example_places {
    return [ 'Glendale Way', 'Manorway Green' ];
}

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;

    FixMyStreet::Cobrand::UKCouncils::munge_report_new_bodies($_[0], $_[1])
}

sub munge_report_new_contacts { FixMyStreet::Cobrand::UKCouncils::munge_report_new_contacts($_[0], $_[1]) }

sub privacy_policy_url {
    'https://www.thamesmeadnow.org.uk/terms-and-conditions/privacy-statement/'
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $results = {
        %{ $self->SUPER::disambiguate_location() },
        bounds => [ 51.49, 0.075, 51.514, 0.155 ],
        string => $string,
        result_only_if => 'Greenwich|Bexley|Thamesmead',
        result_strip => ', London, Greater London, England',
    };

    return $results;
}

my @categories = qw( blockbuildings hardsurfaces grass water treegroups planting );
my %category_titles = (
    blockbuildings => 'Caretaker defects (staff only)',
    hardsurfaces => 'Hard surfaces/paths/road (Peabody)',
    grass => 'Grass and grass areas (Peabody)',
    water => 'Water areas (Peabody)',
    treegroups => 'Trees (Peabody)',
    planting => 'Planters and flower beds (Peabody)',
);
my %cat_idx = map { $categories[$_] => $_ } 0..$#categories;

sub area_type_for_point {
    my ( $self ) = @_;

    my ($x, $y) = Utils::convert_latlon_to_en(
        $self->{c}->stash->{latitude},
        $self->{c}->stash->{longitude},
        'G'
    );

    my $filter = "(<Filter><Contains><PropertyName>Extent</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>)";
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my $cfg = {
        url => "https://$host/mapserver/thamesmead",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => join(',', @categories),
        filter => $filter x 6,
        outputformat => "GML3",
    };

    my $features = FixMyStreet::Cobrand::UKCouncils->new->_fetch_features($cfg, $x, $y, 'xml');
    # Want the feature in the 'highest' category
    my @sort;
    foreach (@$features) {
        my $type = (keys %$_)[0];
        $type =~ s/ms://;
        push @sort, [ $cat_idx{$type}, $type ];
    }
    @sort = sort { $b->[0] <=> $a->[0] } @sort;
    return $sort[0][1];
}

sub munge_thamesmead_body {
    my ($self, $bodies) = @_;

    if ( my $category = $self->area_type_for_point ) {
        $self->{c}->stash->{'thamesmead_category'} = $category;
        %$bodies = map { $_->id => $_ } grep { $_->get_column('name') eq 'Thamesmead' } values %$bodies;
    } else {
        $self->{c}->stash->{'thamesmead_category'} = '';
        %$bodies = map { $_->id => $_ } grep { $_->get_column('name') ne 'Thamesmead' } values %$bodies;
    }
}

sub munge_categories {
    my ($self, $categories) = @_;

    if ($self->{c}->stash->{'thamesmead_category'}) {
        $self->{c}->stash->{'preselected_categories'} = { 'category' => $category_titles{ $self->{c}->stash->{'thamesmead_category'} }, 'subcategory' => '' };
    }
}

1;
