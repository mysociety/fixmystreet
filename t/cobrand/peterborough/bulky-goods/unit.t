use Test::Fatal;
use Test::MockModule;
use Test::MockObject;
use Test::MockTime 'set_fixed_time';
use Test::More;
use DateTime;
use DateTime::Format::Strptime;
use FixMyStreet::TestMech;
use FixMyStreet::Cobrand::Peterborough;
use Catalyst::Plugin::FixMyStreet::Session::WasteCache;

subtest '_bulky_collection_window' => sub {
    my $mock_pbro = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
    $mock_pbro->mock(
        'bulky_cancellation_cutoff_time', sub {
            { hours => 15, minutes => 15 }
        },
    );
    set_fixed_time('2021-12-31T15:00:00Z');
    is_deeply(
        FixMyStreet::Cobrand::Peterborough->_bulky_collection_window(),
        {   date_from => '2022-01-01',
            date_to   => '2022-02-26',
        },
        'before cutoff time',
    );
    set_fixed_time('2021-12-31T15:15:00Z');
    is_deeply(
        FixMyStreet::Cobrand::Peterborough->_bulky_collection_window(),
        {   date_from => '2022-01-02',
            date_to   => '2022-02-26',
        },
        'at cutoff time',
    );
    set_fixed_time('2021-12-31T16:00:00Z');
    is_deeply(
        FixMyStreet::Cobrand::Peterborough->_bulky_collection_window(),
        {   date_from => '2022-01-02',
            date_to   => '2022-02-26',
        },
        'greater than cutoff hours, less than cutoff minutes',
    );
};

subtest 'find_available_bulky_slots' => sub {
    my $dummy_property = { uprn => 123456789 };
    my $mock_bartec    = Test::MockModule->new('Integrations::Bartec');
    $mock_bartec->mock(
        'WorkPacks_Get',
        sub {
            my ( undef, %args ) = @_;
            my $wp = _workpacks_by_date()->{ $args{date_from} };
            return $wp ? $wp : _workpacks_by_date()->{ $args{date_to} };
        },
    );
    $mock_bartec->mock(
        'Jobs_Get_for_workpack',
        sub {
            my ( undef, $workpack_id ) = @_;
            return _jobs_by_workpack_id()->{$workpack_id};
        },
    );

    my $mech = FixMyStreet::TestMech->new;
    my $body = $mech->create_body_ok(2566, 'Peterborough City Council', {}, { cobrand => 'peterborough', wasteworks_config => { daily_slots => 40 } });
    my $cobrand = FixMyStreet::Cobrand::Peterborough->new;
    $cobrand->{c} = Test::MockObject->new;
    my %session_hash;
    $cobrand->{c}->mock( waste_cache_get => sub {
        Catalyst::Plugin::FixMyStreet::Session::WasteCache::waste_cache_get(@_);
    });
    $cobrand->{c}->mock( waste_cache_set => sub {
        Catalyst::Plugin::FixMyStreet::Session::WasteCache::waste_cache_set(@_);
    });
    $cobrand->{c}->mock( session => sub { \%session_hash } );
    $cobrand->{c}->mock( stash => sub { {} } );

    $mock_bartec->mock( 'Premises_FutureWorkpacks_Get', &_future_workpacks );
    is_deeply(
        $cobrand->find_available_bulky_slots($dummy_property),
        [   {   date        => '2022-08-05T00:00:00',
                workpack_id => 75474,
            },
            {   date        => '2022-09-02T00:00:00',
                workpack_id => 75496,
            },
        ],
    );

    my $start_date = '2022-09-17';
    $mock_bartec->mock( 'Premises_FutureWorkpacks_Get',
        &_future_workpacks($start_date) );
    is_deeply(
        $cobrand->find_available_bulky_slots( $dummy_property, $start_date ),
        [   {   date        => '2022-09-23T00:00:00',
                workpack_id => 75499,
            },
            {   date        => '2022-09-30T00:00:00',
                workpack_id => 75500,
            },
            {   date        => '2022-10-07T00:00:00',
                workpack_id => 75600,
            },
            {   date        => '2022-10-08T00:00:00',
                workpack_id => 75800,
            },
            {   date        => '2022-10-09T00:00:00',
                workpack_id => 75900,
            },
        ],
    );

    is_deeply(
        [ sort keys %{$session_hash{waste}} ],
        [   'peterborough:bartec:available_bulky_slots:earlier:123456789',
            'peterborough:bartec:available_bulky_slots:later:123456789',
        ],
        'cache keys should be set',
    );

    %session_hash = ();
    like(
        exception {
            $cobrand->find_available_bulky_slots( $dummy_property,
                '17-09-22' )
        },
        qr/Invalid date provided/,
    );
};

