package FixMyStreet::Script::UpdateAllReports;

use strict;
use warnings;

use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use CronFns;

use List::MoreUtils qw(zip);
use List::Util qw(sum);

my $site = CronFns::site(FixMyStreet->config('BASE_URL'));

my $fourweeks = 4*7*24*60*60;

# Age problems from when they're confirmed, except on Zurich
# where they appear as soon as they're created.
my $age_column = 'confirmed';
$age_column = 'created' if $site eq 'zurich';

my $dtf = FixMyStreet::DB->schema->storage->datetime_parser;

my $cobrand_cls = FixMyStreet::Cobrand->get_class_for_moniker($site)->new;
FixMyStreet::DB->schema->cobrand($cobrand_cls);

sub generate {
    my $include_areas = shift;

    my $problems = FixMyStreet::DB->resultset('Problem')->search(
        {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            bodies_str => \'is not null',
        },
        {
            columns => [
                'id', 'bodies_str', 'state', 'areas', 'cobrand', 'category',
                { duration => { extract => \"epoch from current_timestamp-lastupdate" } },
                { age      => { extract => \"epoch from current_timestamp-$age_column"  } },
            ]
        }
    );
    $problems = $problems->cursor; # Raw DB cursor for speed

    my ( %fixed, %open );
    my %stats = (
        fixed => \%fixed,
        open => \%open,
    );
    my @cols = ( 'id', 'bodies_str', 'state', 'areas', 'cobrand', 'category', 'duration', 'age' );
    while ( my @problem = $problems->next ) {
        my %problem = zip @cols, @problem;
        my @bodies = split( /,/, $problem{bodies_str} );
        my $cobrand = $problem{cobrand};

        if (my $type = $cobrand_cls->call_hook(dashboard_categorize_problem => \%problem)) {
            foreach my $body ( @bodies ) {
                $stats{$type}{$body}++;
                $stats{$cobrand}{$type}{$body}++;
            }
            next;
        }

        my $duration_str = ( $problem{duration} > 2 * $fourweeks ) ? 'old' : 'new';

        my $type = ( $problem{duration} > 2 * $fourweeks )
            ? 'unknown'
            : ($problem{age} > $fourweeks ? 'older' : 'new');
        my $problem_fixed =
               FixMyStreet::DB::Result::Problem->fixed_states()->{$problem{state}}
            || FixMyStreet::DB::Result::Problem->closed_states()->{$problem{state}};

        foreach my $body ( @bodies ) {
            if ( $problem_fixed ) {
                # Fixed problems are either old or new
                $fixed{$body}{$duration_str}++;
                $fixed{$cobrand}{$body}{$duration_str}++;
            } else {
                # Open problems are either unknown, older, or new
                $open{$body}{$type}++;
                $open{$cobrand}{$body}{$type}++;
            }
        }

        if ( $include_areas ) {
            my @areas = grep { $_ } split( /,/, $problem{areas} );
            foreach my $area ( @areas ) {
                if ( $problem_fixed ) {
                    $fixed{areas}{$area}{$duration_str}++;
                } else {
                    $open{areas}{$area}{$type}++;
                }
            }
        }
    }

    return \%stats;
}

sub end_period {
    my ($period, $end) = @_;
    $end ||= DateTime->now;
    FixMyStreet->set_time_zone($end)->truncate(to => $period)->add($period . 's' => 1)->subtract(seconds => 1);
}

sub loop_period {
    my ($date, $extra, $period, $end) = @_;
    $end = end_period($period, $end);
    my @out;
    while ($date <= $end) {
        push @out, { n => $date->$period, $extra ? (d => $date->$extra) : () };
        $date->add($period . 's' => 1);
    }
    return @out;
}

sub get_period_group {
    my ($start, $end) = @_;
    my ($group_by, $extra);
    if (DateTime::Duration->compare($end - $start, DateTime::Duration->new(months => 1)) < 0) {
        $group_by = 'day';
    } elsif (DateTime::Duration->compare($end - $start, DateTime::Duration->new(years => 1)) < 0) {
        $group_by = 'month';
        $extra = 'month_abbr';
    } else {
        $group_by = 'year';
    }

    return ($group_by, $extra);
}

