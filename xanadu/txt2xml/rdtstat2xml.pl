#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;

open(INFILE, $ARGV[0]);

xml_start_stat_doc(name => "\"Rdtstat\"");
xml_meta(name => "\"RunId\"", value => "\"$ARGV[1]\"");

xml_start_stat_group(name => "\"Network Activity\"", display => '"gnuplot-png"');
xml_start_cell_list();

$interval = 0;

while (<INFILE>)
{
    @fields = split;

    next if ($#fields >= 4);

    foreach $field (@fields)
    {
	xml_start_cell();
	print $field;
	xml_end_cell();
    }

    $interval++;
}

xml_end_cell_list();

xml_start_dim_list();
xml_start_dim();
xml_start_dimval();
print 'opackets';
xml_end_dimval();
xml_start_dimval();
print 'ipackets';
xml_end_dimval();
xml_start_dimval();
print 'intrs sent';
xml_end_dimval();
xml_start_dimval();
print 'timers exp';
xml_end_dimval();
xml_end_dim();

xml_start_dim();
for ($i = 0; $i < $interval; $i++)
{
    xml_start_dimval();
    print $i * 10;
    xml_end_dimval();
}
xml_end_dim();
xml_end_dim_list();

xml_end_stat_group();
xml_end_stat_doc();
