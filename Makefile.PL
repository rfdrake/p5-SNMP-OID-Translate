use ExtUtils::MakeMaker;
require 5;
use Config;
use Getopt::Long;
my $lib_version;
my %MakeParams = ();
my $opts;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

%MakeParams = InitMakeParams();

WriteMakefile(%MakeParams);

sub InitMakeParams {
    my %Params = (
		  NAME         => 'SNMP::Translate',
		  dist         => { SUFFIX => "gz", COMPRESS => "gzip -9f"},
		  MAN3PODS => { 'Translate.pm' => '$(INST_MAN3DIR)/SNMP::Translate.3' },
		  XSPROTOARG   => '-noprototypes', 	# XXX remove later?
		  VERSION_FROM => 'Translate.pm',
		  realclean        => { FILES => 'host' },
		  );

    if ($ENV{'OSTYPE'} eq 'msys') {
      $Params{'DEFINE'} = "-DMINGW_PERL";
    }

    my ($snmp_lib, $snmp_llib, $sep);
    if (($Config{'osname'} eq 'MSWin32' && $ENV{'OSTYPE'} ne 'msys')) {
      $opts = NetSNMPGetOpts();
      $Params{'DEFINE'} = "-DMSVC_PERL";
      $sep = '\\';
      $snmp_lib_file = 'netsnmp.lib';
      $snmp_link_lib = 'netsnmp';

      if (lc($opts->{'debug'}) eq "true") {
        $lib_dir = 'lib\\debug';
      }
      else {
        $lib_dir = 'lib\\release';
      }

      if (lc($opts->{'insource'}) eq "true") {
	$Params{'LIBS'} = "-L$basedir\\win32\\$lib_dir\\ -l$snmp_link_lib";
      }
      else {
	my @LibDirs = split (';',$ENV{LIB});
        my $LibDir;
	if ($opts->{'prefix'}) {
	  push (@LibDirs,"$ENV{'NET-SNMP-PATH'}${sep}lib");
	}
	$noLibDir = 1;
	while ($noLibDir) {
	  $LibDir = find_files(["$snmp_lib_file"],\@LibDirs);
	  if ($LibDir ne '') {
	    $noLibDir = 0;
            # Put quotes around LibDir to allow spaces in paths
            $LibDir = '"' . $LibDir . '"';
	  }
	  else
	  {
	    @LibDirs = ();
	    $LibDirs[0] = prompt("The Net-SNMP library ($snmp_lib_file) could not be found.\nPlease enter the directory where it is located:");
	    $LibDirs[0] =~ s/\\$//;
	  }
	}
	$Params{LIBS} = "-L$LibDir -l$snmp_link_lib";
      }

      $Params{'INC'} = "-I$basedir\\include\\ -I$basedir\\include\\net-snmp\\ -I$basedir\\win32\\ ";
    }
    else {
	$opts = NetSNMPGetOpts();
	$Params{'LDDLFLAGS'} = "$Config{lddlflags} " . `$opts->{'nsconfig'} --ldflags`;
	if (!$ENV{'NETSNMP_LIBS'}) {
	    $Params{'LIBS'}    = `$opts->{'nsconfig'} --libs`;
	    chomp($Params{'LIBS'});
	} else {
	    $Params{'LIBS'} = $ENV{'NETSNMP_LIBS'};
	}
	if (!$ENV{'NETSNMP_CCFLAGS'}) {
	    $Params{'CCFLAGS'} = `$opts->{'nsconfig'} --cflags`;
	    chomp($Params{'CCFLAGS'});
	    $Params{'CCFLAGS'} .= " " . $Config{'ccflags'};
	} else {
	    $Params{'CCFLAGS'} = $ENV{'NETSNMP_CCFLAGS'};
	}
        $lib_version = `$opts->{'nsconfig'} --version`;
	if (lc($opts->{'insource'}) eq "true") {
	    $Params{'LIBS'} = "-L../../snmplib/.libs -L../../snmplib/ " . $Params{'LIBS'};
	    $Params{'CCFLAGS'} = "-I../../include " . $Params{'CCFLAGS'};
#	} else {
#	    $Params{'PREREQ_PM'} = { 'NetSNMP::default_store' => 0.01 };
	}
	$Params{'CCFLAGS'} =~ s/ -W(all|inline|strict-prototypes|write-strings|cast-qual|no-char-subscripts)//g; # ignore developer warnings
	if (!$ENV{'NETSNMP_PREFIX'}) {
	    $prefix            = `$opts->{'nsconfig'} --prefix`;
	    chomp($prefix);
	    $sep = '/';
	} else {
	    $prefix = $ENV{'NETSNMP_PREFIX'};
	}
	if ($Params{'LIBS'} eq "" || $Params{'CCFLAGS'} eq "") {
        die "need net-snmp-config thing..";
	}
    }

    # needed to remove system perl that net-snmp-config adds (for perlbrew but
    # should be safe for non-perlbrew environments)
    $Params{'CCFLAGS'} =~ s/-I\S+perl\S+\/CORE//;

    return(%Params);

}

