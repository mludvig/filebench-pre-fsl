#!/bin/perl -w
#!/usr/local/bin/perl -w

#
# Revision History:
#     5/22/02  zenon: Initial version
#

#
# Plan:
# 1. Parse the arguments.
# 2. Copy input file to stdout

#
# Get options 
#

while ($#ARGV > -1) {
    $arg = shift @ARGV;
    if ( $arg =~ /^-(.)(.*)$/ ) {
        $flag=$1; $val=$2;
        # print "flag=$flag, val=$val\n";
        if ( $flag eq "i" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $infile = $val;
        } elsif ($flag eq "o") {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $outfile = $val;
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

if (! defined $infile) {
    &usage();
}


#
# Set some options, like "autoflash"
#

$| = 1;

if (defined $infile) {
    open(STDIN, "<$infile") || die "Could not open $infile\n";
}

if (defined $outfile) {
    open(STDOUT, ">$outfile") || die "Could not open $outfile\n";
}

# Copy all input lines:

while (defined($line = <STDIN>)) {
    print "$line";
}

exit (0);

# end of MAIN


sub usage
{
    $prog = $0;
    $prog =~ s/.*\///;
    print "
    usage : $prog [-i <infile>] [-o <outfile>] [-v] [-r <runId>] [<infile>] [<runId>]
    -i <name>: input file name
    -o <name>: output file name
    -r <runId>: Run Identifier
    -v : turn on verbose

    Without input/output files specified, the 'stdin' and 'stdout' will be used.
    \n";
        
    exit 1;
}
