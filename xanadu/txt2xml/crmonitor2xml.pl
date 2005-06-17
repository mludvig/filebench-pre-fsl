#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;

open(INPUT, $ARGV[0]);

xml_start_stat_doc(name => "\"CR Test\"");
xml_meta(name => "\"RunId\"", value => "\"$ARGV[1]\"");

$_=<INPUT>;

if (/cr received/)
{
    $client = 1;
}
else
{
    $client = 0;
}

# Skip the first 3 lines
<INPUT>; <INPUT>; <INPUT>;

# Split on ,
while (<INPUT>)
{
    @fields = split(",");

    $totThroughput += $fields[1];

    $totLatency += $fields[2] if ($client);

    $numSamples++;
}

# Remove the last sample
$totThroughput -= $fields[1];

$totLatency -= $fields[2] if ($client);

$numSamples--;


if ($client)
{
    xml_start_stat_group(name => "\"Client Results\"");
}
else
{
    xml_start_stat_group(name => "\"Server Results\"");
}

xml_start_cell_list();

xml_start_cell();
printf "%.0f",  $totThroughput / $numSamples;
xml_end_cell();

if ($client)
{
    xml_start_cell();
    printf "%.2f",  $totLatency / $numSamples;
    xml_end_cell();
}

xml_end_cell_list();

xml_start_dim_list();

xml_start_dim(group => '"0"', level => '"0"');

xml_start_dimval();
print "Avg Throughput";
xml_end_dimval();

if ($client)
{
    xml_start_dimval();
    print "Avg Latency";
    xml_end_dimval();
}

xml_end_dim();

xml_end_dim_list();

xml_end_stat_group();

xml_end_stat_doc();
