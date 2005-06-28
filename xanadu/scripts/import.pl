#!/usr/bin/perl -w

sub runBatch()
{
    die "src dir undefined\n" if (! defined($src));
    die "dst dir undefined\n" if (! defined($dst) && ! $noExec);
    die "runId undefined\n" if (! defined($runId) && ! $noExec);

    get_default_names();

    if (! $noExec) {
        if (! -d $dst) {
            die "Cannot mkdir($dst, 0777)\n" if (! mkdir($dst, 0777));
        }
        print "src = $src\n";
        print "dst = $dst\n";
        for ($i=0; $i<$count; $i++) {
            $j = $i + 1;
            print "$j. $fs[$i] => $cs[$i] => $rs[$i]\n";
            if (!defined ($pid = fork)) {
                die "Unable to fork: $!\n";  
            } elsif (! $pid) {
                # child process here

# BNG: I am commenting out the following line for now as it is required for
# Java converters and it seems to work for Perl
                #close (STDIN); close (STDOUT); close (STDERR);

                if ($cs[$i] =~ /oracle/) {
                    $csOracleMeta="tpccmeta2xml.pl";
                    $rsOracleMeta= "tpcc-meta.xml";
                    $oraMeta = "$Converters" . "/" . "$csOracleMeta";
                    if (-x $oraMeta) {
                        system("$oraMeta $src/$fs[$i] $runId | gzip -c > $dst/$rsOracleMeta.gz");
                    } else {
                        print "Cannot execute $oraMeta | gzip -c > $dst/$rsOracleMeta.gz\n";
                    }
                }
		if ($^O eq 'MSWin32') {
		    system("perl $Converters\\$cs[$i] $src\\$fs[$i] $runId $dst > $dst/$rs[$i]");
		} else {
		    system("perl $Converters/$cs[$i] $src/$fs[$i] $runId $dst | gzip -c > $dst/$rs[$i].gz");
		}
	        exit 0;
            } else {
                # parent branch here
                $pids[$i] = $pid;
#                print "PID $pid started\n";
            }
        }
        $kid = 0;
        do {
            $kid = waitpid(-1,&WNOHANG);
            if ($kid > 0) {
                $exit_value = $? >> 8;
                $found = 0;
                for ($i=0; $i<$count; $i++) {
                    $j = $i + 1;
                    if ($pids[$i] == $kid) {
                        print "Done $cs[$i] on $fs[$i] => exit value $exit_value\n";
                        $found = 1;
                        $pids[$i] = 0;
                        last;
                    }
                }
                if ($found == 0) {
                    print "PID $kid => exit value $exit_value\n";
                }
            }
            for ($i=0; $i<$count; $i++) {
                if ($pids[$i] > 0) {
                    sleep 2;
                    last;
                }
            }
        } until $kid == -1;
        print "DONE IMPORT\n";
        exit 0;
    } else {
        print "Recognized $count files for IMPORT:\n";
        for ($i=0; $i<$count; $i++) {
            $j = $i + 1;
            print " $j. $fs[$i] => $cs[$i] => $rs[$i]\n";
        }
    }
}

sub usage
{
    $prog = $0;
    $prog =~ s/.*\///;
    print "
    usage : $prog [-b] [-v] [-n] [-r <runId>] [<src>] [<dst>] [<runId>]
    -b : run in batch mode (otherwise: run as CGI)
    -v : turn on verbose
    -n : no execution mode
    -r <runId>: Run Identifier

    With -n flag files recognized for IMPORT will be listed.
    \n";
        
    exit 1;
}


