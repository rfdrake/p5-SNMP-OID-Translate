#!perl -w
use strict;
use warnings;

use Test::More;
plan skip_all => 'running under Devel::Cover' if ($INC{'Devel/Cover.pm'});
eval 'use Test::LeakTrace; 1' or plan skip_all => 'require Test::LeakTrace';
plan tests => 1;

use SNMP::OID::Translate;

leaks_cmp_ok{
    SNMP::OID::Translate::translateObj('ifDescr');
    SNMP::OID::Translate::translateObj('.1',1,1);
    SNMP::OID::Translate::translate([ 'ifDescr', 'ifOperStatus' ]);
} '<', 1;

