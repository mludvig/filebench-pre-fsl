#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;



sub first_pass()
{
open(INFILE, $ARGV[0]);

xml_start_stat_doc(name => '"Oracle Statistics"');
xml_meta(name => '"RunId"', value => "\"$ARGV[1]\"");

my($foundTimeStats, $foundThroughput, $foundResults);
$foundTimeStats = $foundThroughput = $foundResults  = 0;

while (<INFILE>)
{
    if ($foundTimeStats == 0 && /timed_statistics/)
    {
	$foundTimeStats = 1;
	@fields = split;
	if ($fields[2] eq 'TRUE')
	{
	    $timedStats = 1;
	}
	else
	{
	    $timedStats = 0;
	}
    }

    if ($foundThroughput == 0 && /^MQ/)
    {
	$foundThroughput = 1;
	tr_throughput_graph();
    }

}

close INFILE;
}

sub third_pass()
{
open(INFILE, $ARGV[0]);

tr_database_stats();

tr_wait_stats();

tr_system_event_stats();

tr_latch_stats();

tr_db_file_stats();

# tr_rollback_stats();  Not required for now

tr_sql_stmt_stats();

xml_end_stat_doc();

close INFILE;
}


sub second_pass()
{
    open(INFILE, $ARGV[0]);

    $procstate = 0;

    while (<INFILE>)
    {
	if (/CLS/)
	{
	    tr_process_times();
	}

	last if $procstate == 2;
    }

    close INFILE;
}

sub tr_process_times()
{
    if ($procstate == 0)
    {
	$procstate = 1;

	while (<INFILE>)
	{
	    last if ($_ eq "\n");
	    next unless /(TS|RT|FX).*ora.*bench/;

	    @fields = split;
	    $time = &timeInSec();
  
	    if (/ora_lgwr/)
	    {
		$init_lgwr = $time;
	    }
	    elsif (/ora_dbw/)
	    {
		$init_dbwr += $time;
	    }
	    elsif (/oracle bench/)
	    {
		$initOracleMT = $time;
	    }
	}
    }
    elsif ($procstate == 1)
    {
	$procstate = 2;

	while (<INFILE>)
	{
	    last if ($_ eq "\n");
	    next unless /((TS|RT|FX).*ora.*bench)/;

	    @fields = split;
	    $time = &timeInSec();
  
	    if (/ora_lgwr/)
	    {
		$fin_lgwr = $time;
	    }
	    elsif (/ora_dbw/)
	    {
		$fin_dbwr += $time;
	    }
	    elsif (/oraclebench/)
	    {
		$fin_shadow += $time;
	    }
	    elsif (/oracle bench/)
	    {
		$finOracleMT = $time;
	    }
	}

	xml_start_stat_group(name => '"Process CPU Times"');
	xml_start_cell_list();
	xml_start_cell();

	if (defined($fin_dbwr))
	{
	    if (defined($fin_shadow))
	    {
		print $fin_shadow;
		xml_end_cell();
		xml_start_cell();
		printf "%.2f", 1000 * $fin_shadow / $xacts;
		xml_end_cell();
		xml_start_cell();
		$shadowExists = 1;
	    }
	    else
	    {
		$fin_shadow = 0;
	    }

	    print $fin_dbwr - $init_dbwr;
	    xml_end_cell();
	    xml_start_cell();
	    printf "%.2f",  1000 * ($fin_dbwr - $init_dbwr) / $xacts;
	    xml_end_cell();
	    xml_start_cell();
	    print $fin_lgwr - $init_lgwr;
	    xml_end_cell();
	    xml_start_cell();
	    printf "%.2f", 1000 * ($fin_lgwr - $init_lgwr) / $xacts;
	    xml_end_cell();
	    xml_start_cell();
	    print $fin_dbwr - $init_dbwr + $fin_lgwr - $init_lgwr + $fin_shadow;
	    xml_end_cell();
	    xml_start_cell();
	    printf "%.2f",  1000 * ($fin_dbwr - $init_dbwr + $fin_lgwr - $init_lgwr + $fin_shadow) / $xacts;
	}
	else
	{
	    print $finOracleMT - $initOracleMT;
	    xml_end_cell();
	    xml_start_cell();
	    printf "%.2f",  1000 * ($finOracleMT - $initOracleMT) / $xacts;
	}

	xml_end_cell();
	xml_end_cell_list();

	xml_start_dim_list();
	xml_start_dim();
	xml_start_dimval();
	print "Total (s)";
	xml_end_dimval();
	xml_start_dimval();
	print "Per Trans (ms)";
	xml_end_dimval();
	xml_end_dim();

	xml_start_dim(name => '"Process"');

	if (defined($fin_dbwr))
	{
	    @statList = ("Fgnd", "Dbwr", "Lgwr", "Total");
	    shift(@statList) unless (defined($shadowExists));
	}
	else
	{
	    @statList = ("Total");
	}

	foreach $stat (@statList)
	{
	    xml_start_dimval();
	    print $stat;
	    xml_end_dimval();
	}
	xml_end_dim();
	xml_end_dim_list();
	xml_end_stat_group();
    }
}

