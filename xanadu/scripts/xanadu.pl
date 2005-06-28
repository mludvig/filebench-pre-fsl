#!/usr/bin/perl -w

use Cwd;
use File::Basename;


sub syntax()
{
    print "\nUsage:\t xanadu [import|export|compare|average] arguments ...\n";
    print "\nor\n\n\t xanadu [-i|-e|-c|-a] -s srcdir(s) -d dstdir [-r runid] ...\n";
    exit;
}


$option="";
$src="";
$osrcs = $srcs="";
$dst="";
$last_arg="";
$runId="";
$debug=0;
$cwd=getcwd;

if (defined($ENV{"XANADU_HEAP"})) {
    $xanadu_heap = $ENV{"XANADU_HEAP"};
}
else {
    $xanadu_heap = 256;
}
$xanadu_heap = "-mx${xanadu_heap}m";

if (defined($ENV{"XANADU_HOST"})) {
    $xanadu_host = $ENV{"XANADU_HOST"};
}
else {
    $xanadu_host = "romulus.sfbay.sun.com";
}

$xanadu_home = "..";
$xanadu_url = "http://$xanadu_host/xanadu/xc?action=view&file=";
$xanadu_defines=" -Dxanadu.url=$xanadu_url -Dxanadu.basedir=$xanadu_home -Djava.awt.headless=true ";

if ($^O eq 'MSWin32') {
    $classpath = "$xanadu_home/WEB-INF/classes;$xanadu_home/WEB-INF/lib/servlet-api.jar;$xanadu_home/WEB-INF/lib/jaxb-rt-1.0-ea.jar;$xanadu_home/WEB-INF/lib/jfreechart.jar;$xanadu_home/WEB-INF/lib/jcommon.jar";
} else {
    $classpath = "$xanadu_home/WEB-INF/classes:$xanadu_home/WEB-INF/lib/servlet-api.jar:$xanadu_home/WEB-INF/lib/jaxb-rt-1.0-ea.jar:$xanadu_home/WEB-INF/lib/jfreechart.jar:$xanadu_home/WEB-INF/lib/jcommon.jar";
}
#
# Options should be decoded to "import", "export", "compare" or "average"
#


$argc=$#ARGV + 1;

&syntax if $argc < 1;

while ($argc > 0) {
    $_ = $ARGV[0];
    # Outer switch

    if (/^-.*/) { 

	INNER_SWITCH: {
	    if ($_ eq '-i') { $option = 'import'; last INNER_SWITCH; }
	    if ($_ eq '-e') { $option = 'export'; last INNER_SWITCH; }
	    if ($_ eq '-c') { $option = 'compare'; last INNER_SWITCH; }
	    if ($_ eq '-a') { $option = 'average'; last INNER_SWITCH; }

	    if ($_ eq '-s') { 
		$src = $ARGV[1];

		$srcs="$srcs $src";

		shift(@ARGV);
		$argc--;

		last INNER_SWITCH; 
	    }

	    if ($_ eq '-d') { 
		$dst = $ARGV[1];

		shift(@ARGV);
		$argc--;

		last INNER_SWITCH; 
	    }
	    

	    if ($_ eq '-r') { 
		$runId = $ARGV[1];

		shift(@ARGV);
		$argc--;

		last INNER_SWITCH; 
	    }

	    if ($_ eq '-v') { 
		$debug = 1;
		last INNER_SWITCH; 
	    }
	}

      } else {
	  if (length($option) == 0) {
	      $option = $_;
	  }
	  elsif ($option eq 'average') {
	      $osrcs = $srcs;
	      if ($argc == 2) {
		  $last_arg = $_;
		  $dst = $_;
		  $runId = $ARGV[1];
		  $argc = 0;
	      } else {
		  $srcs = $_;
	      }
	  } elsif ($option eq 'compare') {
	      $osrcs = $srcs;
	      $last_arg = $_;
	      if (length($srcs) > 0) {
		  $srcs = "$srcs $_";
	      } else {
		  $srcs = $_;
	      }

	  } elsif (length($src) == 0) {
	      $src = $_;

	      $srcs = "$srcs $src";

	  } elsif (length($dst) == 0) {
	      $dst = $_;

	  } elsif ($option eq 'import' && length($runId) == 0) {
	      $runId = $_;
	  } else {
	      print STDERR "Unexpected Argument $_\n";
	      $argc = 0;
	  }	  
      }

    $argc--;
    shift(@ARGV);
#    print "$argc\t$ARGV[0]\n";
}

