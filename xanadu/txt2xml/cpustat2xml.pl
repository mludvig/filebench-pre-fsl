#!/bin/perl -w
#!/usr/local/bin/perl -w

#
# Revision History:
#     01/10/16/zenon: Initial version
#

use lib "../txt2xml";

use txt2xml ;

#
# Plan:
# The "cpustat" output from the Paul's script generates the following sections:
# 1. "CPU statistics"  (when the $cpuonly flag is set)
# 2A."CPU user mode statistics"  (when the $ukonly flag is set)
# 2B."CPU kernel mode statistics" ( as above )
# 2C."Memory Banks Statistics"    ( as above, for HA3 )
# 3A."Gigaplane Bus Statistics"  (when the $aconly flag is set)
# 3B."Memory Banks Statistics"   (as above, for HA2)
# 4. "Sbus I/O Bus Statistics"   (when the $sysioonly flag is set)
#
# The outputs for "ha2" (the SunFire) and "ha3" (the Serengeti) differ in
# some details, which will be scanned for to be recognized asap.
# One of the known detail difference is the early print_cpu_cpi info line,
# which looks like follows:
# "CPI      LdUse   IcMiss  BrMiss  StBuf   RaW     FpUse" for the SunFire
# "CPI     Data_Stall   IcMiss     BrMiss  FpUse"          for the Serengeti
#

#
# Define some variables and lists
#

@allMetrics = ();
%hash_aggregate_list = ();
@allGigaplaneMetrics = ();
@allGigaplaneValues = ();
@SbusMetrics = ();
@SbusValues = ();
%hash_percpu_list = ();
%hash_memory_list = ();
@allModes = ();
@allCpuModes = ();

#
# Get options 
#

