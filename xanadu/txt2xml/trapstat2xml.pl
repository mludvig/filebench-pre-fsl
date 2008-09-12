#!/bin/perl -w
#
#   Borrowed good ideas and code from vmstat2xml.pl and others
#   adapted for use here
#
#   This is ...
#               trapstat2xml.pl
#
#   it handles output from
#      trapstat without parameters (2 versions)
#      trapstat with -t
#
#   Approach:
#   it "peeks" inside the datafile and determines which "slave"
#   script should be invoked to handle the "type" of trapstat data.
#   The function pointer is just an exercise to see if perl can do it

use lib "../txt2xml";

use trapmisc;
$debug = 0;

@SAVEARGV=@ARGV;	# preserve for use later

#   pick up options
while ($#ARGV > -1) {
    $arg = shift @ARGV;
    if ( $arg =~ /^-(.)(.*)$/ ) {
        $flag=$1; $val=$2;
        # $flag2=$flag.$val;
        if ( $flag eq "i" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $infile = $val;
		  } elsif ($flag eq "I" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $INTERVAL = $val;
		  } elsif ($flag eq "F" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $FILTER = $val;
        } elsif ($flag eq "o") {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $outfile = $val;
        } elsif ($flag eq "v") {
#            if ( $val ne "")  { &usage();}
#            $verbose = 1;
        } elsif ($flag eq "r") {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $runId = $val;
        } else { &usage(); }
    } elsif ( $arg =~ /^(.*)$/ ) {
        if (defined($infile)) {
            if (! defined($runId)) {
                $runId = $1;
            }
        } else {
            $infile = $1;
        }
    }
}

#   set options

$| = 1;

if (defined $infile) {
    open(STDIN, "<$infile") || die "Could not open $infile\n";
}

@todo = (
	\&trapstat0,
	\&trapstat1,
	);

# this is it
&doit;

# test filetype and do it
sub doit
{
	$filetype=-1;	# unknown data file
	$cnt=0;
	while (<STDIN>)
	{
		last if ($cnt++ > 100);	# time to stop if nothing happens 
		if (/^vct/) {
			$filetype = 0;	# trapstat without options
			last;
		}
		# /^cpu/
		if (/dtsb-miss/) {
			$filetype = 1;	# trapstat with -t option
			last;
		}
	}
	# be nice and reset any opened file-handles
	close STDIN;

	die "unable to determine if this is a trapstat data file"
		if ( $filetype < 0 );

	# call appropriate routine to handle it
	&{$todo[$filetype]};
}

sub trapstat0
{
	print "debug: trapstat0\n" if ($debug);
	system "../txt2xml/x0.pl @SAVEARGV";
}

sub trapstat1
{
	print "debug: trapstat1\n" if ($debug);
	system "../txt2xml/y.pl @SAVEARGV";
}

sub print_debug_info
{
	if ($debug)
	{
		print "outfile: $outfile";
		print "infile: $infile";
		print "INTERVAL: $INTERVAL";
		print "FILTER: $FILTER";
		print "slots in SAVEARGV: @SAVEARGV";
	}
}

__END__
