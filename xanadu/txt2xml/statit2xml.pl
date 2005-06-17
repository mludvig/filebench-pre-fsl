#!/bin/perl -w

use lib "../txt2xml";

use txt2xml;


sub trans_interval()
{
    # First open the summary
    $report = $ARGV[0];
    $report =~ s/statit.*/summary/;

    open(SUMMARY, $report) || return;

    $state = 0;
    while (<SUMMARY>)
    {
	if ($state == 0 && /^Run-time/)
	{
	    @fields = split;
	    $measure = $fields[2];
	    $state++;
	}
	elsif ($state == 1 && /^Total/)
	{
	    @fields = split;
	    $xact = $fields[5] / $measure;
	    last;
	}
    }

    close SUMMARY;
}

sub elapsed_time_stats
{
 
  @cell_list = ();

  while (<INFILE>) {
    
    # Skip whitespace and headers
    chop;
    next if (/Elapsed Time Statistics/ || /^$/);
    last if (/CPU/);

    @f = split;

    if (/Hostid/) {
      # Get meta info
      s/://g;     
      $hostid = $f[1];
      $hostname = $f[3];
      $version = $f[5];
      defined $f[7] ? $command = $f[7] : $command = "";
      
      # Check version;
#      print STDERR "WARNING: Statit version = ", $f[5], ".  Expecting 6.00.\n"
#	if ($f[5] != 6.00);
 
      next;
    } 

    if (/Start time:/) {
      $time = "$f[7] $f[8] $f[9] $f[10] $f[11])";
      $time =~ s/\)//g;
    }
   
    push @cell_list, $f[0];
    push @cell_list, $f[3];
  }

  # Start doc
  xml_start_stat_doc((name => "\"Statit\"", version => "\"$version\""));

  # Print Meta info
  xml_meta((name => "\"RunId\"", value => "\"$runId\""));
  xml_meta((name => "\"hostid\"", value => "\"$hostid\""));
  xml_meta((name => "\"hostname\"", value => "$hostname"));
  xml_meta((name => "\"command\"", value => "\"$command\""));
  xml_meta((name => "\"time\"", value => "\"$time\""));

  # Print Elapsed time stats
  xml_start_stat_group((name => "\"Elapsed Time Summary\""));
  xml_start_cell_list();
  foreach $cell (@cell_list) {
    xml_start_cell(); 
    print $cell;
    xml_end_cell;
  }
  xml_end_cell_list();

  xml_start_dim_list();

  xml_start_dim();
  foreach $dimval (("time (s)", "%")) {
    xml_start_dimval();
    print $dimval;
    xml_end_dimval();
  }
  xml_end_dim();

  xml_start_dim();
  foreach $dimval (("total", "idle", "user", "system", "wait")) {
    xml_start_dimval();
    print $dimval;
    xml_end_dimval();
  }
  xml_end_dim();

  xml_end_dim_list();
  xml_end_stat_group();

  
  xml_start_stat_group((name => "\"CPU Time Statistics\""));
  xml_start_cell_list();
 
  @cpu_list = ();

  while (<INFILE>) {
    chop;
    @f = split;
    
    last if (/Totals/);
 
    push @cpu_list, $f[1];
    
    for ($i = 2; $i < 8; $i++) {
      xml_start_cell();
      print $f[$i];
      xml_end_cell();
    }
  }

  push @cpu_list, "totals";
  for ($i = 1; $i <= 6; $i++) {
    xml_start_cell();
    print $f[$i];
    xml_end_cell();
  }

  xml_end_cell_list();

  xml_start_dim_list();

  xml_start_dim();
  foreach $dimval (("idle%", "user%", "system%", "wait%", "total%", 
		    "total (secs)")) {
    xml_start_dimval();
    print $dimval;
    xml_end_dimval();
  }
  xml_end_dim();

  xml_start_dim((name => "\"cpu\""));
  foreach $dimval (@cpu_list) {
    xml_start_dimval();
    print $dimval;
    xml_end_dimval();
  }
  xml_end_dim();
  xml_end_dim_list();
  xml_end_stat_group();
}

sub parse_line 
{

#BNG: Completely change this algorithm to col based like statspack
#There are some irregular cases that was breaking the earlier regex

    $startInd = 0;

    do 
    {
	if ($startInd == 0) {
	    $len = 38;
	}
	else  {
	    $len = 50;
        }

	$stat = substr($_, $startInd, $len);

	($statval, @fields) = split(' ', $stat);

	if ($statval >= 1) 
	{
	    $statname = "@fields";
	    push @stat_name, $statname;

	    xml_start_cell(); print $statval; xml_end_cell();

	    if ($perXact)
	    {
		xml_start_cell(); printf "%.2f",  $statval / $xact; xml_end_cell();
	    }
	}

	# Two stats per line
	$startInd += $len;
    }
    while (length($_) > $startInd + 10);

}   



