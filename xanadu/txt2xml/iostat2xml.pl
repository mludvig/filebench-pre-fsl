#!/usr/bin/perl -w

# This should be able to handle -xnz options

use lib "../txt2xml";

use txt2xml;

open(INFILE, $ARGV[0]);



$disknum = 0;

xml_start_stat_doc(name => "\"Iostat\"");

$samples = -1;
$firstTime = 1;
$interval = 10;

while (<INFILE>)
{
    if (/^Iostat/)
    {
	@fields = split;
	$interval = $fields[9];
    }
    elsif (/^\# iostat/)
    {
	@fields = split;
	$interval = $fields[3];
    }
    elsif (/extended/)
    {
        last;
    }
    else
    {
	next;
    }
}

xml_meta(name => "\"RunId\"", value => "\"$ARGV[1]\"");
xml_meta(name => "\"interval\"", value => "\"$interval\"");

do {{
    if (/extended/)
    {
        $_ = <INFILE>;

	if ($firstTime)
	{
	    # Get the header
	    if (/r\/s/)
	    {
		@header = split;
		$firstTime = 0;
	    }
	}

	$samples++;
	next;
    } 

    # Skip the first sample
    next if $samples == 0;

    @fields = split;

    # Ignore invalid lines in input
    next if $#fields < 10;

    # The assumption that the first input cycle ($samples=1) includes 
    # all possible existing devices is not valid when -z is used
    # Device name is always last field

    $j = $devHash{$fields[$#fields]};

    unless (defined($j))
    {
	# Must record the disks
	$devHash{$fields[$#fields]} = $disknum;

	$j = $disknum++;
	    
	push @devList, $fields[$#fields];
    }

# Record the data

    for ($i = 1; $i <= $#fields; $i++)
    {
	#$fields[$#fields] is device's name.
	$tmp[$j][$i][$samples] = $fields[$i-1];
    }

}} while (<INFILE>);


#Each metric is a stat group
%metrics = ( 
	    "r/s" => "Reads per second",
            "w/s" => "Writes per second",
            "kr/s" => "Kilobytes read per second",
            "kw/s" => "Kilobytes written per second",
            "wait" => "Transactions waiting for service",
            "actv" => "Transactions actively being serviced",
            "wsvc_t" => "Average wait time (ms)",
            "asvc_t" => "Average service time (ms)",
            "%w" => "Wait Time Percentage",
            "%b" =>  "Disk Busy Percentage",
	    "s/w" => "Soft Errors",
	    "h/w" => "Hard Errors",
	    "trn" => "Transport Errors",
	    "tot" => "Total Errors"
	    );

$labelNum = 1;
foreach $label (@header)
{
    next if ($label eq "device");

    xml_start_stat_group(name => "\"$metrics{$label}\"", display => "\"gnuplot-png\"");

    # Now print all the data
    xml_start_cell_list();

    for ($ind = 1; $ind <= $samples; $ind++)
    {
	for ($disknum = 0; $disknum <= $#devList; $disknum++)
	{
	    xml_start_cell();

	    $v = $tmp[$disknum][$labelNum][$ind];

	    if (defined($v))
	    {
		print $v;
	    }
	    else
	    {
		print "0";
	    }

	    xml_end_cell();
	}
    }

    xml_end_cell_list();

    xml_start_dim_list();

    # Print the devs as columns
    xml_start_dim(group => '"0"', level => '"0"');
    $j = 0;
    foreach $dev (@devList)
    {
	xml_start_dimval();
	print "$dev";
	xml_end_dimval();

	$j++;
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
    $labelNum++;
}

xml_end_stat_doc();


__END__
