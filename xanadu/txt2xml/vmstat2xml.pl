#!/bin/perl -w
#!/usr/local/bin/perl -w

#
# Revision History:
#     01/10/24/zenon: Initial version
#

use lib "../txt2xml";

use txt2xml ;

#
# Plan:
# The "vmstat" output typically includes the following parts:
#
# 1. An initial line, which specifies the "interval", something like
#   "Vmstat must always be run at some interval. Using 10 secs ..."
#
#    Without the above (interval) line, we would assume default of 10 secs.
#
# Then many repeated groups (which contents is script dependent) follow:
#
# 2A. Group Titles, like
#       kthr   memory   page    disk   faults   cpu
#
# 2B. Group Headers, like
#   r b w   swap free   re mf pi po fr de sr   s0 s1 s6 s8   in sy cs   us sy id
#
# 3C. data numbers, corresponding to the headers above
#

$debug = 0;

#
# The Groups may have different members. For example the "page" group for
# the vmstat.92G.txt has "re mf pi po fr de st" headers, but for
# the vmstat.52b.txt there are only "re mf fr de sr"
#
# Because of this kind of differences, we maintain hashed Group lists, with all
# possible members/headers
#
%hash_group_list = ();
$hash_group_list{"kthr"."title"} = "Kernel Threads";
$hash_group_list{"kthr"."0"} = "r";
$hash_group_list{"kthr"."0L"} = "In Run Queue";
$hash_group_list{"kthr"."1"} = "b";
$hash_group_list{"kthr"."1L"} = "Blocked";
$hash_group_list{"kthr"."2"} = "w";  # from the vmstat.{92G,177G}.txt files
$hash_group_list{"kthr"."2L"} = "Runnable But Swapped";

$hash_group_list{"memory"."title"} = "Memory Usage";
$hash_group_list{"memory"."0"} = "swap";
$hash_group_list{"memory"."0L"} = "Swap Space Available";
$hash_group_list{"memory"."1"} = "free"; # from vmstat.{52b,92G,177G}.txt files
$hash_group_list{"memory"."1L"} = "Free List Size";

$hash_group_list{"page"."title"} = "Page Faults/Paging Activity";
$hash_group_list{"page"."0"} = "re";
$hash_group_list{"page"."0L"} = "Page Reclaims";
$hash_group_list{"page"."1"} = "mf";
$hash_group_list{"page"."1L"} = "Minor Faults";
$hash_group_list{"page"."2"} = "pi"; # not in vmstat.52b.txt
$hash_group_list{"page"."2L"} = "Paged In (kb)"; # not in vmstat.52b.txt
$hash_group_list{"page"."3"} = "po"; # not in vmstat.52b.txt
$hash_group_list{"page"."3L"} = "Paged Out (kb)"; # not in vmstat.52b.txt
$hash_group_list{"page"."4"} = "fr";
$hash_group_list{"page"."4L"} = "Freed (kb)";
$hash_group_list{"page"."5"} = "de";
$hash_group_list{"page"."5L"} = "Anticipaged Memory Shortfall";
$hash_group_list{"page"."6"} = "sr"; # from vmstat.{92G,177G}.txt
$hash_group_list{"page"."6L"} = "Pages Scanned";

  #
  # Special case: Patterns with regex
  #

$hash_group_list{"disk"."title"} = "Disk Operations/sec";
$hash_group_list{"disk"."0"} = "s[0-9]+";
$hash_group_list{"disk"."0L"} = "SCSI Disk"; # from vmstat.{92G,177G}.txt
$hash_group_list{"disk"."1"} = "i[0-9]+";
$hash_group_list{"disk"."1L"} = "IPI Disk";
$hash_group_list{"disk"."2"} = "sd";
$hash_group_list{"disk"."2L"} = "Photon Disk";
$hash_group_list{"disk"."3"} = "m[0-9]+";
$hash_group_list{"disk"."3L"} = "Meta Devices";
$hash_group_list{"disk"."4"} = "dd";
$hash_group_list{"disk"."4L"} = "Disk";
$hash_group_list{"disk"."5"} = "--";
$hash_group_list{"disk"."5L"} = "No Disk";