while ($#ARGV > -1) {
    $arg = shift @ARGV;
    if ( $arg =~ /^-(.)(.*)$/ ) {
        $flag=$1; $val=$2;
        # print "flag=$flag, val=$val\n";
        if ( $flag eq "i" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $infile = $val;
        } elsif ($flag eq "o") {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $outfile = $val;
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
$debug = 0;

if (defined $infile) {
    open(STDIN, "<$infile") || die "Could not open $infile\n";
}

if (defined $outfile) {
    open(STDOUT, ">$outfile") || die "Could not open $outfile\n";
}

#  $word = "[a-zA-Z,=0-9_-]+";
#  $smallword = "[a-zA-Z]+";
$num = "\-?[0-9]+";
#  $perc = "[0-9]+\%";
#  $dec = "[0-9]+\.[0-9]+|[0-9]+|\.[0-9]+|[0-9]+\.";
#  $time = 0;

#
# Read the input data
#

# We will try to identify the $type asap, to use proper parsing subroutines

$type0="SunFire";
$type1="Serengeti";
$type="unknown";

$mode="unknown";


# Read all input data:

while ($line = &get_next_significant_line()) {

    if ($line =~ /statistics/i ) {
        $mode="unknown";
        if ($line =~ /CPU statistics/i) {                     #  "TOTALmode"
            # $mode="CPUmode";
            $mode="Total";
            if ($debug) {print "MODE=$mode\n";}
            push (@allModes,$mode);

            # Get the next line to proceed with the cpu_cpi_info
            # In the "CPUmode" we will identify also the processor type

            if (! ($line = &get_next_significant_line()) ) {  # EOF ??
                die "Premature EOF on input data\n";
            }
            if ($line =~ /CPI\s+LdUse\s+IcMiss\s+BrMiss\s+StBuf\s+RaW\s+FpUse/){
                $type = $type0;    # "SunFire"
            } elsif ($line =~ /CPI\s+Data_Stall\s+IcMiss\s+BrMiss\s+FpUse/) {
                $type = $type1;    # "Serengeti"
            } else {
                die "Unknown system type";
            }

            # Known here: Either "Serengeti" or "SunFire" type
            if ($type eq $type0) {   # "SunFire"
                &get_per_cpu_info();
                &get_mips_aggregate_info();
                &get_mips_percpu_info();
                &get_cpu_cache_stats_info();
            } elsif ($type eq $type1) {   # "Serengeti"
                &get_cpu_cpi_info();
                &get_data_stall_components_info();
                &get_per_cpu_info();
                &get_mips_aggregate_info();
                &get_mips_percpu_info();
                &get_cpu_cache_stats_info();
            }

            # Re-use the last line from the STDIN
            $repeat_last_line = 1;

        } elsif ($line =~ /CPU user mode statistics/i) {      # "USERmode"
            # $mode="USERmode";
            $mode="User";
            if ($debug) {print "MODE=$mode\n";}
            push (@allModes,$mode);

            # Get the next line to proceed with the cpu_cpi_info
            if (! ($line = &get_next_significant_line()) ) {  # EOF ??
                die "Premature EOF on input data\n";
            }

            if ($type eq $type0) {   # "SunFire"
                &get_per_cpu_info();
                &get_mips_aggregate_info();
                &get_mips_percpu_info();
                &get_cpu_cache_stats_info();
            } elsif ($type eq $type1) {   # "Serengeti"
                &get_cpu_cpi_info();
                &get_data_stall_components_info();
                &get_per_cpu_info();
                &get_mips_aggregate_info();
                &get_mips_percpu_info();
                &get_cpu_cache_stats_info();
            }

            # Re-use the last line from the STDIN
            $repeat_last_line = 1;

        } elsif ($line =~ /CPU kernel mode statistics/i) {   # "KERNELmode"
            # $mode="KERNELmode";
            $mode="Kernel";
            if ($debug) {print "MODE=$mode\n";}
            push (@allModes,$mode);

            # Get the next line to proceed with the cpu_cpi_info
            if (! ($line = &get_next_significant_line()) ) {  # EOF ??
                die "Premature EOF on input data\n";
            }

            if ($type eq $type0) {   # "SunFire"
                &get_per_cpu_info();
                &get_mips_aggregate_info();
                &get_mips_percpu_info();
                &get_cpu_cache_stats_info();
            } elsif ($type eq $type1) {   # "Serengeti"
                &get_cpu_cpi_info();
                &get_data_stall_components_info();
                &get_per_cpu_info();
                &get_mips_aggregate_info();
                &get_mips_percpu_info();
                &get_cpu_cache_stats_info();
            }

            # Re-use the last line from the STDIN
            $repeat_last_line = 1;

        } elsif ($line =~ /Memory Banks Statistics/i) {    # "MEMORYmode"
            $mode="MEMORYmode";
# "MEMORY" mode was not used in original cpustat2xml.pl conversion
#            push (@allModes,$mode);

            &get_memory_bank_stats_info();

        } elsif ($line =~ /Gigaplane Bus Statistics/i) {    # "GIGAPLANEmode"
            $mode="GIGAPLANEmode";
            if ($debug) {print "MODE=$mode\n";}
#            push (@allModes,$mode);

            &get_gigaplane_info();

            $repeat_last_line = 1;
        } elsif ($line =~ /Sbus I\/O Bus Statistics/i) {    # "SBUSmode"
            $mode="SBUSmode";
            if ($debug) {print "MODE=$mode\n";}
#            push (@allModes,$mode);

            &get_sbus_info();

            $repeat_last_line = 1;
        } else {
            die "Unknown line type at $line\n";
        }
        if ($debug) {
            print "With Line=$line\n";
            print "End of mode=$mode\n";
        }
    } # "statistics" line
}

&generate_xml();

exit (0);

# end of MAIN


sub usage
{
    $prog = $0;
    $prog =~ s/.*\///;
    print "
    usage : $prog [-i <infile>] [-o <outfile>] [-v] [-r <runId>] [<infile>] [<runId>]
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
        if ($next_line =~ /^\s*\Z/ || $next_line =~ /--/ ||
                $next_line =~ /components/i) {
            next;
        }
        # skip the leading whitespace
        $next_line =~ s/^\s+//;
        return $next_line;
    }
    return undef;
}

sub get_cpu_cpi_info
{
    if ($debug) {print "-> in get_cpu_cpi_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
        } elsif (/$type1/) {
            if ($debug) {print "We are in Serengeti case\n";}
            @metricList = split(/\s+/,$line) ;
            $numMetrics = $#metricList + 1;
            if ($debug) {print "metriclist= @metricList\n";}
            if ($metricList[0] ne "CPI") {
                die "Unexpected line $line\n";
            }
#            for( $i=0 ; $i < $numMetrics ; $i++) {
#                if ($metricList[$i] eq "IcMiss") {
#                    $metricList[$i]= "IcMisses" ;
#                }
#            }
            while ($line = &get_next_significant_line()) {
                if ($line =~ /^\s*($num)/) {
                    @metricValueList = split(/\s+/,$line) ;
                    if ($debug) {print "metricValueList= @metricValueList\n";}
                    &add_metrics_and_values();
                } else {
                    if ($debug) {print "Breaking at line=$line\n";}
                    # $repeat_last_line = 1;
                    last;
                }
            }
            return;
        } else {
            die "Unknown system type $type\n";
        }
    }
}

sub get_data_stall_components_info
{
    if ($debug) {print "-> in get_data_stall_components_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
        } elsif (/$type1/) {
            if ($debug) {print "We are in Serengeti case\n";}
            @metricList = split(/\s+/,$line) ;
            $numMetrics = $#metricList + 1;
            if ($debug) {print "metriclist= @metricList\n";}
            unless ($line =~ /Dmiss_stall/) {
                die "Unexpected line $line\n";
            }
#            for( $i=0 ; $i < $numMetrics ; $i++) {
#                if ($metricList[$i] eq "IcMiss") {
#                    $metricList[$i]= "IcMisses" ;
#                }
#            }
            while ($line = &get_next_significant_line()) {
                if ($line =~ /^\s*($num)/) {
                    @metricValueList = split(/\s+/,$line) ;
                    if ($debug) {print "metricValueList= @metricValueList\n";}
                    &add_metrics_and_values();
                } else {
                    if ($debug) {print "Breaking at line=$line\n";}
                    # $repeat_last_line = 1;
                    last;
                }
            }
            return;
        } else {
            die "Unknown system type $type\n";
        }
    }
}