sub generic_stats
{

  xml_start_stat_group((name => "\"Average Load Statistics\""));

  xml_start_cell_list(); 
  @stat_name = ();

  $perXact = 0;

  while (<INFILE>) {
    chop;

    # If there is no number on this line
    # then it is a section heading
    if (!/\d/) {
        xml_end_cell_list();
	xml_start_dim_list();

	xml_start_dim();
	xml_start_dimval();
	print "Value";
	xml_end_dimval();
	if ($perXact)
	{
	    xml_start_dimval();
	    print "Per Trans";
	    xml_end_dimval();
	}	    
        xml_end_dim();

	xml_start_dim(name => '"Stat"');
	foreach $dimval (@stat_name) {
	  xml_start_dimval(); print $dimval; xml_end_dimval();
	}
	xml_end_dim();
	xml_end_dim_list();
	xml_end_stat_group();
	
	last if (/Network Statistics/);

	(/^\s+(.*?)$/);
	xml_start_stat_group((name => "\"$1\""));

	if (defined($xact) && $1 =~ /^Sysinfo/)
	{
	    $perXact = 1;
	}
	else
	{
	    $perXact = 0;
	}

	xml_start_cell_list();
	
	
	@stat_name = ();
	
	next;
    }
    
    parse_line();
  }

}


sub network_stats
{
  @net_list = ();
  xml_start_stat_group((name => '"Network Statistics (per second)"'));

  xml_start_cell_list();
  while (<INFILE>) {
    chop;
  
    # Skip whitespace and headers
    next if (/Net/ || /^$/);
    last if (/Disk/);

    @f = split;

    next if $f[1] + $f[3] < 10;
    
    push @net_list, $f[0];

    for ($i = 1; $i < 8; $i++) {
      xml_start_cell(); print $f[$i]; xml_end_cell();
    }
    
  }
  xml_end_cell_list();
  
  xml_start_dim_list();

  xml_start_dim();
  foreach $dimval (("Ipkts", "Ierrs", "Opkts", "Oerrs", "Colls", "Dfrs", "Rtryerr")) {
    xml_start_dimval(); print $dimval; xml_end_dimval();
  }
  xml_end_dim();

  xml_start_dim((name => "\"Net\""));
  foreach $net (@net_list) {
    xml_start_dimval();
    print $net;
    xml_end_dimval();
  }
  xml_end_dim();

  xml_end_dim_list();
  xml_end_stat_group();
}

sub disk_stats
{
  @disk_list = ();
  xml_start_stat_group((name => "\"Average Disk I/O Statistics (per second)\""));

  for ($i = 1; $i < 10; $i++) {
      $avg[$i] = 0;
  }
  
  xml_start_cell_list();
  while (<INFILE>) {
    chop;
  
    # Skip whitespace and headers
    next if (/Disk/ || /^$/);

    @f = split;

    next if ($f[1] < 5);

    push @disk_list, $f[0];
  
    # Calculate the average
    $numDisks++;
    for ($i = 1; $i < 10; $i++) {
	xml_start_cell(); print $f[$i]; xml_end_cell();

	$avg[$i] += $f[$i];
    }
  }

  $numDisks = 1 unless defined($numDisks);

  for ($i = 1; $i < 10; $i++) {
      xml_start_cell(); printf "%.1f", $avg[$i] / $numDisks; xml_end_cell();
  }
  xml_end_cell_list();
  
  xml_start_dim_list();

  xml_start_dim();
  foreach $dimval (("util%","xfer/s","rds/s","wrts/s","rdb/xfr","wrb/xfr","wtqlen","svqlen","srv-ms")) {
    xml_start_dimval(); print $dimval; xml_end_dimval();
  }
  xml_end_dim();

  xml_start_dim((name => "\"Disk\""));

  foreach $disk (@disk_list) {
    xml_start_dimval();
    print $disk;
    xml_end_dimval();
  }

    xml_start_dimval();
    print "Average";
    xml_end_dimval();

  xml_end_dim();

  xml_end_dim_list();
		      
  xml_end_stat_group();
}

# main starts here

open(INFILE, $ARGV[0]);

$runId = $ARGV[1];

# Retrieve number of trans and measurement interval from Oracle file if possible
trans_interval();

elapsed_time_stats();
<INFILE>; <INFILE>;
generic_stats();
network_stats();
disk_stats();

xml_end_stat_doc();

