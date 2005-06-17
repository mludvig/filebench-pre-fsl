#!/bin/perl -w

#Usage:  davenet2xml_mf.pl <infile1> <runid>

use Time::Local;
use lib "../txt2xml";

use txt2xml;


#Each metric is a stat group
%metrics = ( "KBi/s" => "Input Kbytes/s",
	    "KBo/s" => "Output Kbytes/s",
	    "ipkts/s" => "Input Packets/s",
	    "opkts/s" => "Output Packets/s",
	    "ierr" => "Input Error",
	    "oerr" => "Output Error",
	    "col" => "Collisions",
	    "mxst" => "Mxst",
	    "rxofl" => "rxofl",
            "Bi/pkt" => "Input Bytes/Packet",
            "Bo/pkt" => "Output Bytes/Packet",
           );


# an arbitrary date
$year = 2002;
$month = 10;
$day = 29;

if ($#ARGV < 1) {
    $prog = $0;
    print "Usage: $prog <infile> <runid> \n";
    exit (-1);
}
    
&one_xml($ARGV[0], $ARGV[1]);

sub one_xml {
  my ($infile, $runid) = @_; 

  $raw_data = {};

  #print "= @_\n";
  #print "infile: $#infiles\n";
 
  &read_one_raw($raw_data, $infile, 0);

  #print "save into header @{$raw_data->{'header'}}\n";
  #print "save into samples $raw_data->{'samples'}\n";
  #print "save into nics @{$raw_data->{'nics'}}\n";
  #print "save into timeline @{$raw_data->{'timeline'}}\n";
  #print "save into ge0 @{$raw_data->{'ge0'}[0]}\n";
  #print "save into qfe1 @{$raw_data->{'qfe1'}[0]}\n";


  &print_one_xml($raw_data, $runid); 

}

sub read_one_raw {

  my ($data, $in_fn, $readtimeline_flag) = @_;

  my %seen_time = ();

  $samples = 0;
  open (INPUT, $in_fn);

  while (<INPUT>) {

        next if /^\n/;

        if (/^Name/) {
            # Get the header
	    unless ($data->{'header'}) { 
                @header = split;
                $data->{'header'} = \@header;
            }

        }
        else {
    	    @fields = split;
	    $nic = $fields[0];
           
            next if ( $nic !~ /(qfe|ge|ce|eri|lo|bcme|hme)\d+/ );
          
            unless ($data->{$nic}) {
                push (@{$data->{'nics'}}, $nic);
                #print "got a NIC: $nic\n";
            } 

            $timeval=$fields[$#fields];
            unless ($seen_time{$timeval}) {
                if ( $readtimeline_flag == 0 ) {
	            ($hours, $min, $sec) = split (":", $timeval);
                    $t = timelocal($sec, $min, $hours, $day, $month, $year);
                    push (@{$data->{'timeline'}}, $t);
                } 
                $seen_time{$timeval} = 1;
	        $samples++;
            }

    	    for ($i = 1; $i < $#fields; $i++) {
                $data->{$nic}[$samples][$i] = $fields[$i];  
	    }
        }
    }
    if ( $readtimeline_flag == 0) {
       $data->{'samples'} = $samples;
    }
    elsif ($data->{'samples'} > $samples) {
        $data->{'samples'} = $samples; 
    }
    close (INPUT);
}


sub print_one_xml { 

  my ($data, $runid) = @_;
  my $header = $data->{'header'};

  #print "$xml_fn\n";
  #open (OUTPUT, ">$xml_fn");
  #select (OUTPUT);

  xml_start_stat_doc(name => "\"Davenet\"");
  xml_meta(name => "\"RunId\"", value => "\"$runid\"");

  $avg ={};

  $labelNum = 1;
  foreach $label (@header)
  {
      next if ($label eq "Name");
      next if ($label eq "Time"); 

      xml_start_stat_group(name => "\"$metrics{$label}\"", display => "\"gnuplot-png\"");

      # Now print all the data
      xml_start_cell_list();

      $sum = {};

      for $samples (1 .. $data->{'samples'}) {
          foreach $nic ( @{$data->{'nics'}} ) {

              unless ($sum->{$nic}) {
                  $sum->{$nic} = 0; 
              }

              xml_start_cell();
              $value = $data->{$nic}->[$samples][$labelNum];
              print $value;
              $sum->{$nic} +=  $value;
              xml_end_cell();
          }
      }

      xml_end_cell_list();

      xml_start_dim_list();

      xml_start_dim(group => '"0"', level => '"0"');
      for $nic ( @{$data->{'nics'}} ) {
      	  xml_start_dimval();
          print "NIC $nic";
          xml_end_dimval();

          $average = $sum->{$nic} / $data->{'samples'};
          push (@{$avg->{$nic}}, $average);

      }
      xml_end_dim();


      xml_start_dim(group => '"1"', level => '"1"', name => '"Time (s)"');
      $start = $data->{'timeline'}[0];
      for $i (0 .. $data->{'samples'}-1)
      {
      	xml_start_dimval();
      	printf "%d", $data->{'timeline'}[$i] - $start;
        xml_end_dimval();
      }
      xml_end_dim();

      xml_end_dim_list();

      xml_end_stat_group();
      $labelNum++;
  }

  #print averages
  xml_start_stat_group(name => "\"Averages\"");
  xml_start_cell_list();
  for $nic ( @{$data->{'nics'}} ) {
      for $k ( 0 .. $#{$avg->{$nic}})
      {
          xml_start_cell();
          printf "%.2f", $avg->{$nic}->[$k];
          xml_end_cell();
      }
  }
  xml_end_cell_list();
  xml_start_dim_list();
  xml_start_dim();
  foreach $dimval (@header) {
      next if ($dimval eq "Name");
      next if ($dimval eq "Time");
      xml_start_dimval();
      print $dimval;
      xml_end_dimval();
  }
  xml_end_dim();
  xml_start_dim();
  foreach $nic ( @{$data->{'nics'}} ) {
      xml_start_dimval();
      print $nic;
      xml_end_dimval();
  }
  xml_end_dim();
  xml_end_dim_list();
  xml_end_stat_group();

  xml_end_stat_doc();

  #select(STDOUT);
}