sub get_per_cpu_info
{
    if ($debug) {print "-> in get_per_cpu_info:\n";}

    push (@allCpuModes, $mode);

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
            @metricList = split(/\s+/,$line) ;
            $len = $#metricList + 1;
            if ($debug) {print "metriclist= @metricList\n";}
            if ($metricList[0] ne "CPI") {
                die "Unexpected line $line\n";
            }
            $found = 0;
            foreach $metrics (@percpuMetrics) {
                if ($metrics eq "CPI") {
                    $found = 1;
                    last;
                }
            }
            if ($found == 0) {
                push (@percpuMetrics, @metricList);
            }
            #
            # First data line contains the aggregate info
            #
            $line = &get_next_significant_line();
            if ($line =~ /^\s*($num)/) {
                @metricValueList = split(/\s+/,$line) ;
                $len = $#metricValueList + 1;
                if ($debug) {print "metricValueList= @metricValueList\n";}
                &add_metrics_and_values();
            } else {
                die "expecting a raw of numbers after the @metricList\n";
            }
            while ($line = &get_next_significant_line()) {
                if ($line =~ /^\s*($num)/) {
                    @metricValueList = split(/\s+/,$line) ;
                    $len = $#metricValueList + 1;
                    if ($debug) {print "metricValueList= @metricValueList\n";}
                    #
                    # We assume: the CPU id is at the end, and in parentheses
                    #
		    $cpuId = $metricValueList[$len - 1];
		    $cpuId =~ s/\(// ;
		    $cpuId =~ s/\)// ;
                    # print "cpuId=$cpuId\n";
                    &add_metrics_and_percpu_values();
                } else {
                    if ($debug) {print "Breaking at line=$line\n";}
                    # $repeat_last_line = 1;
                    last;
                }
            }
            return;
        } elsif (/$type1/) {
            if ($debug) {print "We are in Serengeti case\n";}
            @metricList = split(/\s+/,$line) ;
            $len = $#metricList + 1;
            if ($debug) {print "metriclist= @metricList\n";}
            if ($metricList[0] ne "CPI") {
                die "Unexpected line $line\n";
            }
            $found = 0;
            foreach $metrics (@percpuMetrics) {
                if ($metrics eq "CPI") {
                    $found = 1;
                    last;
                }
            }
            if ($found == 0) {
                push (@percpuMetrics, @metricList);
            }
            while ($line = &get_next_significant_line()) {
                if ($line =~ /^\s*($num)/) {
                    @metricValueList = split(/\s+/,$line) ;
                    $len = $#metricValueList + 1;
                    if ($debug) {print "metricValueList= @metricValueList\n";}
                    #
                    # We assume: the CPU id is at the end, and in parentheses
                    #
		    $cpuId = $metricValueList[$len - 1];
		    $cpuId =~ s/\(// ;
		    $cpuId =~ s/\)// ;
                    # print "cpuId=$cpuId\n";
                    &add_metrics_and_percpu_values();
                } elsif ($line =~ /^\s*\($num\)/) {
                    if ($debug) {print "Empty CPU info: $line (skipped)\n";}
                    next;
                } else {
                    if ($debug) {print "Breaking at line=$line\n";}
                    # $repeat_last_line = 1;
                    last;
                }
            }
            return;
        } else {
            die "Unknown system type $type\n";
        }
    }
}

sub get_mips_aggregate_info
{
    if ($debug) {print "-> in get_mips_aggregate_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
            # example: "MIPS"
            #          "1098"
            #          "cpu_number 13  147"
            #          ....
            @metricList = split(/\s+/,$line) ;
            if ($metricList[0] ne "MIPS") {
                die "Expected \"MIPS\" not $metricList[0] in $line\n";
            }
            $numMetrics = $#metricList + 1;
            $line = &get_next_significant_line();
            @metricValueList = split(/\s+/,$line) ;
            if ($debug) {print "metricValueList= @metricValueList\n";}
            &add_metrics_and_values();
            return;
        } elsif (/$type1/) {
            if ($debug) {print "We are in Serengeti case\n";}
            # example: "MIPS  3968   TPS   4195.93   M-Instr/Txn  0.9457"
            @lineSplit = split(/\s+/,$line) ;
            @metricList = ( $lineSplit[0], $lineSplit[2], $lineSplit[4] );
            $numMetrics = $#metricList + 1;
            if ($debug) {print "metriclist= @metricList\n";}
            @metricValueList = ( $lineSplit[1], $lineSplit[3], $lineSplit[5] );
            if ($debug) {print "metricValueList= @metricValueList\n";}
            &add_metrics_and_values();
            return;
        } else {
            die "Unknown system type $type\n";
        }
    }
}

sub get_mips_percpu_info
{
    if ($debug) {print "-> in get_mips_per_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
            $per_cpu_count = 0;
            while ($line = &get_next_significant_line()) {
                if ($debug) {print "line=$line\n";}
                if ($line =~ /^\s*cpu_number/) {
                    $per_cpu_count++;
		    @perCpuList = split(/\s+/,$line) ;
                    &add_percpu_mips();
                } else {
                    if ($per_cpu_count == 0) {
                        #
                        # Data missing for USER and KERNEL modes
                        #
                        &make_empty_percpu();
                    }
                    if ($debug) {print "Breaking at line=$line\n";}
                    last;
                }
            }
            return;
        } elsif (/$type1/) {
            if ($debug) {print "We are in Serengeti case\n";}
            while ($line = &get_next_significant_line()) {
                if ($debug) {print "line=$line\n";}
                if ($line =~ /^\s*CPU/) {
		    @perCpuList = split(/\s+/,$line) ;
                    &add_percpu_mips();
                } else {
                    if ($debug) {print "Breaking at line=$line\n";}
                    last;
                }
            }
            return;
        } else {
            die "Unknown system type $type\n";
        }
    }
}

