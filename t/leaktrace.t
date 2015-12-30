#!perl -w
use strict;
use constant HAS_LEAKTRACE => eval{ require Test::LeakTrace };
use Test::More HAS_LEAKTRACE ? (tests => 1) : (skip_all => 'require Test::LeakTrace');
use Test::LeakTrace;

use SNMP::Translate;

leaks_cmp_ok{
    SNMP::Translate::translateObj('ifDescr');
    SNMP::Translate::translateObj('.1',1,1);
    SNMP::Translate::translate([ 'ifDescr', 'ifOperStatus' ]);
} '<', 1;