# For Premises_FutureWorkpacks_Get() calls
sub _future_workpacks {
    my $start_date = shift;
    my $fw         = [
        # No black bin - ignored
        {   'id'           => 57127,
            'WorkPackDate' => '2022-07-29T00:00:00',
            'WorkPackName' => 'Waste-Round 2 Garden-290722',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Brown' } },
        },

        {   'id'           => 75474,
            'WorkPackDate' => '2022-08-05T00:00:00',
            'WorkPackName' => 'Waste-Round 16-050822',
            'Actions'      => {
                'Action' => [
                    { 'ActionName' => 'Empty 1100l Refuse' },
                    { 'ActionName' => 'Empty Bin 240L Black' }
                ],
            },
        },

        {   'id'           => 75481,
            'WorkPackDate' => '2022-08-12T00:00:00',
            'WorkPackName' => 'Waste-Round 16-120822',
            'Actions'      => [
                { 'ActionName' => 'Empty 1100l Refuse' },
                { 'ActionName' => 'Empty Bin 240L Black' }
            ],
        },

        {   'id'           => 75488,
            'WorkPackDate' => '2022-08-19T00:00:00',
            'WorkPackName' => 'Waste-Round 16-190822',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75495,
            'WorkPackDate' => '2022-08-26T23:59:59',
            'WorkPackName' => 'Waste-Round 16-260822',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75496,
            'WorkPackDate' => '2022-09-02T00:00:00',
            'WorkPackName' => 'Waste-Round 16-020922',
            'Actions'      => { 'ActionName' => 'Empty Bin 240L Black' },
        },

        {   'id'           => 75497,
            'WorkPackDate' => '2022-09-09T00:00:00',
            'WorkPackName' => 'Waste-Round 16-090922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75498,
            'WorkPackDate' => '2022-09-16T00:00:00',
            'WorkPackName' => 'Waste-Round 16-160922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75499,
            'WorkPackDate' => '2022-09-23T00:00:00',
            'WorkPackName' => 'Waste-Round 16-230922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        {   'id'           => 75500,
            'WorkPackDate' => '2022-09-30T00:00:00',
            'WorkPackName' => 'Waste-Round 16-300922',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        # In reality this shouldn't happen, but test for two black bin WPs
        # for the same day
        {   'id'           => 75600,
            'WorkPackDate' => '2022-10-07T00:00:00',
            'WorkPackName' => 'Waste-Round 16-071022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'id'           => 75700,
            'WorkPackDate' => '2022-10-07T00:00:00',
            'WorkPackName' => 'Waste-Round 17-071022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },

        # Extra workpacks, to test that the number of available slot dates is
        # not limited if a start date is provided to
        # find_available_bulky_slots()
        {   'id'           => 75800,
            'WorkPackDate' => '2022-10-08T00:00:00',
            'WorkPackName' => 'Waste-Round 16-081022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
        {   'id'           => 75900,
            'WorkPackDate' => '2022-10-09T00:00:00',
            'WorkPackName' => 'Waste-Round 16-091022',
            'Actions'      =>
                { 'Action' => { 'ActionName' => 'Empty Bin 240L Black' } },
        },
    ];

    if ($start_date) {
        return [
            grep {
                my $parser
                    = DateTime::Format::Strptime->new( pattern => '%F' );
                $parser->parse_datetime( $_->{WorkPackDate} )
                    >= $parser->parse_datetime($start_date);
            } @$fw
        ];
    } else {
        return $fw;
    }
}

# For WorkPacks_Get() calls
sub _workpacks_by_date {
    {
        # No bulky workpacks; i.e. no booked bulky collections
        '2022-08-05T00:00:00' => [
            {   'ID'          => '508221',
                'Name'        => 'Waste-R5 Ref-050822',
                'RecordStamp' => {},                      # Not relevant
            },
        ],

        # Workpacks with jobs that exceed the bulky limit:

        # 'WHITES' (bulky) workpack
        '2022-08-12T00:00:00' => [
            {   'ID'          => '1208221',
                'Name'        => 'Waste-WHITES-120822',
                'RecordStamp' => {},
            },
        ],

        # 'BULKY WASTE' workpack
        '2022-08-19T00:00:00' => [
            {   'ID'          => '1908221',
                'Name'        => 'Waste-BULKY WASTE-190822',
                'RecordStamp' => {},
            },
        ],

        # Both 'WHITES' & 'BULKY WASTE'
        '2022-08-26T23:59:59' => [
            {   'ID'          => '2608221',
                'Name'        => 'Waste-BULKY WASTE-260822',
                'RecordStamp' => {},
            },
            {   'ID'          => '2608222',
                'Name'        => 'Waste-WHITES-260822',
                'RecordStamp' => {},
            },
        ],

        # Both 'WHITES' & 'BULKY WASTE' but wrong/bad date in 'Name' - so
        # job counts for these collections are ignored
        '2022-09-02T00:00:00' => [
            {   'ID'   => '209221',
                'Name' => 'Waste-BULKY WASTE-010122',    # Non-matching date
                'RecordStamp' => {},
            },
            {   'ID'          => '209222',
                'Name'        => 'Waste-WHITES-20922',    # Bad format
                'RecordStamp' => {},
            },
            {   'ID'          => '209223',
                'Name'        => 'Waste-WHITES-311322',    # Impossible date
                'RecordStamp' => {},
            },
        ],

        # Workpacks with jobs that do not exceed the bulky limit:

        '2022-09-09T00:00:00' => [
            {   'ID'          => '909221',
                'Name'        => 'Waste-BULKY WASTE-090922',
                'RecordStamp' => {},
            },
        ],

        '2022-09-16T00:00:00' => [
            {   'ID'          => '1609221',
                'Name'        => 'Waste-WHITES-160922',
                'RecordStamp' => {},
            },
        ],

        '2022-09-23T00:00:00' => [
            {   'ID'          => '2309221',
                'Name'        => 'Waste-BULKY WASTE-230922',
                'RecordStamp' => {},
            },
            {   'ID'          => '2309222',
                'Name'        => 'Waste-WHITES-230922',
                'RecordStamp' => {},
            },
        ],

        # Workpacks with no jobs:

        '2022-09-30T00:00:00' => [
            {   'ID'          => '3009221',
                'Name'        => 'Waste-BULKY WASTE-300922',
                'RecordStamp' => {},
            },
            {   'ID'          => '3009222',
                'Name'        => 'Waste-WHITES-300922',
                'RecordStamp' => {},
            },
        ],

        '2022-10-07T00:00:00' => [
            {   'ID'          => '710221',
                'Name'        => 'Waste-BULKY WASTE-071022',
                'RecordStamp' => {},
            },
        ],
    };
}

sub _jobs_by_workpack_id {
    {
        # Not a bulky workpack so limit ignored
        508221 => _jobs_arrayref(40),

        # 'WHITES' - max jobs
        1208221 => _jobs_arrayref(40),

        # 'BULKY WASTE' - max jobs
        1908221 => _jobs_arrayref(40),

        # 'WHITES' & 'BULKY WASTE' that together make max jobs
        2608221 => _jobs_arrayref(10),
        2608222 => _jobs_arrayref( 30, 20001 ),

        # Connected to faulty workpack names so limit ignored
        209221 => _jobs_arrayref(40),
        209222 => _jobs_arrayref(40),
        209223 => _jobs_arrayref(40),

        # Limit not reached:

        # Same UPRN for all jobs so counts as single bulky collection
        909221 => [ ( { Job => { UPRN => 10001 } } ) x 40 ],

        1609221 => _jobs_arrayref(39),

        3009221 => _jobs_arrayref(25),
        # Same UPRN for all jobs so counts as single bulky collection
        3009222 => [ ( { Job => { UPRN => 10001 } } ) x 15 ],
    };
}

sub _jobs_arrayref {
    my ( $job_count, $uprn ) = @_;
    $uprn //= 10001;
    return [ map { { Job => { UPRN => $uprn++ } } } 1 .. $job_count ];
}

### end 'find_available_bulky_slots'

subtest '_bulky_check_within_a_window cancellation' => sub {
    my $mock_pbro = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
    my $now_dt;
    my $collection_date;
    $mock_pbro->mock(
        'bulky_cancellation_cutoff_time', sub {
            { hours => 15, minutes => 0, working_days => 1}
        },
    );

#      April 2023
# Su Mo Tu We Th Fr Sa
#                    1
#  2  3  4  5  6  7  8
#  9 10 11 12 13 14 15
# 16 17 18 19 20 21 22
# 23 24 25 26 27 28 29
# 30

    subtest 'Now one working day earlier than collection date' => sub {
        $now_dt = DateTime->new(
            year      => 2023,
            month     => 3,
            day       => 31,
            time_zone => FixMyStreet->local_time_zone,
        );
        $collection_date = DateTime->new(year => 2023, month => 4, day => 2);

        subtest 'Now time earlier than 15:00' => sub {
            $now_dt->set( hour => 14, minute => 59, second => 59 );
            ok( FixMyStreet::Cobrand::Peterborough->_bulky_check_within_a_window(
                    $now_dt, $collection_date, 'cancellation'
                )
            );
        };
        subtest 'Now time equals 15:00' => sub {
            $now_dt->set( hour => 15, minute => 0, second => 0 );
            ok!( FixMyStreet::Cobrand::Peterborough->_bulky_check_within_a_window(
                    $now_dt, $collection_date, 'cancellation'
                )
            );
        };
        subtest 'Now time later than 15:00' => sub {
            $now_dt->set( hour => 15, minute => 1 );
            ok!( FixMyStreet::Cobrand::Peterborough->_bulky_check_within_a_window(
                    $now_dt, $collection_date, 'cancellation'
                )
            );
        };
    };

    for my $dates (
        { day => 31, month => 3, desc => 'weekday' },
        { day => 1, month => 4, desc => 'weekend' },
    ) {
        subtest 'Now same day as collection date on ' . $dates->{desc} => sub {
            $now_dt = DateTime->new(
                year      => 2023,
                month     => $dates->{month},
                day       => $dates->{day},
                time_zone => 'Europe/London',
            );
            $collection_date = DateTime->new(year => 2023, month => $dates->{month}, day => $dates->{day});

            ok !( FixMyStreet::Cobrand::Peterborough->_bulky_check_within_a_window(
                    $now_dt, $collection_date, 'cancellation'
                )
            );
        };
    };

    subtest 'Now later day than collection date' => sub {
        $now_dt = DateTime->new(
            year      => 2023,
            month     => 4,
            day       => 3,
            time_zone => 'Europe/London',
        );
        $collection_date = DateTime->new(year => 2023, month => 3, day => 31);

        ok !( FixMyStreet::Cobrand::Peterborough->_bulky_check_within_a_window(
                $now_dt, $collection_date, 'cancellation'
            )
        );
    };

    # Check we are taking year into account when considering day comparisons
   for my $dates (
        { day => 31, month => 3, desc => 'weekday' },
        { day => 1, month => 4, desc => 'weekend' },
    ) {
        subtest 'Now same date as collection date but year earlier on ' . $dates->{desc} => sub {
            $now_dt = DateTime->new(
                year      => 2022,
                month     => $dates->{month},
                day       => $dates->{day},
                time_zone => 'Europe/London',
            );
            $collection_date = DateTime->new(year => 2023, month => $dates->{month}, day => $dates->{day});

            ok( FixMyStreet::Cobrand::Peterborough->_bulky_check_within_a_window(
                    $now_dt, $collection_date, 'cancellation'
                )
            );
        };
    };

    subtest 'Now later date than collection date but year earlier' => sub {
        $now_dt = DateTime->new(
            year      => 2022,
            month     => 4,
            day       => 3,
            time_zone => 'Europe/London',
        );
        $collection_date = DateTime->new(year => 2023, month => 3, day => 31);

        ok( FixMyStreet::Cobrand::Peterborough->_bulky_check_within_a_window(
                $now_dt, $collection_date, 'cancellation'
            )
        );
    };
};

subtest '_bulky_check_within_a_window refund' => sub {
    my $mock_pbro = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
    my $now_dt;
    my $collection_dt;
    $mock_pbro->mock(
        'bulky_refund_cutoff_time', sub {
            { hours => 06, minutes => 45, working_days => 1 }
        },
    );
    subtest 'Now same day as collection date' => sub {
        $now_dt = DateTime->new(
            year      => 2023,
            month     => 4,
            day       => 3,
            time_zone => 'Europe/London',
        );
        $collection_dt = DateTime->new(
            year      => 2023,
            month     => 4,
            day       => 3,
            time_zone => 'Europe/London',
        );

        subtest 'before 6:45' => sub {
            $now_dt->set( hour => 6, minute => 44 );
            ok !(
                FixMyStreet::Cobrand::Peterborough
                ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                )
            );
        };
        subtest 'at 6:45' => sub {
            $now_dt->set( hour => 6, minute => 45 );
            ok !(
                FixMyStreet::Cobrand::Peterborough
                ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                )
            );
        };
        subtest 'after 6:45' => sub {
            $now_dt->set( hour => 6, minute => 46 );
            ok !(
                FixMyStreet::Cobrand::Peterborough
                ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                )
            );
        };
    };

    subtest 'Now one working day before collection date' => sub {
        $now_dt = DateTime->new(
            year      => 2023,
            month     => 3,
            day       => 31,
            time_zone => 'Europe/London',
        );
        $collection_dt = DateTime->new(
            year      => 2023,
            month     => 4,
            day       => 2,
            time_zone => 'Europe/London',
        );

        subtest 'before 6:45' => sub {
            $now_dt->set( hour => 6, minute => 44 );
            ok( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
        subtest 'at 6:45' => sub {
            $now_dt->set( hour => 6, minute => 45 );
            ok !( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
        subtest 'after 6:45' => sub {
            $now_dt->set( hour => 6, minute => 46 );
            ok !(
                FixMyStreet::Cobrand::Peterborough
                ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                )
            );
        };
    };

    # Check we are taking year into account when considering day comparisons
    subtest 'Now same date as collection date but year earlier' => sub {
        $now_dt = DateTime->new(
            year      => 2022,
            month     => 4,
            day       => 1,
            time_zone => 'Europe/London',
        );
        $collection_dt = DateTime->new(
            year      => 2023,
            month     => 4,
            day       => 1,
            time_zone => 'Europe/London',
        );

        subtest 'before 6:45' => sub {
            $now_dt->set( hour => 6, minute => 44 );
            ok( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
        subtest 'at 6:45' => sub {
            $now_dt->set( hour => 6, minute => 45 );
            ok( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
        subtest 'after 6:45' => sub {
            $now_dt->set( hour => 6, minute => 46 );
            ok( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
    };

    subtest 'Now date a date after collection date, one year earlier' => sub {
        $now_dt = DateTime->new(
            year      => 2022,
            month     => 4,
            day       => 2,
            time_zone => 'Europe/London',
        );
        $collection_dt = DateTime->new(
            year      => 2023,
            month     => 4,
            day       => 1,
            time_zone => 'Europe/London',
        );

        subtest 'before 6:45' => sub {
            $now_dt->set( hour => 6, minute => 44 );
            ok( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
        subtest 'at 6:45' => sub {
            $now_dt->set( hour => 6, minute => 45 );
            ok( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
        subtest 'after 6:45' => sub {
            $now_dt->set( hour => 6, minute => 46 );
            ok( FixMyStreet::Cobrand::Peterborough
                    ->_bulky_check_within_a_window(
                    $now_dt, $collection_dt, 'refund'
                    )
            );
        };
    };
};

subtest 'bulky_collection_window_start_date' => sub {
    my $mock_pbro = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
    $mock_pbro->mock(
        'bulky_cancellation_cutoff_time', sub {
            { hours => 14, minutes => 0, working_days => 1}
        },
    );
    my $mock_uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
    $mock_uk->mock('public_holidays', sub { return [ '2024-10-21' ]});
    my $now_dt = DateTime->new(
        year      => 2024,
        month     => 10,
        time_zone => 'Europe/London',
    );
    for my $test (
        { day => 17, hour => 13, result => '2024-10-18T00:00:00', desc => 'Before cut off on Thu, Friday (standard next working day)' },
        { day => 17, hour => 14, result => '2024-10-22T00:00:00', desc => 'After cut off on Thu, Tue (as BH weekend, 2nd working day)' },
        { day => 18, hour => 13, result => '2024-10-22T00:00:00', desc => 'Before cut off on Fri, Tue (as BH weekend, next working day)' },
        { day => 18, hour => 14, result => '2024-10-23T00:00:00', desc => 'After cut off on Fri, Wed (as BH weekend), 2nd working day' },
        { day => 19, hour => 13, result => '2024-10-23T00:00:00', desc => 'Before cut off on Sat, Wed (as BH weekend)' },
        { day => 19, hour => 14, result => '2024-10-23T00:00:00', desc => 'After cut off on Sat, Wed (as BH weekend)' },
        { day => 20, hour => 13, result => '2024-10-23T00:00:00', desc => 'Before cut off on Sun, Wed (as BH weekend)' },
        { day => 20, hour => 14, result => '2024-10-23T00:00:00', desc => 'After cut off on Sun, Wed (as BH weekend)' },
        { day => 21, hour => 13, result => '2024-10-23T00:00:00', desc => 'Before cut off on Mon, Wed (as BH weekend)' },
        { day => 21, hour => 14, result => '2024-10-23T00:00:00', desc => 'After cut off on Mon, Wed (as BH weekend)' },
        { day => 22, hour => 13, result => '2024-10-23T00:00:00', desc => 'Before cut off on Tue, Wed (standard next working day)' },
        { day => 22, hour => 14, result => '2024-10-24T00:00:00', desc => 'After cut off on Tue, Thu (standard 2nd working day)' },
        { day => 23, hour => 13, result => '2024-10-24T00:00:00', desc => 'Before cut off on Wed, Thu (standard next working day)' },
        { day => 23, hour => 14, result => '2024-10-25T00:00:00', desc => 'After cut off on Wed, Fri (standard 2nd working day)' },
        { day => 24, hour => 13, result => '2024-10-25T00:00:00', desc => 'Before cut off on Thu, Fri (standard next working day)' },
        { day => 24, hour => 14, result => '2024-10-28T00:00:00', desc => 'After cut off on Thu, Mon (standard 2nd working day)' },
        { day => 25, hour => 13, result => '2024-10-28T00:00:00', desc => 'Before cut off on Fri, Mon (standard next working day)' },
        { day => 25, hour => 14, result => '2024-10-29T00:00:00', desc => 'After cut off on Fri, Tue (standard 2nd working day)' },
        { day => 26, hour => 13, result => '2024-10-29T00:00:00', desc => 'Before cut off on Sat, Tue (standard next working day)' },
        { day => 26, hour => 14, result => '2024-10-29T00:00:00', desc => 'After cut off on Sat, Tue (standard 2nd working day)' },
    ) {
        $now_dt->set(day => $test->{day}, hour => $test->{hour});
        is( FixMyStreet::Cobrand::Peterborough
            ->bulky_collection_window_start_date(
                $now_dt
            ), $test->{result}, $test->{desc}
        );
    }
};

done_testing;