sub get_cpu_cache_stats_info
{
    if ($debug) {print "-> in get_cpu_cache_stats_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
            @metricList = split(/\s+/,$line) ;
            #
            # truncate the "DrtyRd" (the last on the list)
            #
            if ( $metricList[$#metricList] eq "DrtyRd" ) {
                $#metricList--;
            }
            $numMetrics = $#metricList + 1;
            if ($metricList[0] ne "IcMiss") {
                die "Unexpected line $line\n";
            }
            for( $i=0 ; $i < $numMetrics ; $i++) {
                if ($metricList[$i] eq "IcMiss") {
                    $metricList[$i]= "IcMiss%" ;
                } elsif ($metricList[$i] eq "DcMiss") {
                    $metricList[$i]= "DcMiss%" ;
                } elsif ($metricList[$i] eq "EcMiss") {
                    $metricList[$i]= "EcMiss%" ;
                }
            }
            if ($debug) {print "metriclist= @metricList\n";}
            #
            # first numeric row contains totals
            # ... but may need splitting in "User" mode
            #
            $splitIndex = -1;
            $line = &get_next_significant_line();
            if ($line =~ /^\s*$num/) {
                @metricValueList = split(/\s+/,$line) ;
                $len = $#metricValueList + 1;
                @metricValueListSplit = ();
                if ($mode eq "User") {
                    for ($i=0; $i<$len; $i++) {
                        if ($metricValueList[$i] =~ /\%/) {
                        } else {
                            $splitIndex = $i;
                            last;
                        }
                    }
                    if ($splitIndex > -1) {
                        for ($i=$splitIndex; $i<$len; $i++) {
                            push(@metricValueListSplit, $metricValueList[$i]);
                        }
                        $#metricValueList = $splitIndex - 1;
                        if ($debug) {
                            print "truncated metricValueList=@metricValueList\n";
                            print "truncated metricValueListSplit=@metricValueListSplit\n";
                        }
                    }
                }
                if ($debug) {
                    print "metricValueList= ";
                    for( $i=0 ; $i < $#metricValueList + 1 ; $i++) {
                        print "$metricValueList[$i] ";
                    }
                    print "\n";
                }
                &add_metrics_and_values();
            } else {
                die "Expected numeric values instead of $line\n";
            }
            if ($splitIndex > -1) {
                @metricValueList = @metricValueListSplit;
                $len = $#metricValueList + 1;
                if ($debug) {print "metricValueList= @metricValueList\n";}
                #
                # We assume: the CPU id is at the end, and in parentheses
                #
		$cpuId = $metricValueList[$len - 1];
		$cpuId =~ s/\(// ;
		$cpuId =~ s/\)// ;
                # print "cpuId=$cpuId\n";
                &add_metrics_and_percpu_misses();
            }
            while ($line = &get_next_significant_line()) {
                if ($line =~ /^\s*$num/) {
                    @metricValueList = split(/\s+/,$line) ;
                    $len = $#metricValueList + 1;
                    if ($debug) {print "metricValueList= @metricValueList\n";}
                    #
                    # We assume: the CPU id is at the end, and in parentheses
                    #
		    $cpuId = $metricValueList[$len - 1];
		    $cpuId =~ s/\(// ;
		    $cpuId =~ s/\)// ;
                    # print "cpuId=$cpuId\n";
                    &add_metrics_and_percpu_misses();
                } else {
                    if ($debug) {print "Breaking at line=$line\n";}
                    last;
                }
            }
            return;
        } elsif (/$type1/) {
            if ($debug) {print "We are in Serengeti case\n";}
            @metricList = split(/\s+/,$line) ;
            $numMetrics = $#metricList + 1;
            if ($debug) {print "metriclist= @metricList\n";}
            if ($metricList[0] ne "IcMissTotal" &&
		$metricList[0] ne "IcMssTot") {
                die "Unexpected line $line\n";
            }
            for( $i=0 ; $i < $numMetrics ; $i++) {
                if ($metricList[$i] eq "IcMiss") {
                    $metricList[$i]= "IcMiss%" ;
                }
            }
            while ($line = &get_next_significant_line()) {
                if ($line =~ /^\s*$num/) {
                    @metricValueList = split(/\s+/,$line) ;
                    if ($debug) {print "metricValueList= ";}
                    for( $i=0 ; $i < $#metricValueList + 1 ; $i++) {
                        if ($debug) {print "$metricValueList[$i] ";}
                    }
                    if ($debug) {print "\n";}
                    &add_metrics_and_values();
                } else {
                    if ($debug) {print "Breaking at line=$line\n";}
                    last;
                }
            }
            return;
        } else {
            die "Unknown system type $type\n";
        }
    }
}

