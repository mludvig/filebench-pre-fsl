#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;

open(INPUT, $ARGV[0]);

xml_start_stat_doc(name => "\"Mpstat\"");
xml_meta(name => "\"RunId\"", value => "\"$ARGV[1]\"");

$samples = 0;
$firstTime = 1;
$prevCpu = -1;
$interval = 10;

while (<INPUT>)
{
    if (/^Mpstat/)
    {
	@fields = split;
	$interval = $fields[9];
    }
    elsif (/^\# iostat/)
    {
	@fields = split;
	$interval = $fields[3];
    }
    elsif (/^(CPU|SET)/)
    {
        last;
    }
    else
    {
	next;
    }
}


do {{
    next if /State change/;
    next if /^\n/;

    if (/^(CPU|SET)/)
    {
	if ($firstTime == 1)
	{
            # Get the header
	    @header = split;
	    $numMetrics = $#header;

	    $firstTime = 2;

	    xml_meta(name => "\"interval\"", value => "\"$interval\"");
	}
	elsif ($firstTime == 2)
	{
	    $firstTime = 0;
	}

	$samples++;
	$cpunum = 0;
    }
    elsif (/^Mpstat/)
    {
	@fields = split;
	$interval = $fields[9];
    }
    else
    {
	@fields = split;
	$cpu = $fields[0];

	if ($prevCpu == $cpu)
	{
	    $samples++;
	    $cpunum = 0;
	}
	elsif ($firstTime == 2)
	{
	    # Must record the CPUs
	    push @cpuList, $cpu;

	    # Zero out the significance flag
	    for ($i = 1; $i <= $numMetrics; $i++)
	    {
		$significant[$i][$#cpuList] = 0;
	    }
	}

	$prevCpu = $cpu;

	for ($i = 1; $i <= $#fields; $i++)
	{
	    push @{$data[$i]}, $fields[$i];

	    # Is this data significant?
	    $significant[$i][$cpunum] = 1 if ($fields[$i] >= 5);
	}
	$cpunum++;
    }
}}
while (<INPUT>);


# This is where the XML output happens

#Each metric is a stat group
%metrics = ( "minf" => "Minor Faults",
	    "mjf" => "Major Faults",
	    "xcal" => "Cross Calls",
	    "intr" => "Interrupts",
	    "ithr" => "Interrupt Threads",
	    "csw" => "Total Context Switches",
	    "icsw" => "Involuntary Context Switches",
	    "migr" => "Thread Migrations",
	    "smtx" => "Mutex Spins",
	    "srw" =>  "R/W Lock Spins",
	    "syscl" => "System Calls",
	    "usr" => "User Time",
	    "sys" => "System Time",
	    "wt" => "Wait Time",
	    "idl" => "Idle Time",
	    "sze" => "Processor Set Size");

$labelNum = -1;
foreach $label (@header)
{
    # This has to be put here for skipping empty statgroups
    $labelNum++;

    next if ($label =~ /CPU|SET/);

    # Check if this stat group is significant
    $sig = 0;
    $cpunum = 0;
    foreach $cpu (@cpuList)
    {
	if ($significant[$labelNum][$cpunum])
	{
	    $sig = 1;
	    last;
	}
	$cpunum++;
    }

    next unless $sig == 1;


    xml_start_stat_group(name => "\"$metrics{$label}\"", display => "\"gnuplot-png\"");

# Now print all the data
    xml_start_cell_list();

    $cpunum = 0;
    foreach $value (@{$data[$labelNum]})
    {
	if ($significant[$labelNum][$cpunum])
	{
	    xml_start_cell();
	    print $value;
	    xml_end_cell();
	}
	$cpunum = ++$cpunum % ($#cpuList + 1);
    }

    xml_end_cell_list();

    xml_start_dim_list();

# Print the cpus as columns
    xml_start_dim(group => '"0"', level => '"0"');
    $cpunum = 0;
    foreach $cpu (@cpuList)
    {
	if ($significant[$labelNum][$cpunum])
	{	
	    xml_start_dimval();
	    if ($header[0] eq "CPU") {
		print "CPU ";
	    } else {
		print "SET ";
	    }
	    print $cpu;
	    xml_end_dimval();
	}

	$cpunum++;
    }
    xml_end_dim();

    xml_start_dim(group => '"1"', level => '"1"', name => '"Time (s)"');
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
