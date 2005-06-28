#!/usr/bin/perl

################################################################
# Script written by Duc Pham, Duc.Pham@Sun.COM, dated 10/12/2004
# This script analyzes the wcp output files for each host and
# modifies them accordingly for them to be processed by Xanadu.
#
# Requirements: increment.pl, process-scripts/
# Usage: ./wcp-xanadu.pl <dir w/ hosts, tmp/, xanadu.log> <runid>
# Now the script also auto-detects WCP source directory
################################################################

#Written by: Suleen Hong (03/12/04)
#Description: increments the time value in cpustat.soak output

################################################
#Modification: 
#v1: (03/12/04) increment time value. Repeat twice.
#v2: (10/12/04) repeats according to no. of times time repeats
#v3: (15/10/04) gets rid of decimals in time
#v4: (16/12/04) handle varying repetitions.
################################################
#Usage: increment(dir with wcstat data>

sub increment
{
#Takes the first parameter given by the user as the directory with wcp files.
my $sourcedir = shift;
my @data = `ls $sourcedir`;

foreach $d (@data)
{
  if ($d =~ /^cpustat.soak.*/)
  {
    #Reads cpustat.soak output
    $source = "$sourcedir/$d";
    open (SOURCE, "<$source") or die("$! $source\n");
    @rawdata = <SOURCE>;
    close (SOURCE);
   
    #Overwrites cpustat.soak 
    open (SOURCE, ">$source") or die("$! $source\n");

    my $time = 0;
    my @line;
    my @rawline;
    my @dot;
    my $olddot = "";

###################################################
# Increment time value
###################################################
    foreach $rawdata (@rawdata)
    {
      #Puts each line into an array.
      @line = split(/ /, $rawdata);  

      #Goes through each element of array till time value
      my $x = 0;
      while ($line[$x] eq "")
      {
        $x=$x+1;
      }
      #Check if header.
      if ($line[$x] =~ "time")
      {
        print SOURCE "$rawdata";
      }
      #If not header, change time value
      else
      {
        @dot = split(/\./, $line[$x]);
        chomp($dot[0]);
        chomp($time);
        #Check if time changes
        if ($dot[0] eq $olddot)
        {
          $line[$x] = $time."\.$dot[1]";
        }
        else 
        {
          $time = $time + 1;  
          $line[$x] = $time."\.$dot[1]";
        }  
          
        $olddot = $dot[0];

        print SOURCE "@line";
      }
    }
    close (SOURCE);
  }
}
}

# Main starts here
use File::Basename;

$xanaduDir = dirname($0);

$wcpHome = $ARGV[0];
# Commented out logging - causing perl -w errors
#use CGI::Carp qw(carpout);
#open(LOG,">$wcpHome/xanadu.log") || die "can't open $wcpHome/xanadu.log: $!\n";
#carpout(LOG);

#open(HOSTS,"$wcpHome/hosts") || die "no $wcpHome/hosts?: $!\n";
#@hostNames = <HOSTS>;
#close(HOSTS);

#Check if this is a WC raw directory
if (-e "$wcpHome/tmp") {
	$wcpDatDir = "$wcpHome/tmp";
} else {
	$wcpDatDir = $wcpHome;
}

@hostNames = glob("$wcpDatDir/*");
print STDERR "@hostNames\n";

$xmlDir = "$wcpHome/xml";
system("mkdir -p $xmlDir");

$htmlDir = "$wcpHome/html";
system("mkdir -p $htmlDir");

$txtDir = "$wcpHome/txt";
system("mkdir -p $txtDir");

$xanadu = "$xanaduDir/xanadu";

foreach $hostName (@hostNames) {
    chomp($hostName);
    $hostName = basename($hostName);

  print "$hostName is being processed ...\n";
  $wcpDir = "$wcpDatDir/$hostName";
  my @wcpFiles = `ls $wcpDir | grep WcP`;
  $soakFile = "";

  # Checking the WCLOG for the time interval
  $interval = `egrep \"Interval\" $wcpDir/WCLOG | awk '{print \$2}'`;
  chomp($interval);

  $txtHostDir = "$txtDir/$hostName";
  system("mkdir -p $txtHostDir");

  foreach $wcpFile (@wcpFiles) {
    chomp($wcpFile);
    @temp = split(/_/,$wcpFile);
      open(IN,"$wcpDir/$wcpFile") || die "cannot open $wcpDir/$wcpFile for reading: $!\n";
      if ($temp[1] =~ /^cpustat.soak.*/) {
        $soakFile = "$temp[1].txt";
        open(OUT,">$txtHostDir/$temp[1].txt") || die "cannot create $txtHostDir/$temp[1].txt: $!\n";
        filter();
      }
      if ($temp[1] =~ /^vmstat.*/ ||
          $temp[1] =~ /^mpstat.*/ ||
          $temp[1] =~ /^iostat.*/ ||
          $temp[1] =~ /^statit.*/ ||
          $temp[1] =~ /^netsum.*/) {
        open(OUT,">$txtHostDir/$temp[1].txt") || die "cannot create $txtHostDir/$temp[1].test: $!\n";
	@command = split(/\./,$temp[1]);
        print OUT "$command[0] must always be run at some interval. Using $interval secs...\n\n";
        filter();
      }
  }

  sub filter {
    <IN>;
    <IN>;
    <IN>;
    while (<IN>) {
      print OUT $_;
    }
    close(IN);
    close(OUT);
  }

  # Resequencing the time number in cpustat.soak to be sequential
  increment($txtHostDir);

  # Checking the WCLOG for the system architecture
  $chip = `egrep \"Chip\" $wcpDir/WCLOG | awk '{print \$3}'`;
  chomp($chip);

  # Determining the appropriate post-processing script to use
  # depending on the chip architecture
  if ($chip eq "US-III+" || $chip eq "US-IIIi" || $chip eq "US-IV") {
    $process_script = "cpustat.post.us3p";
  } elsif ($chip eq "US-IV+") { 
    $process_script = "cpustat.post.us4p";
  } elsif ($chip eq "US-III") { 
    $process_script = "cpustat.post.us3";
  } elsif ($chip eq "US-II" || $chip eq "US-IIi") {
    $process_script = "cpustat.post.us2";
  } else {
    print "Chip architecture is UNKNOWN!\n";
  }

  # Directory with all the post-processing scripts
  system("$xanaduDir/../txt2xml/cpustat-post/$process_script -cpu -uk -ac -i $txtHostDir/$soakFile > $txtHostDir/$soakFile.post");
  unlink "$txtHostDir/$soakFile" || warn "can't delete $soakFile: $!\n";
  rename("$txtHostDir/$soakFile.post","$txtHostDir/$soakFile");

  system("$xanadu import $txtHostDir $xmlDir/$hostName $ARGV[1]");

  if ($#hostNames == 0)
  {
      system("$xanadu export $xmlDir/$hostName $htmlDir");
  }
  else
  {
      system("$xanadu export $xmlDir/$hostName $htmlDir/$hostName");
  }

link "$htmlDir/$hostName/index.html", "$htmlDir/index.html" if ($#hostNames == 0);

}

system("rm -r $txtHostDir $wcpHome/tmp");