sub timeInSec()
{
    if ($fields[7] =~ ":")
    {
	$timeField = $fields[7];
    }
    else
    {
	$timeField = $fields[8];
    }

    ($min, $sec) = split /:/, $timeField;

    $min * 60 + $sec;
}

sub tr_throughput_graph()
{
    xml_start_stat_group(name=> '"Throughput"');
    xml_start_cell_list();

    @fields = split;
    xml_start_cell();
    print $fields[4];
    xml_end_cell();
    
    xml_end_cell_list();
    
    xml_start_dim_list();

    xml_start_dim();
    xml_start_dimval();
    print "Average Throughput";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name=>'"Transaction"');
    xml_start_dimval();
    print "New-order";
    xml_end_dimval();
    xml_end_dim();

    xml_end_dim_list();
    xml_end_stat_group();

    while (<INFILE>)
    {
	if (/^Total number of transactions/)
	{
	    @fields = split;
	    $xacts = $fields[5];
	}
	last if /^TIME/;
    }

    xml_start_stat_group(name=> "\"Throughput Graph\"", display=>"\"gnuplot-png\"");
    xml_start_cell_list();

    # Get the data
    my(@rowlist);

    while (<INFILE>)
    {
	last if (/Payment/);

	@fields = split;
	last if ($fields[1] == 0);

	push(@rowlist, $fields[0]);
	xml_start_cell();
	print $fields[1] * 2;
	xml_end_cell();
    }	
    xml_end_cell_list();
    
    xml_start_dim_list();

    xml_start_dim();
    xml_start_dimval();
    print "New Order";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => "\"Time (s)\"");
    foreach $timeSample (@rowlist)
    {
	xml_start_dimval();
	print $timeSample;
	xml_end_dimval();
    }
    xml_end_dim();

    xml_end_dim_list();
    xml_end_stat_group();    
}

