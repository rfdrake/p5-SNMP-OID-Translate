
use strict;
use warnings;

use Test::More;
use SNMP::Translate qw (translate);

my $iftable_tags = [ 'ifDescr','ifSpeed','ifHighSpeed','ifAdminStatus', 'ifAlias' ];

my $output = [
            '.1.3.6.1.2.1.2.2.1.2',
            '.1.3.6.1.2.1.2.2.1.5',
            '.1.3.6.1.2.1.31.1.1.1.15',
            '.1.3.6.1.2.1.2.2.1.7',
            '.1.3.6.1.2.1.31.1.1.1.18'
          ];

is_deeply(translate($iftable_tags), $output, 'Can we translate some things?');

done_testing();
