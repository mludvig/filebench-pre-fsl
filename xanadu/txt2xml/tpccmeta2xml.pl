#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;


sub getHWConfig()
{
    xml_start_stat_group(name => '"Hardware Config"', type => '"categorical"');
    
    xml_start_cell_list();

    # Machine name
    @fields = split;
    xml_start_cell();
    print $fields[2];
    xml_end_cell();

    # Platform
    <INFILE>;
    $_ = <INFILE>;
    @fields = split;
    xml_start_cell();
    print $fields[-1];
    xml_end_cell();

    xml_start_cell();
    print $numcpus;
    xml_end_cell();

    # Memory
    $_ = <INFILE>;
    @fields = split;
    xml_start_cell();
    print @fields[-2..-1];
    xml_end_cell();

    $_ = <INFILE>;
    if (/^System clock/)
    {
	$defSysClock = 1;

	@fields = split;
	xml_start_cell();
	print $fields[-1];
	xml_end_cell();
    }

    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    xml_start_dimval();
    print "Value";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => '"Parameter"');
    
    foreach $name ('Machine Name', 'Platform', 'Num CPUs', 'Memory')
    {
	xml_start_dimval();
	print $name;
	xml_end_dimval();
    }
    if (defined($defSysClock))
    {
	xml_start_dimval();
	print 'System Clock';
	xml_end_dimval();
    }

    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();


    while (<INFILE>)
    {
	if (/= CPU/)
	{
	    xml_start_stat_group(name => '"CPU Detail"', type => '"categorical"');
    
	    xml_start_cell_list();
	}

	if (/CPU/ .. /Memory/)
	{
	    if (/US/) 
	    {
	    @fields = split;

	    $cpus = $fields[1];
	    @cpulist = split /,/, $cpus;
	    
	    xml_start_cell();
	    for ($c = 0; $c <= $#cpulist; $c++)
	    {
		$cpulist[$c] =~ s/\s+//g;

		print $online{$cpulist[$c]};
	    }
	    xml_end_cell();

	    if ($#fields == 6)
	    {
		$start = 3;
		$end = 6;
	    }
	    else
	    {
		$start = 2;
		$end = 5;
	    }
		
	    for ($f = $start; $f <= $end; $f++)
	    {
		xml_start_cell();
		print $fields[$f];
		xml_end_cell();
	    }

	    push(@cpulist, $cpus);
	}
	}
    
	if (/Memory/)
	{
	    xml_end_cell_list();

	    xml_start_dim_list();
	    xml_start_dim(name => '"Parameters"');
    
	    foreach $name (qw(Status MHz Ecache CPU Mask))
	    {
		xml_start_dimval();
		print $name;
		xml_end_dimval();
	    }
	    xml_end_dim();

	    xml_start_dim(name => '"CPU"');
    	    foreach $cpu (@cpulist)
	    {
		xml_start_dimval();
		print $cpu;
		xml_end_dimval();
	    }
	    xml_end_dim();
	    xml_end_dim_list();
	    xml_end_stat_group();
	}
    
	last if (/Memory/);
    }
    
}

sub getOSConfig()
{
    local @namelist;

    xml_start_stat_group(name => '"OS Config"', type => '"categorical"');
    xml_start_cell_list();
    <INFILE>;

    while (<INFILE>)
    {
	last if (/^Prtdiag/);

	if (/^set/)
	{
	    chop;
	    s/set //;

	    ($name, $value) = split("=");

	    # Get rid of comments and extra spaces
	    $value =~ s/\#.*//;
	    $value =~ s/\s+//;

	    xml_start_cell();
	    print $value;
	    xml_end_cell();

	    push(@namelist, $name);
	}

	if (/^\d/)
	{
	    ($proc, $status) = split;
	    $online{$proc} = $status;
	    $numcpus++;
	}

	if (/^SunOS/)
	{
	    @fields = split;

	    xml_start_cell();
	    print $fields[1];
	    xml_end_cell();
	    xml_start_cell();
	    print $fields[2];
	    xml_end_cell();

	    push(@namelist, "Version");
	    push(@namelist, "Version String");

	    last;
	}
    }

    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    xml_start_dimval();
    print "Value";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => '"Parameter"');
    
    foreach $name (@namelist)
    {
	xml_start_dimval();
	print $name;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

sub getDBConfig()
{
    local @namelist;

    xml_start_stat_group(name => '"Oracle Config"', type => '"categorical"');
    xml_start_cell_list();

    <INFILE>;
    while (<INFILE>)
    {
	last if ((/^SVRMGR/) || (/^SQL/));
	next if (/^(\s|-|NAME)/);

	@fields = split;
	
	xml_start_cell();
	print $fields[2] if (defined($fields[2]));
	xml_end_cell();

	push(@namelist, $fields[0]);
    }

    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    xml_start_dimval();
    print "Value";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => '"Parameter"');
    
    foreach $name (@namelist)
    {
	xml_start_dimval();
	print $name;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

sub getBenchConfig()
{
    @fields = split;
    $rampup = $fields[2];

    <INFILE>; 
    $_ = <INFILE>;
    @fields = split;
    $measure = $fields[2];

    <INFILE>; 
    $_ = <INFILE>;
    @fields = split;
    $scale = $fields[2];

    $_ = <INFILE>;
    @fields = split;
    $users = $fields[2];

    <INFILE>; <INFILE>;    <INFILE>; <INFILE>;
    $_ = <INFILE>;
    @fields = split;
    $servers = $fields[4];

    <INFILE>; <INFILE>;
    $_ = <INFILE>;
    @fields = split;
    $throughput = $fields[4];

    xml_start_stat_group(name=> "\"TPC-C Config\"", type => '"categorical"');
    xml_start_cell_list();

    foreach $stat ($throughput, $measure, $rampup, $scale, $servers, $users, 
		   $bdate, $comment)
    {
	xml_start_cell();
	print $stat;
	xml_end_cell();
    }

    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    xml_start_dimval();
    print "Value";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => '"Quantity"');

    foreach $stat ("Throughput", "Measurement", "Ramp Up", "Scale", "Servers", "Users", "Date", "Comment")
    {
	xml_start_dimval();
	print $stat;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}

sub getBindConfig()
{
    do {
	last if ($_ eq "\n");
	next unless (/was not bound/);

	@fields = split;

	$bind{$fields[7]}++;
    } while (<INFILE>);

    xml_start_stat_group(name => '"Process Binding"', type => '"categorical"');

    xml_start_cell_list();

    foreach $cpu (sort(keys %bind))
    {
	xml_start_cell();
	print $bind{$cpu};
	xml_end_cell();	
    }


    xml_end_cell_list();

    xml_start_dim_list();
    xml_start_dim();
    xml_start_dimval();
    print "Processes";
    xml_end_dimval();
    xml_end_dim();

    xml_start_dim(name => '"CPU"');

    foreach $cpu (sort(keys %bind))
    {
	xml_start_dimval();
	print $cpu;
	xml_end_dimval();
    }
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
}


# Main starts here

open(INFILE, $ARGV[0]);

xml_start_stat_doc(name=> '"TPCC Configuration"');
xml_meta(name => '"RunId"', value => "\"$ARGV[1]\"");


while (<INFILE>)
{
    getOSConfig() if (/^Contents of \/etc\/system/);

    getHWConfig() if (/^Prtdiag/);

    getDBConfig() if (/VALUE/);

    getBenchConfig() if (/^Ramp-up/);

#    getBindConfig() if (/^process id/);

    if (/^BENCH_DATE is:/)
    {
	@fields = split("is:");
	$bdate = $fields[1];
	$bdate =~ s/^\s+//;
    }
    elsif (/^comment/)
    {
	@fields = split(/:/);
	$comment = $fields[1];
	$comment =~ s/^\s+//;
	$comment =~ s/&/&amp;/g;
    }
}

xml_end_stat_doc();