$hash_group_list{"faults"."title"} = "Trap/Interrupt Rates";
$hash_group_list{"faults"."0"} = "in";
$hash_group_list{"faults"."0L"} = "Interrupts";
$hash_group_list{"faults"."1"} = "sy";
$hash_group_list{"faults"."1L"} = "System Calls";
$hash_group_list{"faults"."2"} = "cs"; # from vmstat.{92G,177G}.txt
$hash_group_list{"faults"."2L"} = "Context Switches";

$hash_group_list{"cpu"."title"} = "CPU % Usage";
$hash_group_list{"cpu"."0"} = "us";
$hash_group_list{"cpu"."0L"} = "User Time";
$hash_group_list{"cpu"."1"} = "sy";
$hash_group_list{"cpu"."1L"} = "System Time";
$hash_group_list{"cpu"."2"} = "id"; # from vmstat.{92G,177G}.txt
$hash_group_list{"cpu"."2L"} = "Idle Time";

$hash_group_list{"executable"."title"} = "Executable Paging";
$hash_group_list{"executable"."0"} = "epi";
$hash_group_list{"executable"."0L"} = "Executable page-ins";
$hash_group_list{"executable"."1"} = "epo";
$hash_group_list{"executable"."1L"} = "Executable page-outs";
$hash_group_list{"executable"."2"} = "epf"; # from vmstat.52b.txt
$hash_group_list{"executable"."2L"} = "Executable page-frees";

$hash_group_list{"anonymous"."title"} = "Anonymous Paging";
$hash_group_list{"anonymous"."0"} = "api";
$hash_group_list{"anonymous"."0L"} = "Anonymous page-ins";
$hash_group_list{"anonymous"."1"} = "apo";
$hash_group_list{"anonymous"."1L"} = "Anonymous page-outs";
$hash_group_list{"anonymous"."2"} = "apf"; # from vmstat.52b.txt
$hash_group_list{"anonymous"."2L"} = "Anonymous page-frees";

$hash_group_list{"filesystem"."title"} = "Filesystem Paging";
$hash_group_list{"filesystem"."0"} = "fpi";
$hash_group_list{"filesystem"."0L"} = "File system page-ins";
$hash_group_list{"filesystem"."1"} = "fpo";
$hash_group_list{"filesystem"."1L"} = "File system page-outs";
$hash_group_list{"filesystem"."2"} = "fpf"; # from vmstat.52b.txt
$hash_group_list{"filesystem"."2L"} = "File system page-frees";

if ($debug) {
    @keys = keys %hash_group_list;
    $len = $#keys;
    print "hash_group_list len is $len, with the following keys:\n";
    for ($i=0; $i<=$len; $i++) {
        print "$i. $keys[$i]\n";
    }
}

#
# Define some variables and lists
#

@words = ();
$titles = 0;
$headers = 0;
% hash_long_headers = ();

#
# Get options 
#

while ($#ARGV > -1) {
    $arg = shift @ARGV;
    if ( $arg =~ /^-(.)(.*)$/ ) {
        $flag=$1; $val=$2;
        # $flag2=$flag.$val;
        if ( $flag eq "i" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $infile = $val;
        } elsif ($flag eq "o") {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $outfile = $val;
        } elsif ($flag eq "v") {
#            if ( $val ne "")  { &usage();}
#            $verbose = 1;
        } elsif ($flag eq "r") {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $runId = $val;
        } else { &usage(); }
    } elsif ( $arg =~ /^(.*)$/ ) {
        if (defined($infile)) {
            if (! defined($runId)) {
                $runId = $1;
            }
        } else {
            $infile = $1;
        }
    }
}

#
# Set some options, like "autoflash"
#

$| = 1;
$repeat_last_line = 0;

if (! defined $runId) {
    &usage();
}

if (defined $infile) {
    open(STDIN, "<$infile") || die "Could not open $infile\n";
}