sub tr_database_stats()
{
    while (<INFILE>)
    {
	last if (/Database Statistics/);
    }

    ## See if we really have any data
    <INFILE>;
    $_ = <INFILE>;

    return unless (/^STAT_NAME/);

    my(@rowlist);
    xml_start_stat_group(name => '"Database Statistics"');
    xml_start_cell_list();
    while (<INFILE>)
    {
	chop;

	# Skip whitespace & headers
	next if (/^STAT_NAME/ || /^---------/ ||$_ eq '');
	last if (/^Per Transaction/);

	s/\t/        /g;
	@fields = split(/  +/);

	$dbBlockGets = $fields[1] if (/^db block gets/);
	$consistentGets = $fields[1] if (/^consistent gets/);
	$physReads = $fields[1] if ($fields[0] eq "physical reads");

	if ($fields[1] ne '###########')
	{
	    $fields[2] = $fields[1] / $xacts;
	}

	if ($fields[2] >= 0.01)
	{
	    push(@rowlist, $fields[0]);
	    xml_start_cell();
	    printf("%.3f", $fields[2]);
	    xml_end_cell();
	}
    }
    xml_start_cell();
    printf("%.3f", $physReads * 100 / ($dbBlockGets + $consistentGets));
    xml_end_cell();
    push(@rowlist, "Buffer Miss Ratio (%)");

    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    xml_start_dimval();
    print "Per Txn";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => "\"Stat Name\"");
    foreach $stat (@rowlist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

sub tr_wait_stats()
{
    while (<INFILE>) 
    {
	last if ($_ eq "Total Wait Stats By Class\n");
    }

    <INFILE>; 
    $_ = <INFILE>; 

    return unless (/^CLASS/);

    <INFILE>;

    my(@rowlist);
    xml_start_stat_group(name => '"Waits by Class"');
    xml_start_cell_list();

    while (<INFILE>)
    {
	last if ($_ eq "\n");

	chop;
	s/\t/        /g;
	@fields = split(/  +/);

	if ($fields[1] =~ /#/)
	{
	  $fields[1] =~ s/ #+//;
	  $fields[2] = 0;
	}

	$fields[1] /= $xacts;

	if ($fields[1] >= 0.0001 || $_ =~ /#/)
	{
	    push(@rowlist, $fields[0]);

	    xml_start_cell();
	    printf("%.5f", $fields[1]);
	    xml_end_cell();

		xml_start_cell();
		printf("%.1f", $fields[2] / ($fields[1] * $xacts));
		xml_end_cell();
 	}
    }

    xml_end_cell_list();

    xml_start_dim_list();

    xml_start_dim();
    xml_start_dimval();
    print "Waits Per Txn";
    xml_end_dimval();
	xml_start_dimval();
	print "Time Per Wait";
	xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => "\"Class Name\"");
    foreach $stat (@rowlist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();

    @rowlist = ();
    xml_start_stat_group(name => '"Waits by File"');
    xml_start_cell_list();

    while (<INFILE>) 
    {
	last if ($_ eq "Total Wait Stats By File\n");
    }

    <INFILE>; <INFILE>; <INFILE>;

    while (<INFILE>)
    {
	last if ($_ eq "System Event Stats\n");
	# Skip whitespace & headers
	next if (/^DATA_FILENAME/ || /^---------/ || /TIME/ ||$_ eq "\n");

	chop;
	@fields = split;

	$time = undef;

	if ($#fields >= 2)
	{
	  $filename = $fields[0];
	  $count = $fields[2];
	  $count /= $xacts;

	  if ($count >= 0.0001)
	  {
	    push(@rowlist, $filename);

	    xml_start_cell();
	    printf("%.5f", $count);
	    xml_end_cell();
	  }

	  $time = $fields[3]  if ($#fields == 3);
	}
	else
	{
	  $time = $fields[0];
	}

	if (defined($time) && $count >= 0.0001)
	{
		xml_start_cell();
		printf("%.1f", $time / ($count * $xacts));
		xml_end_cell();
	}
    }

    xml_end_cell_list();

    xml_start_dim_list();

    xml_start_dim();
    xml_start_dimval();
    print "Waits Per Txn";
    xml_end_dimval();
	xml_start_dimval();
	print "Time Per Wait";
	xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => "\"File Name\"");
    foreach $stat (@rowlist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

sub tr_system_event_stats()
{
    my(@rowlist);

    <INFILE>; 
    $_ = <INFILE>; 

    return unless /^EVENT/;

    <INFILE>;

    xml_start_stat_group(name => '"System Event Statistics"');

    xml_start_cell_list();

    while (<INFILE>)
    {
	last if ($_ eq "\n");

	chop;
	s/\t/        /g;
	@fields = split(/  +/);

	@newfields = split(/ +/, $fields[3]);
	# Sometimes the above is not required
	$newfields[1] = $fields[4] if (defined($fields[4]));

	$fields[1] /= $xacts;

	if ($fields[1] >= 0.001 || $newfields[0] / $xacts >= 0.001)
	{
	    push(@rowlist, $fields[0]);
	    xml_start_cell();
	    printf("%.3f", $fields[1]);
	    xml_end_cell();

	    if ($timedStats)
	    {
		xml_start_cell();
		printf("%.2f", $newfields[1]);
		xml_end_cell();
	    }
	}
    }

    xml_end_cell_list();

    xml_start_dim_list();

    xml_start_dim();
    xml_start_dimval();
    print "Count Per Txn";
    xml_end_dimval();
    if ($timedStats)
    {
	xml_start_dimval();
	print "Time Per Event";
	xml_end_dimval();
    }
    xml_end_dim();

    xml_start_dim(name => "\"System Event Name\"");
    foreach $stat (@rowlist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

sub tr_latch_stats()
{
    my(@rowlist);

    while (<INFILE>) 
    {
	last if (/^Latch Gets/);
    }
    <INFILE>;
    $_ = <INFILE>;

    return unless (/^NAME/);

    xml_start_stat_group(name => '"Latch Statistics"');

    xml_start_cell_list();

    for ($i = 0; <INFILE>;)
    {
	last if (/^Latch Gets/);
	# Skip whitespace & headers
	next if (/^NAME/ || /^---------/ ||$_ eq "\n");

	chop;
	s/\t/        /g;
	$latchname[$i] = substr($_, 0, 20);

	$_ = substr($_, 22);
	@fields = split;

	$latchgets[$i] = $fields[0];
	$latchmisses[$i] = $fields[1];
	$latchsleeps[$i] = $fields[2];
	# Has to be done here so that the 'next' does not increment $i
	$i++;
    }

    for ($i = 0; <INFILE>;)
    {
	last if (/^Total Latch/);
	# Skip whitespace & headers
	next if (/^NAME/ || /^---------/ ||$_ eq "\n");

	chop;
	s/\t/        /g;
	$newlatchname = substr($_, 0, 20);

	if ($newlatchname ne $latchname[$i])
	{
	    print STDERR "$i\t$newlatchname\t$latchname[$i]\n";
	    die;
	}

	$_ = substr($_, 22);
	@fields = split;

	$latchgets[$i] /= $xacts;
	$fields[0] /= $xacts;

	if (($latchgets[$i] >= 0.001) || ($fields[0] >= 0.001))
	{
	    push(@rowlist, $newlatchname);

	    xml_start_cell();
	    printf("%.3f", $latchgets[$i]);
	    xml_end_cell();

	    xml_start_cell();
	    if ($latchgets[$i] == 0)
	    {
		print "0.00";
	    }
	    else
	    {
	      printf("%.2f", $latchmisses[$i] * 100 / ($latchgets[$i] * $xacts));
	    }
	    xml_end_cell();

	    xml_start_cell();
	    if ($latchgets[$i] == 0)
	    {
		print "0.00";
	    }
	    else
	    {
	      printf("%.2f", $latchsleeps[$i] * 100 / ($latchgets[$i] * $xacts));
	    }
	    xml_end_cell();

	    xml_start_cell();
	    printf("%.3f", $fields[0]);
	    xml_end_cell();

	    if ($fields[0] > 0)
	    {
		xml_start_cell();
		printf("%.2f", $fields[1] * 100 / ($fields[0] * $xacts));
		xml_end_cell();
	    }
	    else
	    {
		xml_start_cell();
		print "0.00";
		xml_end_cell();
	    }
	}

	$i++;
    }

    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    foreach $stat ("Gets Per Txn", "Miss %", "Sleep %", "Im Gets Per Txn", "Im Miss %")
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();

    xml_start_dim(name => '"Latch Name"');
    foreach $stat (@rowlist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

sub tr_db_file_stats()
{
    my(@rowlist);
    my(@collist);
    while (<INFILE>) 
    {
	last if (/^Database File/);
    }

    <INFILE>;
    $_ = <INFILE>;

    return unless /^FILE_NAME/;

    xml_start_stat_group(name => '"DB File Statistics"');

    while (<INFILE>)
    {
	last if (/WRITES/);
	# Skip whitespace & headers
	next if (/^FILE_NAME/ || /^---------/ ||$_ eq "\n");

	chop;
	@fields = split;

	$filename = $fields[0];

	# Just use the type of file, e.g. stk, cust etc
	$filename =~ s/\d+$//;

	$reads{$filename} += $fields[1];
	$readtime{$filename} += $fields[3];
    }

    while (<INFILE>)
    {
	last if (/^Rollback/);
	# Skip whitespace & headers
	next if (/^FILE_NAME/ || /^---------/ ||$_ eq "\n");

	chop;
	@fields = split;

	$filename = $fields[0];

	# Just use the type of file, e.g. stk, cust etc
	$filename =~ s/\d+$//;

	$writes{$filename} += $fields[1];
	$writetime{$filename} += $fields[3];
    }

    xml_start_cell_list();
    foreach $filename (keys %reads)
    {
	push(@rowlist, $filename);
	xml_start_cell();
	printf("%.4f", $reads{$filename} / $xacts);
	xml_end_cell();

	$totalReads += $reads{$filename};

	if ($timedStats)
	{
	    xml_start_cell();
	    printf("%.2f", $readtime{$filename} / $reads{$filename});
	    xml_end_cell();
	}

	xml_start_cell();
	printf("%.4f", $writes{$filename} / $xacts);
	xml_end_cell();

	$totalWrites += $writes{$filename};

	if ($timedStats)
	{
	    xml_start_cell();
	    printf("%.2f", $writetime{$filename} / $writes{$filename});
	    xml_end_cell();
	}
    }
    # Now write the total
    push(@rowlist, "Total");
    xml_start_cell();
    printf("%.4f", $totalReads / $xacts);
    xml_end_cell();

    if ($timedStats)
    {
	xml_start_cell();
	print '-';
	xml_end_cell();
    }

    xml_start_cell();
    printf("%.4f", $totalWrites / $xacts);
    xml_end_cell();

    if ($timedStats)
    {
	xml_start_cell();
	print '-';
	xml_end_cell();
    }
    
    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    @collist = "Reads Per Txn";
    push(@collist, "Time Per Read") if $timedStats;
    push(@collist, "Writes Per Txn");
    push(@collist, "Time Per Write") if $timedStats;
    foreach $stat (@collist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();

    xml_start_dim(name => "\"File Name\"");
    foreach $stat (@rowlist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

#sub tr_rollback_stats()
#{
#    my(@rowlist);
#    xml_start_stat_group("Rollback Segment Statistics");
#    xml_start_dim_list("col");
#    xml_start_dim();
#    xml_dimval("Writes", "Gets", "Waits", "Hwmsize", "Wraps", "Aveactive");
#    xml_end_dim();
#    xml_end_dim_list("col");

#    for ($i = 0; <INFILE>;)
#    {
#	last if (/SHRINKS/);
	# Skip whitespace & headers
#	next if (/^NAME/ || /^---------/ ||$_ eq "\n");

#	chop;
#	@fields = split;

#	$name[$i] = $fields[0];
#	$writes[$i] = $fields[3];
#	$gets[$i] = $fields[5];
#	$waits[$i] = $fields[6];

#	$i++;
#    }

#    for ($i = 0; <INFILE>;)
#    {
#	last if (/WRAPS/);
	# Skip whitespace & headers
#	next if (/^NAME/ || /^---------/ ||$_ eq "\n");

#	chop;
#	@fields = split;

#	die if ($fields[0] ne $name[$i]);

#	$hwmsize[$i] = $fields[1];

#	$i++;
#    }

#    for ($i = 0; <INFILE>;)
#    {
#	last if (/^Row Cache/);
	# Skip whitespace & headers
#	next if (/^NAME/ || /^---------/ ||$_ eq "\n");

#	chop;
#	@fields = split;

#	die if ($fields[0] ne $name[$i]);

#	    push(@rowlist, $fields[0]);
#	    xml_cell($writes[$i]);
#	    xml_cell($gets[$i]);
#	    xml_cell($waits[$i]);
#	    xml_cell($hwmsize[$i]);
#	    xml_cell($fields[1]);
#	    xml_cell($fields[4]);
#	$i++;
#    }
#    xml_start_dim_list("row");
#    xml_start_dim("label=\"Rollback Segment\"");
#    xml_dimval(@rowlist);
#    xml_end_dim();
#    xml_end_dim_list("row");
#    xml_end_stat_group();
#}

sub tr_sql_stmt_stats()
{
    my(@rowlist);
    <INFILE>;
    $_ = <INFILE>;

    return unless /ABORTS/;

    <INFILE>;

    xml_start_stat_group(name => '"SQL Statement Statistics"');

    xml_start_cell_list();

    while (<INFILE>)
    {
	last if ($_ eq "\n");

	chop;
	@fields = split;

	# Remove Everything except the statement
	s/\d|\.|\#//g;
	# Remove leading spaces
	s/^\s+//;

	$stmtmap{$_}[0] += $fields[1];
	$stmtmap{$_}[3] += $fields[0];
    }
    <INFILE>; <INFILE>;

    while (<INFILE>)
    {
	last if ($_ eq "\n");

	chop;
	@fields = split;

	# Remove Everything except the statement
	s/\d|\.|\#//g;
	# Remove leading spaces
	s/^\s+//;

	$stmtmap{$_}[0] += $fields[1] unless (defined($stmtmap{$_}));
	$stmtmap{$_}[2] += $fields[0];
    }
    <INFILE>; <INFILE>;

    while (<INFILE>)
    {
	last unless (/^\s+\d/);

	chop;
	@fields = split;

	# Remove Everything except the statement
	s/\d|\.|\#//g;
	# Remove leading spaces
	s/^\s+//;

	$stmtmap{$_}[0] += $fields[1] unless (defined($stmtmap{$_}));
	$stmtmap{$_}[1] += $fields[0];
    }

    foreach $stmt (keys(%stmtmap))
    {
	push(@rowlist, $stmt);

	xml_start_cell();
	print $stmtmap{$stmt}[0];
	xml_end_cell();

	if (defined($stmtmap{$stmt}[1]))
	{
	    xml_start_cell();
	    print STDERR "$stmt $stmtmap{$stmt}[0]\n";
	    printf("%.2f", $stmtmap{$stmt}[1] / $stmtmap{$stmt}[0]);
	    xml_end_cell();
	}
	else
	{
	    xml_start_cell();
	    print "0";
	    xml_end_cell();
	}
	if (defined($stmtmap{$stmt}[2]))
	{
	    xml_start_cell();
	    printf("%.2f", $stmtmap{$stmt}[2] / $stmtmap{$stmt}[0]);
	    xml_end_cell();
	}
	else
	{
	    xml_start_cell();
	    print "0";
	    xml_end_cell();
	}
	if (defined($stmtmap{$stmt}[3]))
	{
	    xml_start_cell();
	    printf("%.2f", $stmtmap{$stmt}[3] / $stmtmap{$stmt}[0]);
	    xml_end_cell();
	}
	else
	{
	    xml_start_cell();
	    print "0";
	    xml_end_cell();
	}
    }

    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    foreach $stat ("Execs", "Gets Per Exec", "Reads Per Exec", "Aborts per Exec")
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();

    xml_start_dim(name => "\"SQL Statement\"");
    foreach $stat (@rowlist)
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}



first_pass();
second_pass();
third_pass();