sub get_memory_bank_stats_info
{
    if ($debug) {print "-> in get_memory_bank_stats_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
            while ($line = &get_next_significant_line()) {
                if ($line =~ /Board/) {
                    @metricList = split(/\s+/,$line) ;
                    for ($i=2; $i<=$#metricList; $i++) {
                        push(@memoryMetrics,$metricList[$i]) ;
                    }
                    ## push(@memoryMetrics,$metricList[4]) ;
                    ## push(@memoryMetrics,$metricList[5]) ;
                    ## push(@memoryMetrics,$metricList[2]) ;
                    ## push(@memoryMetrics,$metricList[3]) ;
                } else {
                    if ($line =~ /Total/) {
                        @list = split(/\s+/,$line);
                        ## $totalMrd=$list[1];
                        ## $totalMwr=$list[2];
                        last;
                    } else {
                        @valueList = split(/\s+/,$line) ;
                        $boardNum = $valueList[0] ;
                        $found = 0;
                        foreach $num (@boardList) {
                            if ($boardNum == $num) {
                                $found = 1;
                            }
                        }
                        if ( $found != 1) {
                            push (@boardList, $boardNum);
                            $found = 0;
                        }
                        $bankNum = $valueList[1] ;
                        $found = 0;
                        foreach $num (@bankList) {
                            if ($bankNum == $num) {
                                $found = 1;
                            }
                        }
                        if ( $found != 1) {
                            push (@bankList, $bankNum);
                            $found = 0;
                        }
                        for ($i=0; $i<=$#memoryMetrics; $i++) {
                            $hash_memory_list{$valueList[0].$valueList[1].$memoryMetrics[$i]}=$valueList[$i+2];
                        }
                        # $hash_memory_list{$valueList[0].$valueList[1].$metricList[4]}=$valueList[4];
                        # $hash_memory_list{$valueList[0].$valueList[1].$metricList[5]}=$valueList[5];
                        # $hash_memory_list{$valueList[0].$valueList[1].$metricList[2]}=$valueList[2];
                        # $hash_memory_list{$valueList[0].$valueList[1].$metricList[3]}=$valueList[3];

                    }
                }
            }
        } elsif (/$type1/) {
            if ($debug) {print "We are in Serengeti case\n";}
            while ($line = &get_next_significant_line()) {
                if ($line =~ /Bank/) {
                    @metricList = split(/\s+/,$line) ;
                    for ($i=2; $i<=$#metricList; $i++) {
                        push(@memoryMetrics,$metricList[$i]) ;
                    }
                    # push(@memoryMetrics,$metricList[2]) ;
                    # push(@memoryMetrics,$metricList[3]) ;
                } else {
                    if ($line =~ /Total/) {
                        @list = split(/\s+/,$line);
                        ## $totalMrd=$list[1];
                        ## $totalMwr=$list[2];
                        last;
                    } else {
                        @valueList = split(/\s+/,$line) ;
                        $boardNum = $valueList[1] ;
                        $found = 0;
                        foreach $num (@boardList) {
                            if ($boardNum == $num) {
                                $found = 1;
                            }
                        }
                        if ( $found != 1) {
                            push (@boardList, $boardNum);
                            $found = 0;
                        }
                        for ($i=0; $i<=$#memoryMetrics; $i++) {
                            $hash_memory_list{$valueList[0].$valueList[1].$memoryMetrics[$i]}=$valueList[$i+2];
                        }
                        # $hash_memory_list{$valueList[0].$valueList[1].$metricList[2]}=$valueList[2];
                        # $hash_memory_list{$valueList[0].$valueList[1].$metricList[3]}=$valueList[3];

                    }
                }
            }
        } else {
            die "Unknown system type $type\n";
        }
    }
    if ($debug) {
        @keys = keys %hash_memory_list;
        $len = $#keys;
        print "hash_memory_list len is $len\n";
    }
}

sub get_gigaplane_info
{
    if ($debug) {print "-> in get_gigaplane_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
            #
            # We expect here 2 groups of lines:
            # One beginning with the "AbUtil", another with "RIO"
            #
            $line = &get_next_significant_line();
            if ($line =~ /AbUtil/) {
                if ($debug) {print "Parsing info with \"AbUtil\" line ...\n";}
                @metricList = split(/\s+/,$line) ;
                while ($line = &get_next_significant_line()) {
                    if ($line =~ /^\s*($num)/) {
                        @metricValueList = split(/\s+/,$line) ;
                        &add_metrics_and_values_for_gigaplane();
                    } else {
                        if ($debug) {print "Breaking at line=$line\n";}
                        # $repeat_last_line = 1;
                        last;
                    }
                }
            } else {
                die "Expected line with \"AbUtil\" keyword.\n";
            }

            if ($line =~ /RIO/) {
                if ($debug) {print "Parsing info with \"RIO\" line ...\n";}
                @metricList = split(/\s+/,$line) ;
                while ($line = &get_next_significant_line()) {
                    if ($line =~ /^\s*($num)/) {
                        @metricValueList = split(/\s+/,$line) ;
                        &add_metrics_and_values_for_gigaplane();
                    } else {
                        if ($debug) {print "Breaking at line=$line\n";}
                        # $repeat_last_line = 1;
                        last;
                    }
                }
            } else {
                die "Expected line with \"RIO\" keyword.\n";
            }

$debug = 0;
            return;
        } elsif (/$type1/) {
            die "The gigaplane info unsupported for $type\n";
        }
    }
}

sub get_sbus_info
{
    if ($debug) {print "-> in get_sbus_info:\n";}

    for( $type ) {
        if (/$type0/) {
            if ($debug) {print "We are in SunFire case\n";}
            #
            # We expect here a list of lines like follows:
            #    Ctl#   MB/sec   Kintr/sec
            #    0      7.088    3.3
            #    1 ....
            #    Total  35.608   11.7
            #
            while ($line = &get_next_significant_line()) {
                if ($line =~ /Ctl/) {
                    @metricList = split(/\s+/,$line) ;
                    push(@SbusMetrics,$metricList[1]) ;
                    push(@SbusMetrics,$metricList[2]) ;
                } else {
                    if ($line =~ /Total/) {
                        @list = split(/\s+/,$line);
                        # $totalMBsec=$list[1];
                        # $totalKintrsec=$list[2];
                        last;
                    } else {
                        @valueList = split(/\s+/,$line) ;
                        $ctlNum = $valueList[0] ;
                        push(@CtlList,$ctlNum);
                        push(@SbusValues,$valueList[1]) ;
                        push(@SbusValues,$valueList[2]) ;
                    }
                }
            }

            return;
        } elsif (/$type1/) {
            die "The sbus info unsupported for $type\n";
        }
    }
}

