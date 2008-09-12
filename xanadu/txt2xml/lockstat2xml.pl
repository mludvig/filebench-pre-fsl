#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;

$traceNum = 0;
$maxdepth = 100;

xml_start_stat_doc(name => '"lockstat"');

$runId = $ARGV[1];

xml_meta((name => "\"RunId\"", value => "\"$runId\""));

xml_start_stat_group(name => '"stacks"');

xml_start_cell_list();


open(INFILE, $ARGV[0]);

<INFILE>; <INFILE>; <INFILE>; <INFILE>; 
$_ = <INFILE>;

while (<INFILE>)
{
    @fields = split;
    
    $fields[5] =~ s/cpu\[//;
    $fields[5] =~ s/\].*//;

    # Store the CPU
    $cpu[$traceNum] = $fields[5];

    # Store the count
    $count[$traceNum] = $fields[0];

    $frameNum = 0;
    printStackFrame($fields[6]);

    $frameNum++;
    <INFILE>; <INFILE>;
    while (<INFILE>)
    {
	if (/^--/)
	{
	    <INFILE>;
	    last;
	}

	next if (/lockstat_intr|cyclic_fire|cbe_level14|current_thread/);

	@fields = split;
	next if ($#fields == 2);

	if (defined($fields[3]))
	{
	    printStackFrame($fields[3]);
	}
	else
	{
	    printStackFrame($fields[0]);
	}
	$frameNum++;
    }

    $traceNum++;
}

xml_end_cell_list();

xml_start_dim_list();
xml_start_dim(name => '"Frame Data"');
  xml_start_dimval();
  print "module";
  xml_end_dimval();
  xml_start_dimval();
  print "function";
  xml_end_dimval();
  xml_start_dimval();
  print "offset";
  xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Stack Frame"');
for ($i = 0; $i < $maxdepth; $i++)
{
  xml_start_dimval();
  print $i;
  xml_end_dimval();
}
xml_end_dim();

xml_start_dim(name => '"Stack Trace Num"');
for ($i = 0; $i < $traceNum; $i++)
{
  xml_start_dimval();
  print $i;
  xml_end_dimval();
}
xml_end_dim();

xml_end_dim_list();

xml_end_stat_group();


# Now print the samples

xml_start_stat_group(name => '"samples"');

xml_start_cell_list();

for ($i = 0; $i < $traceNum; $i++)
{
    xml_start_cell();
    print $cpu[$i];
    xml_end_cell();

    xml_start_cell();
    print $count[$i];
    xml_end_cell();
}

xml_end_cell_list();

xml_start_dim_list();
xml_start_dim(name => '"Profile Data"');
xml_start_dimval();
print "cpu";
xml_end_dimval();
xml_start_dimval();
print "time";
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Trace Num"');

for ($i = 0; $i < $traceNum; $i++)
{
  xml_start_dimval();
  print $i;
  xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();

xml_end_stat_doc();


sub printStackFrame()
{
    $module = $func = $offset = $frame = $_[0];

    $ordinal = $traceNum * $maxdepth * 3 + $frameNum * 3;

    if ($frame =~ /`/)
    {
    $module =~ s/`.*//;
      xml_start_cell(ordinal => "\"$ordinal\"");
      print $module;
      xml_end_cell();
    }

    $ordinal++;
    $func =~ s/(.*\`)|(\+.*)//g;
    xml_start_cell(ordinal => "\"$ordinal\"");
    print $func;
    xml_end_cell();

    $ordinal++;

    if ($frame =~ /\+/)
    {
	$offset =~ s/.*\+//;
    }
    else
    {
	$offset = '0x0';
    }    

    # Change the offset from hex to a decimal number
    xml_start_cell(ordinal => "\"$ordinal\"");
    print hex($offset);
    xml_end_cell();
}
