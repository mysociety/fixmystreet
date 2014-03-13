package Open311::Endpoint::Result;
use Moo;

has status => (
    is => 'ro',
);
has data => (
    is => 'ro',
);

sub success {
    my ($class, $data) = @_;
    return $class->new({
        status => 200,
        data => $data,
    });
}

sub error {
    my ($class, $code, @errors) = @_;
    $code ||= 400;
    return $class->new({
        status => $code,
        data => {
            errors => [
                map {
                    ref $_ eq 'HASH' ? $_ :
                    {
                        code => $code,
                        description => $_,
                    }
                } @errors,
            ],
        },
    });
}

1;