sub add_metrics_and_values()
{
    #
    # Add to allMetrics if non-existent
    #
    #print "Will add metrics and values:\n";
    $len = $#allMetrics + 1;
    #print "allMetrics len is $len\n";
    #print "metricList: @metricList\n";
    foreach $newMetric (@metricList) {
        $found = 0;
        foreach $knownMetric (@allMetrics) {
            if ($newMetric eq $knownMetric ) {
                $found = 1;
                last;
            }
        }
        if (! $found) {
            push (@allMetrics, $newMetric); 
            if ($debug) {
                print "Added $newMetric to allMetrics\n";
            }
        }
    }
    # print "metricValueList: @metricValueList\n";
    #print "allMetrics: @allMetrics\n";
    for( $i=0 ; $i < $#metricList + 1 ; $i++) {
        $hash_aggregate_list{$metricList[$i].$mode} = $metricValueList[$i];
    }
    if ($debug) {
        @keys = keys %hash_aggregate_list;
        $len = $#keys;
        print "hash_aggregate_list len is $len\n";
    }
}

sub add_metrics_and_values_for_gigaplane()
{
    #
    # Add to allGigaplaneMetrics if non-existent
    #
    #print "Will add metrics and values:\n";
    $len = $#allGigaplaneMetrics + 1;
    #print "allGigaplaneMetrics len is $len\n";
    #print "metricList: @metricList\n";
    foreach $newMetric (@metricList) {
        push (@allGigaplaneMetrics, $newMetric); 
    }
    foreach $newValue (@metricValueList) {
        push (@allGigaplaneValues, $newValue); 
    }
}

sub add_metrics_and_percpu_values()
{
    if ($debug) {print "-> in add_metrics_and_percpu_values, cpuId=$cpuId:\n";}
    #
    # Add to allMetrics if non-existent
    #
    $len = $#metricList + 1;
    foreach $newMetric (@metricList) {
        $found = 0;
        foreach $knownMetric (@allMetrics) {
            if ($newMetric eq $knownMetric ) {
                $found = 1;
                last;
            }
        }
        if (! $found) {
            push (@allMetrics, $newMetric); 
        }
#        else {
#            push (@percpuMetrics, @metricList);
#            $flag=0;
#        }
    }
    if ($debug) {
        print "metricValueList: @metricValueList\n";
        print "allMetrics: @allMetrics\n";
        print "len: $len\n";
    }
    for( $i=0 ; $i < $len ; $i++) {
        $hash_percpu_list{$metricList[$i].$mode.$cpuId} = $metricValueList[$i];
    }
    $found = 0;
    foreach $knownCpuId (@allCpus) {
        if ($knownCpuId eq $cpuId ) {
            $found = 1;
            last;
        }
    }
    if (! $found) {
        push (@allCpus, $cpuId);
    }
    if ($debug) {
        @keys = keys %hash_percpu_list;
        $len = $#keys;
        print "hash_percpu_list len is $len\n";
    }
}

sub add_metrics_and_percpu_misses()
{
    if ($debug) {print "-> in add_metrics_and_percpu_misses, cpuId=$cpuId:\n";}

    if ($type eq $type0) {
        $len = $#metricList;
    } else {
        $len = $#metricList + 1;
    }

    #
    # Add to allMetrics if non-existent
    #
    foreach $newMetric (@metricList) {
        $found = 0;
        foreach $knownMetric (@allMetrics) {
            if ($newMetric eq $knownMetric ) {
                $found = 1;
                last;
            }
        }
        if (! $found) {
            push (@allMetrics, $newMetric); 
        }
#        else {
#            push (@percpuMetrics, @metricList);
#            $flag=0;
#        }
    }
    if ($debug) {
        print "metricValueList: @metricValueList\n";
        print "allMetrics: @allMetrics\n";
        print "len: $len\n";
    }
    for( $i=0 ; $i < $len ; $i++) {
        $hash_percpu_list{$metricList[$i].$mode.$cpuId} = $metricValueList[$i];
    }
    $found = 0;
    foreach $knownCpuId (@allCpus) {
        if ($knownCpuId eq $cpuId ) {
            $found = 1;
            last;
        }
    }
    if (! $found) {
        push (@allCpus, $cpuId);
    }
    if ($debug) {
        @keys = keys %hash_percpu_list;
        $len = $#keys;
        print "hash_percpu_list len is $len\n";
    }
}

sub add_percpu_mips
{
    $hash_percpu_list{"MIPS".$mode.$perCpuList[1]} = $perCpuList[2] ;
    $flag = 0;
    foreach $tst (@percpuMetrics) {
        if ($tst eq "MIPS") {
            $flag = 1;
            last;
        }
    }
    if ($flag !=1) {
        push (@percpuMetrics, "MIPS");}
}

sub make_empty_percpu
{
    foreach $cpu(@allCpus) {
        if (exists $hash_percpu_list{"MIPS"."Total".$cpu}) {
            $hash_percpu_list{"MIPS".$mode.$cpu} = '' ;
        }
    }
}
	      

#
# ===============================================
#        XML generation

