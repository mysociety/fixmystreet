package DBD::Oracle;
use strict; use warnings;
use base 'Exporter';

$DBD::Oracle::VERSION = 'DUMMY';

our @EXPORT_OK = qw(
    ORA_DATE
    ORA_NUMBER
    ORA_VARCHAR2
);
our %EXPORT_TAGS = (ora_types => \@EXPORT_OK);

# dummy constants
use constant ORA_DATE => 'ORA_DATE'; 
use constant ORA_NUMBER => 'ORA_NUMBER'; 
use constant ORA_VARCHAR2 => 'ORA_VARCHAR2'; 

1;
