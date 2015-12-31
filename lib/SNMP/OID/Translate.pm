package SNMP::OID::Translate;


use strict;
use warnings;

require Exporter;
our @EXPORT_OK = qw( translateObj translate );

require DynaLoader;
our @ISA = qw(DynaLoader Exporter);
bootstrap SNMP::OID::Translate;

use vars qw(
  $auto_init_mib $use_long_names
  %MIB $verbose
  $best_guess
);

$auto_init_mib = 1; # enable automatic MIB loading at session creation time
$use_long_names = 0; # non-zero to prefer longer mib textual identifiers rather
                   # than just leaf indentifiers (see translateObj)
                   # may also be set on a per session basis(see UseLongNames)
%MIB = ();      # tied hash to access libraries internal mib tree structure
                # parsed in from mib files
$verbose = 0;   # controls warning/info output of SNMP module,
                # 0 => no output, 1 => enables warning and info
                # output from SNMP module itself (is also controlled
                # by SNMP::debugging)
$best_guess = 0;  # determine whether or not to enable best-guess regular
                  # expression object name translation.  1 = Regex (-Ib),
		  # 2 = random (-IR)

=head1 SUBROUTINES

=head2 translateObj

    my $oid = translateObj('ifDescr');

Translate object identifier(tag or numeric) into alternate representation
(i.e., sysDescr => '.1.3.6.1.2.1.1.1' and '.1.3.6.1.2.1.1.1' => sysDescr)
when $SNMP::OID::Translate::use_long_names or second arg is non-zero the translation will
return longer textual identifiers (e.g., system.sysDescr).  An optional
third argument of non-zero will cause the module name to be prepended
to the text name (e.g. 'SNMPv2-MIB::sysDescr').  If no Mib is loaded
when called and $SNMP::OID::Translate::auto_init_mib is enabled then the Mib will be
loaded. Will return 'undef' upon failure.

=cut

sub translateObj {
   SNMP::OID::Translate::init_snmp("perl");
   my $obj = shift;
   my $temp = shift;
   my $include_module_name = shift || "0";
   my $long_names = $temp || $SNMP::OID::Translate::use_long_names;

   return undef if not defined $obj;
   my $res;
   if ($obj =~ /^\.?(\d+\.)*\d+$/) {
      $res = SNMP::OID::Translate::_translate_obj($obj,1,$long_names,$SNMP::OID::Translate::auto_init_mib,0,$include_module_name);
   } elsif ($obj =~ /(\.\d+)*$/ && $SNMP::OID::Translate::best_guess == 0) {
      $res = SNMP::OID::Translate::_translate_obj($`,0,$long_names,$SNMP::OID::Translate::auto_init_mib,0,$include_module_name);
      $res .= $& if defined $res and defined $&;
   } elsif ($SNMP::OID::Translate::best_guess) {
      $res = SNMP::OID::Translate::_translate_obj($obj,0,$long_names,$SNMP::OID::Translate::auto_init_mib,$SNMP::OID::Translate::best_guess,$include_module_name);
   }

   return($res);
}

=head2 translate

    my $result = translate([ 'ifDescr', 'ifInOctets' ]);

This will translate an arrayref or list of objects into their OIDs or
translate OIDs into their names.  Returns an arrayref.

=cut

sub translate {
    [ map { translateObj($_) } ref($_[0]) eq 'ARRAY' ?  @{$_[0]} : @_ ];
}


1;

=head1 AUTHOR

bugs, comments, questions to rdrake@cpan.org

=head1 Copyright

Most of the source code is directly copied from the SNMP.pm/xs modules.  I am
leaving their copyright notice intact but please direct complaints, feature
requests or whatever to me.

     Copyright (c) 1995-2000 G. S. Marzot. All rights reserved.
     This program is free software; you can redistribute it and/or
     modify it under the same terms as Perl itself.

     Copyright (c) 2001-2002 Networks Associates Technology, Inc.  All
     Rights Reserved.  This program is free software; you can
     redistribute it and/or modify it under the same terms as Perl
     itself.

=cut