sub doSelectedImport()
{
    print $q->header();
    print "\n";

    $src = $q->param("src");
    $dst = $q->param("dst");
    if (! -d $dst) {
        if (! mkdir($dst, 0777)) {
            print "<BODY>\n";
            print "Cannot mkdir($dst, 0777)\n";
            print "</BODY>\n";
            print $q->end_html();
            exit(0);
        }
    }
    $runId = $q->param("runId");
    $count = $q->param("count");
#    $count_max = $q->param("count_max");
    $info = $q->param("info");

    @pairs = split(',', $info);

    $n = $#pairs + 1;
    @fs0 = ();
    @cs0 = ();
    @rs0 = ();
    for ($i=0; $i<$n; $i++) {
        $j = int $i/2;
        ($key,$val) = split(':', $pairs[$i]);
        # print "j=$j, key=$key, val=$val<BR>\n";
        if ($key =~ /^f/) {
          $fs0[$#fs0+1] = $val;
        } elsif ($key =~ /^c/) {
          $cs0[$#cs0+1] = $val;
        } elsif ($key =~ /^r/) {
          $rs0[$#rs0+1] = $val;
        }
    }

    print $q->start_html(-bgcolor => "#ffffff");
    print "\n";


    @fs = ();
    @rs = ();
    @cs = ();
    @ss = ();
    @pids = ();
    for ($i=0; $i<$count; $i++) {
        $j = $i+1;
        ($f = $fs0[$i]) =~ s#.*/##;
        if ($cs0[$i] =~ /cpustat/ ||
                $cs0[$i] =~ /copy/ ||
                $cs0[$i] =~ /davenet/ ||
                $cs0[$i] =~ /netsum/ ||
                $cs0[$i] =~ /iostat/ ||
                $cs0[$i] =~ /mpstat/ ||
                $cs0[$i] =~ /vmstat/ ||
                $cs0[$i] =~ /trapstat/ ||
                $cs0[$i] =~ /statit/ ||
                $cs0[$i] =~ /oracle/) {
            $fs[$i] = $f;
            $cs[$i] = $cs0[$i];
            $rs[$i] = $rs0[$i];
            $ss[$i] = "Not Started";
        }
    }
#
#
    startConverters();
#
#
    open FP, ">$SessionFile";
    print FP "src=$src\n";
    print FP "dst=$dst\n";
    print FP "count=$count\n";
    for ($i=0; $i<$count; $i++) {
        $j = $i+1;
        print FP "f$j=$fs[$i]\n";
        print FP "c$j=$cs[$i]\n";
        print FP "r$j=$rs[$i].gz\n";
        print FP "pid$j=$pids[$i]\n";
    }
    close FP; 

    print $q->h3("<A HREF=\"file://$dst\">Imported Data</A>");
    print "\n";

    print "Source Directory: <B>$src</B><BR>\n";
    print "Destination Directory: <B>$dst</B><BR>\n";
    if (! -d $dst) {
        print "Don't see dst=$dst, which should be created earlier...\n";
        print "</BODY>\n";
        print $q->end_html();
        exit(0);
    }

    print "<FORM NAME=results>\n";
    print "<INPUT TYPE=hidden NAME=SessionId VALUE=$session>\n";
    print "<TABLE BORDER=0>\n";
    print "<TR>\n";
    print " <TH>Input File</TH>\n";
    print " <TH>Converter</TH>\n";
    print " <TH>Result File</TH>\n";
    print " <TH>Status</TH>\n";
    print "</TR>\n";
    for ($i=0; $i < $count; $i++) {
         $j = $i + 1;
         if ($j % 2 == 0) {
           print "<TR>\n";
         } else {
           print "<TR BGCOLOR=#f5f5f5>\n";
         }
         print " <TD>\n";
         print " <A HREF=\"file:$src/$fs[$i]\" TARGET=\"_blank\">$fs[$i]</A>\n";
         print " <INPUT TYPE=hidden NAME=f$j VALUE=$fs[$i]>\n";
         print " </TD>\n";
         print " <TD>\n";
         ($scs = $cs[$i]) =~ s/.pl\Z//;
         print " $scs\n";
         print " <INPUT TYPE=hidden NAME=c$j VALUE=$cs[$i]>\n";
         print " </TD>\n";
         print " <TD>\n";
         print " <A HREF=\"file:$dst/$rs[$i]\" TARGET=\"_blank\">$rs[$i]</A>\n";
         print " <INPUT TYPE=hidden NAME=r$j VALUE=$rs[$i]>\n";
         print " </TD>\n";
         print " <TD>\n";
         print " <INPUT TYPE=text NAME=s$j VALUE=\"$ss[$i]\">\n";
         print " </TD>\n";
         print "</TR>\n";
    }
    print "</TABLE>\n";
    print "</FORM>\n";
    print $q->end_html();

    exit( 0 );
}

sub startConverters()
{
    for ($i=0; $i<$count; $i++) {
        $j = $i+1;
        if ($cs[$i] =~ /cpustat/ ||
                $cs[$i] =~ /copy/ ||
                $cs[$i] =~ /davenet/ ||
                $cs[$i] =~ /netsum/ ||
                $cs[$i] =~ /iostat/ ||
                $cs[$i] =~ /mpstat/ ||
                $cs[$i] =~ /oracle/ ||
                $cs[$i] =~ /statit/ ||
                $cs[$i] =~ /trapstat/ ||
                $cs[$i] =~ /vmstat/) {
            if (!defined ($pid = fork)) {
                die "Unable to fork: $!\n";  
            } elsif (! $pid) {
                # child process here
                close (STDIN); close (STDOUT); close (STDERR);
                if ($cs[$i] =~ /oracle/) {
                    $csOracleMeta="oracle-meta2xml.pl";
                    $rsOracleMeta=$rs[$i] . "-meta";
                    $oraMeta = "$Converters" . "/" . "$csOracleMeta";
                    if (-x $oraMeta) {
                        `$oraMeta $src/$fs[$i] $runId | gzip -c > $dst/$rsOracleMeta.gz`;
                    } else {
                        `echo Cannot execute $oraMeta | gzip -c > $dst/$rsOracleMeta.gz`;
                    }
                }
                `$Converters/$cs[$i] $src/$fs[$i] $runId | gzip -c > $dst/$rs[$i].gz`;
                exit 0;
            } else {
                # parent branch here
                $pids[$i] = $pid;
            }
        }
    }
}


sub selectImport()
{
    print $q->header();

    $src = $q->param("src");
    $dst = $q->param("dst");
    $runId = $q->param("runId");

    print $q->start_html(-bgcolor => "#ffffff");

# Open the src directory
    @srcfiles = <$src/*>;
    $count = $#srcfiles + 1;

    print "<HEAD>\n";
    print "<SCRIPT>\n";
    print "var Count = $count;\n";
    print "var WinXanadu1;\n";
    print "var Timer1 = 0;\n";
    print "var Session = 0;\n";
    print "function initImport() {\n";
    print "  var i, j;\n";
    print "  var form;\n";
    print "  var name='';\n";
    print "  var box;\n";
    print "  var field;\n";
    print "  var file;\n";
    print "  var sel;\n";
    print "  var ind;\n";
    print "  var info='';\n";
    print "  fs = new Array();\n";
    print "  cs = new Array();\n";
    print "  rs = new Array();\n";
    print "  form = document.forms['preSelect'];\n";
    print "  j = 0;\n";
    print "  for (i=1; i<=Count; i++) {\n";
    print "    name = 's'+i;\n";
    print "    box = form.elements[name];\n";
    print "    if (! box.checked)\n";
    print "      continue;\n";
    print "    file = box.value;\n";
    print "    name = 'sel'+i;\n";
    print "    sel = form.elements[name];\n";
    print "    ind = sel.selectedIndex;\n";
    print "    if (ind == 0) {\n";
    print "      alert('You need to specify a Converter for Input File '+file);\n";
    print "      return;\n";
    print "    }\n";
    print "    // alert('converter='+sel.options[ind].value);\n";
    print "    fs[j] = file;\n";
    print "    cs[j] = sel.options[ind].value;\n";
    print "    name = 'r'+i;\n";
    print "    field = form.elements[name];\n";
    print "    rs[j] = field.value;\n";
    print "    j++;\n";
    print "    //alert('box'+i+'='+box.checked);\n";
    print "  }\n";
    print "  if (j == 0) {\n";
    print "    alert('No items selected');\n";
    print "    return;\n";
    print "  }\n";
    print "  for (i=0; i<j; i++) {\n";
    print "    // alert('file'+i+'='+fs[i]+', c='+cs[i]);\n";
    print "    info = info+'f'+i+':'+fs[i]+',c'+i+':'+cs[i]+',r'+i+':'+rs[i]+',';\n";
    print "  }\n";
    print "  form.elements['count'].value=j;\n";
    print "  form.elements['info'].value=info;\n";
    print "  // alert('info='+info);\n";
#
# Now, before submitting the form, open WinXanadu1 window and get "session"
#
    print "  WinXanadu1 = open('../html/xanI.html','xanI','width=100,height=100,screenX=2000,screenY=400');\n";
    print "  if (Timer1 > 0)\n";
    print "    clearTimeout( Timer1 );\n";
    print "  Timer1 = setTimeout( waitForSession, 1000 );\n";
    print "}\n";
    print "function waitForSession() {\n";
    print "  form = document.forms['preSelect'];\n";
    print "  if (Timer1 > 0)\n";
    print "    clearTimeout( Timer1 );\n";
    print "  // alert('Session='+Session);\n";
    print "  if (Session == 0 || Session == 'undefined' || typeof Session == 'undefined') {\n";
    print "    Timer1 = setTimeout( waitForSession, 2000 );\n";
    print "    // alert('waiting for session');\n";
    print "    return;\n";
    print "  }\n";
    print "  // alert('SETTING session='+Session);\n";
    print "  form.elements['session'].value = Session;\n";
    print "  form.submit();\n";
    print "}\n";
    print "</SCRIPT>\n";
    print "</HEAD>\n";

    print "<BODY>\n";
    print "Source Directory: <B>$src</B><BR>\n";
    print "Destination Directory: <B>$dst</B><BR>\n";
    print "<FORM NAME=preSelect METHOD=POST ACTION='../cgi/import.cgi'>\n";
    print "<INPUT TYPE=hidden NAME=src VALUE=$src>\n";
    print "<INPUT TYPE=hidden NAME=dst VALUE=$dst>\n";
    print "<INPUT TYPE=hidden NAME=count VALUE=0>\n";
#    print "<INPUT TYPE=hidden NAME=count_max VALUE=$count_max>\n";
    print "<INPUT TYPE=hidden NAME=info VALUE=' '>\n";
    print "<INPUT TYPE=hidden NAME=mode VALUE='withSelection'>\n";
    print "<INPUT TYPE=hidden NAME=session VALUE=0>\n";
    print "<INPUT TYPE=hidden NAME=runId VALUE=$runId>\n";
    print "<TABLE BORDER=0>\n";
    print "<TR>\n";
    print " <TH>Selection</TH>\n";
    print " <TH>Input File</TH>\n";
    print " <TH>Converter</TH>\n";
    print " <TH>Result File</TH>\n";
    print "</TR>\n";
    $i = 0;
    foreach $f (@srcfiles) {
        $f =~ s#.*/##;
        if ($f =~ /.txt\Z/) {
            ($resName = $f) =~ s/.txt\Z/.xml/;
	}
	elsif ($f =~ /.log\Z/) {
            ($resName = $f) =~ s/.log\Z/.xml/;
        } else {
            $resName = $f . ".xml";
        }
        $j = $i + 1;
        if ($j % 2 == 0) {
          print "<TR>\n";
        } else {
          print "<TR BGCOLOR=#f5f5f5>\n";
        }
        print " <TD ALIGN=center>\n";
        if ($f =~ /^cpustat.*(txt|log)/ ||
                $f =~ /^davenet.*/ ||
                $f =~ /^netsum.*/ ||
                $f =~ /^iostat.*/ ||
                $f =~ /^mpstat.*/ ||
                $f =~ /^vmstat.*/ ||
                $f =~ /^trapstat.*/ ||
                $f =~ /^statit.*/ ||
                $f eq 'report') {
            print "<INPUT TYPE=checkbox NAME=s$j value=\"$f\" CHECKED>\n";
        } else {
            print "<INPUT TYPE=checkbox NAME=s$j value=\"$f\">\n";
        }
        print " </TD>\n";
        print " <TD>\n";
        print " <A HREF=\"file:$src/$f\" TARGET=\"_blank\">$f</A>\n";
        print "<INPUT TYPE=hidden NAME=f$j value=\"$f\">\n";
        print " </TD>\n";
        print " <TD>\n";
        print " <SELECT NAME=sel$j SIZE=1>\n";
        print " <OPTION VALUE=undefined>?</OPTION>\n";
        if ($f =~ /^cpustat.*(txt|log)/) {
            print " <OPTION VALUE=cpustat2xml.pl SELECTED>cpustat2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=cpustat2xml.pl>cpustat2xml</OPTION>\n";
        }
        if ($f =~ /^davenet.*/) {
            print " <OPTION VALUE=netsum2xml.pl SELECTED>netsum2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=netsum2xml.pl>netsum2xml</OPTION>\n";
        }
        if ($f =~ /^netsum.*/) {
            print " <OPTION VALUE=netsum2xml.pl SELECTED>netsum2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=netsum2xml.pl>netsum2xml</OPTION>\n";
        }
        if ($f =~ /^iostat.*/) {
            print " <OPTION VALUE=iostat2xml.pl SELECTED>iostat2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=iostat2xml.pl>iostat2xml</OPTION>\n";
        }
        if ($f =~ /^mpstat.*/) {
            print " <OPTION VALUE=mpstat2xml.pl SELECTED>mpstat2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=mpstat2xml.pl>mpstat2xml</OPTION>\n";
        }
        if ($f =~ /^vmstat.*/) {
            print " <OPTION VALUE=vmstat2xml.pl SELECTED>vmstat2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=vmstat2xml.pl>vmstat2xml</OPTION>\n";
        }
        if ($f =~ /^trapstat.*/) {
            print " <OPTION VALUE=trapstat2xml.pl SELECTED>trapstat2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=trapstat2xml.pl>trapstat2xml</OPTION>\n";
        }
        if ($f =~ /^statit.*/) {
            print " <OPTION VALUE=statit2xml.pl SELECTED>statit2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=statit2xml.pl>statit2xml</OPTION>\n";
        }
        if ($f eq 'report') {
            print " <OPTION VALUE=oracle-stats2xml.pl SELECTED>oracle-stats2xml</OPTION>\n";
        } else {
            print " <OPTION VALUE=oracle-stats2xml.pl>oracle-stats2xml</OPTION>\n";
        }
        print " </SELECT>\n";
        print " </TD>\n";
        print " <TD>\n";
        print "<INPUT TYPE=text NAME=r$j value=\"$resName\">\n";
        print " </TD>\n";
        print "</TR>\n";
        $i++;
    }
    print "</TABLE>\n";
    print "<BR><BR>\n";
    print "<UL>\n";
    print "<INPUT TYPE=button NAME=import_button VALUE=IMPORT onClick='javascript:initImport();'></UL>\n";
    print "</FORM>\n";

    print $q->end_html();
}

sub doImport()
{
    print $q->header();

    $src = $q->param("src");
    $dst = $q->param("dst");
    $runId = $q->param("runId");

    if (! -d $dst) {
        if (! mkdir($dst, 0777)) {
            print "<BODY>\n";
            print "Cannot mkdir($dst, 0777)\n";
            print "</BODY>\n";
            print $q->end_html();
            exit(0);
        }
    }

    print $q->start_html(-bgcolor => "#ffffff");

    print "<HEAD>\n";
    print "<SCRIPT>\n";
    print "var Timer1 = 0;\n";
    print "var Update = false;\n";
    print "function reloadDaemon() {\n";
    print "  if (Timer1 > 0)\n";
    print "    clearTimeout( Timer1 );\n";
    print "  Timer1 = setTimeout( reloadDaemon, 1000 );\n";
    print "  if (Update) {\n";
    print "    Update = false;\n";
    print "    location.reload();\n";
    print "  }\n";
    print "}\n";
    print "</SCRIPT>\n";
    print "</HEAD>\n";

    print "<BODY onLoad='javascript:reloadDaemon();'>\n";
    print '<p>';

    get_default_names();

#
#
    startConverters();
#
#

    open FP, ">$SessionFile";
    print FP "src=$src\n";
    print FP "dst=$dst\n";
    print FP "count=$count\n";
    for ($i=0; $i < $count; $i++) {
        $j = $i + 1;
        print FP "f$j=$fs[$i]\n";
        print FP "c$j=$cs[$i]\n";
        print FP "r$j=$rs[$i].gz\n";
        print FP "pid$j=$pids[$i]\n";
    }
    close FP; 

    # print $q->h3("Xanadu SessionId=$session\n");

    print $q->h3("<A HREF=\"file://$dst\">Imported Data</A>");

    print "Source Directory: <B>$src</B><BR>\n";
    print "Destination Directory: <B>$dst</B><BR>\n";
    if (! -d $dst) {
        print "Don't see dst=$dst, which should be created earlier...\n";
        print "</BODY>\n";
        print $q->end_html();
        exit(0);
    } else {
        print "(directory exists)<BR>\n";
    }
    print "<FORM NAME=results>\n";
    print "<INPUT TYPE=hidden NAME=SessionId VALUE=$session>\n";
    print "<TABLE BORDER=0>\n";
    print "<TR>\n";
    print " <TH>Input File</TH>\n";
    print " <TH>Converter</TH>\n";
    print " <TH>Result File</TH>\n";
    print " <TH>Status</TH>\n";
    print "</TR>\n";
    for ($i=0; $i < $count; $i++) {
         $j = $i + 1;
         if ($j % 2 == 0) {
           print "<TR>\n";
         } else {
           print "<TR BGCOLOR=#f5f5f5>\n";
         }
         print " <TD>\n";
         print " <A HREF=\"file:$src/$fs[$i]\" TARGET=\"_blank\">$fs[$i]</A>\n";
         print " <INPUT TYPE=hidden NAME=f$j VALUE=$fs[$i]>\n";
         print " </TD>\n";
         print " <TD>\n";
         ($scs = $cs[$i]) =~ s/.pl\Z//;
         print " $scs\n";
         print " <INPUT TYPE=hidden NAME=c$j VALUE=$cs[$i]>\n";
         print " </TD>\n";
         print " <TD>\n";
         print " <A HREF=\"file:$dst/$rs[$i]\" TARGET=\"_blank\">$rs[$i]</A>\n";
         print " <INPUT TYPE=hidden NAME=r$j VALUE=$rs[$i]>\n";
         print " </TD>\n";
         print " <TD>\n";
         print " <INPUT TYPE=text NAME=s$j VALUE=\"$ss[$i]\">\n";
         print " </TD>\n";
         print "</TR>\n";
    }
    print "</TABLE>\n";
    print "</FORM>\n";
    print $q->end_html();

    exit(0);
}

sub get_default_names()
{
    # Open the src directory
    @srcfiles = <$src/*>;

    @fs = ();
    @rs = ();
    @cs = ();
    @ss = ();
    @pids = ();
    $i = 0;
    foreach $f (@srcfiles) {
        $f =~ s#.*/##;
        $type = "unknown";

	if ($f =~ /xan/) {
	    $type = "xyy";
        } elsif ($f =~ /^cpustat.*(txt|log)/) {
            if (-f "$src/cpustat.xml") {
                next;
            } else {
                $type = "cpustat";
            }
        } elsif ($f =~ /^davenet.*/) {
            if (-f "$src/$f.xml") {
                next;
            } else {
                $type = "netsum";
            }
        } elsif ($f =~ /^netsum.*/) {
            if (-f "$src/$f.xml") {
                next;
            } else {
                $type = "netsum";
            }
        } elsif ($f =~ /^iostat.*/) {
            if (-f "$src/iostat.xml") {
                next;
            } else {
                $type = "iostat";
            }
        } elsif ($f =~ /^mpstat.*/) {
            $type = "mpstat";
        } elsif ($f =~ /^vmstat.*/) {
            $type = "vmstat";
        } elsif ($f =~ /^trapstat.*/) {
            $type = "trapstat";
        } elsif ($f =~ /^statit.*/) {
            $type = "statit";
        } elsif ($f eq 'report.txt') {
            $type = "statspack";
        } elsif ($f =~ /^statspack.*/) {
            $type = "statspack";
        } elsif ($f =~ /^ktcovall.*/) {
            $type = "kernel-dis";
#        } elsif ($f =~ /^lockstat.*/) {
#            $type = "lockstat";
        } elsif ($f =~ /^ps_begin.*/) {
            $type = "ps";
        } elsif ($f =~ /^davenet.*/) {
            $type = "netsum";
        } elsif ($f =~ /^netsum.*/) {
            $type = "netsum";
        } elsif ($f =~ /^jvmstat.*/) {
            $type = "jvmstat";
        } elsif ($f =~ /^jvmsnap.*/) {
            $type = "jvmsnap";
        } elsif ($f =~ /^vxstat.*/) {
            $type = "vxstat";
        } elsif ($f =~ /^rdtstat.*/) {
            $type = "rdtstat";
        } elsif ($f eq 'report') {
            $type = "oracle-stats";
        } elsif ($f =~ /cr_monitor.*/) {
            $type = "crmonitor";
        }
        if ($type ne "unknown") {
            $fs[$i] = $f;
            $cs[$i] = "${type}2xml.pl";
            if ($f =~ /.txt\Z/) {
                ($rs[$i] = $f) =~ s/.txt\Z/.xml/;
	    }
	    elsif ($f =~ /.log\Z/) {
                ($rs[$i] = $f) =~ s/.log\Z/.xml/;
	    }
	    elsif ($f eq "report") {
                ($rs[$i] = $f) = "oracle-stats.xml";
            } else {
                $rs[$i] = $f . ".xml";
	    }
            $ss[$i] = "Not Started";
            $i++;
        }
    }
    $count = $i;
}


# MAIN STARTS HERE

$| = 1;
$batch = 0;
$noExec = 0;

use CGI;
use POSIX ":sys_wait_h";

if ($^O eq 'MSWin32') {
    $Converters = '..\txt2xml';
} else {
    $Converters = "../txt2xml";
}

#
# Get options 
#

while ($#ARGV > -1) {
    $arg = shift @ARGV;
    if ( $arg =~ /^-(.)(.*)$/ ) {
        $flag=$1; $val=$2;
        # print "flag=$flag, val=$val\n";
        if ( $flag eq "b" ) {
            $batch = 1;
        } elsif ( $flag eq "n" ) {
            $noExec = 1;
        } elsif ( $flag eq "s" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $src = $val;
        } elsif ( $flag eq "d" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $dst = $val;
        } elsif ( $flag eq "r" ) {
            if ( $val eq "" ) { $val = shift @ARGV;}
            if ( $val eq "" ) { &usage();}
            $runId = $val;
        } else { &usage(); }
    } elsif ( $arg =~ /^(.*)$/ ) {
        SWITCH: {
            if (! defined($src)) {
                $src = $1; last SWITCH;
            }
            if (! defined($dst)) {
                $dst = $1; last SWITCH;
            }
            if (! defined($runId)) {
                $runId = $1; last SWITCH;
            }
        }
    }
}


if ($batch == 1) {
    runBatch();
    exit (0);
}


$q = new CGI;

$session = $q->param("session");
$SessionFile = "/tmp/xan".$session.".info";

if ($q->param("mode") eq "all") {
    doImport();
} elsif ($q->param("mode") eq "withSelection") {
    doSelectedImport();
} else {
    selectImport();
}

exit (0);

# end of MAIN

