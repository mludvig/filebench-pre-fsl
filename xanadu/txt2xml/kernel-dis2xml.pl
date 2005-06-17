#!/usr/bin/perl -w

use lib "../txt2xml";

use txt2xml;

open(INFILE, $ARGV[0]);

$runId = $ARGV[1];

xml_start_stat_doc(name => '"Kernel Symbols"');
xml_meta((name => "\"RunId\"", value => "\"$runId\""));

xml_start_stat_group(name => '"Kernel Symbols"');
xml_start_cell_list();

while(<INFILE>)
{
  @fields = split(":");

  $_ = $fields[0];
  $instr = $fields[1];
  chop($instr);

  $instr = "" unless (defined($instr));
  $instr =~ s/^(\s+)//;
  $instr =~ s/\s+/ /g;

  $instr =~ s/<|>//g;
  $instr = substr($instr, 0, 60);

  @fields = split;
  $_ = $fields[1];

  ($func, $offset) = split(/\+/);
  
  $offset = "0x0" unless (defined($offset));

  $offset = "0x" . $offset unless ($offset =~ /^0x/);

  xml_start_cell();
  print "$func";
  xml_end_cell();

  xml_start_cell();
  print hex($offset);
  xml_end_cell();

  xml_start_cell();
  print "$instr";
  xml_end_cell();
  $numInstr++;
}

xml_end_cell_list();
xml_start_dim_list();

xml_start_dim(name => '"Symbol Data"');
xml_start_dimval();
print "function";
xml_end_dimval();
xml_start_dimval();
print "offset";
xml_end_dimval();
xml_start_dimval();
print "instr";
xml_end_dimval();
xml_end_dim();

xml_start_dim(name => '"Instr Num"');
for ($i = 0; $i < $numInstr; $i++)
{
  xml_start_dimval();
  print $i;
  xml_end_dimval();
}
xml_end_dim();
xml_end_dim_list();
xml_end_stat_group();
xml_end_stat_doc();

