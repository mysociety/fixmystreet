package Open311::Endpoint::Spark;
use Moo;
use Data::Visitor::Callback;

=head1 NAME

Open311::Endpoint::Spark - transform from canonical data-structure to XML or JSON

=head1 SUMMARY 

The Open311 docs discuss the Spark convention, to transform between XML and JSON.

    http://wiki.open311.org/JSON_and_XML_Conversion#The_Spark_Convention

These options seem fragile, and require starting with the verbose XML form,
which isn't really natural in Perl.  Instead, we'll start with a standard
Perl data structure, with a single extra hash wrapper, and will:

    * for JSON, remove the outside hash wrapper

    * for XML, for arrays, insert an extra layer with the singular name:
        (this is the way XML::Simple knows how to do this nesting)

So:

    # FROM
    {
        foo => {
            bars => [ 1, 2, 3 ]
        }
    }

    # JSON (note the 'foo' has been removed
    {
        bars: [
            1,
            2,
            3
        ]
    }

    # XML intermediate
    {
        foo => {
            bars => {
                bar => [ 1, 2, 3 ]
            }
        }
    }

    # XML result
    <foo>
        <bars>
            <bar>1</bar>
            <bar>2</bar>
            <bar>3</bar>
        </bars>
    </foo>

=cut

sub process_for_json {
    my ($self, $data) = @_;
    if (ref $data eq 'HASH' and scalar keys %$data == 1) {
        return $data->{ (keys %$data)[0] };
    }
    else {
        return $data;
    }
}

sub process_for_xml {
    my ($self, $data) = @_;

    # NB: in place mutation
    _process_for_xml($data);
    return $data;
}

# NB: in place mutation
sub _process_for_xml {
    my $data = shift;
    return unless ref $data;

    if (ref $data eq 'HASH') {
        while ( my ($k, $v) = each %$data) {
            if (ref $v eq 'ARRAY') {
                my $singular = _singularize($k);
                # add extra layer
                $data->{$k} = { 
                    $singular => $v,
                };
            }
            _process_for_xml($v);
        }
    }
    elsif (ref $data eq 'ARRAY') {
        for my $item (@$data) {
            _process_for_xml($item);
        }
    }
}
sub _singularize {
    my $name = shift;
    $name =~s/s$//;
    return $name;
}

1;
