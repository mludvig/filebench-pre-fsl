#!/bin/perl -w
use lib "../txt2xml";
use txt2xml;

sub main {
	open(INPUT, $ARGV[0]) || die "Cannot open input file";
	my $title = <INPUT>;
	if($title =~ /^Title:/){
	    $title =~ s/Title://;
	    chomp($title);
	} else {
		die "Title: is not the first line. Quitting.\n";
	}
	xml_start_stat_doc(name => "\"$title\"");
	xml_meta(name => "\"RunId\"", value => "\"$ARGV[1]\"");
	while(<INPUT>){
		chomp;
		s/#.*//;    # no comments
		s/^-.*//;    # ignore lines beginning with -
		s/^\s+//;   # No leading whitespaces
		s/\s+$//;   # No trailing whitespaces
		next unless length;
		if(/^Section:/){
			my ($junk, $hdr) = split(/:/,$_, 2);
			parse_group($hdr);
		} else {
			print "Ignoring $_\n";
		}
	}
	xml_end_stat_doc();
}

sub parse_group {
	my $grp_name = $_[0];
	# We have the section header in $grp_name, now get display
	# and headings for the columns
	# Before we get the display, we have to ignore comments
	while(<INPUT>){
		s/#.*//;    # no comments
		s/^-.*//;    # ignore lines beginning with -
		s/^\s+//;   # No leading whitespaces
		s/\s+$//;   # No trailing whitespaces
		next unless length;
		chomp;
		if (/^Display/i){
			xml_start_stat_group(name => "\"$grp_name \"", 
				display => "\"gnuplot-png\"");
			$hdr = <INPUT>;
		} else {
			xml_start_stat_group(name => "\"$grp_name \"");
			$hdr = $_;
		}
		last;
	}
  	xml_start_cell_list();
	##print "HEADER: $hdr\n";
	@headers = split(/\t+\s*|\s{2,}\t*/, $hdr);
	##print "HEADERLEN: $#headers\n";
	##print "HEADER: " . join(" **\n", @headers) . "\n";
	
	while(<INPUT>)
	{
		s/#.*//;    # no comments
		s/^-.*//;    # ignore lines beginning with -
		s/^\s+//;   # No leading whitespaces
		s/\s+$//;   # No trailing whitespaces
		next unless length;
		chomp;
	
		if(/^Section:/){
			my ($junk, $hdr) = split(/:/,$_, 2);
   			xml_end_cell_list();
			dump_xml();
			parse_group($hdr);
			return;
		}
		##print $_;
		@junk = split(/\t+\s*|\s\s+\t*/);
		$series = $#junk;
		##print "SERIES: $series\n";
		##print "JUNK: " . join(" **\n",@junk) . "\n";
		push(@xseries, $junk[0]);
		for ($i = 1; $i <= $series; $i++) {
			xml_start_cell();
			print $junk[$i];
	   		xml_end_cell();
			##push(@yseries, $junk[$i]);
			##print "DEBUG $junk[$i] Series = $series \n";
		}
	}
   	xml_end_cell_list();
	dump_xml();
}

sub dump_xml {

   	xml_start_dim_list();
		
	xml_start_dim(group => '"0"', level => '"0"', name => '"Volumes"');
	# Check if see if the headers we have is the same as the 
	# no of series we have
	if($#headers != $series){
		print STDERR join(",", @headers);
		die "\nError: Length of Column headers does not match length of data! $#headers != $series \nMake sure they are tab-separated";
	}
	for($i=1; $i<=$series;$i++){
		xml_start_dimval();
		print $headers[$i];
		xml_end_dimval();
	}
	##foreach $line (@headers) {
		#xml_start_dimval();
		#print $line;
		#xml_end_dimval();
	#}
    	xml_end_dim();
		
	# Print the timelines
    	xml_start_dim(group => '"1"', level => '"1"', name => "\"$headers[0]\"");
	foreach $value (@xseries) {
		xml_start_dimval();
		print $value;
		xml_end_dimval();
	}
    	xml_end_dim();
    	xml_end_dim_list();
    	xml_end_stat_group();
	@xseries = ();
	@headers = ();
}

@xseries = ();
&main;