if (defined $outfile) {
    open(STDOUT, ">$outfile") || die "Could not open $outfile\n";
}

#  $word = "[a-zA-Z,=0-9_-]+";
$smallword = "[a-zA-Z]+";
#  $num = "[0-9]+";
#  $perc = "[0-9]+\%";
#  $dec = "[0-9]+\.[0-9]+|[0-9]+|\.[0-9]+|[0-9]+\.";
#  $time = 0;

#
# Read the input data

#
# First, get to the line defining the "interval"
#

while ($line = &get_next_significant_line()) {
    if ($line =~ /interval/) {
        $interval = 0;
        @words = split(/\s+/,$line) ;
        for ($i=0; $i<$#words; $i++) {
            if ($words[$i] eq 'Using') {
                $interval = $words[$i + 1];
                last;
            }
        }
        die "Cannot find interval definition\n" if ($interval == 0);
    } else {
#
# Old/original version assumed to have the line defining "interval".
# Now we accept to begin with the data, taking default interval of 10 secs
#
##        die "Expected line containing the word 'interval', not $line\n";
      $interval = 10;
      $repeat_last_line = 1;
    }
    last;
}

#
# Now, read the groups
#

while ($line = &get_next_significant_line()) {
    if ($titles == 0) {
        @titles = split(/\s+/,$line) ;
        $titles[0] = "kthr" if ($titles[0] eq "procs");
        $titles = 1;
    }
    if (! ($line = &get_next_significant_line()) ) {  # EOF ??
        die "Premature EOF on input data\n";
    }
    if ($headers == 0) {
        @headers = split(/\s+/,$line) ;
        $headers = 1;
    }
    while ($line = &get_next_significant_line()) {
        @words = split(/\s+/,$line) ;
            ## print "from words0=$words[1]\n";
        if ($words[1] =~ /$smallword/) {
            $repeat_last_line = 1;
            last;
        } else {
            ## print "from line=$line\n";
	    for ($i = 0; $i <= $#words; $i++) {
	        push @{$data[$i]}, $words[$i];
            }
        }
    }
}

if ($debug) {
    print "titles = @titles\n";
    $tlen = $#titles;
    for ($i=0; $i<=$tlen; $i++) {
        print "Group $titles[$i]:\n";
        $j=0;
        while (1) {
            $key = $titles[$i] . "$j";
            if (exists $hash_group_list{$key}) {
                print "header$j: $hash_group_list{$key}\n";
            } else {
                $hash_group_list{$titles[$i] . "len"} = $j;
                print "$j headers total\n";
                last;
            }
            $j++;
        }
    }
}

if ($debug) {
    print "headers = @headers\n";
    for ($i=0; $i<=$#headers; $i++) {
        print "data=@{$data[$i]}\n";
    }
}

&prepare_header_limits();

&generate_xml();

exit (0);

# end of MAIN


sub usage
{
    $prog = $0;
    $prog =~ s/.*\///;
    print "
    usage : $prog [-i <infile>] [-o <outfile>] [-v] [-r <runId>] [<infile>] [<ru
nId>]
    -i <name>: input file name
    -o <name>: output file name
    -r <runId>: Run Identifier
    -v : turn on verbose

    Without input/output files specified, the 'stdin' and 'stdout' will be used.
    \n";

    exit 1;
}

sub get_next_significant_line
{
    if ($repeat_last_line == 1) {
        if ($debug) {
            print "repeat_last_line is set, so returning the last line ...\n";
        }
        $repeat_last_line = 0;
        return $line;
    }
    while (defined($next_line = <STDIN>)) {
        chomp($next_line);
        if ($next_line =~ /^\s*\Z/ || $next_line =~ /components/i) {
            next;
        }
        # skip the leading whitespace
        $next_line =~ s/^\s+//;
        return $next_line;
    }
    return undef;
}

#
# ===============================================
#        XML generation