sub generate_xml
{
    if ($debug) {print "Generating XML: (Type = $type) \n";}
    #PRINTING PHASE!
    if ( $type eq $type1 ) {
        xml_start_stat_doc((name => '"cpustat"', version => '"serengeti"'));
    } elsif ( $type eq $type0 ) {
        xml_start_stat_doc((name => '"cpustat"', version => '"sunfire"'));
    }
    #print all the aggregate stats

    # Print the runId
    xml_meta(name => '"RunId"', value => "\"$runId\"");

    # Print cpu cycles 
    xml_start_stat_group((name=> '"Aggregate CPU Cycle Components"'));

    $m = $#allModes + 1;
    $n = $#allMetrics + 1;
    $i = 0;
    $IcMissTotalIndex = 0;
    while ($i < $n) {
        if ($type eq $type0) {
            if ($allMetrics[$i] =~ /IcMiss\%/) {
                $IcMissTotalIndex = $i;
	        last;
            }
        } elsif ($type eq $type1) {
            if ($allMetrics[$i] =~ /IcMissTotal/ || $allMetrics[$i] =~ /IcMssTot/) {
                $IcMissTotalIndex = $i;
	        last;
            }
        }
        push(@tempList,$allMetrics[$i]);
        $i++;
    }
    if ($IcMissTotalIndex > 0) {
        $i = 0;
        xml_start_cell_list();
        while ($i < $IcMissTotalIndex) {
            $j = 0;
            while ($j < $m) {
                xml_start_cell();
                    $vx = $hash_aggregate_list{$allMetrics[$i].$allModes[$j]};
                    $vx =~ s/%//;
                    print $vx;
                xml_end_cell();
                $j++;
            }
            $i++;
        }
        xml_end_cell_list();

        xml_start_dim_list();

        xml_start_dim();
            xml_start_dimval();
                print "Total";
            xml_end_dimval();
            xml_start_dimval();
                print "User";
            xml_end_dimval();
            xml_start_dimval();
                print "Kernel";
            xml_end_dimval();
        xml_end_dim();

        xml_start_dim((name => '"Cycle Component"'));
        foreach $val(@tempList)
        {
            xml_start_dimval();
                print $val;
            xml_end_dimval();
        }
        xml_end_dim();

        xml_end_dim_list();

        xml_end_stat_group();
    }


    # Print detailed stats
    foreach $mode (@allCpuModes) {
    
        xml_start_stat_group((name => "\"Per CPU $mode Mode Statistics\"")) ;
        xml_start_cell_list();

        $i = 0;
        foreach $cpu(@allCpus) {
	    foreach $metric(@percpuMetrics) {
                if (exists $hash_percpu_list{$metric.$mode.$cpu}) {
                    if ( $metric eq "CPI" && $mode eq "Kernel" ) {
	                xml_start_cell(type => '"categorical"');
                            print $i;
                            $i++;
	                xml_end_cell();
                    }
	            xml_start_cell();
	                $vx = $hash_percpu_list{$metric.$mode.$cpu} ;
                        $vx =~ s/%//;
	                print $vx;
	            xml_end_cell();
                }
	    }
        }
        xml_end_cell_list();

        xml_start_dim_list();
        xml_start_dim();
        foreach $val(@percpuMetrics)
        {
            if ( $val eq "CPI" && $mode eq "Kernel" ) {
	        xml_start_dimval();
	            print "CPUid";
	        xml_end_dimval();
            }
	    xml_start_dimval();
	        print $val;
	    xml_end_dimval();
        }
        xml_end_dim();

    
##
## "Cpu ID" changed into "categorical" "Row"
##
#        xml_start_dim((name => '"Cpu ID"'));
#        foreach $val(@allCpus)
#        {
#	    xml_start_dimval();
#	        print $val;
#	    xml_end_dimval();
#        }
        if ( $mode eq "Kernel" ) {
            xml_start_dim((name => '"Row"'));
            $i = 0;
            foreach $val(@allCpus)
            {
	        xml_start_dimval();
	            print $i;
                    $i++;
	        xml_end_dimval();
            }
        } else {
            xml_start_dim((name => '"Cpu ID"'));
            foreach $val(@allCpus)
            {
	        xml_start_dimval();
	            print $val;
	        xml_end_dimval();
            }
        }
        xml_end_dim();
        xml_end_dim_list();
        xml_end_stat_group();
    }


    #print cache stats
    xml_start_stat_group((name => '"Aggregate Cache Miss Statistics"'));
    xml_start_cell_list();

    $i = $IcMissTotalIndex;
    while ($i < $n) {
        push(@tmpList,$allMetrics[$i]) ;
        $i++;
    }
    $i = $IcMissTotalIndex;
    while ($i < $n) {
        $j = 0;
        while ($j < $m) {
            xml_start_cell();
                chop($hash_aggregate_list{$allMetrics[$i].$allModes[$j]});
                $vx = $hash_aggregate_list{$allMetrics[$i].$allModes[$j]} ;
                $vx =~ s/%//;
                print $vx;
            xml_end_cell();
            $j++;
        }
        $i++;
    }
    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
        xml_start_dimval();
            print "Total (%)";
        xml_end_dimval();
        xml_start_dimval();
            print "User (%)";
        xml_end_dimval();
        xml_start_dimval();
            print "Kernel (%)";
        xml_end_dimval();
    xml_end_dim();

    xml_start_dim((name =>'"Cache Stat"'));
    foreach $val(@tmpList)
    {
        xml_start_dimval();
            print $val;
        xml_end_dimval();
    }

    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();


## Per CPU Cache Misses
    if ($type eq $type0) {   # "SunFire"
      $i = $IcMissTotalIndex;
      @tmpList = ();
      while ($i < $n - 1) {
        push(@tmpList,$allMetrics[$i]) ;
        $i++;
      }

      $j = 0;
      while ($j < $m) {

        if ($j == 0) {
          xml_start_stat_group((name => '"Per CPU Cache Miss Statistics: Total Mode"'));
        } elsif ($j == 1) {
          xml_start_stat_group((name => '"Per CPU Cache Miss Statistics: User Mode"'));
        } else {
          xml_start_stat_group((name => '"Per CPU Cache Miss Statistics: Kernel Mode"'));
        }
        xml_start_cell_list();

        foreach $cpu(@allCpus) {
          $i = $IcMissTotalIndex;
          while ($i < $n) {
            if (exists $hash_percpu_list{$allMetrics[$i].$allModes[$j].$cpu}) {
	      xml_start_cell();
	        $vx = $hash_percpu_list{$allMetrics[$i].$allModes[$j].$cpu} ;
                $vx =~ s/%//;
	        print $vx;
	      xml_end_cell();
            }
            $i++;
          }
        }
        xml_end_cell_list();

        xml_start_dim_list();

        xml_start_dim((name =>'"Cache Stat"'));
        foreach $val(@tmpList)
        {
          xml_start_dimval();
            print $val;
          xml_end_dimval();
        }
        xml_end_dim();

        xml_start_dim((name => '"Cpu ID"'));
        foreach $val(@allCpus)
        {
	  xml_start_dimval();
	    print $val;
	  xml_end_dimval();
        }
        xml_end_dim();

        xml_end_dim_list();
        xml_end_stat_group();

        $j++;
      }
    }
## END: Per CPU Cache Misses


    #Print Memory stats
    xml_start_stat_group((name => '"Memory Bank Statistics"'));

    xml_start_cell_list();
    if ($type eq $type0) {
      foreach $board(@boardList) {
        foreach $bank(@bankList) {
            for ($i=0; $i <= $#memoryMetrics; $i++) {
                if (exists $hash_memory_list{$board.$bank.$memoryMetrics[$i]}) {
                    xml_start_cell();
                    $vx = $hash_memory_list{$board.$bank.$memoryMetrics[$i]};
                    $vx =~ s/%//;
                    print $vx;
                    xml_end_cell();
                }
            }
        }
      }
    } elsif ($type eq $type1) {
      foreach $cpu(@allCpus) {
        foreach $board(@boardList) {
            for ($i=0; $i <= $#memoryMetrics; $i++) {
                if (exists $hash_memory_list{$cpu.$board.$memoryMetrics[$i]}) {
                    xml_start_cell();
                    print $hash_memory_list{$cpu.$board.$memoryMetrics[$i]};
                    xml_end_cell();
                }
            }
        }
      }
    }
    xml_end_cell_list();

    xml_start_dim_list();

    xml_start_dim(group => '"0"', level => '"0"');
        for ($i=0; $i <= $#memoryMetrics; $i++) {
            xml_start_dimval();
                print $memoryMetrics[$i];
            xml_end_dimval();
        }
    xml_end_dim();

    if ($type eq $type0) {
        xml_start_dim((name => '"Board"', group=> '"1"' , level=> '"1"'));
        foreach $val(@boardList)
        {
            xml_start_dimval();
                print $val;
            xml_end_dimval();
        }
        xml_end_dim();

        xml_start_dim((name => '"Bank"', group => '"1"' , level=> '"0"'));
        foreach $val(@bankList)
        {
            xml_start_dimval();
                print $val;
            xml_end_dimval();
        }
        xml_end_dim();
    } elsif ($type eq $type1) {
        xml_start_dim((name => '"Cpu ID"', group=> '"1"' , level=> '"0"'));
        foreach $val(@allCpus)
        {
            xml_start_dimval();
                print $val;
            xml_end_dimval();
        }
        xml_end_dim();

        xml_start_dim((name => '"Bank"', group => '"1"' , level=> '"1"'));
        foreach $val(@boardList)
        {
            xml_start_dimval();
                print $val;
            xml_end_dimval();
        }
        xml_end_dim();
    }

    xml_end_dim_list();
    xml_end_stat_group();

    if ($type eq $type0) {     # for SunFire only: Gigaplane and Sbus

        #Print Gigaplane stats
        xml_start_stat_group((name => '"Gigaplane Bus Statistics"'));

        xml_start_cell_list();
        foreach $gpValue (@allGigaplaneValues) {
	    xml_start_cell();
	    $vx = $gpValue;
            $vx =~ s/%//;
	    print $vx;
	    xml_end_cell();
        }
        xml_end_cell_list();

        xml_start_dim_list();

	xml_start_dim();
	xml_start_dimval();
	print "Value";
	xml_end_dimval();
	xml_end_dim();

        xml_start_dim(name => '"Stat"');
        foreach $gpMetric (@allGigaplaneMetrics) {
            xml_start_dimval();
	    print $gpMetric;
            xml_end_dimval();
        }
        xml_end_dim();
        xml_end_dim_list();

        xml_end_stat_group();


        #Print Sbus stats
        xml_start_stat_group((name => '"Sbus I/O Bus Statistics"'));

        xml_start_cell_list();
        foreach $sbValue (@SbusValues) {
	    xml_start_cell();
	    $vx = $sbValue;
            $vx =~ s/%//;
	    print $vx;
	    xml_end_cell();
        }
        xml_end_cell_list();

        xml_start_dim_list();
        xml_start_dim();
        foreach $sbMetric (@SbusMetrics) {
            xml_start_dimval();
	    print $sbMetric;
            xml_end_dimval();
        }
        xml_end_dim();
        xml_start_dim((name => '"Ctl"'));
        foreach $val(@CtlList)
        {
            xml_start_dimval();
                print $val;
            xml_end_dimval();
        }
        xml_end_dim();
        xml_end_dim_list();

        xml_end_stat_group();
    }

    xml_end_stat_doc();
}
