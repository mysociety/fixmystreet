package Integrations::Roles::SOAP;
use Moo::Role;
use Tie::IxHash;

sub force_arrayref {
    my ($res, $key) = @_;
    return [] unless $res;
    my $data = $res->{$key};
    return [] unless $data;
    $data = [ $data ] unless ref $data eq 'ARRAY';
    return $data;
}

sub make_soap_structure {
    my @out;
    for (my $i=0; $i<@_; $i+=2) {
        my $name = $_[$i] =~ /:/ ? $_[$i] : $_[$i];
        my $v = $_[$i+1];
        my $val = $v;
        my $d = SOAP::Data->name($name);
        if (ref $v eq 'HASH') {
            $val = \SOAP::Data->value(make_soap_structure(%$v));
        } elsif (ref $v eq 'ARRAY') {
            my @map = map { make_soap_structure(%$_) } @$v;
            $val = \SOAP::Data->value(SOAP::Data->name('dummy' => @map));
        }
        push @out, $d->value($val);
    }
    return @out;
}

sub make_soap_structure_with_attr {
    my @out;
    for (my $i=0; $i<@_; $i+=2) {
        my $name = $_[$i] =~ /:/ ? $_[$i] : $_[$i];
        my $v = $_[$i+1];
        if (ref $v eq 'HASH') {
            my $attr = delete $v->{attr};
            my $value = delete $v->{value};

            my $d = SOAP::Data->name($name => $value ? $value : \SOAP::Data->value(make_soap_structure_with_attr(%$v)));

            $d->attr( $attr ) if $attr;
            push @out, $d;
        } elsif (ref $v eq 'ARRAY') {
            push @out, map { SOAP::Data->name($name => \SOAP::Data->value(make_soap_structure_with_attr(%$_))) } @$v;
        } else {
            push @out, SOAP::Data->name($name => $v);
        }
    }
    return @out;
}

sub ixhash {
    tie (my %data, 'Tie::IxHash', @_);
    return \%data;
}

1;
