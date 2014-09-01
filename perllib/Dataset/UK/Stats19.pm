package Dataset::UK::Stats19;
use Moo;
use MooX::Options;
use MooX::Cmd;
use Path::Tiny;

option dsn => (
    is => 'ro',
    default => sub {
        my $self = shift;
        my $path = path( $self->data_directory, 'stats19.db' )->stringify;
        "dbi:SQLite:dbname=$path",
    }
);

option db => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        require Dataset::UK::Stats19::Schema;
        Dataset::UK::Stats19::Schema->connect( $self->dsn );
    },
);

option url => (
    is => 'ro',
    default => 'http://data.dft.gov.uk.s3.amazonaws.com/road-accidents-safety-data/Stats19-Data2005-2013.zip'
);

option data_directory => (
    is => 'ro',
    default => 'data/stats19',
);

around data_directory => sub {
    my ($orig, $self) = @_;
    my $dir = $self->$orig;
    system 'mkdir', '-p', $dir;
    return $dir;
};

option zipfile => (
    is => 'ro',
    default => 'data.zip',
);

sub execute {
    my ($self, $args, $chain) = @_;
    # noop
}
1;
