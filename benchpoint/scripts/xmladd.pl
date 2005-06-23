#!/usr/bin/perl 
#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#


use POSIX;

my $QUIT = 0;
my $USE_XANADU = 0;
my $TIMEOUT = 60;
my $FILEBENCH = "DEFINE_FILEBENCHDIR";
my $PROGDIR = "DEFINE_PROGDIR";
my $FSCRIPT;
my $SCRIPT_NO;

sub op_xmlstats {
     my ($statsfile) = shift;
	if($statsfile ne '') {
		# The following loop adds the benchpoint run parameters and statistics into the filebench XML file
		# We capture the meta data from the start of the filebench xml file
		$phase=1;
		open(STATSFILE,"<".conf_reqval("statsdir")."/$statsfile");
		open(XMLFILE,"<".conf_reqval("statsdir")."/$statsfile.config");
		open(OSTATSFILE,">".conf_reqval("statsdir")."/$statsfile.new");
		while (<STATSFILE>) {
			if ((!((/.*meta.*/) || (/.*stat_doc.*/))) && ($phase == 1)) {
				while (<XMLFILE>) {
					print OSTATSFILE $_;
				}
			} else {
				print OSTATSFILE $_;
			}
		}
		close(STATSFILE);
		close(XMLFILE);
		close(OSTATSFILE);
		unlink(conf_reqval("statsdir")."/$statsfile");
	      	rename(conf_reqval("statsdir")."/$statsfile.new",conf_reqval("statsdir")."/$statsfile");
		return(0);	
	}
}

##############################################################################
## Main program
##############################################################################


## Make sure arguments are okay
if(@ARGV != 1) {
    print "Usage: xmladd <stats filename>\n"; 
    exit(1);
} 

$FILENAME = $ARGV[0];

xmlstats("$FILENAME");

