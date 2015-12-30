
use strict;
use warnings;

use Test::More;
use SNMP::Translate qw (translate translateObj);

my $iftable_tags = [ 'ifDescr','ifSpeed','ifHighSpeed','ifAdminStatus', 'ifAlias' ];

my $output = [
            '.1.3.6.1.2.1.2.2.1.2',
            '.1.3.6.1.2.1.2.2.1.5',
            '.1.3.6.1.2.1.31.1.1.1.15',
            '.1.3.6.1.2.1.2.2.1.7',
            '.1.3.6.1.2.1.31.1.1.1.18'
          ];

is_deeply(translate($iftable_tags), $output, 'Can we translate some things?');
is_deeply(translate($output), $iftable_tags, 'Can we reverse translate?');

is(translateObj('.1.3.6.1.2.1.2.2.1.2',1),
    '.iso.org.dod.internet.mgmt.mib-2.interfaces.ifTable.ifEntry.ifDescr',
    'Do long_names work?');
is(translateObj('.1.3.6.1.2.1.2.2.1.2',0,1), 'IF-MIB::ifDescr', 'Does MIBNAME prepend work?');
is(translateObj(undef), undef, 'return undef if not defined obj');

done_testing();
