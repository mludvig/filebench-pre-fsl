#!/bin/perl -w
##

use lib "../txt2xml";

use txt2xml;
#############################################################################
# Typical o/p line is
# vol aux.df-backup1         0      4097         0   1048800    0.0  132.7
#headers are
#                        OPERATIONS           BLOCKS        AVG TIME(ms)
# TYP NAME              READ     WRITE      READ     WRITE   READ  WRITE
#############################################################################
sub parse_body {
	my @returnval;
	do {
		if (/^vol /) {
			@junk = split;
			$vol = $junk[1];
			$volumes{$vol} = 1;
			push(@linearvols, $vol);
			for ($i = 2; $i <= $#junk; $i++) {
					push(@{$data[$i]}, $junk[$i]);
			}
		}
		if (/^vxstat must always be run at some interval/){
			$interval = 0;
			@words = split(/\s+/,$_) ;
			for ($i=0; $i<$#words; $i++) {
				if ($words[$i] eq 'Using') {
					$interval = $words[$i + 1];
					last;
				}
			}
		}
	} while (<INPUT>);
}

%volumes=();
@linearvols=();
$interval = 10;

sub main {

	open(INPUT, $ARGV[0]);
	xml_start_stat_doc(name => "\"Veritas Stats (vxstat) \"");
	##xml_meta(name => "\"RunId\"", value => "\"$ARGV[1]\"");

	while (<INPUT>)
	{
		&parse_body;
	}
	&dump_xml;
	xml_end_stat_doc();
}

sub dump_xml {
	$index = 1;
	$str1 = "Operations Read";
	$str2 = "Operations Write";
	$str3 = "Blocks Read";
	$str4 = "Blocks Write";
	$str5 = "Average Read time (ms)";
	$str6 = "Average Write time (ms)";
	$index = 2;
	foreach $label ($str1, $str2, $str3, $str4, $str5, $str6) {
		xml_start_stat_group(name => "\"$label\"", display => "\"gnuplot-png\"");

		# Now print all the data
  	xml_start_cell_list();

	######################################################################
	# The first set of o/p produced by vxstat is a total. we reset it.
	######################################################################
		$count = 0;
		@volnames = keys(%volumes);
   	foreach $value (@{$data[$index]})
    		{
	    		xml_start_cell();
	    		if($count > $#volnames) {
						print $value;
					} else {
						print "0";
					}
	    		xml_end_cell();
					$count++;
   	}

   	xml_end_cell_list();
   	xml_start_dim_list();
		
		xml_start_dim(group => '"0"', level => '"0"', name => '"Volumes"');
		$i = 0;
		foreach $vol (@volnames) {
			xml_start_dimval();
			print "$linearvols[$i]";
			xml_end_dimval();
			$i++;
		}
    xml_end_dim();
		
		# Print the timelines
    xml_start_dim(group => '"1"', level => '"1"', name => '"Time (s)"');
		$curr = 0;
		@novols = keys(%volumes);
#		$max = $#{data[$index]}/$#volumes;
		$max = 0;
		foreach $value (@{$data[$index]}) {
			$max++;
		}
		##print "No of volumes= $#volnames, max = $max";
		$max = $max/$#volnames;

		for($i = 0; $i < $max; $i++) {
	    		xml_start_dimval();
	    		print $curr;
					$curr += $interval;
	    		xml_end_dimval();
		}
    xml_end_dim();
    xml_end_dim_list();
    xml_end_stat_group();
		$data[$index] = ();
    $index++;
	}
}

&main;