sub generate_dashboard {
    my $body = shift;

    my %data;

    my $rs = FixMyStreet::DB->resultset('Problem');
    $rs = $rs->to_body($body) if $body;

    my $rs_c = FixMyStreet::DB->resultset('Comment');
    $rs_c = $rs_c->to_body($body) if $body;

    my $end_today = end_period('day');
    my $min_confirmed = $rs->search({
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
    }, {
        select => [ { min => 'confirmed' } ],
        as => [ 'confirmed' ],
    })->first->confirmed;
    if ($min_confirmed) {
        $min_confirmed = $min_confirmed->truncate(to => 'day');
    } else {
        $min_confirmed = FixMyStreet->set_time_zone(DateTime->now)->truncate(to => 'day');
    }

    my ($group_by, $extra) = get_period_group($min_confirmed, $end_today);
    my @problem_periods = loop_period($min_confirmed, $extra, $group_by);

    my %problems_reported_by_period = stuff_by_day_or_year(
        $group_by, $rs,
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
    );
    my %problems_fixed_by_period = stuff_by_day_or_year(
        $group_by, $rs,
        state => [ FixMyStreet::DB::Result::Problem->fixed_states() ],
    );

    my (@problems_reported_by_period, @problems_fixed_by_period);
    foreach (map { $_->{n} } @problem_periods) {
        push @problems_reported_by_period, ($problems_reported_by_period[-1]||0) + ($problems_reported_by_period{$_}||0);
        push @problems_fixed_by_period, ($problems_fixed_by_period[-1]||0) + ($problems_fixed_by_period{$_}||0);
    }
    $data{problem_periods} = [ map { $_->{d} || $_->{n} } @problem_periods ];
    $data{problems_reported_by_period} = \@problems_reported_by_period;
    $data{problems_fixed_by_period} = \@problems_fixed_by_period;

    my %last_seven_days = (
        problems => [],
        updated => [],
        fixed => [],
    );
    $data{last_seven_days} = \%last_seven_days;

    my $eight_ago = $dtf->format_datetime(DateTime->now->subtract(days => 8));
    %problems_reported_by_period = stuff_by_day_or_year('day',
        $rs,
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        'me.confirmed' => { '>=', $eight_ago },
    );
    %problems_fixed_by_period = stuff_by_day_or_year('day',
        $rs_c,
        'me.confirmed' => { '>=', $eight_ago },
        -or => [
            problem_state => [ FixMyStreet::DB::Result::Problem->fixed_states() ],
            mark_fixed => 1,
        ],
    );
    my %problems_updated_by_period = stuff_by_day_or_year('day',
        $rs_c,
        'me.confirmed' => { '>=', $eight_ago },
    );

    my $date = DateTime->today->subtract(days => 7);
    while ($date < DateTime->today) {
        push @{$last_seven_days{problems}}, $problems_reported_by_period{$date->day} || 0;
        push @{$last_seven_days{fixed}}, $problems_fixed_by_period{$date->day} || 0;
        push @{$last_seven_days{updated}}, $problems_updated_by_period{$date->day} || 0;
        $date->add(days => 1);
    }
    $last_seven_days{problems_total} = sum @{$last_seven_days{problems}};
    $last_seven_days{fixed_total} = sum @{$last_seven_days{fixed}};
    $last_seven_days{updated_total} = sum @{$last_seven_days{updated}};

    if ($body) {
        calculate_top_five_wards(\%data, $rs, $body);
    } else {
        calculate_top_five_bodies(\%data);
    }

    my $week_ago = $dtf->format_datetime(DateTime->now->subtract(days => 7));
    my $last_seven_days = $rs->search({
        confirmed => { '>=', $week_ago },
    })->count;
    my @top_five_categories = $rs->search({
        confirmed => { '>=', $week_ago },
        category => { '!=', 'Other' },
    }, {
        select => [ 'category', { count => 'id' } ],
        as => [ 'category', 'count' ],
        group_by => 'category',
        rows => 5,
        order_by => { -desc => 'count' },
    });
    $data{top_five_categories} = [ map {
        { category => $_->category, count => $_->get_column('count') }
        } @top_five_categories ];
    foreach (@top_five_categories) {
        $last_seven_days -= $_->get_column('count');
    }
    $data{other_categories} = $last_seven_days;

    return \%data;
}

sub stuff_by_day_or_year {
    my $period = shift;
    my $rs = shift;
    my %params = @_;
    my $results = $rs->search({
        %params
    }, {
        select => [ { extract => \"$period from me.confirmed", -as => $period }, { count => 'me.id' } ],
        as => [ $period, 'count' ],
        group_by => [ $period ],
    });
    my %out;
    while (my $row = $results->next) {
        my $p = $row->get_column($period);
        $out{$p} = $row->get_column('count');
    }
    return %out;
}

sub calculate_top_five_bodies {
    my ($data) = @_;

    my(@top_five_bodies);

    my $bodies = FixMyStreet::DB->resultset('Body')->search;
    while (my $body = $bodies->next) {
        my $avg = $body->calculate_average($cobrand_cls->call_hook("body_responsiveness_threshold"));
        push @top_five_bodies, { name => $body->name, days => int($avg / 60 / 60 / 24 + 0.5) }
            if defined $avg;
    }
    @top_five_bodies = sort { $a->{days} <=> $b->{days} } @top_five_bodies;
    $data->{average} = @top_five_bodies
        ? int((sum map { $_->{days} } @top_five_bodies) / @top_five_bodies + 0.5) : undef;

    @top_five_bodies = @top_five_bodies[0..4] if @top_five_bodies > 5;
    $data->{top_five_bodies} = \@top_five_bodies;
}

sub calculate_top_five_wards {
    my ($data, $rs, $body) = @_;

    my $children = $body->first_area_children;
    die $children->{error} if $children->{error};

    my $week_ago = $dtf->format_datetime(DateTime->now->subtract(days => 7));
    my $last_seven_days = $rs->search({ confirmed => { '>=', $week_ago } });
    my $last_seven_days_count = $last_seven_days->count;
    $last_seven_days = $last_seven_days->search(undef, { select => 'areas' });

    while (my $row = $last_seven_days->next) {
        $children->{$_}{reports}++ foreach grep { $children->{$_} } split /,/, $row->areas;
    }
    my @wards = sort { $b->{reports} <=> $a->{reports} } grep { $_->{reports} } values %$children;
    @wards = @wards[0..4] if @wards > 5;

    my $sum_five = (sum map { $_->{reports} } @wards) || 0;
    $data->{other_wards} = $last_seven_days_count - $sum_five;
    $data->{wards} = \@wards;
}

1;
