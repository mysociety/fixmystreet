package BexleyAddresses;

use strict;
use warnings;

use DBI;
use FixMyStreet;

sub database_file {
    FixMyStreet->path_to('../data/bexley-ww-postcodes.sqlite');
}

sub addresses_for_postcode {
    my $postcode = shift;

    die $! unless -e database_file();

    my $db = DBI->connect( 'dbi:SQLite:dbname=' . database_file(),
        undef, undef )
        or return [];

    # Remove whitespaces, make sure uppercase
    $postcode =~ s/ //g;
    $postcode = uc $postcode;

    my $addresses = $db->selectall_arrayref(
        <<SQL,
   SELECT p.uprn uprn,
          p.usrn usrn,

          pao_start_number,
          pao_start_suffix,
          pao_end_number,
          pao_end_suffix,
          pao_text,

          sao_start_number,
          sao_start_suffix,
          sao_end_number,
          sao_end_suffix,
          sao_text,

          street_descriptor,
          locality_name,
          town_name,

          parent_uprn
     FROM postcodes p
     JOIN street_descriptors sd
       ON sd.usrn = p.usrn
     LEFT OUTER JOIN child_uprns cu
       ON cu.uprn = p.uprn
    WHERE p.postcode = ?
      AND p.uprn NOT IN (
        SELECT parent_uprn FROM child_uprns
      )
SQL
        { Slice => {} },
        $postcode,
    );

    return [ sort _sort_addresses @$addresses ];
}

sub build_address_string {
    my $row = shift;

    my $sao;
    if ( $row->{parent_uprn} ) {
        $sao = _join_extended(
            ' ',
            $row->{sao_text},
            _join_extended(
                '-',
                _join_extended(
                    '', $row->{sao_start_number},
                    $row->{sao_start_suffix},
                ),
                _join_extended(
                    '',
                    $row->{sao_end_number},
                    $row->{sao_end_suffix},
                ),
            ),
        );
    }

    my $pao = _join_extended(
        ' ',
        $row->{pao_text},
        _join_extended(
            '-',
            _join_extended(
                '',
                $row->{pao_start_number},
                $row->{pao_start_suffix},
            ),
            _join_extended(
                '',
                $row->{pao_end_number},
                $row->{pao_end_suffix},
            ),
        ),
    );

    return _join_extended(
        ', ',
        _join_extended( ' ', $sao, $pao, $row->{street_descriptor} ),
        $row->{locality_name},
        $row->{town_name},
    );
}

# Only joins strings that are true / non-empty
sub _join_extended {
    my ( $sep, @strings ) = @_;

    my @strings_true_only;
    for (@strings) {
        push @strings_true_only, $_ if $_;
    }

    return join $sep, @strings_true_only;
}

sub _sort_addresses {
    ( $a->{pao_start_number} // 0 ) <=> ( $b->{pao_start_number} // 0 )
    or
    ( $a->{pao_start_suffix} // '' ) cmp ( $b->{pao_start_suffix} // '' )
    or
    ( $a->{pao_text} // '' ) cmp ( $b->{pao_text} // '' )
    or
    ( $a->{sao_start_number} // 0 ) <=> ( $b->{sao_start_number} // 0 )
    or
    ( $a->{sao_start_suffix} // '' ) cmp ( $b->{sao_start_suffix} // '' )
    or
    ( $a->{sao_text} // '' ) cmp ( $b->{sao_text} // '' )
}

1;