# common subroutines -- DO NOT EDIT.
# They are imported from the Makefile.subs.pl file
sub NetSNMPGetOpts {
    my %ret;
    my $rootpath = shift;
    $rootpath = "../" if (!$rootpath);
    $rootpath .= '/' if ($rootpath !~ /\/$/);

    if (($Config{'osname'} eq 'MSWin32' && $ENV{'OSTYPE'} ne 'msys')) {

      # Grab command line options first.  Only used if environment variables are not set
      GetOptions("NET-SNMP-IN-SOURCE=s" => \$ret{'insource'},
        "NET-SNMP-PATH=s"      => \$ret{'prefix'},
        "NET-SNMP-DEBUG=s"     => \$ret{'debug'});

      if ($ENV{'NET-SNMP-IN-SOURCE'})
      {
	$ret{'insource'} = $ENV{'NET-SNMP-IN-SOURCE'};
        undef ($ret{'prefix'});
      }
      elsif ($ENV{'NET-SNMP-PATH'})
      {
	$ret{'prefix'} = $ENV{'NET-SNMP-PATH'};
      }

      if ($ENV{'NET-SNMP-DEBUG'})
      {
	$ret{'debug'} = $ENV{'NET-SNMP-DEBUG'};
      }

      # Update environment variables in case they are needed
      $ENV{'NET-SNMP-IN-SOURCE'}    = $ret{'insource'};
      $ENV{'NET-SNMP-PATH'}         = $ret{'prefix'};
      $ENV{'NET-SNMP-DEBUG'}        = $ret{'debug'};

      $basedir = `%COMSPEC% /c cd`;
      chomp $basedir;
      $basedir =~ /(.*?)\\perl.*/;
      $basedir = $1;
      print "Net-SNMP base directory: $basedir\n";
      if ($basedir =~ / /) {
        die "\nA space has been detected in the base directory.  This is not " .
            "supported\nPlease rename the folder and try again.\n\n";
      }
    }
    else
    {
      if ($ENV{'NET-SNMP-CONFIG'} &&
        $ENV{'NET-SNMP-IN-SOURCE'}) {
	# have env vars, pull from there
	$ret{'nsconfig'} = $ENV{'NET-SNMP-CONFIG'};
	$ret{'insource'} = $ENV{'NET-SNMP-IN-SOURCE'};
      } else {
	# don't have env vars, pull from command line and put there
	GetOptions("NET-SNMP-CONFIG=s" => \$ret{'nsconfig'},
	           "NET-SNMP-IN-SOURCE=s" => \$ret{'insource'});

	if (lc($ret{'insource'}) eq "true" && $ret{'nsconfig'} eq "") {
	    $ret{'nsconfig'}="sh ROOTPATH../net-snmp-config";
	} elsif ($ret{'nsconfig'} eq "") {
	    $ret{'nsconfig'}="net-snmp-config";
	}

	$ENV{'NET-SNMP-CONFIG'}    = $ret{'nsconfig'};
	$ENV{'NET-SNMP-IN-SOURCE'} = $ret{'insource'};
      }
    }

    $ret{'nsconfig'} =~ s/ROOTPATH/$rootpath/;

    $ret{'rootpath'} = $rootpath;

    \%ret;
}

sub find_files {
    my($f,$d) = @_;
    my ($dir,$found,$file);
    for $dir (@$d){
	$found = 0;
	for $file (@$f) {
	    $found++ if -f "$dir/$file";
	}
	if ($found == @$f) {
	    return $dir;
	}
    }
}