print "option=$option src=$src srcs=$srcs dst=$dst runId=$runId\n" if $debug;


#
# In case of "relative" path, convert it to an absolute path
#

if (length($src) > 0) {
    $src = "$cwd/$src" unless $src =~ /^\//;
}

if (length($dst) == 0) {
    if (length($osrcs) > 0) {
	$srcs = $osrcs;
	$dst = $last_arg;
    }
}

$dst = "$cwd/$dst" unless $dst =~ /^\//;

$srcs2 = '';
@srcfields = split(/\s+/, $srcs);

foreach $s (@srcfields) {
    if ($s =~ /^\//) {
	$srcs2 = "$srcs2 $s";
    } else {
	$srcs2 = "$srcs2 $cwd/$s";
    }
}
$srcs = $srcs2;

print "option=$option src=$src srcs=$srcs dst=$dst runId=$runId\n" if $debug;



$home_dir=dirname($0);
chdir($home_dir); # Needed by import.pl as it references ../txt2xml
                  # Also classpath is relative

#
# Now, do the job
#

if ($option eq 'import') {
    if (length($src) == 0 || length($dst) == 0 || length($runId) == 0) {
	print "\nUsage:\t xanadu import srcdir(TXT) dstdir(XML) runId\n\n";
	print "or\n";
	print "\nUsage:\t xanadu -i -s srcdir(TXT) -d dstdir(XML) -r runId\n\n";
	exit;
    }

    $cmdstr = "perl $home_dir/import.pl -b $src $dst $runId";
    print "$cmdstr\n";
    system($cmdstr);

} elsif ($option eq 'export') {
    if (length($src) == 0 || length($dst) == 0) {
	print "\nUsage:\t xanadu export srcdir(XML) dstdir(HTML)\n\n";
	print "or\n";
	print "\nUsage:\t xanadu -e -s srcdir(XML) -d dstdir(HTML)\n\n";
	exit;
    }

    $_ = "java $xanadu_heap -classpath $classpath $xanadu_defines org.xanadu.cmd.ExportFromXML $src $dst";
    print "$_\n";
    system(split);

} elsif ($option eq 'compare') {
    if (length($srcs) == 0 || length($dst) == 0) {
	print "\nUsage:\t xanadu compare srcdir1(XML) srcdir2(XML) dstdir(HTML)\n\n";
	print "or\n";
	print "\nUsage:\t xanadu -c -s srcdir1(XML) srcdir2(XML)  -d dstdir(HTML)\n\n";
	exit;
    }

    $_ = "java $xanadu_heap -classpath $classpath $xanadu_defines org.xanadu.cmd.CompareXML $srcs $dst";
    print "$_\n";
    system(split);

} elsif ($option eq 'average') {
    if (length($srcs) == 0 || length($dst) == 0) {
	print "\nUsage:\t xanadu average srcdir1(XML) srcdir2(XML) srcdir3(XML) dstdir(XML)\n\n";
	print "or\n";
	print "\nUsage:\t xanadu -a -s srcdir1(XML) srcdir2(XML) srcdir3(XML)  -d dstdir(XML)\n\n";
	exit;
    }

    $cmdstr = "java $xanadu_heap -classpath $classpath $xanadu_defines org.xanadu.cmd.CompareXML $srcs $dst";
    print "$cmdstr\n";
    system($cmdstr);
}
