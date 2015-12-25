
use strict;
use warnings;

use Test::More;
use SNMP::Translate;

my $iftable_tags = [ 'ifDescr','ifSpeed','ifHighSpeed','ifAdminStatus', 'ifAlias' ];

my $output = [
            '.1.3.6.1.2.1.2.2.1.2',
            '.1.3.6.1.2.1.2.2.1.5',
            '.1.3.6.1.2.1.31.1.1.1.15',
            '.1.3.6.1.2.1.2.2.1.7',
            '.1.3.6.1.2.1.31.1.1.1.18'
          ];

sub translate {
    [ map { SNMP::Translate::translateObj($_) } ref($_[0]) eq 'ARRAY' ? @{$_[0]} : @_ ];
}

is_deeply(translate($iftable_tags), $output, 'Does an arrayref work for translate?');

done_testing();
