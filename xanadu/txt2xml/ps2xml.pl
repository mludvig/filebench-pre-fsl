#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;

$begin = 1;
&readPsFile();

$begin = 0;
$ARGV[0] =~ s/ps_begin/ps_end/;
&readPsFile();

xml_start_stat_doc(name => "\"CPU Consumption\"");
xml_meta(name => "\"RunId\"", value => "\"$ARGV[1]\"");

xml_start_stat_group(name => '"Oracle processes"');
xml_start_cell_list();

foreach $process (sort(keys(%procTime)))
{
    xml_start_cell();
    print "$procTime{$process}";
    xml_end_cell();
}

xml_end_cell_list();

xml_start_dim_list();
xml_start_dim();
xml_start_dimval();
print 'CPU Time (s)';
xml_end_dimval();
xml_end_dim();

xml_start_dim();
foreach $process (sort(keys(%procTime)))
{
    xml_start_dimval();
    print "$process";
    xml_end_dimval();
}

xml_end_dim();
xml_end_dim_list();


xml_end_stat_group();
xml_end_stat_doc();



sub readPsFile()
{
open(INFILE, $ARGV[0]);

while (<INFILE>)
{
    @fields = split;
    if ($#fields == 1)
    {
	$time = $fields[0];
	$process = $fields[1];
    }
    elsif ($#fields >= 2)
    {
	$time = $fields[1];
	$process = $fields[2];
    }
    else
    {
	exit;
    }

    next unless ($process =~ /^ora/);

    if ($process =~ /^ora_/)
    {
	$process =~ s/\d?_[^_]+$//;
    }
    elsif ($process =~ /^oracle/)
    {
	$process = "ora_fgnd";
    }
    else
    {
	next;
    }

    if ($begin)
    {
	$procTime{$process} -= &convertToSec();
    }
    else
    {
	$procTime{$process} += &convertToSec();
    }

}
}

sub convertToSec()
{
    ($min, $sec) = split(':', $time);

    return $min * 60 + $sec;
}
