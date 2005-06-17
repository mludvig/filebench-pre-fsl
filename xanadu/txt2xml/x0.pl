#!/bin/perl -w
#
#   Borrowed good ideas and code from vmstat2xml.pl and others
#   adapted for use here
#
#   it handles output from
#
#      trapstat without parameters
#
#   A sample of expected input files can be found at the "__END__" 
#
#   Approach:
#
#   Instead of looking at data coming in line by line, approach
#   was changed to look at "blocks" of lines pertaining to one
#   sample.  A sample is usually taken every 10 seconds.
#
#   "trapstat"
#   ----------
#   Number of columns will vary depending on number of cpus.
#   If number of cpus exceed what can be printed on an 80 column
#   "page" ie 8 cpus, then additional "pages" will be printed for
#   any given sample.
#   Number of rows (per sample) will also vary as well eg set-psr
#   get-psr may not occur in every sample
#   Additional requirement is to compute "average" values for
#   table output.
#
#   Assumptions:
#   Interval is assumed to be 10 sec unless specified at cmdline
#   RUNID will default to string "RUNID" unless specified at cmdline
#
#   Caveat:
#   There is no support for extracting RUNID and INTERVAL from within
#   output right now. cmdline options should take care of that.
#   Incomplete sample set will cause this script to generate incomplete
#   xml code which eventually will cause xml2html to puke
#   Two separate code pieces were originally written to handle two
#   very different kinds of outputs, but now required to combine the
#   two - not efficiently done so.
#

use lib "../txt2xml";

use txt2xml ;
use trapmisc;
$debug = 0;
# temp headers to handle rotating column names
# over several "blocks" (for trapstat w/o options)
# or "massaged" headers (for trapstat w -t option)
@header=();
$noheaders=0;
%global_header_col=();   # list of all known col/cpu headers
%global_header_row=();   # list of all known row labels
%eliminated_row=();      # list of all known row labels that didnt' make it
%sumCol=();
%sample=();              # buckets
$nosamples=0;            # number of samples taken
$count=0;                # debug
$INTERVAL = 10;
$FILTER   = 1000;
$backfillrows = 0;
$backfillcols = 0;