sub generate_xml
{
    if ($debug) {print "Generating XML:\n";}
    #PRINTING PHASE!
    xml_start_stat_doc(name => "\"Vmstat\"");
    #print all the aggregate stats

    # Print the runId
    xml_meta(name => "\"RunId\"", value => "\"$runId\"");

    # Print the interval
    xml_meta(name => "\"interval\"", value => "\"$interval\"");

    # Get number of samples, taking it from any column (here: from column 0)
    $samples = $#{$data[0]};
    if ($debug) {
        print "SAMPLES=$samples\n";
    }

    foreach $title (@titles) {
        $title_str = '"'.$hash_group_list{$title."title"}.'"';
        xml_start_stat_group(name => "$title_str", display => "\"gnuplot-png\"");
        #
        # get list of headers for this title
        # For title=kthr headers are between 0 and 2
        #
        $hmin = $hash_group_list{$title."hmin"};
        $hmax = $hash_group_list{$title."hmax"};
        xml_start_cell_list();
        for ($i=0; $i<$samples; $i++) {
            for ($header=$hmin; $header <= $hmax; $header++) {
	        xml_start_cell();
                print "${$data[$header]}[$i]";
	        xml_end_cell();
            }
        }
        xml_end_cell_list();

        xml_start_dim_list();
        xml_start_dim(name => $title_str);
            for ($header=$hmin; $header <= $hmax; $header++) {
	        xml_start_dimval();
	        # print "$headers[$header]";
                $long_header = $hash_long_headers{$title."hdr".$header};
	        print "$long_header";
	        xml_end_dimval();
            }
        xml_end_dim();

        xml_start_dim(name => '"Time (s)"');
        for ($i = 0; $i <$samples; $i++)
        {
            xml_start_dimval();
            printf "%d", $i * $interval;
            xml_end_dimval();
        }
        xml_end_dim();

        xml_end_dim_list();

        xml_end_stat_group();
    }

    xml_end_stat_doc();
}

sub prepare_header_limits
{
    $offset = 0;
    foreach $title (@titles) {
        #
        # get the number of header options, from the @hash_group_list
        #
        $j=0;
        while (1) {
            $key = $title . "$j";
            if (! exists $hash_group_list{$key}) {
                $hash_group_list{$title . "len"} = $j;
                # print "$j headers total for $title\n";
                last;
            }
            $j++;
        }

        #
        # begin from the $offset on the @headers list and identify the limits
        # comparing with all possible header options
        #
        $hash_group_list{$title . "hmin"} = -1;
        $hash_group_list{$title . "hmax"} = -1;
        $found = 0;
        for ($i=$offset; $i<=$#headers; $i++) {
            $found = 0;
            for ($j=0; $j<$hash_group_list{$title . "len"}; $j++) {
                $hoption = $hash_group_list{$title."$j"};
                # print "comparing $headers[$i] with $hoption\n";
                if ($headers[$i] =~ /^$hoption\Z/) {
                    $found = 1;
                    if ($title eq "disk") {
                        $hash_long_headers{$title . "hdr$i"} =
                            $hash_group_list{$title."${j}L"}."/".$headers[$i];
                    } else {
                        $hash_long_headers{$title . "hdr$i"} =
                            $hash_group_list{$title."${j}L"};
                    }
                    last;
                }
            }
            if (! $found) {
                if ($hash_group_list{$title . "hmin"} == -1) {
                    next;
                }
                $offset = $i;
                # print "No more MATCHES; New group.\n";
                last;
            } else {
                if ($hash_group_list{$title . "hmin"} == -1) {
                    $hash_group_list{$title . "hmin"} = $i;
                }
                $hash_group_list{$title . "hmax"} = $i;
            }
        }
        $hmin = $hash_group_list{$title . "hmin"};
        $hmax = $hash_group_list{$title . "hmax"};
        if ($debug) {
            print "for group $title: hmin=$hmin, hmax=$hmax\n";
        }
        if ($hmin == -1 || $hmax == -1) {
            die "Didn\'t find header limits for $title group.\n";
        }
    }
}
