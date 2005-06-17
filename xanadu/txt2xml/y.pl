#!/bin/perl -w
#
use lib "../txt2xml";

use txt2xml ;
use trapmisc;
$debug = 0;
@header=();
%global_header_col=();	# list of all known cpu headers
%global_header_row=();	# list of all known row labels
%sample_u=();		# samples for User mode
%sample_k=();		# samples for Kernel mode
%sample_t=();		# samples for both modes
%sum_u=();		# sum/avg samples for User mode
%sum_k=();		# sum/avg samples for Kernel mode
%sum_t=();		# sum/avg samples for both modes
$nosamples=0;  	# Number of samples taken
$nocpus=0;
$count=0;
$INTERVAL = 10;
$FILTER   = -1;	# no filtering takes place
# if ever there is a future need for filter,
# code review for major changes needed

#	pick up options
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
#				if ( $val ne "")  { &usage();}
#				$verbose = 1;
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

#	set options

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

$lcount=0;
while (<STDIN>)
{
	print "debug: next_line: $next_line:\n" if ($debug>2);
	# cannot use 'if ( $next_line =~ (/^vct/ ... /^ttl/ ) )'
	# otherwise block concept will not work
	if ( /^cpu/ ... /^ttl/ )
	{
		$lcount++;
		print "lcount:$lcount\n" if ($debug>2);
		$next_line = $_;
		next if ( $next_line =~ /^\s*$/);
		next if ( $next_line =~ /^---/);
		next if ( $next_line =~ /^===/);
		next if ( $next_line =~ /^\s*\#/);
		$next_line =~ s/^\s+//;
		# do not enable: $next_line =~ s/\|//g;
		if ( $next_line =~ /^ttl/)
		{
			$nosamples++;
			#do not ignore#next;
		}
		chomp($next_line);
		@words = split /\s+/, $next_line;
# an example:
# cpu  | itlb-miss %tim itsb-miss %tim | dtlb-miss %tim dtsb-miss %tim | %tim
# -or-
# cpu m| itlb-miss %tim itsb-miss %tim | dtlb-miss %tim dtsb-miss %tim | %tim
		if ($words[0] =~ /cpu/) {
			$count=0;
			$noheader = @header;
			next if ($noheader > 0);	# already done it once before
			$nocols=@words;		# number of columns to process
			print "Columns:$nocols" if ($debug>3);
			$nocols=$nocols - 2;	# ignore first 2 columns
			# warning: must not get rid of '|' before this line
			for ($i=2;$i<=$#words;$i++)
			{
				if ($words[$i] =~ /^\|%tim/)
				{
					$prev = "total" if ( $prev =~ /dtsb/ );
					# this is a trick trying to find the last column
					# which has '%tim' in it, it should be the total
					# miss percentage for this "row" (ie includes
					# both instruction and data tsb and tlb misses)
				}
				$words[$i] =~ s/\|// ;	# leave it here!
				next if ($words[$i] =~ /^\s*$/);
				print ":",$words[$i] if ($debug>3);
					#push @header, $words[$i];
				$key = $words[$i];
				($this) = ($key =~ /([a-z]+)-miss/);
				if (!defined($this)) {
					$this = $prev;
					# most likely it is %tim but which one?
					$key=$prev . "." . $key;	# tranform key to relate to {i,d}tlb or {i,d}tsb
				}
				$prev = $this;
				push @header, $key;
				#$key = $key . "." . "$count";
				$key = "$count" . "." . $key ;
				$count++;
				print "key:$key", " ", "value:",$words[$i],"\n" if ($debug>2);
				$global_header_col{$key} = $words[$i]
					if (! defined($global_header_col{$key}));
			}
			# header names are transformed now into:
			# itlb-miss
			# itlb-%tim
			# itsb-miss
			# itsb-%tim
			# dtlb-miss
			# dtlb-%tim
			# dtsb-miss
			# dtsb-%tim
			# total-%tim
			print "\n" if ($debug>2);
			next;
		}

		#
		# non header line dealt with from here on
		#
		# an example: k and u mode for cpus 0 and 1
		#-----+------------------------------+-----------------------------+-----
		#  0 k|		4815  0.0			0  0.0 |	 263334  5.1		1181  0.1 |  5.3
		#  0 u|	  41459  0.7		  11  0.0 |	 275725  3.8		4190  0.9 |  5.4
		#-----+------------------------------+-----------------------------+-----
		#  1 k|		7981  0.1			0  0.0 |	 309992  5.7		1076  0.1 |  6.0
		#  1 u|	  36836  0.6			8  0.0 |	 213063  2.9		3142  0.6 |  4.2
		# ....
		# ttl |	  51475  0.1			1  0.0 |  16598639 15.4	  21814  0.3 |15.7

		# determine which row entity are we dealing with
		$global_header_row{$words[0]} = $words[1]
			if (! defined($global_header_row{$words[0]}));
#
# 23 u|		2141  0.1			0  0.0 |	 645171 14.3		  54  0.0 |14.4
#
		$next_line =~ s/\|//g;
		@words = split /\s+/, $next_line;	# repeat the split
		# data transformed: pipe has been stripped
#
# 23 u		2141  0.1			0  0.0 	 645171 14.3		  54  0.0 14.4
#
		$cpu = $words[0];
		$mode = $words[1];

		if($cpu =~ /ttl/)
		{
			# ttl |	  51475  0.1			1  0.0 |  16598639 15.4	  21814  0.3 |15.7
		   # ttl 51475  0.1			1  0.0 16598639 15.4	  21814  0.3 15.7
			#  .  .      .          .  .   .        .      .      .   .
			for ($i=1,$h=0;$i<=$#words;$i++)
			{
				$words[$i] =~ s/\|//;	# strip vertical bars
				next if ($words[$i] =~ /^\s*$/);
				$s_index = "$cpu" . "." . $header[$h];
				$h++;
				print $s_index, "\n" if ($debug>3);
				push @{$sample_t{$s_index}}, "$words[$i]";
					# accumulator
					$sum_t{$s_index} += $words[$i];
			}
			next;
		}

		# save to list of valid cpu IDs
		$global_cpu_list{"$cpu"} = $cpu;

		SWITCH: {
			if ($mode =~ /k/) {
				for ($i=2,$h=0;$i<=$#words;$i++)
				{
					$words[$i] =~ s/\|//;	# strip vertical bars
					next if ($words[$i] =~ /^\s*$/);
					$s_index = "$cpu" . "." . $header[$h];
					$h++;
					print $s_index, "\n" if ($debug>3);
					push @{$sample_k{$s_index}}, "$words[$i]";

						# accumulator
						$sum_k{$s_index} += $words[$i];
				}
				last SWITCH;
				}
			if ($mode =~ /u/) {
				for ($i=2,$h=0;$i<=$#words;$i++)
				{
					$words[$i] =~ s/\|//;	# strip vertical bars
					next if ($words[$i] =~ /^\s*$/);
					$s_index = "$cpu" . "." . $header[$h];
					$h++;
					print $s_index, "\n" if ($debug>3);
					push @{$sample_u{$s_index}}, "$words[$i]";

						# accumulator
						$sum_u{$s_index} += $words[$i];
				}
				last SWITCH;
				}
		}
		# R x C matrix of arrays of data
		# kernel vs user mode
	}
}

	#&debug_dump_sum;
	#&debug_dump_all;

	&generate_xml_main_opt1;

sub generate_xml_main_opt1
{
   #      XML meta
   xml_start_stat_doc(
      name => "\"Trapstat (-t flag)\""
      );
   xml_meta(
      name => "\"RunId\"",
      value => "\"$runId\""
      );
   xml_meta(
      name => "\"Interval\"",
      value => "\"$INTERVAL\""
      );
	xml_meta(
		name => "\"Filter\"",
		value => "\"Disabled\""
		);
   xml_meta(
      name => "\"Samples\"",
      value => "\"$nosamples\""
      );

	# data tranformed mks
	&massageNavg1;
   &gen_xml_table1;
   #&gen_xml_table2;
	# reversed
	&gen_xml_graph1;

   #      XML meta
   xml_end_stat_doc();
}

sub massageNavg1
{
	# traps
	foreach $c ( @header )
	{
		# cpus
		$tcpus=0;
		foreach $r ( keys %global_cpu_list )
		{
			$s_index = "$r" . "." .  "$c";
			$sum_k{$s_index} /= $nosamples;
			$sum_u{$s_index} /= $nosamples;
			$tcpus++;
		}
		$s_index = "ttl" . "." .  "$c";
		$sum_t{$s_index} /= $nosamples;
		$nocpus = $tcpus; # foolish
	}
}

%allcpusum_u=();
%allcpusum_k=();

sub gen_xml_table1
{
	#      XML details - display summary table
	xml_start_stat_group(
		name => "\"Summary : Average across all samples\"",
		);
	{
		xml_start_cell_list();
		{
			# all data for cpus
			foreach $r ( sort numerically keys %global_cpu_list )
			{
				# for all traps; previous: foreach $c ( @header )

				#-- kernel mode
				for ($i=0,$sum=0;$i<$#header;$i++)
				{
					$c=$header[$i]; $s_index = $r . "." . $c;
                  xml_start_cell();
                     printf "%9.2lf", $sum_k{$s_index};
                  xml_end_cell();
						$sum += $sum_k{$s_index};
					$allcpusum_k{$c} += $sum_k{$s_index};
            }
				# throw in calc row/col
				#xml_start_cell(); print "-1";xml_end_cell();
				xml_start_cell(); printf "%9.2lf", $sum;xml_end_cell();
				$c=$header[$#header]; $s_index = $r . "." . $c;
				xml_start_cell(); printf "%9.2lf", $sum_k{$s_index};xml_end_cell();

				#-- all summary data for all cpus

				#-- user mode
				for ($i=0,$sum=0;$i<$#header;$i++)
            {
					$c=$header[$i]; $s_index = $r . "." . $c;
                  xml_start_cell();
                     printf "%9.2lf", $sum_u{$s_index};
                  xml_end_cell();
						$sum += $sum_u{$s_index};
					$allcpusum_u{$c} += $sum_u{$s_index};
            }
				# throw in calc row/col
				xml_start_cell(); printf "%9.2lf", $sum;xml_end_cell();
				$c=$header[$#header]; $s_index = $r . "." . $c;
				xml_start_cell(); printf "%9.2lf", $sum_u{$s_index};xml_end_cell();

				#-- all summary data for all cpus
			}

		# total up all the columns for the last line
		# bng wants sum for the miss's
		# and avg for the pct's

			# kernel mode
			$sum=0;
			$sum_pct=0;
			for ($i=0;$i<$#header;$i++)
			{
				$c=$header[$i];
				xml_start_cell();
					if ($c =~ /miss/)
					{
					printf "%9.2lf s", $allcpusum_k{$c};
					$sum += $allcpusum_k{$c};
					}
					else
					{
					printf "%9.2lf a", $allcpusum_k{$c}/$nocpus;
					$sum_pct += ($allcpusum_k{$c}/$nocpus);
					}
				xml_end_cell();
			}
			xml_start_cell(); printf "%9.2lf ", $sum;xml_end_cell();
			xml_start_cell(); printf "%9.2lf ", $sum_pct;xml_end_cell();

			# user mode
			$sum=0;
			$sum_pct=0;
			for ($i=0;$i<$#header;$i++)
			{
				$c=$header[$i];
				xml_start_cell();
					if ($c =~ /miss/)
					{
					printf "%9.2lf s", $allcpusum_u{$c};
					$sum += $allcpusum_u{$c};
					}
					else
					{
					printf "%9.2lf a", $allcpusum_u{$c}/$nocpus;
					$sum_pct += ($allcpusum_u{$c}/$nocpus);
					}
				xml_end_cell();
			}
			xml_start_cell(); printf "%9.2lf ", $sum;xml_end_cell();
			xml_start_cell(); printf "%9.2lf ", $sum_pct;xml_end_cell();

		}
		xml_end_cell_list();

		xml_start_dim_list();
		{
			# columns
			xml_start_dim( group => '"0"', level => '"0"');
			{
				# print traps as columns
					xml_start_dimval();
						print "Instr tlb";
					xml_end_dimval();
					xml_start_dimval();
						print "Instr tsb";
					xml_end_dimval();
					xml_start_dimval();
						print "Data tlb";
					xml_end_dimval();
					xml_start_dimval();
						print "Data tsb";
					xml_end_dimval();

				xml_start_dimval();
					print "Total Columns (Sum)";
				xml_end_dimval();
			}
			xml_end_dim();
			xml_start_dim( group => '"0"', level => '"1"');
			{
					xml_start_dimval();
						print "miss";
					xml_end_dimval();
					xml_start_dimval();
						print "%time";
					xml_end_dimval();
			}
			xml_end_dim();

			# rows
			xml_start_dim( group => '"1"', level => '"0"', name => '"Cpu ID"',);
			{
				foreach $r ( sort keys %global_cpu_list )
				{
					xml_start_dimval();
						print $r;
					xml_end_dimval();
				}
				xml_start_dimval();
					print "ALL (a-avg, s-sum)";
				xml_end_dimval();
			}
			xml_end_dim();
			xml_start_dim( group => '"1"', level => '"1"', name => '"Mode"',);
			{
					xml_start_dimval();
						print "kernel";
					xml_end_dimval();
					xml_start_dimval();
						print "user";
					xml_end_dimval();
			}
			xml_end_dim();
		}
		xml_end_dim_list();
   }
	xml_end_stat_group();
}

sub gen_xml_graph1
{
	#      XML details - display graphs

	# for all traps
	foreach $c ( @header )
	{
		next if ($c =~ /tim/);

		# kernel
		xml_start_stat_group(
			name => "\"Kernel $c\"",
			display => "\"gnuplot-png\"",
			);
			xml_start_cell_list();
				# all data for cpus
				foreach $r ( sort keys %global_cpu_list )
				{
					$s_index = $r . "." . $c;
					for($i=0; $i<=$#{$sample_k{$s_index}}; $i++)
					{
						xml_start_cell();
							print ${$sample_k{$s_index}}[$i];
						xml_end_cell();
					}
				}
			xml_end_cell_list();

			xml_start_dim_list();
				# columns
				xml_start_dim( group => '"0"', level => '"0"');
					# print traps as columns
					foreach $r ( sort keys %global_cpu_list )
					{
						xml_start_dimval();
							print "CPU $r";
						xml_end_dimval();
					}
				xml_end_dim();

				# rows
				xml_start_dim( group => '"1"', level => '"1"', name => '"Time (s)"',);
					for ($i=0; $i<=$#{$sample_k{$s_index}}; $i++)
					{
						xml_start_dimval();
							printf "%d", $i * $INTERVAL;
						xml_end_dimval();
					}
				xml_end_dim();
			xml_end_dim_list();
		xml_end_stat_group();
		# user
		xml_start_stat_group(
			name => "\"User $c\"",
			display => "\"gnuplot-png\"",
			);
			xml_start_cell_list();
				# all data for cpus
				foreach $r ( sort keys %global_cpu_list )
				{
					$s_index = $r . "." . $c;
					for($i=0; $i<=$#{$sample_u{$s_index}}; $i++)
					{
						xml_start_cell();
							print ${$sample_u{$s_index}}[$i];
						xml_end_cell();
					}
				}
			xml_end_cell_list();

			xml_start_dim_list();
				# columns
				xml_start_dim( group => '"0"', level => '"0"');
					# print traps as columns
					foreach $r ( sort keys %global_cpu_list )
					{
						xml_start_dimval();
							print "CPU $r";
						xml_end_dimval();
					}
				xml_end_dim();

				# rows
				xml_start_dim( group => '"1"', level => '"1"', name => '"Time (s)"',);
					for ($i=0; $i<=$#{$sample_u{$s_index}}; $i++)
					{
						xml_start_dimval();
							printf "%d", $i * $INTERVAL;
						xml_end_dimval();
					}
				xml_end_dim();
			xml_end_dim_list();
		xml_end_stat_group();
	}
}

sub numerically { $a <=> $b; }

sub debug_dump_all
{
	if ($debug)
	{
		foreach $c ( @header )
		{
			$LEVEL=0;
			print "\t" x $LEVEL, "Trap: $c", "\n";
			$LEVEL++;
			foreach $r ( sort numerically keys %global_cpu_list )
			{
				print "\t" x $LEVEL, "cpu: $r", "\n";
				$s_index = $r . "." . $c;

				$sname = "User";
				print "\t" x ($LEVEL + 1), "$sname mode:";
				$cnt=0;
				foreach $v (@{$sample_u{$s_index}})
				{
					print " ", $v;
					if (++$cnt > 10) {
						print "\n";
						print "\t" x ($LEVEL + 1), "\t";
						$cnt=0;
					}
				}
				print "\n";

				$sname = "Kernel";
				print "\t" x ($LEVEL + 1), "$sname mode:";
				$cnt=0;
				foreach $v (@{$sample_k{$s_index}})
				{
					print " ", $v;
					if (++$cnt > 10) {
						print "\n";
						print "\t" x ($LEVEL + 1), "\t";
						$cnt=0;
					}
				}
				print "\n";
			}
		}
	}
}

sub debug_dump_sum
{
	if ($debug)
	{
		foreach $c ( @header )
		{
			$LEVEL=0;
			print "\t" x $LEVEL, "Trap: $c", "\n";
			$LEVEL++;
			foreach $r ( sort numerically keys %global_cpu_list )
			{
				print "\t" x $LEVEL, "cpu: $r", "\n";
				$s_index = $r . "." . $c;

				$sname = "User";
				print "\t" x ($LEVEL + 1), "$sname mode:";
				$v = $sum_u{$s_index};
					print " ", $v; print "\n";

				$sname = "Kernel";
				print "\t" x ($LEVEL + 1), "$sname mode:";
				$v = $sum_k{$s_index};
					print " ", $v; print "\n";

				$sname = "Total";
				print "\t" x ($LEVEL + 1), "$sname mode:";
				$v = $sum_t{$s_index};
					print " ", $v; print "\n";
			}
		}
	}
}

__END__
# sample data
cpu m| itlb-miss %tim itsb-miss %tim | dtlb-miss %tim dtsb-miss %tim |%tim
-----+-------------------------------+-------------------------------+----
  0 u|		2047  0.1			0  0.0 |	 720519 15.9		 378  0.1 |16.1
  0 k|		  64  0.0			0  0.0 |		5642  0.2			2  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  1 u|		1654  0.1			0  0.0 |	 745764 16.6		1368  0.4 |17.1
  1 k|		  38  0.0			0  0.0 |		1898  0.1			6  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
  2 u|		2268  0.1			0  0.0 |	 705855 15.4		  58  0.0 |15.5
  2 k|		  91  0.0			0  0.0 |		6769  0.2		  20  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  3 u|		2364  0.1			0  0.0 |	 702667 15.4		  70  0.0 |15.6
  3 k|		  80  0.0			0  0.0 |		4921  0.2		  14  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  4 u|		2281  0.1			0  0.0 |	 663434 14.7		  59  0.0 |14.8
  4 k|		  98  0.0			0  0.0 |		5861  0.2		  10  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  5 u|		1724  0.1			0  0.0 |	 784998 17.3		  47  0.1 |17.4
  5 k|		  27  0.0			0  0.0 |		 664  0.0			4  0.0 | 0.0
-----+-------------------------------+-------------------------------+----
  6 u|		1853  0.1			0  0.0 |	 750205 16.2		  61  0.1 |16.3
  6 k|		  48  0.0			0  0.0 |		2445  0.1			2  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
  7 u|		2122  0.1			0  0.0 |	 709552 15.6		  49  0.0 |15.8
  7 k|		  78  0.0			0  0.0 |		4714  0.2		  21  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  8 u|		2742  0.1			0  0.0 |	 705677 15.2		  56  0.0 |15.3
  8 k|		 108  0.0			0  0.0 |		5263  0.2		  10  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  9 u|		2014  0.1			0  0.0 |	 735672 16.1		  46  0.0 |16.2
  9 k|		  62  0.0			0  0.0 |		3678  0.1			7  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 10 u|		2145  0.1			0  0.0 |	 726103 15.6		  44  0.0 |15.7
 10 k|		  72  0.0			0  0.0 |		5252  0.2		  14  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 11 u|		1912  0.1			0  0.0 |	 711557 15.6		  39  0.0 |15.7
 11 k|		  59  0.0			0  0.0 |		4423  0.2			7  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 12 u|		1961  0.1			0  0.0 |	 567012 12.5		  35  0.0 |12.6
 12 k|		  81  0.0			1  0.0 |		5039  0.2		  10  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 13 u|		1859  0.1			0  0.0 |	 637823 14.0		1282  0.4 |14.4
 13 k|		  67  0.0			0  0.0 |		6964  0.2		  46  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 14 u|		1986  0.1			0  0.0 |	 757709 16.5		  52  0.0 |16.7
 14 k|		  64  0.0			0  0.0 |		2606  0.1			4  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 15 u|		1926  0.1			0  0.0 |	 714707 15.6		 421  0.2 |15.9
 15 k|		  71  0.0			0  0.0 |		4659  0.2			8  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 16 u|		2252  0.1			0  0.0 |	 640985 14.3		4190  1.3 |15.7
 16 k|		  93  0.0			0  0.0 |		7477  0.3		  20  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
 17 u|		2147  0.1			0  0.0 |	 700851 15.4		  70  0.1 |15.5
 17 k|		  82  0.0			0  0.0 |		6578  0.2		  11  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 18 u|		2049  0.1			0  0.0 |	 720085 15.6		  37  0.0 |15.7
 18 k|		  88  0.0			0  0.0 |		4833  0.2		  11  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 19 u|		2025  0.1			0  0.0 |	 749445 16.4		 154  0.1 |16.6
 19 k|		  61  0.0			0  0.0 |		4021  0.1		  10  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 20 u|		3018  0.1			0  0.0 |	 656454 14.4		  67  0.1 |14.6
 20 k|		 146  0.0			0  0.0 |		7947  0.3		  20  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
 21 u|		2741  0.1			0  0.0 |	 625196 13.8		  55  0.1 |13.9
 21 k|		 138  0.0			0  0.0 |	  10418  0.3		  49  0.0 | 0.4
-----+-------------------------------+-------------------------------+----
 22 u|		2398  0.1			0  0.0 |	 689484 15.4		  70  0.0 |15.5
 22 k|		 101  0.0			0  0.0 |		4794  0.2			9  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 23 u|		2066  0.1			0  0.0 |	 725470 15.9		  69  0.1 |16.0
 23 k|		  73  0.0			0  0.0 |		4826  0.2			5  0.0 | 0.2
=====+===============================+===============================+====
 ttl |	  53444  0.1			1  0.0 |  16968916 15.6		9097  0.1 |15.8

cpu m| itlb-miss %tim itsb-miss %tim | dtlb-miss %tim dtsb-miss %tim |%tim
-----+-------------------------------+-------------------------------+----
  0 u|		1576  0.1			0  0.0 |	 750380 16.7		 174  0.1 |16.8
  0 k|		  28  0.0			0  0.0 |		3248  0.1			9  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
  1 u|		1705  0.1			0  0.0 |	 722387 16.3	  16408  4.9 |21.3
  1 k|		  43  0.0			0  0.0 |		1635  0.1			9  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
  2 u|		1806  0.1			0  0.0 |	 711780 15.7		2202  0.7 |16.4
  2 k|		  54  0.0			0  0.0 |		4614  0.2			9  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  3 u|		1729  0.1			0  0.0 |	 610207 13.5		 291  0.1 |13.6
  3 k|		  64  0.0			0  0.0 |		9069  0.3		 107  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
  4 u|		1597  0.1			0  0.0 |	 764418 17.1		 926  0.3 |17.5
  4 k|		  28  0.0			0  0.0 |		 704  0.0			3  0.0 | 0.0
-----+-------------------------------+-------------------------------+----
  5 u|		1891  0.1			0  0.0 |	 727434 16.1		 347  0.1 |16.3
  5 k|		  67  0.0			0  0.0 |		3477  0.1		  18  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
  6 u|		2154  0.1			0  0.0 |	 746209 16.3		  51  0.0 |16.4
  6 k|		  94  0.0			0  0.0 |		3033  0.1		  13  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
  7 u|		1804  0.1			0  0.0 |	 582307 12.9		  48  0.0 |13.0
  7 k|		  70  0.0			0  0.0 |		4295  0.2		  11  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
  8 u|		3044  0.1			1  0.0 |	 585884 12.7		  59  0.0 |12.8
  8 k|		 160  0.0			0  0.0 |		9551  0.3		  21  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
  9 u|		2715  0.1			0  0.0 |	 615590 13.7		  59  0.0 |13.8
  9 k|		 125  0.0			0  0.0 |		9283  0.3		  17  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
 10 u|		2709  0.1			0  0.0 |	 622567 13.6		  62  0.0 |13.7
 10 k|		 132  0.0			0  0.0 |		7861  0.3		  18  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
 11 u|		2301  0.1			0  0.0 |	 634005 14.0		  58  0.0 |14.1
 11 k|		 120  0.0			0  0.0 |		9013  0.3		  17  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
 12 u|		2087  0.1			0  0.0 |	 727911 16.0		  47  0.1 |16.2
 12 k|		  91  0.0			0  0.0 |		4064  0.2			8  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 13 u|		2237  0.1			0  0.0 |	 562975 12.6		  67  0.0 |12.7
 13 k|		  95  0.0			0  0.0 |		8400  0.3		  81  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
 14 u|		1869  0.1			0  0.0 |	 718117 16.0		  62  0.1 |16.1
 14 k|		  51  0.0			0  0.0 |		2575  0.1			6  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 15 u|		2402  0.1			0  0.0 |	 663201 14.7		  64  0.0 |14.8
 15 k|		 100  0.0			0  0.0 |		7573  0.3		  14  0.0 | 0.3
-----+-------------------------------+-------------------------------+----
 16 u|		2006  0.1			0  0.0 |	 707264 15.7		  39  0.0 |15.8
 16 k|		  66  0.0			0  0.0 |		3384  0.1			7  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 17 u|		2084  0.1			0  0.0 |	 683385 15.1		  50  0.0 |15.2
 17 k|		  95  0.0			0  0.0 |		6058  0.2		  12  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 18 u|		1959  0.1			0  0.0 |	 760643 16.6		  55  0.0 |16.8
 18 k|		  53  0.0			0  0.0 |		2156  0.1			9  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 19 u|		1863  0.1			0  0.0 |	 719339 15.9		  51  0.1 |16.0
 19 k|		  67  0.0			0  0.0 |		4465  0.2		  17  0.0 | 0.2
-----+-------------------------------+-------------------------------+----
 20 u|		1879  0.1			0  0.0 |	 750976 16.6		  46  0.0 |16.7
 20 k|		  55  0.0			0  0.0 |		2377  0.1		  22  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 21 u|		1965  0.1			0  0.0 |	 715436 15.9		  52  0.0 |16.0
 21 k|		  67  0.0			0  0.0 |		3309  0.1			8  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 22 u|		2059  0.1			0  0.0 |	 749522 16.9		  47  0.0 |17.0
 22 k|		  71  0.0			0  0.0 |		2562  0.1		  11  0.0 | 0.1
-----+-------------------------------+-------------------------------+----
 23 u|		2141  0.1			0  0.0 |	 645171 14.3		  54  0.0 |14.4
 23 k|		  97  0.0			0  0.0 |		8825  0.3		  48  0.0 | 0.3
=====+===============================+===============================+====
 ttl |	  51475  0.1			1  0.0 |  16598639 15.4	  21814  0.3 |15.7