#   pick up options
while ($#ARGV > -1) {
    $arg = shift @ARGV;
    if ( $arg =~ /^-(.)(.*)$/ ) {
        $flag=$1; $val=$2;
        # $flag2=$flag.$val;
        if ( $flag eq "i" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $infile = $val;
		  } elsif ($flag eq "I" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $INTERVAL = $val;
		  } elsif ($flag eq "F" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $FILTER = $val;
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

#   set options

$| = 1;

if (! defined $runId) {
    $runId = "RUNID";
}

if (defined $infile) {
    open(STDIN, "<$infile") || die "Could not open $infile\n";
}

if (defined $outfile) {
    open(STDOUT, ">$outfile") || die "Could not open $outfile\n";
}

	while (<STDIN>)
	{
		# cannot use 'if ( $next_line =~ (/^vct/ ... /^ttl/ ) )'
		# otherwise block concept will not work
		# comment: even if there is no terminating ttl, still works
		if ( /^vct/ ... /^ttl/ )
		{
			$next_line = $_;
			print "debug: next_line: $next_line:\n" if ($debug>2);
			next if ( $next_line =~ /^\s*$/);
			next if ( $next_line =~ /^---/);
			next if ( $next_line =~ /^\s*\#/);
			$next_line =~ s/^\s+//;
			chomp($next_line);
			@words = split /\s+/, $next_line;
			# an example:
			# vct  name |  cpu0  cpu1  cpu2  cpu3  cpu4  cpu5
			if ($words[0] =~ /vct/) {
				$count=0;
				@header=();
				$nocols=@words;
				$nocols=$nocols - 3;   # get rid of vct,name,|
				$noheaders=$nocols;
				$countSamples{$words[3]} += 1;
				print "Columns:$nocols:" if ($debug>3);
				for ($i=3;$i<=$#words;$i++)
				{
					print ":",$words[$i],":" if ($debug>3);
					push @header, $words[$i];
					$key = $words[$i];
					$key =~ s/cpu//;	# strip "cpu" and get number
					print "key:$key", " ", "value:",$words[$i],"\n" if ($debug>2);
					# preserve alternative:
					#$global_header_col{$words[$i]} = $words[$i]
					#   if (! defined($global_header_col{$words[$i]}));
					if (! defined($global_header_col{$key}))
					{
						$global_header_col{$key} = $words[$i];
						$backfillcols++ if ($nosamples>1);
						# did someone turn cpu offline/online?
					}
				}
				print "\n" if ($debug>2);
				next;
			}
			# an example of "data" row:
			# -------------------------
			# 20 fp-disabled
			# 24 cleanwin
			# ....
			#print $count++, ":", "$words[1]","\n";
			# determine which row entity are we dealing with
			# preserve alternative:
			#$global_header_row{$words[1]} = $words[1]
			#   if (! defined($global_header_row{$words[1]}));
			if (! defined $global_header_row{$words[0]} )
			{
				$global_header_row{$words[0]} = $words[1];
				# here is the interesting part
				# this block of code should have been exec
				# on the first pass thru data sample set 1
				# if it is called again, then we have new
				# fields appearing in the middle of dataset.
				# Per bng's requirement, we need to back
				# fill all previous data to 0 if this occurs;
				# just have to assume cpus does not get turned
				# on off as well - there is no support for cpus
				# offlined
				$backfillrows++ if ($nosamples>1);
				# remember the number of occassions
			}
			$index=3;
			if ($words[$index] =~ /vct/)
			{
				# we have corrupted memory
				die "corrupt word";
			}
			for ($i=$index,$h=0;$i<=$#words;$i++)
			{
				if ($h >= $noheaders) {
					die "number of headers exceeded:$noheaders";
				}
				# memory corruption
				if (! defined($header[$h])) {
					print " corruption header: h:$h ",
						"word0:$words[0]",
						"word1:$words[1]",
						"\n";
				}
				# index is row, col
				$s_index = $words[1] . "." . $header[$h];
				$h++;
				print "$s_index", ":","$words[$i]","\n" if ($debug>3);
				# save it!
				push @{$sample{$s_index}}, "$words[$i]";
			}
			# R x C matrix of arrays of data

			$next_line="";
			if ( $next_line =~ /^vct/)
			{
				$nosamples++;
			}
		}
	}

	if ($debug)
	{
		foreach $c ( sort numerically keys %global_header_col )
		{
			print "col:$c:", $global_header_col{$c},"\n";
			print "$global_header_col{$c}:", "\n";
			foreach $r ( sort keys %global_header_row )
			{
				print "row $r", "\n";
				$s_index = $global_header_row{$r} . "." . $global_header_col{$c};
				#print "\t","$global_header_row{$r} is ";
				print "\t","$global_header_row{$r} => ";
				#for ($i=0; $i<$#{$sample{$s_index}}; $i++)
				foreach $v (@{$sample{$s_index}})
				{
					print " ", $v;
				}
				print "\n";
			}
		}
	}

	foreach $v (keys %countSamples )
	{
		$nosamples=$countSamples{$v};
		last;
	}
	# data tranformed
	&massageNavg;
	&generate_xml_main_opt0;

sub generate_xml_main_opt0
{
   #      XML meta
   xml_start_stat_doc(
      name => "\"Trapstat (no flag)\""
      );
   xml_meta(
      name => "\"RunId\"",
      value => "\"$runId\""
      );
   xml_meta(
      name => "\"Interval\"",
      value => "\"$INTERVAL\""
      );
	$f = $FILTER;
   xml_meta(
      name => "\"Filter\"",
      value => "\"$f\""
      );
   xml_meta(
      name => "\"Samples\"",
      value => "\"$nosamples\""
      );
   &gen_xml_table0;
   &gen_xml_graph0;
   #      XML meta
   xml_end_stat_doc();
}

sub gen_xml_graph0
{
   #      XML details - display graphs
   foreach $r ( sort keys %global_header_row )
   {
      xml_start_stat_group(
         name => "\"$global_header_row{$r}\"",
         display => "\"gnuplot-png\""
         );
      {
         xml_start_cell_list();
         {
            # all data for cpus
            foreach $c ( sort numerically keys %global_header_col )
            {
               $s_index = $global_header_row{$r} . "." .  $global_header_col{$c};
               for ($i=0; $i<=$#{$sample{$s_index}}; $i++)
               {
                  xml_start_cell();
                     print ${$sample{$s_index}}[$i];
                  xml_end_cell();
               }
            }
         }
         xml_end_cell_list();

         xml_start_dim_list();
         {
            # columns
            xml_start_dim(
               group => '"0"',
               level => '"0"'
               );
            {
               # print cpus as columns
               foreach $cpu ( sort numerically keys %global_header_col )
               {
                  xml_start_dimval();
                     print "CPU $cpu";
                  xml_end_dimval();
               }
            }
            xml_end_dim();

            # rows
            xml_start_dim(
               group => '"1"',
               level => '"1"',
               name => '"Time (s)"'
               );
            {
               #for ($i = 0; $i <= $nosamples; $i++)
               for ($i=0; $i<=$#{$sample{$s_index}}; $i++)
               {
                  xml_start_dimval();
                     printf "%d", $i * $INTERVAL;
                  xml_end_dimval();
               }
            }
            xml_end_dim();
         }
         xml_end_dim_list();
      }
      xml_end_stat_group();
   }
}

sub massageNavg
{
	# it is here we massage in-memory data to
	#  -. compute average values
	#  -. eliminate data that do not measure up to filter
	#  -. backfill data for traps that appear only a couple of samples

	# collapse rows (interval) and compute average
	%sumAcrossRows=();
#	mks
# for each trap we find
	foreach $r ( sort keys %global_header_row )
	{
		$high_water=0;
		# is used to eliminate traps where all samples did not reach $FILTER
		$sumAcrossCols=0;
		foreach $c ( sort numerically keys %global_header_col )
		{
			$s_index = $global_header_row{$r} . "." . $global_header_col{$c};
			$sumval = 0;
			$numsamples=1+$#{$sample{$s_index}};
			for ($i=0; $i<=$#{$sample{$s_index}}; $i++)
			{
				$sumval += ${$sample{$s_index}}[$i];
			}
			#@{$sample{$s_index}} = ();	# destroy samples
			$numsamples = 1 if ( $numsamples < 1 );
			$avg=$sumval / $numsamples;

			$sumAcrossCols += $avg;	# sumtotals
			$sumAcrossRows{$c} = $avg; # sumtotals

			push @{$sum_sample{$s_index}}, "$avg";
			if ($sum_sample{$s_index}[0] > $FILTER ) {
				$high_water++;
			}
		}
		if ($high_water < 1) {
			# we have to clean it but what the heck
			foreach $c ( sort numerically keys %global_header_col )
			{
				$s_index = $global_header_row{$r} . "." . $global_header_col{$c};
				@{$sample{$s_index}} = ();	# destroy samples
			}
			$eliminated_row{$r} = $global_header_row{$r};
			#- Wed Nov 21 13:26:01 PST 2001
			delete($global_header_row{$r});	# no one can refer to it
			next;
		}
		# if we are here, this set of values is worth keeping
		$s_index = $global_header_row{$r} . "." . "Total";
		push @{$sum_sample{$s_index}}, "$sumAcrossCols";

		# also worth summing down
		foreach $c ( sort numerically keys %global_header_col )
		{
			$s_index = "Total" . "." . $global_header_col{$c};
			$sumCol{$s_index} += $sumAcrossRows{$c};
		}
	}
	if (%global_header_row) 
	{
		$avg=0;	# recycle variable
		foreach $c ( sort numerically keys %global_header_col )
		{
			$s_index = "Total" . "." . $global_header_col{$c};
			push @{$sum_sample{$s_index}}, $sumCol{$s_index};
			$avg += $sumCol{$s_index};
		}
		$s_index = "Total" . "." . "Total";
		push @{$sum_sample{$s_index}}, "$avg";
	}
	else
	{
		die "Filter $FILTER may be too high, no traps meet criteria, empty file";
	}
}

sub gen_xml_table0
{
	#
	#      XML details - display summary table
	# may have to consolidate data/collapse
	xml_start_stat_group(
		name => "\"Summary : Average across all samples\"",
		);
	{
		xml_start_cell_list();
		{
			foreach $r ( sort keys %global_header_row )
			{
            # all data for cpus
            foreach $c ( sort numerically keys %global_header_col )
            {
               $s_index = $global_header_row{$r} . "." .  $global_header_col{$c};
               for ($i=0; $i<=$#{$sum_sample{$s_index}}; $i++)
               {
                  xml_start_cell();
                     #print ${$sample{$s_index}}[$i];
                     printf "%9.2lf", ${$sum_sample{$s_index}}[$i];
                  xml_end_cell();
               }
            }
				$s_index = $global_header_row{$r} . "." . "Total";
				for ($i=0; $i<=$#{$sum_sample{$s_index}}; $i++)
				{
					xml_start_cell();
						printf "%-9.2lf", ${$sum_sample{$s_index}}[$i];
					xml_end_cell();
				}
			}
			foreach $c ( sort numerically keys %global_header_col )
			{
				$s_index = "Total" . "." . $global_header_col{$c};
				xml_start_cell();
					printf "%-11.2lf", ${$sum_sample{$s_index}}[0];
				xml_end_cell();
			}
			$s_index = "Total" . "." . "Total";
			xml_start_cell();
			#print ${$sample{$s_index}}[0];
				printf "%-12.2lf", ${$sum_sample{$s_index}}[0];
			xml_end_cell();
		}
		xml_end_cell_list();

		xml_start_dim_list();
		{
			# columns
			xml_start_dim(
				group => '"0"',
				level => '"0"'
				);
			{
				# print cpus as columns
				foreach $cpu ( sort numerically keys %global_header_col )
				{
					xml_start_dimval();
						print "CPU $cpu";
					xml_end_dimval();
				}
				xml_start_dimval();
					print "Total all CPUs";
				xml_end_dimval();
			}
			xml_end_dim();

			# rows
			xml_start_dim(
				group => '"1"',
				level => '"1"',
				name => '"Traps"',
				);
			{
				foreach $r ( sort keys %global_header_row )
				{
					xml_start_dimval();
						print $global_header_row{$r};
					xml_end_dimval();
				}
				xml_start_dimval();
					print "Total all traps";
				xml_end_dimval();
			}
			xml_end_dim();
		}
		xml_end_dim_list();
   }
	xml_end_stat_group();
}

sub numerically { $a <=> $b; }

__END__
# real data file - "trapstat" - contains 2 "samples" for a 24way system
vct  name               |     cpu0     cpu1     cpu2     cpu3     cpu4     cpu5
------------------------+------------------------------------------------------
 20 fp-disabled         |        0        0        0        0        0        0
 24 cleanwin            |        0        0        0        0        4        0
 41 level-1             |       40        0        0        0        0        0
 44 level-4             |        0        6        3       11        0        1
 46 level-6             |        0       11        0        0        0        0
 4a level-10            |      100        0        0        0        0        0
 4d level-13            |        2        2        2        2        2        2
 4e level-14            |      100        0        0        0        0        0
 60 int-vec             |        6       23        9       17        6        7
 64 itlb-miss           |        0        0        0        0       42        0
 68 dtlb-miss           |        6       41       26      175       33       10
 6c dtlb-prot           |        0        0        0        0        0        0
 84 spill-user-32       |        0        0        0        0        0        0
 88 spill-user-64       |        0        0        0        0        3        0
 8c spill-user-32-cln   |        0        0        0        0        0        0
 90 spill-user-64-cln   |        0        0        0        0        1        0
 98 spill-kern-64       |      233      118       37      106       28        8
 a4 spill-asuser-32     |        0        0        0        0        0        0
 a8 spill-asuser-64     |        0        0        0        0        6        0
 ac spill-asuser-32-cln |        0        0        0        0        0        0
 b0 spill-asuser-64-cln |        0        0        0        0        1        0
 c4 fill-user-32        |        0        0        0        0        0        0
 c8 fill-user-64        |        0        0        0        0        0        0
 cc fill-user-32-cln    |        0        0        0        0        0        0
 d0 fill-user-64-cln    |        0        0        0        0       10        0
 d8 fill-kern-64        |      138      102       30       93       25        5
103 flush-wins          |        0        0        0        0        0        0
108 syscall-32          |        0        0        0        0        0        0
124 getts               |        0        0        0        0        2        0
126 self-xcall          |        0        0        0        0        0        0
127 gethrtime           |        0        0        0        0        1        0
140 syscall-64          |        0        0        0        0       11        0

vct  name               |     cpu6     cpu7     cpu8     cpu9    cpu10    cpu11
------------------------+------------------------------------------------------
...
