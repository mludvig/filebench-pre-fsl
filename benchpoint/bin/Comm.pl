
$HEADER = <<'EOF';
------------------------------------ Comm.pl -----------------------------------

This is a free library of IPC goodies.  There is no warrenty, but I'd
be happy to get ideas for improvements.  - Eric.Arnold@Sun.com.

It's been tested with Perl4/Perl5 and SunOS4.x and Solaris2.3 - 2.5.
Work is being done on AIX3.2.5, IRIX5.3, HP-UX(9), Linux

A lot was borrowed from "chat2.pl"(Randal L. Schwartz), and then
diverged as its goals became generalized client/server IPC, support for
SVR4/Solaris, and to facilitate my "shelltalk" program.  Since then, I/we've
been using it for all sorts of stuff.

Per the notes on creating new modules, here is some boilerplate:
Copyright (c) 1995 Eric Arnold.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

See the end of this file for example programs demonstrating usage.

It's normally put into a file and "require"d, but can also be simply
concatinated to the end of some other perl script.  If you do that, use:
	require "Comm.pl" unless defined &Comm'init;

Function summary:

  (Remember to use prefixes (i.e. "&Comm'init") for anything not exported.)
  (All file handles passed up from these functions are exported into the
  caller's package.)


  init :
  ----

    &Comm'init();		# Required after "require".  It sets up all
				# internal symbols, and exports functions to
				# caller's package.

    &Comm'init(1.8);		# If first arg is numeric, it specifies a 
				# desired version for compatibility.

    &Comm'init(1.8, "func",...);# Tell it to export specified function(s),
				# otherwise, init() will export all documented
				# functions.

  open_port :
  ---------

    # Open a STREAM socket connection to a host:
    $handle = &open_port($host, $port, $timeout);

  open_listen :
  -----------

    # Open a STREAM listen socket on your host:

    $handle = &open_listen( $port );

    # Or you can specify the $host if you need to listen on an address 
    # other than:  `uname -n` (E.g. if you have a second ethernet)

    $handle = &open_listen( $host, $port );

  select_it :
  ---------

    # Give it a timeout and a list of handles, and it tells you which ones
    # have data ready (or some condition, like EOF).  It's called "select_it"
    # so it won't clash with "select".

    @ready_handles = &select_it( $timeout, $handle1, $handle2, ..... );

  accept_it :
  ---------

    # Complement to "open_listen":

    ( $new_handle, $rem_host ) = &accept_it( $handle );

  open_proc :
  ---------

    # Set up a pseudo-tty, and start "$Command" running in it.

    ( $Proc_pty_handle, $Proc_tty_handle, $Proc_pid ) = 
	&open_proc($Command);

  wait_nohang :
  -----------

    # Does a portable wait4/waitpid.  Used mostly internally.  Not exported.
    &Comm'wait_nohang( $pid );
    # If pid is -1 or undef, wait for any.

  wait_hang :
  -----------

    # Does a portable blocking waitpid.  Used mostly internally.  Not exported.
    &Comm'wait_hang( $pid );
    # If pid is -1 or undef, wait for any.

  expect :
  ------

    # This function scans an input stream for a pattern, without blocking,
    # a la "sysread()".
    #
    # Patterns are scanned in the order given, so later patterns can contain
    # general defaults that won't be examined unless the earlier patterns
    # have failed.  Be careful of timing problems, however.  If you specify
    # a very general pattern later in the list, it might match undesireably
    # if a partial packet of data is received.  

    # "$err" can contain "TIMEOUT" or "EOF".  

    # "$before" and "$after" are intended to help you debug your process.
    # "$before" will contain anything before "$match", or everything
    # accumulated if "$err" is set.  "$after" contains everything after
    # "$match" (assuming the pattern succeeds).

    # Each file handle has an associated internal accumulator containing
    # any data read but not discarded:
    #   - A successful match will discard "$before" and "$match" from 
    #     the accumulator.  
    #   - A TIMEOUT will return "$before", but not clear the accumulator.
    #   - An EOF will return "$before", and clear the accumulator.
    # Each call to "expect()" will try to match in the accumulator first.

    ( $match, $err, $before, $after ) = 
		&expect( $fh, $timeout, 'regexp1', 'regexp2' );
    # or
    $match = &expect( $fh, $timeout, 'regexp1', 'regexp2', ... );

    # You can give it any file handle, but remember to pass the type glob,
    # so it can be used in a different package namespace:

    open(RDR, "somecommand|");
    # or
    &open3(WRT, RDR, ERR, 'somecommand' );
    ( $match, $err, $before, $after ) = expect( *RDR, 1, $pattern );

    # $timeout can be an absolute time (i.e. $timeout = time + 10 )
    # or just a relative time (i.e. $timeout = 10 )

    # If you need to pass in regex options, you can use the Perl5 syntax:

    &expect( $fh, $timeout, qq{(?i)(?m)what} );



  interact :
  --------

    # This connects a process opened with "open_proc()" to the user via
    # STDIN, and allows them to "interact".
    #
    # You specify patterns to trigger return of control to your script, which
    # can be matched either in STDIN or the process file handle.  The
    # $Proc_pty_handle serves as a delimeter between string patterns for STDIN,
    # and regex patterns for $Proc_pty_handle.
    #
    # Any pattern matched for STDIN isn't sent to the process.  Therefore,
    # patterns for STDIN are treated only as strings (it's too hard to
    # figure out partial matches on a regex).

    # You must set terminal modes for programs which don't handle that 
    # themselves (like "telnet"):
    &stty_sane($Proc_tty_handle);	# use $Proc_pty_handle for HP
    &stty_raw(STDIN);
    ( $match, $err ) = &interact( "optional string patterns for STDIN", ..., 
			$Proc_pty_handle, "optional regex patterns", ... );
    &stty_sane(STDIN);



  open_udp_port :
  -------------

    # Open a UDP port.  There are more variations possible for UDP ports,
    # so the arguments you can give are more variable:

    # Just open a UDP socket on your host.  You'll have to use "send_to"
    # if you want to do more than read from it.  If you don't specify
    # a host (i.e. ""), it uses `uname -n`.  If you don't specify a port
    # (i.e. 0 ) it will assign a port for you.

    $handle = &open_udp_port( "", 0 )

    # Set up a connected UPD port.  You can "print" to this handle:

    $handle = &open_udp_port( "local_addr", 5050, "remotehost", 5050 )
      etc.

  send_to :
  -------

    # This is a convenience interface function to "send()".  It packs up
    # the appropriate binary structure from the remote address and port.

    &send_to( $handle, $buf, $flags, $remote_addr, $remote_port );

  sockaddr_struct :
  ---------------

    # If you're really pressed for performance, you can save a packed struct,
    # and use "send()", which saves some overhead with each call:

    $remote_sockaddr = &sockaddr_struct( $remote_addr, $remote_port );
    send( $handle, $buf, 0, $remote_sockaddr ) || die "send $!";

  recv_from :
  ---------

    # This is another convenience function, which unpacks the returned struct
    # from "recv()", and tells you what address and port the data came from.
    # You have to pass it a glob (i.e. *buf) so it can fill that variable with
    # the data.

    ( $addr, $port ) = &recv_from($handle, *buf, 10000, 0);


  close_it :
  --------

    # This will either call "shutdown()" if the handle is a socket type,
    # or kill the child process if the handle is a pty type.

    &close_it( $handle )

  close_noshutdown :
  ----------------

    # Use this when a parent forks a child to handle a request on a socket
    # file handle.  The parent would like to close the file handle, but
    # leave the socket alive so the child can continue to read/write it
    # (the child inherited the file handle and therefore the socket).

    &close_noshutdown( $handle );


  stty_sane, stty_raw, stty_ioctl :
  --------------------------------
    
    # These use "stty" to set the terminal modes the first time through,
    # because "stty" is easy and portable.  The binary ioctl struct
    # containing the modes is then cached for subsequent calls to
    # "ioctl()", which is much faster for switching between modes, but is
    # a pain to make portable.  "$Proc_tty_handle" can be "STDIN".
    # Use $Proc_pty_handle for HP.

    &stty_sane( $Proc_tty_handle );
    &stty_raw( $Proc_tty_handle );

    # "stty_raw/sane" use "stty_ioctl".  See the header for
    # "get_ioctl_from_stty" for more information about getting and saving
    # binary ioctl structs.

    &stty_ioctl( $Proc_tty_handle, "stty intr '^c'" );


  open_dupsockethandle, open_dupprochandle :
  ----------------------------------------

    # I don't know if anybody will ever use these.  They dup file
    # handles, which will fool the utilities here into thinking that
    # your file handle (created from some other package) was actually
    # created by a routine in here.

    &open_dupsockethandle($handle);
    &open_dupprochandle($handle);



Misc:

  $Debug is "inherited" from $main'Debug


Portability bug-a-boos:

  - There are two versions of getpty().  getpty_svr4() tries to do the
    right SVR4 thing, although without direct access to the right function
    calls :-(.  getpty() also works for SVR4/Solaris, using some partial BSD
    backward compatibility.  Neither is all too clean.

    If you do have "grantpt()" and "ptsname()", etc., but not
    "/usr/lib/pt_chmod" or the bit hack for "ptsname()" doesn't work
    for you, try compiling the "pt_chmod.c" and "ptsname.c" programs
    I've supplied with this package in the tar file.  (Remember to give
    "pt_chmod" setuid perms.)

  - Once I decide to bite the bullet, and give up support for perl4, it
    should use "use Socket" for all the socket defines like SOCK_STREAM.
    There's no getting around putting some of the other defines directly
    in here, I think (i.e. I_STR).


Bugs:

  - There used to be some odd problems with the value for SOCK_STREAM,
    depending on whether it was perl4 or perl5 and whether it was compiled
    under SunOS or Solaris, but it seems to be better now.

History:

09/11/94 07:03:04 PM;  eric:	fixed for Solaris and /dev/tty
09/14/94 02:11:19 AM;  eric:	close correct file handle in open_listen
09/15/94 03:33:31 AM;  eric:	added system()
09/19/94 10:48:11 AM;  eric:	added cheapo/easy ioctl dump/do
10/11/94 11:07:14 AM;  eric:	added I_POP to clear stream on pty
11/08/94 03:03:19 PM;  eric:	changed to first try SOCK_STREAM=1, then =2
02/28/95 12:53:22 PM;  eric:	found the right place to set SO_LINGER!
03/18/95 08:19:46 PM;  eric:	added timeout arg to open_port
05/07/95 10:56:25 PM;  eric:	fixed shutdown/close order bug in close()
				added close_noshutdown
06/08/95 01:06:03 PM;  eric:	fixed Sol2.4 problem with string literal
				as last arg to syscall($SYS_ioctl
09/13/95 10:29:26 AM;  eric:	added emport_FH() function
09/17/95 06:05:35 PM;  eric:	&open_udp_port(), plus examples at the end
09/19/95 07:10:03 PM;  eric:	revamped &open_udp_port(), put all sockaddr
				stuff into &sockaddr_struct(), also added
				&send_to() and &recv_from()
10/03/95 10:23:00 AM;  eric:	added expect(); $Version, more portable
				stty_raw/sane()
10/05/95 04:12:57 PM;  eric:	added interact(), getpty_svr4(), exported funcs
10/07/95 02:14:57 PM;  eric:	added stty_ioctl(), version 1.2, now Comm.pl
10/09/95 04:51:10 PM;  eric:	expect() now keeps accum. data per FH, v1.3
10/12/95 07:02:31 PM;  eric:	added support for user supplied "pt_chmod" 
				and "ptsname" programs
10/16/95 19:20:13 PM;  eric:	fixes for AIX2.3
11/02/95 05:42:51 PM;  eric:	partial fixes for HP-UX9, Linux, v1.4
11/21/95 03:21:51 PM;  eric:	*lots* of hacking for HP-UX, v1.5
06/18/96 02:58:20 PM;  eric:	merged changes for SCO Unix
10/10/96 11:34:22 AM;  eric:	force STDIN to reopen to fd 0 for 
				SunOS/Perl5.003
11/~1/96 ..:..:.. PM;  eric:	stty_ioctl trys to use TTY handle if PTY given
11/06/96 04:03:24 PM;  eric:	merged more fixed for SCO 3.2.4 
11/26/96 11:26:55 AM;  eric:	added name export to open_duphandl*
07/02/97 11:54:46 AM;  eric:	revamped "wait"ing
08/06/97 10:23:01 AM;  eric:	rev'd to 1.7
08/20/97 14:08:34 AM;  eric:	v1.8:  nasty little bug with wait_nohang.
EOF





package Comm;

#&init;		# nah, force them to call it, proper.

sub init{
  local( $version );

  if ( defined($_[0]) &&  ($_[0] =~ /^[\d.-]+$/) )
  {
    $version = shift;
  }
  local( @args) = @_;


  $Version = 1.8;
  if ( $version )
  {
    if ( $Version ne $version )
    {
      warn "Package version, $Version, does not match requested, $version";
    }
  }

  local( $pkg ) = caller;
  $My_pkg = "Comm";
  *Debug = *main'Debug;		# set this before export_sym

  if ( !@args )
  {
    # For some reason, exporting to myself causes later export to main to fail
    if ( $pkg ne $My_pkg )
    {
      &export_sym( $pkg, (
	"open_port", "open_listen", "open_udp_port", "open_proc",
	"send_to", "recv_from", "accept_it", "select_it",
	"expect", "interact", 
	"close_noshutdown", "close_it",
	"stty_sane", "stty_raw", "stty_ioctl",
	) );
    }
  }
  else
  {
    &export_sym( $pkg, @args );
  }

  return if $Inited;

  $Inited = 1;


  $OS_name = `uname`; chop $OS_name;

  if( $OS_name eq "SunOS" )
  {
    if( ! -f "/vmunix" )
    {
      $OS_name = "Solaris";
      $WNOHANG = 64;
    }
    else
    {
      $WNOHANG = 1;
    }
  }

  # First, try to divide the world into two camps.  It works in somewhat,
  # but there will be many overrides :-(
  if ( -f "/vmunix" )
  {
    $OS_type = "BSD";
  }
  else
  {
    $OS_type = "SVR4";
  }

  if ( $OS_name eq "HP-UX" || $OS_name eq "AIX" )
  {
    $OS_type = "BSD";
  }
  elsif( $OS_name eq "Linux" )
  {
    require 'sys/syscall.ph';
    $OS_type = "SVR4";
    $WNOHANG = 1;
  }
  elsif ( -d "/tcb")
  {
    # sco seems to have a pretty worthless implementation of uname.
    # the existence of /tcb seems to be sco specific and this
    # test is used by other pieces of software like "Crisp".
    $OS_name = "SCO";
    print STDERR "OSname is SCO\n" if $Debug;
  }


  print STDERR "OS_type=$OS_type\nOS_name=$OS_name\n" if $Debug;

  chop( $My_host = `uname -n ` );

  $Next_handle="commutils000000";

  $Sockaddr_t = 'S n a4 x8';	# actually should be named $Sockaddr_in_t

  $SYS_ioctl = 54;

  $AF_INET = 2; 

  if ( $OS_type eq "SVR4" )
  {
    $SOCK_STREAM=2;	# the weenies just had to reverse it!
    $SOCK_DGRAM=1;

    # from /usr/include/sys/termios.h
    $tIOC    	=( unpack("C", 't') << 8);
    $TIOCGETP       =($tIOC|8);
    $TIOCSETP       =($tIOC|9);

    $TIOC     	=( unpack("C", 'T' ) <<8);
    $TCGETS         =($TIOC|13);
    $TCSETS         =($TIOC|14);
    $TCSANOW    =(( unpack("C",'T')<<8)|14); #/* same as TCSETS */
    $TCGETA  	=($TIOC|1);
    $TCSETA  	=($TIOC|2);

    # From /usr/include/sys/stropts.h
    $STR =             ( unpack("C", "S") <<8 );
    $I_PUSH =          ($STR|02);	#$I_PUSH = 21250;
    $I_POP =           ($STR|03);
    $I_LOOK =          ($STR|04);
    $I_STR =          ($STR|010);
    #define I_FLUSH         (STR|05)

    # from /usr/include/sys/ptms.h:
    $ISPTM	= ((ord('P')<<8)|1);    #/* query for master */
    $UNLKPT	= ((ord('P')<<8)|2);    #/* unlock master/slave pair */

    if( $OS_name eq "Linux" )
    {
      $SOCK_STREAM=1;
      $SOCK_DGRAM=2;
    
      $TCGETA = 0x5405;
      $TCSETA = 0x5406;
    }

  }
  else
  {
    $SOCK_STREAM=1;
    $SOCK_DGRAM=2;

    if ( $OS_name eq "HP-UX" )
    {
      # Note: "use POSIX" has the nasty habit of causing re-open of STDIN
      # not to use file descriptor 0, if done between closing and re-opening.
      eval "use POSIX";		# quote for perl5.000 (otherwis,e causes 
				# abort during compilation even if not on HP).
      $WNOHANG = 1;

      $TIOCGETP=0x40087408;
      $TIOCSETP=0x80087409;
      $TCGETA=0x40125401;
      $TCSETA=0x80125402;

      $TIOCSCTTY=0x20005421;
      $TIOCTTY=0x80047468;
      $TIOCTRAP=0x80047467;
      $TIOCMONITOR=0x8004745f;
      $TIOCREQSET=0x80187464;
      $TIOCREQCHECK=0x40187471;
      $TIOCCLOSE=0x20007462;

      # not defined: $TIOCNOTTY
    }
    else
    {
      $TIOCGETP=0x40067408;	#d(1074164744)
      $TIOCSETP=0x80067409;	#d(-2147060727)
      $TIOCNOTTY=0x20007471;
    }

  }

  local($ioctl);
  for $ioctl ( TIOCGETP, TIOCSETP, TIOCSCTTY, TIOCTTY, TIOCTRAP, TIOCMONITOR,
   TIOCGETP, TIOCSETP, TIOCNOTTY, TIOCGETP, TIOCSETP, TCGETS, TCSETS, TCSANOW,
   TCGETA, TCSETA, TIOCREQSET, TIOCREQCHECK, TIOCCLOSE )
  {
    eval qq,\$Ioctl_names{\$$ioctl} .= "$ioctl " ,;
  }

  # stuff common to both OS types:

# XXX: changed SO_DEBUG from 0x0001
  $SOL_SOCKET      =0xffff          ;#/* options for socket level */
  $SO_DEBUG        =0x0000          ;#* turn on debugging info recording */
  $SO_ACCEPTCONN   =0x0002          ;#* socket has had listen() */
  $SO_REUSEADDR    =0x0004          ;#* allow local address reuse */
  $SO_KEEPALIVE    =0x0008          ;#* keep connections alive */
  $SO_DONTROUTE    =0x0010          ;#* just use interface addresses */
  $SO_BROADCAST    =0x0020          ;#* permit sending of broadcast msgs */
  $SO_USELOOPBACK  =0x0040          ;#* bypass hardware when possible */
  $SO_LINGER       =0x0080          ;#* linger on close if data present */
  $SO_OOBINLINE    =0x0100          ;#* leave received OOB data in line */

}


sub open_port{
  die "$My_pkg'init not called, aborting" unless $Inited;

  local( $remote_addr, $remote_port, $timeout ) = @_;
  local( $new_handle ) = "socket" . ++$Next_handle;
  local( %saveSIG, $ret );

  local( $local_sockaddr ) = &sockaddr_struct( $My_host, 0 );
  local( $remote_sockaddr ) = &sockaddr_struct( $remote_addr, $remote_port );


  unless (socket( $new_handle, $AF_INET, $SOCK_STREAM, 6)) 
  {
    ($!) = ($!, close( $new_handle)); # close new_handle while saving $!
    print STDERR "Socket error $!\n" if $Debug;
    return undef;
  }
  unless (bind( $new_handle, $local_sockaddr)) 
  {
    ($!) = ($!, close( $new_handle)); # close new_handle while saving $!
    print STDERR "bind error $!\n" if $Debug;
    return undef;
  }

  %saveSIG=%SIG;
  if ( $timeout )
  {
    $SIG{ALRM} = "timedout";
    alarm($timeout);
  }
  eval { $ret = connect( $new_handle, $remote_sockaddr) };

  if ( !$ret || ($@ =~ /^timedout/) ) 
  {
    ($!) = ($!, close( $new_handle)); # close new_handle while saving $!
    #die "connect failed, $!";
    print STDERR "connect error eval=($@)$!\n" if $Debug;
    if ( $@ =~ /^timedout/ ) {
      $! .= ", timeout after $timeout seconds";}
    return undef;
  }

  if ( $timeout )
  {
    %SIG = %saveSIG;
    alarm(0);
  }

  select((select( $new_handle), $| = 1)[0]);

  &export_FH( (caller)[0], $new_handle );
  return $new_handle;
}


sub timedout {
  die "timedout";
}





# Usage:
#   open_udp_port( $local_addr, $local_port, $remote_addr, $remote_port );
# or
#   open_udp_port( $local_addr, $local_port );
#
# To create a port to read on, unconnected, which will create a port based
# on "uname -n":
#
#   open_udp_port( "", 5050 )
#
# A "connected" socket where we don't care what port we're reading on looks
# like:
#
#   open_udp_port( "", 0, "remotehost", 5050 )
#
# This will read on the broadcast address:
#
#   open_udp_port( "129.145.43.255", 5050 )
#
# Note:  reading on broadcast only works for Solaris, haven't found SunOS fix

sub open_udp_port{
  die "$My_pkg'init not called, aborting" unless $Inited;

  local( $local_addr, $local_port, $remote_addr, $remote_port, $proto );
  local( $local_sockaddr, $new_handle );

  if ( @_ == 2 )
  {
    ( $local_addr, $local_port ) = @_;
  }
  elsif ( @_ == 4 )
  {
    ( $local_addr, $local_port, $remote_addr, $remote_port ) = @_;
  }
  else
  {
    warn "open_udp_port: too few args";
    return undef;
  }

  if ( ! $local_addr )	# specified as "", 0, or undef
  {
    $local_sockaddr = &sockaddr_struct( $My_host, $local_port );
  }
  else
  {
    $local_sockaddr = &sockaddr_struct( $local_addr, $local_port );
  }
 
  $new_handle = "socket" . ++$Next_handle;

  $proto = getprotobyname("udp");

  unless (socket( $new_handle, $AF_INET, $SOCK_DGRAM, $proto)) 
  {
	  print STDERR "socket failed: $!\n" if $Debug;
	  ($!) = ($!, close($new_handle)); # close S while saving $!
	  return undef;
  }

  # /usr/demo/SOUND/src/radio/libradio/netbroadcast.c says that SO_BROADCAST
  # not required for Suns
  #
  # Don't know if you can just pass a 1 or need to pass a struct:
  #$val = pack("I", 1 );
  #setsockopt( $new_handle, $SOL_SOCKET, $SO_BROADCAST, $val ) || die "setsockopt: $!";
  #setsockopt( $new_handle, $SOL_SOCKET, $SO_BROADCAST, 1 ) || die "setsockopt: $!";


  select( (select( $new_handle ), $| = 1 )[0] ); 

  unless ( bind( $new_handle, $local_sockaddr )) 
  {
    #die "bind failed: $!";
    print STDERR "bind failed: $!\n" if $Debug;
    ($!) = ($!, close($new_handle)); # close S while saving $!
    return undef;
  }

  if ( $remote_addr )
  {
    $remote_sockaddr = &sockaddr_struct( $remote_addr, $remote_port );
    connect( $new_handle, $remote_sockaddr) || die "connect $!";
    print STDERR "connected to $remote_addr $remote_port\n" if $Debug;
  }
  else
  {
    print STDERR "binding unconnected\n" if $Debug;
  }

  # find out what we actually did:
  local( $family, $port, @myaddr ) = unpack( 
	"S n C4 x8", # $Sockaddr_t is wrong for unpacking
	getsockname( $new_handle ));

  if ( $Debug )
  {
    print "after bind [connect], ( family, port, myaddr ) =",
	"( $family, $port, @myaddr) \n"
  }

  &export_FH( (caller)[0], $new_handle );

  return  $new_handle; 
}




sub sockaddr_struct{
  local( $addr, $port ) = @_;
  local( $addr_struct, $sockaddr_struct, @addr_info );

  if ($addr =~ /^(\d+)+\.(\d+)\.(\d+)\.(\d+)$/) 
  {
    $addr_struct = pack('C4', $1, $2, $3, $4);
  }
  else
  {
    return undef unless ( @addr_info = gethostbyname( $addr ) );
    $addr_struct = $addr_info[4];
  }

  $sockaddr_struct = pack( $Sockaddr_t, 2, $port, $addr_struct);

  if ( $Debug )
  {
    print STDERR "\$sockaddr_struct = pack($Sockaddr_t, 2, $port, ip=(",
	      join(".", unpack("C*", $addr_struct ) ), "),addr=($addr))\n";
  }

  return $sockaddr_struct;
}



# Note: it would be faster to save a copy of the sockaddr,
# and use "send()", if you really need performance:

sub send_to{
  local( $handle, $buf, $flags, $remote_addr, $remote_port ) = @_;
  local( $remote_sockaddr );

  $remote_sockaddr = &sockaddr_struct( $remote_addr, $remote_port );
  send( $handle, $buf, $flags, $remote_sockaddr ) || die "send_to $!";
}


# ($addr, $port ) = recv_from($handle, *buf, 10000, 0);
sub recv_from{
  local( $handle, *buf, $len, $flags ) = @_;
  local( $remote_info );

  return undef unless ( $remote_info = recv($handle, $buf, 10000, 0) );

  local( $family, $port, @addr ) = unpack( "S n C4 x8", $remote_info );

  local($name, $aliases, $type, $len, $acceptaddr) =
	gethostbyaddr( pack( 'C4', @addr ), 2 );
  
  return ( $name, $port );
}


sub open_listen{
  die "$My_pkg'init not called, aborting" unless $Inited;
 
  local( $local_addr, $local_port );
  local( $new_handle );

  if ( @_ == 2 )
  {
    ( $local_addr, $local_port ) = @_;
  }
  elsif ( @_ == 1 )
  {
    ( $local_port ) = @_;
    $local_addr = $My_host;
  }
  else
  {
    warn "open_listen: too few args";
    return undef;
  }

  local( $local_sockaddr ) = &sockaddr_struct( $local_addr, $local_port );

  $new_handle = "socket" . ++$Next_handle;

  unless (socket( $new_handle, $AF_INET, $SOCK_STREAM, 6)) 
  {
    print STDERR "socket failed: $!\n" if $Debug;
    ($!) = ($!, close($new_handle)); # close S while saving $!
    return undef;
  }


  # We want it it release the socket for immediate reuse if the server is
  # shutdown/restarted.  It seems that SO_LINGER and SO_REUSEADDR are most
  # pertinant, but SO_KEEPALIVE seems like it might be nice too, for
  # notification of peer disappearance.
  $linger = pack("II", 0, 0 );	# linger is a C struct in socket.h
  setsockopt( $new_handle, $SOL_SOCKET, $SO_LINGER, $linger);
  setsockopt( $new_handle, $SOL_SOCKET, $SO_KEEPALIVE, 1);
  setsockopt( $new_handle, $SOL_SOCKET, $SO_REUSEADDR, 1);

  # contributed by somebody:
  #setsockopt(S, "0xffff", "0x0004", 1);

  unless ( bind( $new_handle, $local_sockaddr )) 
  {
    #die "bind failed: $!";
    print STDERR "bind failed: $!\n" if $Debug;
    ($!) = ($!, close($new_handle)); # close S while saving $!
    return undef;
  }
  unless ( listen( $new_handle, 1 )) 
  {
    #die "listen failed: $!";
    print STDERR  "listen failed: $!\n" if $Debug;
    ($!) = ($!, close($new_handle)); # close S while saving $!
    return undef;
  }

  select( (select( $new_handle ), $| = 1 )[0] ); 
  local( $family, $port, @myaddr ) = unpack( "S n C C C C x8", 
		getsockname( $new_handle ));

  &export_FH( (caller)[0], $new_handle );
  return  $new_handle; 
}



sub accept_it{ local( $handle ) = @_; local( $addr, $af, $port,
  $inetaddr, $acceptaddr ) = ();

  $new_handle = "socket" . ++$Next_handle;

  unless( ( $addr = accept( $new_handle, $handle ) ) ) 
  {
    print STDERR "accept failed: $!";
  }

  ( $af, $port, $inetaddr ) = unpack( $Sockaddr_t, $addr );
  @inetaddr = unpack( 'C4', $inetaddr );

  ($name, $aliases, $type, $len, $acceptaddr) =
	gethostbyaddr( pack( 'C4', @inetaddr ), 2 );

  select( ( select( $new_handle ), $| = 1 )[0] );

  $name = join(".", @inetaddr ) unless $name;

  &export_FH( (caller)[0], $new_handle );

  return ($new_handle,$name);
}




sub select_it {
  local( $timeout, @handles ) = @_;

  # Init these to make -w happy:
  local( @ready ) = ();
  local( $rout, $rmask, $handle, $eout, $emask ) = ( '', '', '', '', '' );

  for $handle ( @handles ) {
    vec( $rmask, fileno( $handle ), 1 ) = 1;
    vec( $emask, fileno( $handle ), 1 ) = 1;
  }
  ( $nfound, $timeleft ) = select( $rout=$rmask, undef, $eout=$emask, $timeout );

  print "nfound=$nfound\n" if $DEBUG;
  if ( $nfound < 1 )
  {
    if ( $nfound < 0 )
    {
      print "error=$!\n" if $DEBUG; 
    }
    return @ready;
  }

  # You could also do:
  #   @bit = split(//,unpack('b*',$rout));
  #   if ($bit[fileno(STDIN)] == 1){ ... };

  for $handle ( @handles ) 
  {
    if ( vec( $rout, fileno( $handle ), 1 ) == 1 ) 
    {
      print "fh=$handle is ready\n" if $DEBUG;
      push( @ready, $handle ); 
    }
    if ( vec( $eout, fileno( $handle ), 1 ) == 1 ) 
    {
      if ( $OS_name eq "HP-UX" )
      {
	&pty_clear_trap($handle);
      }
      print "Exception on read_handle=$handle\n" if $DEBUG; 
    }
  }

  return @ready;
}





sub open_proc {

  #eval "use Pty_spawn";
  #if ( ! $@ )
  #{
    #return &open_proc_Pty_spawn( @_ );
  #}

  die "$My_pkg'init not called, aborting" unless $Inited;

  local(@cmd) = @_;

  #local(*TTY,*PTY);	# PTY must not die when sub returns
  local( $pty_handle, $tty_handle );
  local($pty,$tty);

  $pty_handle = "proc" . ++$Next_handle;
  *PTY = $pty_handle;			# glob magic needed, apparently :-(
  $tty_handle = "proc" . ++$Next_handle;
  *TTY = $tty_handle;

  ($pty,$tty) = &getpty(PTY,TTY);
  die "Cannot find a new pty" unless defined $pty;

  local($pid) = fork;
  die "Cannot fork: $!" unless defined $pid;

  print STDERR "open_proc: mypid=$$, \$PIDS{$pty_handle} = $pid\n" if $Debug;
  $PIDS{$pty_handle} = $pid;
  $PIDS{$tty_handle} = $pid;
  $TTYS{$tty_handle} = $tty;
  $TTYS{$pty_handle} = $tty;
  $PTY_for_TTY{$tty_handle} = $pty_handle;
  $TTY_for_PTY{$pty_handle} = $tty_handle;

  unless ($pid) 
  {
    &do_tty_child( $tty_handle, $tty, @cmd );
  }

  &export_FH( (caller)[0], $pty_handle,$tty_handle );

  if ( wantarray )
  {
    print STDERR "open_proc returning: ($pty_handle,$tty_handle,$pid) \n" if $Debug;
    return ($pty_handle,$tty_handle,$pid);
  }
  else
  {
    print STDERR "open_proc returning: pty_handle=$pty_handle \n" if $Debug;
    return $pty_handle;
  }

}





<<EOF;
sub open_proc_Pty_spawn{
  my( $file, @args ) = @_;
  my( $pty_handle, $tty_handle, $pid );

  $pty = new Pty_spawn( $file, $file, @args );
  print "pty=$pty\n";

  $pid = $pty->pid;

  $pty_handle = "proc" . ++$Next_handle;
  $tty_handle = "proc" . ++$Next_handle;

  *{$pty_handle} = *{$pty->master};
  *{$tty_handle} = *{$pty->slave};
  print "slave=", $pty->slave, "\n";

  # what does this do??
  #sub gensym 
  #{
  # my ($what) = @_;
  # local *{"Pty_spawn::$what"};
  # \delete $Pty_spawn::{$what};
  #}

  $PIDS{$pty_handle} = $pid;
  $TTYS{$tty_handle} = $pty->tty;
  $PTY_for_TTY{$tty_handle} = $pty_handle;

  if ( wantarray )
  {
    print STDERR "open_proc returning: ($pty_handle,$tty_handle,$pid) \n" if $Debug;
    return ($pty_handle,$tty_handle,$pid);
  }
  else
  {
    print STDERR "open_proc returning: pty_handle=$pty_handle \n" if $Debug;
    return $pty_handle;
  }

}
EOF





sub do_tty_child{
  local( $tty_fh, $tty_name, @cmd ) = @_;
  local( *TTY ) = $tty_fh;

  print STDERR "do_tty_child: ( $tty_fh, $tty_name, @cmd )\n" if $Debug;

  # Since we have to close STDOUT/STDERR in order to get a new controlling
  # tty, we have to find some other place to put the debug data:
  local(*DEBUG_FH);
  $Debug=0;
  if( $Debug )
  {
    open(DEBUG_FH, ">Comm.pl.debug" );
    select DEBUG_FH ; $|=1; select STDOUT;
  }
  close STDIN; close STDOUT; close STDERR;


  # Try to do setsid for systems that have it:
  if ( $OS_name eq "Solaris" )
  {
    &syscall_safe(39,3); #* setsid():: syscall(39,3)
  }
  elsif ( $OS_name eq "Linux" )
  {
    syscall($SYS_setsid);
  }
  elsif ( $OS_name eq "HP-UX" )
  {
    # I hope they have Perl5, cause there's no other access to setsid(),
    # and without it, a new controlling terminal group is not set, and
    # certain things like ^c interrupt signals don't get sent.
    eval " POSIX::setsid()";	# quote it for perl4 compat
    # TIOCSCTTY doesn't seem to be necessary:
    #ioctl( STDIN, $TIOCSCTTY, 0 );
  }
  else
  {
    #???
  }


  # Try to do setpgrp for systems that use it:
  if( $OS_name eq "SunOS" ) 	# Solaris has setsid, so do that instead
  {
    # Check to see if POSIX is/can be set, which will affect which form of
    # setpgrp() to use.

    # perl5.000 "use POSIX" has the nasty habit of opening some file descriptors
    # which causes subsequent reopens of STDIN/OUT/ERR to open on the wrong
    # numbers (i.e. not 0, 1, 2 )
    if ( $] >= 5.001 )
    {
      # Note: "use POSIX" has the nasty habit of causing re-open of STDIN
      # not to use file descriptor 0, if done between closing and re-opening.
      eval "use POSIX";	# eval for perl4
      print DEBUG_FH "do_tty_child: use POSIX returned ($@)\n" if $Debug;
    }
    else
    {
      eval "somejunktoset$@";
    }

    if ( $@ )
    {
      print DEBUG_FH "do_tty_child: trying to setpgrp(0,$$) \n" if $Debug;
      setpgrp(0,$$);
    }
    else
    {
      print DEBUG_FH "do_tty_child: trying to POSIX setpgrp() \n" if $Debug;
      eval "setpgrp()";		# perl4 thinks this is a syntax error
      if ( $@ )
      {
	print DEBUG_FH "do_tty_child: POSIX setpgrp() failed\n" if $Debug;
      }
    }
  }
  elsif ( $OS_name eq "HP-UX" )
  {
    #print DEBUG_FH "do_tty_child: trying to setpgrp(0,0) \n" if $Debug;
    #setpgrp(0, 0); 	# HP dies with setpgrp(0,$$);
  }
  # note, setpgrp kills AIX process.


  if ( $OS_name eq "SunOS" )
  {
    # (TIOCNOTTY not defined on HP-UX)
    # this ioctl is necessary for "isig" to work right,
    # and otherwise "csh" freaks out and hangs:

    if (open( DEVTTY, "/dev/tty")) 
    {
      &ioctl_syscall( DEVTTY, $TIOCNOTTY, undef );
      close DEVTTY;
    }
    else
    {
    }
  }

  print DEBUG_FH "do_tty_child: reopening STDIN \n" if $Debug;

  open(STDIN,"<$tty_name");
  #open(STDIN,"<&TTY");	# fails to assign controlling tty! (Sun)

  # Something broke with SunOS and Perl5.003; the first file descriptor
  # re-assigned is no longer 0, therefore we must force it:
  local($fileno);
  if ( ($fileno = fileno(STDIN) ) != 0 )
  {
    eval "dup2($fileno, 0 )";
    if ( $@ )
    {
      print DEBUG_FH "do_tty_child: POSIX dup2($fileno, 0) failed\n" if $Debug;
    }
    close STDIN;
    open(STDIN, "<&=0" );
  }


  open(STDOUT,">&TTY");
  #open(STDOUT,">$tty_name");	# This causes weirdo problems with AIX

  open(STDERR,">&STDOUT");

  # Wait until STDERR is open to send error message :-)
  die "Should be 0:  fileno(STDIN) = " . fileno(STDIN) 
	unless fileno(STDIN) == 0;	# sanity
  die "Should be 1:  fileno(STDOUT) = " . fileno(STDOUT) 
	unless fileno(STDOUT) == 1;	# sanity
  die "Should be 2:  fileno(STDERR) = " . fileno(STDERR) 
	unless fileno(STDERR) == 2;	# sanity

  close(PTY) || print "error closing master handle:$!\n";


  print DEBUG_FH "do_tty_child: mypid=$$, execing @cmd, STDIN=$tty_name STDOUT=$tty_name \n" if $Debug;

  if ( scalar(@cmd) == 1 )
  {
    exec $cmd[0] || die "Cannot exec @cmd: $!";
  }
  elsif ( scalar(@cmd) > 1 )
  {
    exec @cmd || die "Cannot exec @cmd: $!";
  }
  else
  {
    # Oh no!
  }
}


sub getpty { ## private
  local( $_PTY, $_TTY ) = @_;
  local( $pty, $tty );
  local( @ptys );

  # Force given filehandle names explicitly into caller's package:
  $_PTY =~ s/^([^']+)$/(caller)[$[]."'".$1/e;
  $_TTY =~ s/^([^']+)$/(caller)[$[]."'".$1/e;

  if ( $OS_name ne "OSF1" && -e "/dev/ptmx" || -e "/dev/ptc" )
  {
    return &getpty_svr4($_PTY,$_TTY);
  }

  @ptys = `ls /dev/pty* 2>/dev/null`; chop @ptys;
  if ( @ptys && ! -d "/dev/ptym" )
  {
    $Have_pty = 1;
  }
  else
  {
    @ptys = `ls /dev/ptym/* 2>/dev/null`; chop @ptys;
    if ( @ptys )
    {
      # HP-UX uses ptym:
      $Have_ptym = 1;
    }
    else
    {
      die "Don't know how to allocate a pseudo-tty on your system";
    }
  }

  for $pty ( @ptys )
  {
    open($_PTY,"+>$pty") || next;
    select((select($_PTY), $| = 1)[0]);

    if ( $Have_pty )
    {
      ($tty = $pty) =~ s/pty/tty/;
    }
    elsif ( $Have_ptym )
    {
      ($tty = $pty) =~ s:/dev/ptym/pty:/dev/pty/tty:;
    }
    print STDERR "getpty: trying pty=$pty, tty=$tty\n" if $Debug;

    open($_TTY,"+>$tty") || next;
    select((select($_TTY), $| = 1)[0]);

    system "stty nl > $tty < $tty";	# might cause AIX timing problems??
    print STDERR "getpty: returning ($pty,$tty)\n" if $Debug;
    return ($pty,$tty);
  }
  return undef;
}







# I don't know if this is any more portable than the OS_type switches
# in getpty().  It has that scarey bit thing it does with $rdev.
# The basic code (thanks!) is from:  casper@fwi.uva.nl (Casper H.S. Dik)

sub getpty_svr4{
  local( $MASTER, $SLAVE ) = @_;
  local( $master, $master_fd, $slave, $rdev, @attrib );
  local( $i, $j );

  $master = "/dev/ptmx";
  $master = "/dev/ptc" if ( -e "/dev/ptc" );

  # Try a few times, in case we're competing with another process
  for ( $i = 0 ; ; $i++ )
  {
    if ( open($MASTER, "+>$master") )
    {
      last;
    }
    elsif ( $i >= 5 )
    {
      warn "Could not open $master, $!, after $i attempts";
      return undef;
    }
    sleep 1;
  }

  select((select($MASTER), $| = 1)[0]);
  $master_fd = fileno( $MASTER );

  # Perl sets close-on-exec. stupid.[Casper]
  fcntl($MASTER, 2, 0);

  #@attrib = stat($MASTER);
  @attrib = eval " stat($MASTER ) "; # otherwise, it thinks $MASTER is filename

  $rdev = $attrib[6];
  print STDERR "getpty_svr4: stat($MASTER)=(",join(",",@attrib),"), 6=$rdev\n"
	if $Debug;

  # The user might have an executable "ptsname" program:
  eval "$slave = `ptsname $master_fd 2>/dev/null`";	# trap error messages
  chop $slave;
  if ( !$slave )
  {
    print STDERR "ptsname not found, using Solaris minor numbers\n" if $Debug;
    # Solaris:
    # ptsname - not portable probably: assumes 14 bit minor numbers.
    # only a problem if it's less than 14bits, I think.  [Casper]
    print STDERR "rdev=$rdev\n" if $Debug;
    $rdev &= (1<<14) - 1;
    $slave = "/dev/pts/$rdev";
  }

  print STDERR "slave=$slave, ptsname($master_fd)=$slave\n" if $Debug;

  # Try to find "pt_chmod".  It *might* be in "/usr/lib".
  $ENV{PATH} .= ":/usr/lib" unless $ENV{PATH} =~ m!/usr/lib[^/]*!;

  # grantpt() function emulation, apparently it calls pt_chmod:
  local($cmd) = "pt_chmod $master_fd";
  print STDERR "system ($cmd)\n" if $Debug;
  system $cmd || die "pt_chmod failed";

  # unlockpt  (send STREAMs message UNLKPT) [Casper]
  $p = pack("i3p", $UNLKPT, 0, 0, $ret);

  ioctl($MASTER, $I_STR, $p );

  # open slave
  if (! -e $slave)
  {
    # if the slave pty filename is not of the form /dev/pts/XXX
    # then we might be running under SCO_SV which names the slave
    # ptys /dev/ptsNNN
    # eight bits seems to be appropriate for SCO 3.2.4 because they
    # go up to /dev/pts255
    $rdev &= (1<<9) - 1;
    $slave = sprintf("/dev/pts%03d",$rdev);
    
  }
  open($SLAVE,"+>$slave") || die "could not open slave, $slave, errno=$!";

  if ( $OS_name eq "Solaris" )
  {
    # push streams modules ptem and ldterm,
    # but first remove any modules that might have been hanging around.
    local( $pop ) = pack( "p", $pop );
    ioctl( $SLAVE, $I_POP, 0 );
    ioctl( $SLAVE, $I_POP, 0 );
    ioctl( $SLAVE, $I_POP, $pop );
    #print "looked: len=", length($pop),"($pop)\n";

    #syscall($SYS_ioctl, fileno($_TTY), $I_LOOK, $pop );
    #print "looked: len=", length($pop),"($pop)\n";
    #$pop = pack( "p", $pop );
    #syscall($SYS_ioctl, fileno($_TTY), $I_LOOK, $pop );
    #print "looked: len=", length($pop),"($pop)\n";

    # $tmp needed because Solaris2.4,2.5 complains:
    # Modification of a read-only value attempted at ...
    # if you use a string literal instead, E.g.:
    ###syscall($SYS_ioctl, fileno($_TTY), $I_PUSH, "ptem" );

    local($module) = "ptem";
    ioctl($SLAVE, $I_PUSH, $module ) || die "ioctl $module failed, errno=$!";
    $module = "ldterm";
    ioctl($SLAVE, $I_PUSH, $module ) || die "ioctl $module failed, errno=$!";
    $module = "ttcompat";
    ioctl($SLAVE, $I_PUSH, $module ) || die "ioctl $module failed, errno=$!";
  }
  elsif ($OS_name eq "SCO")
  {
    # push streams modules ptem and ldterm,
    # but first remove any modules that might have been hanging around.
    local( $pop ) = pack( "p", $pop );
    ioctl( $SLAVE, $I_POP, 0 );
    ioctl( $SLAVE, $I_POP, 0 );
    ioctl( $SLAVE, $I_POP, $pop );
    #print "looked: len=", length($pop),"($pop)\n";
 
    #syscall($SYS_ioctl, fileno($_TTY), $I_LOOK, $pop );
    #print "looked: len=", length($pop),"($pop)\n";
    #$pop = pack( "p", $pop );
    #syscall($SYS_ioctl, fileno($_TTY), $I_LOOK, $pop );
    #print "looked: len=", length($pop),"($pop)\n";
 
    # $tmp needed because Solaris2.4,2.5 complains:
    # Modification of a read-only value attempted at ...
    # if you use a string literal instead, E.g.:
    ###syscall($SYS_ioctl, fileno($_TTY), $I_PUSH, "ptem" );
 
    local($module) = "ptem";
    # use "ioctl_syscall()" instead of raw "ioctl()", so Perl4 can be happy:
    &ioctl_syscall( $SLAVE, $I_PUSH, *module );
    #ioctl($SLAVE, $I_PUSH, $module ) || die "ioctl $module failed, errno=$!";
    $module = "ldterm";
    &ioctl_syscall( $SLAVE, $I_PUSH, *module );
    #ioctl($SLAVE, $I_PUSH, $module ) || die "ioctl $module failed, errno=$!";
  }

  system "stty nl < $slave > $slave";	# people generally expect nl to work

  print STDERR "getpty_svr4 returning ($master,$slave)\n" if $Debug;
  return ($master,$slave);

}


# This function scans an input stream for a pattern,
# without blocking, a la "sysread()".
#
# $timeout_time is the time (either relative to the current time, or
# absolute, ala time(2)) at which a timeout event occurs.
#
# Each pat is a regular-expression (probably enclosed in single-quotes
# in the invocation).  
#
# Patterns are scanned in the order given, so later patterns can contain
# general defaults that won't be examined unless the earlier patterns
# have failed.  Be careful of timing problems, however.  If you specify
# a very general pattern later in the list, it might match undesireably
# if a partial packet of data is received.  E.g.:
# 	expect( 10, 'login:', '.+' );
# will probably match
#	Trying 129.145....
# prematurely, since the stuff about "login:" is received in a separate 
# packet about second before the rest of the stuff:
#	Connected to myhost.
#	Escape character is '^]'.
#	
#	UNIX(r) System V Release 4.0 (myhost)
#	
#	login: 
#
#
# ^ and $ should work, respecting the current value of $*.


%Accum = ();	# shut up -w

sub expect {
  local( $fh, $endtime, @patterns ) = @_;

  local( $pattern, $accum, $match, $before, $after, $err );
  local( $rmask, $nfound, $nread, $buf );
  local( $pkg ) = caller;

  return undef unless defined $fh;
  $err = "";    # to get rid of uninitialized values warnings

  $endtime += time if $endtime < 600_000_000;
  #print STDERR "expect: fh=$fh, time=",time,", endtime=$endtime\n" if $Debug;

  # try to speed things up when the child dies
  if ( $PIDS{$fh} )
  {
    1 while ( &wait_nohang() );
    if ( !kill( 0, $PIDS{$fh} ) )
    {
      $endtime = 0;
    }
  }

  LOOP: {
    if ( $Accum{$fh} ne "" )
    {
      for $pattern ( @patterns )
      {
	if ( $Accum{$fh} =~ /$pattern/ )
	{
	  ( $match, $before, $after ) = ( $&, $`, $' );
	  $Accum{$fh} = $after;
	  last LOOP;
	}
      }
    }

    $rmask = "";
    vec($rmask,fileno( $fh ),1) = 1;
    ($nfound, $rmask) = select($rmask, undef, undef, $endtime - time);
    if ($nfound) 
    {
      #print STDERR "expect: nfound=$nfound, reading fh=$fh\n" if $Debug;
      # Oddly enough, 1000 seems to be about optimal.  10,000 is actually
      # slower, since the bottleneck seems to be the above regex match,
      # which takes much more time on longer strings, even if it's just
      # ^.*\n
      $nread = sysread($fh, $buf, 1000);
      if ($nread > 0) 
      {
	$Accum{$fh} .= $buf;
      } 
      else 
      {
	print STDERR "expect: sysread returned null, returning EOF\n" if $Debug;
	$before = $Accum{$fh};
	$Accum{$fh} = "";
	$err = "EOF";
	last LOOP;
      }
    }
    else 
    {
      $before = $Accum{$fh};
      $err = "TIMEOUT";
      last LOOP;
    }

    redo LOOP;
  }

  if ( $err eq "TIMEOUT" )
  {
    # only do this bit when we get a timeout, otherwise, I suppose there
    # is the potential of having data in the buffer after the child dies,
    # and we wouldn't want to return EOF yet.
    if ( $PIDS{$fh} )
    {
      print STDERR "expect: checking pid $PIDS{$fh} \n" if $Debug;
      1 while ( &wait_nohang() );
      if ( !kill( 0, $PIDS{$fh} ) )
      {
	$before = $Accum{$fh};
	$Accum{$fh} = "";
	$err = "EOF";
	print STDERR "expect: pid $PIDS{$fh} gone, returning EOF\n" if $Debug;
      }
    }
  }

  if ( wantarray )
  {
    return ( $match, $err, $before, $after );
  }
  else
  {
    if ( $err eq "TIMEOUT" )
    {
      #$err = "error:$err, errno:($!), after($Accum{$fh})";
      # rats! I can't set $! to any value: it only accepts valid errno's
      #$r = eval qq{ package main ; \$! = "$err" ; die "error=(\$!)" };
      #print "set err, r=$r, \@ = ($@), err=($err)\n";

      # Still doesn't work:
      eval qq{ package $pkg ; \$! = 4 };	# EINTR
    }
    elsif ( $err eq "EOF" )
    {
      eval qq{ package $pkg ; \$! = 5 };	# EIO
    }
    return $match;
  }

}




# I only seem to receive traps when I set TIOCTRAP to 0, oddly.

sub pty_select_clear_trap {
  local( $handle ) = @_;

  return if $handle eq "STDIN";

  if ( $PTY_for_TTY{$handle} )
  {
    $handle = $PTY_for_TTY{$handle};
  }

  # Init these to make -w happy:
  local( @ready ) = ();
  local( $rout, $rmask, $eout, $emask ) = ( '', '', '', '', '' );
  local( $request, $junk, $ioctl_info );

  LOOP:{
    vec( $emask, fileno( $handle ), 1 ) = 1;
    ( $nfound, $timeleft ) = select( undef, undef, $eout=$emask, 0 );
    print STDERR "pty_select_clear_trap: after select fh=$handle, nfound=$nfound\n" if $Debug;

    if ( vec( $eout, fileno( $handle ), 1 ) == 1 ) 
    {
      print STDERR "pty_select_clear_trap: exception on fh=$handle\n" if $Debug;
    }

    if ( $nfound < 1 )
    {
      if ( $nfound < 0 )
      {
	print STDERR "pty_select_clear_trap: error=$!\n" if $Debug; 
      }
      return ;
    }
    &pty_clear_trap($handle);

    redo LOOP;
  }

}


sub pty_clear_trap{
  local($handle) = @_;

  return if $handle eq "STDIN";

  if ( $PTY_for_TTY{$handle} )
  {
    $handle = $PTY_for_TTY{$handle};
  }

  print STDERR "pty_clear_trap: before ioctl TIOCREQCHECK \n" if $Debug;
  ioctl( $handle, $TIOCREQCHECK, $ioctl_info) || die "$!";


  local($request_info_t) = "IIISSII";

  ( $request, $argget, $argset, $pgrp, $pid, $errno_error, $return_value ) =
       unpack( $request_info_t, $ioctl_info );

  print STDERR "pty_clear_trap: request=$request (TIOCCLOSE=$TIOCCLOSE) \n" if $Debug;

  if ( $request == $TIOCCLOSE )
  {
  }
  else
  {
    $errno_error = $return_value = 0;
    $ioctl_info  = pack( $request_info_t, 
      $request, $argget, $argset, $pgrp, $pid, $errno_error, $return_value
       );
    ioctl( $handle, $TIOCREQSET, $ioctl_info)|| die "$!";
    #/* presumably, we trapped an open here */
  }
}


# From /usr/include/sys/ptyio.h on HP-UX:
#struct request_info {
#	int request;		/* ioctl command received (read only) */
#	int argget;		/* request to get argument trapped on
#				   on slave side (read only) */
#	int argset;		/* request to set argument to be returned
#				   to slave side (read only) */
#	short pgrp;		/* process group number of slave side process
#				   doing the operation (read only) */
#	short pid;		/* process id of slave side process 
#				   doing the operation (read only) */
#	int errno_error;	/* errno(2) error returned to be
#				   returned to slave side (read/write) */
#	int return_value;	/* return value for slave side (read/write) */
#};



# The pattern matched in STDIN isnt' sent to the proc.,
# therefore, patterns for STDIN are treated only as strings.
#
# Usage:  $match = &interact( "optional string patterns for STDIN",
#				$Proc_pty_handle, "optional regex patterns" );

sub interact {
  local( @args ) = @_;
  local( $pkg ) = caller;
  local( $pattern, @stdin_patterns, @handle_patterns );
  local( $regex_accum, $string_accum );
  local( $match, $err );
  local( $handle, @ready_handles, $ready_handle );
  local( $c, $s, $waiting );

  for $arg ( @args )
  {
    if ( $arg =~ /commutils\d+$/ )
    {
      $handle = $arg;
      next;
    }
    if ( $handle )
    {
      push( @handle_patterns, $arg );
    }
    else
    {
      push( @stdin_patterns, $arg );
    }
  }

  die "No appropriate file handle passed to interact" unless $handle;

  #&system_proc( $handle, "stty sane" );	# not my job!
  $| = 1; 					# STDOUT better be selected,							# or nothin's gunna work anyway

  if ( $Accum{$handle} ne "" )
  {
    print $Accum{$handle} ;
    $Accum{$handle}  = "";
  }

  LOOP: 
  {
    @ready_handles = &select_it(1, STDIN,$handle);

    for $ready_handle ( @ready_handles )
    {
      if ( $ready_handle eq $handle )
      {
	last unless sysread( $handle, $buf, 100000 );
	print $buf;

	#($buf,$ret) = Pty_spawn::Pty_read(fileno($handle));
	#last if $ret;
	#print "($buf)";

	$regex_accum .= $buf;

	for $pattern ( @handle_patterns )
	{
	  if ( $regex_accum =~ /$pattern/ )
	  {
	    $match = $&;
	    last LOOP;
	  }
	}
	$regex_accum =~ s/^.*[\r\n]//;
      }
      if ( $ready_handle eq "STDIN" )
      {
	last unless sysread( STDIN, $buf, 1024 );
	$string_accum .= $buf;
	$saw_something = 0;
	for $pattern ( @stdin_patterns )
	{
	  if ( $string_accum eq $pattern )
	  {
	    $match = $pattern;
	    last LOOP;
	  }
	  # if it's a string pattern, don't send to proc until we know if
	  # it's not a match:
	  $s = "";
	  for $c ( split(//, $pattern ) )
	  {
	    $s .= $c;
	    if ( $string_accum eq $s )
	    {
	      $waiting = 1;
	      $saw_something = 1;
	      last;
	    }
	  }

	}

	if ( $waiting && ! $saw_something )
	{
	  $waiting = 0;
	  print $handle $string_accum;
	}
	$string_accum = "" unless $saw_something;

	print $handle $buf unless $waiting;
      }
    }

    # try to speed things up when the child dies
    1 while ( &wait_nohang );
    if ( !kill( 0, $PIDS{$handle} ) )
    {
      print STDERR "expect: pid $PIDS{$handle} gone, returning EOF\n" if $Debug;
      #system "ps -lp $PIDS{$handle}" if $Debug;
      $err = "EOF";
      last LOOP;
    }
    else
    {
      #print STDERR "interact: handle=$handle, pid=$PIDS{$handle} still alive\n" if $Debug;
    }

    redo LOOP;
  }

  if ( wantarray )
  {
    return ( $match, $err );
  }
  else
  {
    return $match;
  }
}


# duplicates an file handle to conform to internal format

sub open_dupsockethandle { 
  local( $handle ) = @_;
  local( $new_handle ) = "socket" . ++$Next_handle;
  open($new_handle,"<&$handle");
  &export_FH( (caller)[0], $new_handle );
  return $new_handle;
}

sub open_dupprochandle { 
  local( $handle ) = @_;
  local( $new_handle ) = "proc" . ++$Next_handle;
  open($new_handle,"<&$handle");
  &export_FH( (caller)[0], $new_handle );
  return $new_handle;
}


sub wait_nohang{
  local( $pid ) = @_;
  &wait_it( $pid, "nohang" );
}

sub wait_hang{
  local( $pid ) = @_;
  &wait_it( $pid, "hang" );
}

# "Bring out your deeeeeeead"
# 
# If $pid arg is -1 or undef, reap any all waiting defunct procs
# otherwise just wait on the specific pid
#
sub wait_it{
  local( $pid, $hang ) = @_;
  local( $ret );

  $!=undef;

  if ( $hang eq "nohang" )
  {
    $hang = $WNOHANG;
  }
  elsif ( $hang eq "hang" )
  {
    $hang = 0;	# seems universal
  }
  else
  {
    die "bad arg for \$hang=$hang\n";
  }

  # hmm, can't just say if ! $pid for some reason (undef not false on solaris?)
  $pid = -1 if ( $pid == 0 || $pid == undef );

  #if ( $OS_type eq "SVR4" ) 
  if ( $OS_name eq "Solaris" )
  {
    # syscall 107 == waitsys for Solaris, which seems to be waitid?
    # int waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options);
    #define WNOHANG         0100/* non blocking form of wait    */
    #define WEXITED         0001/* wait for processes that have exited  */
    # See: <sys/procset.h> and <sys/wait.h>
    # Arguments: 7=P_ALL=idtype_t, 64=\100=WNOHANG | 1=W
    #&syscall_safe(107,7,0,0,64|1);

    $ret = waitpid($pid, $hang );
  }
  elsif ( $OS_name eq "SunOS" )
  {
    # Maybe unnecessary, since the SunOS4.x version of Perl does an implicit
    # wait4, apparently.	7==SYS_wait4, 1==WNOHANG
    #&syscall_safe(7,0,0,1,0);

    $ret = waitpid($pid, $hang );
  }
  elsif ( $OS_name eq "Linux" )
  {
    # Hmm. I wonder if this is right.  I don't know why the person
    # submitting the Linux version specified a pgrp

    $pg = getpgrp;
    $ret = waitpid(-$pg, $hang);
  }
  elsif ( $OS_name eq "HP-UX" )
  {
    # 84 is syscall wait3 for HP-UX
    # 200 is syscall waitpid for HP-UX
    #&syscall_safe(200,0,1,0) ;
    # I don't know why the native Perl waitpid() doesn't work with pgrp

    $ret = waitpid($pid, $hang );
  }
  else	
  {
    # make "waitpid" the default?
    # maybe just better not to do anything, since guesses will probably
    # cause a blocking/hanging "wait".
  }
 

  $ret = 0 if $ret < 0;

  #print STDERR "wait_nohang returning $ret\n" if $Debug;
  return $ret;
}





# Ideally, you probably want to keep the file handle name space
# encapsulated in this package.  On the other hand, it is
# also really nice not to have to provide a "Comm'whatever()" function for
# every Perl function which uses a file handle.

# The caller gives this a filehandle opened by main or some other package,
# and we give back a filehandle from this namespace that we can recognize.

sub export_FH{
  &export_sym;
}

sub export_sym{
  local( $pkg, @syms ) = @_;
  local( $eval );

  return undef unless @syms;
  $pkg = "main" if ( $pkg eq "$My_pkg" );
  for $sym ( @syms )
  {
    $eval = qq{ *$pkg'$sym = *$My_pkg'$sym };
    print STDERR "$eval\n" if $Debug;
    eval $eval;
  }
}



# "print", "sysread", etc. are no longer needed, but kept around for
# backward compatibility.

sub print{
  local($fh)=shift;
  local($ret);
  $ret = print $fh @_;
  unless ( $ret ){
    print STDERR "Error printing to fh($fh),$!\n"; }
  return $ret;
}

# Don't use syscall for AIX, it kills the process

sub syscall_safe{
  return 1 if $OS_name eq "AIX";
  #print "syscall( $_[0], $_[1], $_[2], $_[3], $_[4] ) \n" if $Debug;
  syscall( $_[0], $_[1], $_[2], $_[3], $_[4] ) ;
}


# *val must be a glob, because some ioctl() functions return a structure
# into the given variable.

sub ioctl_syscall{
  local($fh,$func,*val)=@_;
  local( $pty );

  # First try using the native "ioctl()" call.  Then if that doesn't work
  # (and it doesn't in some situations, i.e. IRIX5.3), use a "syscall()"
  # equivalent:

  print STDERR "ioctl_syscall($fh, $Ioctl_names{$func}, $val) \n" if $Debug;

  if ( !ioctl($fh, $func, $val ) )
  {
    print STDERR "ioctl_syscall: ioctl failed,resorting to syscall\n" if $Debug;
    if ( &syscall_safe( $SYS_ioctl, fileno($fh), $func, $val ) != 0 )
    {
      warn "ioctl failed, args=(@_)"; 
      warn "syscall_safe( $SYS_ioctl, ", fileno($fh), ", $func, $val )";
      warn " errno=$!";
    }
  }

  print STDERR "ioctl_syscall returning \n" if $Debug;
  return 1;
}

#sub sysread{
#  local(*FH)=shift;
#  sysread(FH, $_[0], $_[1]);
#}


# Use this when a parent forks a child to handle a request on a socket
# file handle.  The parent would like to close the file handle, but
# leave the socket alive so the child can continue to read/write it
# (the child inherited the file handle and therefore the socket) 

sub close_noshutdown{
  for (@_){
    next unless $_;
    close( $_ );
  }
}


# For backward compatibility:
sub close{
  &close_it;
}

# "close_it" exists so it won't clash with "close"
sub close_it{
  local( $fh );

  for $fh (@_)
  {
    next unless $fh;
    if ( $fh =~ /^socket/ )
    {
      print STDERR "Doing shutdown on $fh\n" if $DEBUG;
      shutdown($fh,2) ;	# must happen before close
    }
    #local( *fh ) = $fh;	# some god-aweful magic,
				# left around in case it's ever needed again
    close( $fh );
    if ( $fh =~ /^proc/ && $PIDS{$fh} )	# try not to kill the wrong thing
    {
      # Using -15, to kill the proc group.  Gotta hope that the 
      # process got itself a new pgrp when it spawned.
      kill( -15, $PIDS{$fh} );	# thump it
      for ( 1 .. 5 )
      {
	# try to reap it, but don't hang, because we want the 
	# option to SIGKILL it soon
	&wait_nohang($PIDS{$fh} );

	last unless kill( 0, $PIDS{$fh} );
	print STDERR "Waiting for $PIDS{$fh} to die\n" if $Debug;
	select( undef, undef, undef, .1); # sleep
      }

      kill( -9, $PIDS{$fh} );	# drill it!
      &wait_hang($PIDS{$fh} );
    }

    close ( $PTY_for_TTY{$fh} ) if ( $PTY_for_TTY{$fh} );
    close ( $TTY_for_PTY{$fh} ) if ( $TTY_for_PTY{$fh} );
  }
}



sub system_proc{
  local( $handle, @args ) = @_;
  print STDERR "system_proc: handle($handle), args(@args)\n" if $Debug;
  unless ( $handle =~ /^proc/ || $handle eq "STDIN" )
  {
    warn "Handle($handle) passed &${My_pkg}'system is not a proc/pty handle";
  }
  if ( $handle eq "STDIN" )
  {
    system @args;
  }
  else
  {
    unless ( fork() )
    {
      &do_tty_child( $handle, $TTYS{$handle}, @args );
      if(0)
      {
      local($tty);
      close(STDIN);close(STDOUT);
      # AIX can't seem to handle this idea:
      open(STDIN,"<&$handle" );
      open(STDOUT,">&$handle" );
      exec ( @args );
      }
      exit;
    }
    print STDERR "system_proc: waiting\n" if $Debug;
    wait;
    print STDERR "system_proc: done waiting\n" if $Debug;
  }
}



# "stty_sane" and "stty_raw" use "stty" to set the terminal modes the
# first time through, because "stty" is nice and portable.  It then caches
# the modes for subsequent calls to "ioctl()", which is nice and faster
# for switching between modes, but is a pain to make portable.

sub stty_sane{
  local( $handle ) = @_;
  local( $tmp ) = ();

  if ( $OS_name eq "HP-UX" )
  {
    $handle = $PTY_for_TTY{$handle} if  $PTY_for_TTY{$handle};
  }

  if ( $OS_name eq "AIX" )	# AIX stty hangs in weird places
  {
    $tmp = pack("C*", 13,13,8,21,0,216 );
    return &ioctl_syscall( $handle, $TIOCSETP, *tmp ); 
  }

  &stty_ioctl( $handle, "stty sane" );
  print STDERR "Done, stty_sane\n" if $Debug;
}


sub stty_raw{
  local( $handle ) = @_;
  local( $tmp);

  if ( $OS_name eq "HP-UX" )
  {
    $handle = $PTY_for_TTY{$handle} if  $PTY_for_TTY{$handle};
  }

  if ( $OS_name eq "AIX" )
  {
    $tmp = pack("C*", 13,13,8,21,0,224 );
    return &ioctl_syscall( $handle, $TIOCSETP, *tmp ); 
  }

  if ( $OS_type eq "SVR4" ) {
    &stty_ioctl( $handle, "stty raw -echo" );
  } else {
    &stty_ioctl( $handle, "stty raw -echo -icanon eol '^a'" ); 
  }
  print STDERR "Done, stty_raw\n" if $Debug;
}



sub stty_ioctl{
  local( $handle, $stty_cmd ) = @_;
  local( $tmp, $ret );

  if ( $OS_name eq "HP-UX" )
  {
    $handle = $PTY_for_TTY{$handle} if  $PTY_for_TTY{$handle};
  }
  else
  {
    # they mistakenly gave us the wrong handle
    if ( $TTY_for_PTY{$handle} )
    {
      $handle = $TTY_for_PTY{$handle};
    }
  }

  if ( ! $Stty_struct{$stty_cmd} )
  {
    $Stty_struct{$stty_cmd} = &get_ioctl_from_stty( $handle, $stty_cmd );
  }

  local($tmp) = $Stty_struct{$stty_cmd};

  if ( $OS_type eq "SVR4" || $OS_name eq "HP-UX" ) 
  {
    $ret = &ioctl_syscall( $handle, $TCSETA, *tmp );
  } 
  else 
  {
    $ret = &ioctl_syscall( $handle, $TIOCSETP, *tmp ); 
  }

  warn "stty_ioctl, ioctl failed for handle($handle), command($stty_cmd), errno=$!\n" unless $ret;

  print STDERR "Done, stty_ioctl\n" if $Debug;

}




sub get_ioctl_from_stty{
  local( $handle, $stty_cmd ) = @_;
  local( $ioctl_struct, $get_cmd, $set_cmd, $out, $ret ) = ();
  local( $pty_handle, $pid );


  # This seems to be recommended, but I don't see it doing much:
  if ( $OS_name eq "HP-UX" && $handle ne "STDIN" )
  {
    $pty_handle = $handle;
    $pty_handle = $PTY_for_TTY{$handle} if $PTY_for_TTY{$handle};
    ioctl($pty_handle, $TIOCTRAP, 0 ) || die "$!";

    #ioctl( $pty_handle, $TIOCTTY, 0 );	# causes hang of open_proc child 
					# shell regardless of value???
  }

  local( $tty ) = $TTYS{$handle};
  if ( $handle eq "STDIN" || $handle eq "STDOUT" )
  {
    $tty = "/dev/tty";
  }

  die "Don't know what tty name handle($handle) is associated with" unless $tty;
  print STDERR "get_ioctl_from_stty($handle): $stty_cmd <$tty >$tty\n" if $Debug;

  if ( $OS_name eq "HP-UX" && $handle ne "STDIN" )
  {
    # if I set TIOCTRAP to 0, I will subsequently receive traps once 
    # interact() starts, and for every "stty sane" command run in it,
    # which is backwards, as far as I understand the doc.s (which is poorly).
    # Since it seems to work either way, I'm leaving it alone.
    #&ioctl_syscall($handle, $TIOCTRAP, 0 );
    print STDERR "get_ioctl_from_stty: forking \n" if $Debug;
    local($pid);
    if ( $pid = fork )
    {
      {
	# For some reason, if we don't clear the data from the PTY,
	# anything else will hang until we do.  Also, if we then try
	# reading again.
	# I'm hoping that "expect()" will clear the pending data, and
	# do any PTY trapping necessary.

	print STDERR "get_ioctl_from_stty: waiting for pid=$pid \n" if $Debug;
	local( @r ) = &expect( $handle, 1, '' );
	print STDERR "get_ioctl_from_stty: cleared (",join(",",@r), ") from $handle \n" if $Debug;
	if ( kill( 0, $pid) )
	{
	  # be sure that the child has set the new TTY modes, and exited
	  # before we proceed to read those modes.
	  select( undef, undef, undef, .1); # sleep
	  redo;
	}
      }
      print STDERR "get_ioctl_from_stty: done waiting\n" if $Debug;
    }
    else
    {
      print STDERR "get_ioctl_from_stty: before stty\n" if $Debug;
      system "$stty_cmd <$tty >$tty";
      print STDERR "get_ioctl_from_stty: stty done\n" if $Debug;
      exit 0;
    }
  }
  else
  {
    system "$stty_cmd <$tty >$tty";
  }

  # These only return 4 bytes.  Why?
  # $p = pack("p", $ioctl_struct );
  #$ret = syscall($SYS_ioctl, fileno($handle), $TIOCGETP, $p);
  #$ret = syscall($SYS_ioctl, fileno($handle), $TCGETA, $p);

  if ( $OS_type eq "SVR4" || $OS_name eq "HP-UX" )
  {
    $get_cmd = $TCGETA;
  }
  else
  {
    # If you use TIOCGETP/SETP on HP, it will cause a hang on a PTY/TTY !!!
    # It is defined, but not longer fully supported, I guess.
    $get_cmd = $TIOCGETP;
  }

  $!=0;
  $ioctl_struct = "\0"x256;	# for perl4
  $ret = &ioctl_syscall($handle, $get_cmd, *ioctl_struct );

  warn "get_ioctl_from_stty: ioctl failed, errno=$!" unless $ret;

  return $ioctl_struct;
  #return ( $ioctl_struct, $ret );	# blows up $ioctl_struct on the stack
}




# 
# $ioctl_struct = &get_ioctl_from_stty( $handle, $stty_cmd );
# ...
# ioctl( $handle, $TCSETA, $ioctl_struct );	# note: $TCSETA isn't exported
# 
# # "dump_ioctl" is not normally used.  "sane" and "raw" modes usually
# # suffice.  You can use this to print out the tty modes ioctl_struct 
# # in a list format that you can squirrel away in your script:
# 
# $ioctl_struct = &dump_ioctl( $stty_cmd );
# 
#   E.g.:
# 
#     &dump_ioctl( "stty sane" );
#   
#   would print out something like
# 
#     stty sane = 37,38,0,5,5,173,138,59,0,3,28,127,21,4,0,0,0,0,.....
# 
#   which you could then recreate in your script as:
# 
#     $ioctl_struct = pack("C*", 37,38,0,5,5,173,138,59,0,3,28,127,21,4 );
#     ioctl( $handle, $TCSETA, $ioctl_struct );
# 


sub dump_ioctl{
  local( $handle, $stty_cmd ) = @_;
  local( $ioctl_struct, $c, $out ) = ();

  $ioctl_struct = &get_ioctl_from_stty( $handle, $stty_cmd );
  for $c ( unpack("C*", $ioctl_struct) ){
    #$out .= sprintf("0x%2.2x,", $c );
    $out .= sprintf("%d,", $c );
  }
  print "$stty_cmd = $out \n";
  # I don't know off hand how much of the returned buffer is actually
  # significant; certainly less than the full 256 bytes.
  return $ioctl_struct;
}


1;

__END__

#--------------------------------Example server---------------------------------
#
# Allows multiple client connections, and rebroadcasts data between them.

eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl" unless defined &Comm'init;

$Listen_port = 5050;
$Listen_port = $ARGV[0] if $ARGV[0];  

$SIG{'HUP'} = "my_exit";
$SIG{'INT'} = "my_exit";
$SIG{'QUIT'} = "my_exit";

$DEBUG = 1;
$|=1;

&Comm'init;

if(1)
{
  $Listen_handle = &open_listen( $Listen_port );
  die "open_listen failed on port $Listen_port" unless $Listen_handle;
}
else
{
  # This is optional; it can be useful to use a range of ports
  # if your sockets don't always release a port right away when you kill
  # a process.  However, the "setsockopt()" calls should release the ports
  # for you, so this should no longer be necessary.
  $start_port = $Listen_port;
  {
    if ( ! ( $Listen_handle = &open_listen( $Listen_port ) ) )
    {
      redo unless ( ++$Listen_port <= $start_port + 10 );
      die "open_listen failed on port $Listen_port";
    }
  }
}

print "Listening on port $Listen_port\n" if $DEBUG;

while (1)
{
  @ready_handles = &select_it(1, keys(%Client_handles), $Listen_handle );
  print "Handles ready: @ready_handles\n" if $DEBUG && @ready_handles;
  
  foreach $handle (@ready_handles)
  {  
    if ($handle eq $Listen_handle)
    { 
      ($new_handle, $rem_host) = &accept_it($handle);
      $Client_handles{$new_handle} = $rem_host;
      print "New connection from $rem_host\n" if $DEBUG;
    }
    else
    {
      if ( sysread($handle, $buf, 10000) )
      {
        $buf = $Client_handles{$handle} . ": $buf";
	$buf =~ s/[\n]*$/\n/;
        print $buf;
	# rebroadcast data to all clients:
	for $client_handle ( keys %Client_handles ) {
	  &Comm'print( $client_handle, $buf ); }
      }
      else
      {
	print "Closing handle $handle, host $rem_host\n";
        &Comm'close( $handle );
        delete $Client_handles{ $handle };
      }
    }
  }
}


sub my_exit 
{
  &Comm'close( $Listen_handle );
  print "Closing listen port\n" if $DEBUG;
  exit;
}





#--------------------------------Example client---------------------------------

# Connect to a server, and send STDIN data to it.
# Usage:  tstclient <host> <port>

eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl" unless defined &Comm'init;

$Server_port = 5050;
$Server_host = "serverhost.domain";

( $Server_host, $Server_port ) = @ARGV if @ARGV;

$SIG{'HUP'} = "my_exit";
$SIG{'INT'} = "my_exit";
$SIG{'QUIT'} = "my_exit";

$|=1;
$DEBUG = 1;

&Comm'init;

if ( ! ( $Server_handle = &open_port($Server_host, $Server_port, 5) ) )
{
  die "open_port failed on host $Server_host, port $Server_port";
}


print "Connected to host $Server_host, port $Server_port\n" if $DEBUG;

while (1)
{
  @ready_handles = &select_it(1, $Server_handle, STDIN);
  
  foreach $handle (@ready_handles)
  {  
    if ($handle eq "STDIN")
    {
      $buf = <STDIN>;
      print $Server_handle $buf || die;
    }
    else	# server
    {
      unless ( sysread($handle, $buf, 1000) )
      {
        print "Server connection broken\n";
        &my_exit;
      }
      print $buf;
    }
  }
}


sub my_exit 
{
  &Comm'close($HANDLE);
  exit;
}




#--------------------------------Example udp send ------------------------------




eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl" unless defined &Comm'init;

#$remote_addr = "129.145.43.255";	# broadcast
chop( $remote_addr = `uname -n` );

$remote_port = 5050;

( $remote_port ) = @ARGV if @ARGV == 1;
( $remote_addr, $remote_port ) = @ARGV if @ARGV == 2;

#$Debug = 1;
( $sock = &open_udp_port( "", 0, $remote_addr, $remote_port ) ) 
	|| die "open_udp_port: $!";

print "\nsending\n";
print $sock "testing with print\n" || die "send $!";

# send and send_to won't work with connected sockets under SunOS4.x
$remote_sockaddr = &sockaddr_struct( $remote_addr, $remote_port );
send( $sock, "testing with send\n", 0, $remote_sockaddr ) || die "send $!";

&send_to( $sock, "testing with send_to\n", 0, 
	$remote_addr, $remote_port ) || die "send $!";

#--------------------------------Example udp recv-------------------------------



eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl" unless defined &Comm'init;
&Comm'init;

chop( $My_addr = `uname -n` );

$My_port = 5050;

( $My_port ) = @ARGV if @ARGV == 1;
( $My_addr, $My_port ) = @ARGV if @ARGV == 2;

$SIG{'HUP'} = "my_exit";
$SIG{'INT'} = "my_exit";
$SIG{'QUIT'} = "my_exit";

#$Debug = $DEBUG = 1;
$|=1;

$Udp_handle = &open_udp_port( $My_addr, $My_port );
die "open_udp_port failed on port $My_port" unless $Udp_handle;

while (1)
{
  @ready_handles = &select_it(1, $Udp_handle );
  print "Handles ready: @ready_handles\n" if $DEBUG && @ready_handles;
  
  foreach $handle (@ready_handles)
  {  
    if ($handle eq $Udp_handle)
    { 
      if ( ( $addr, $port ) = &recv_from($handle, *buf, 10000, 0) )
      {
        print "From port=$port, addr=$addr\n";
	print $buf;
      }
      else
      {
	print "Closing handle $handle, host $rem_host\n";
        &Comm'close( $handle );
      }
    }
  }
}


sub my_exit 
{
  &Comm'close( $Udp_handle );
  print "Closing udp port\n" if $DEBUG;
  exit;
}






#-------------------- Example telnet expect, short version ---------------------
#
# This will give an idea of the usage, without becoming overwhelming.  See
# the next example for better error checking and more interesting operations.

eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl";
&Comm'init( 1.8 );

$Host = "somehost";
$User = "someuser";
$Password = "somepassword";
#$PS1 = '(\$|\%|#|Z\|) $';	# shell prompt, Z| is my weird prompt
$PS1 = '([$%#|]) $';	# shell prompt pattern
$|=1;

$proc_handle = &open_proc( "telnet $Host" ) || die "open_proc failed";

( $match, $err, $before ) = &expect( $proc_handle, 3, 'login:' );
die "failed looking for login: err($err), before($before)" unless $match;
print $proc_handle "$User\n";

&expect( $proc_handle, 3, 'word:' ) || die "Didn't get a password prompt";
print $proc_handle "$Password\n";

&expect( $proc_handle, 10, $PS1 ) || die "no shell prompt";

print $proc_handle "who\n";	# do something, anything
{
  # Now, show the results of the above command:
  ( $match, $err, $before, $after ) = &expect( $proc_handle, 5, $PS1 );
  redo unless $match;
  print $before;
  die "err=$err, quitting\n" if ( $err eq "EOF" );
}
print $proc_handle "\n";		# give us another shell prompt, please

&stty_raw(STDIN);
&interact( $proc_handle );
print "Exited interact()\n";
&stty_sane(STDIN);
&close_it( $proc_handle );







#--------------------------- Example telnet expect -----------------------------

eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl";

&Comm'init( 1.8 );

$Program = "telnet";
#$Program = "/usr/ucb/rlogin -l qwerty";   # try this to test login recovery
$Host = "somehost";
$User = "someuser";
$Password = "somepassword";
$Shell_prompt = '(\$|\%|#|Z\|) $';	# Z| is my weird prompt

$|=1;

( $Proc_pty_handle, $Proc_tty_handle, $pid ) = &open_proc( "$Program $Host");
die "open_proc failed" unless $Proc_pty_handle;

{
  ( $match, $err, $before, $after ) = 
	&expect( $Proc_pty_handle, 3, 'login:', 'word:' );

  &print_clean( "err=($err), match=($match), before=($before), after=($after)");

  if ( defined $match )	    # Remember, "if($match)" fails if "$match = '0'" .
  {
    if ( $match eq 'login:' )
    {
      print "got a login: $match\n";
      print $Proc_pty_handle "$User\n";
    }
    else
    {
      print "Oops, got a password prompt or something instead of a login\n";
      print $Proc_pty_handle "\n";		# try to get a login prompt
      sleep 5;
      redo;
    }
  }
  else
  {
    print "exiting on err($err)\n";
    exit;
  }
}

( $match, $err, $before ) = &expect( $Proc_pty_handle, 3, 'word:' );
die "failed looking for password:$err, before=$before" unless $match;

print $Proc_pty_handle "$Password\n";

print "waiting for a shell prompt\n";

&expect( $Proc_pty_handle, 10, '[\0-\377]+' . $Shell_prompt ) || 
	die "no shell prompt";
print "got it\n";

print $Proc_pty_handle "ps\n";

{
  # A little tricky regex note:  if you want to a line at a time, and
  # not miss any newlines, use:
  # ( $m, $err ) = &expect($Proc_pty_handle, 5, '.*\n' );

  # Note: a pattern of '.+' will fail finally, because the last shell prompt
  # won't be terminated with a newline.  Use '[\s\S]+' instead:

  ( $match, $err, $before, $after ) = &expect( $Proc_pty_handle, 5, '[\s\S]+' );

  # Another way to do this would be to expect on the $Shell_prompt, and
  # keep printing out $before until $match hits.

  &print_clean( "getting ps info, ($err)($before)($after)($match)" );

  die "err=$err, quitting\n" if ( $err eq "EOF" );

  redo unless $match =~ /$Shell_prompt/;
}


print   "You are now connected to the telnet process\n",
	"Enter ESC-1 for 'pwd' or ^C to break out\n",
	"type 'date' to trigger the date scanner\n";

print $Proc_pty_handle "\n";		# give us another shell prompt, please

&stty_raw(STDIN);

LOOP: {
  ( $match, $err ) = &interact(
	"\003", "\0331",  # don't use '\003' or string match will see "\ 0 0 3"
	  $Proc_pty_handle, '.*199\d',
	);

  if ( $err )
  {
    print "Aborting, err($err)\n";
    last;
  }

  if ( $match eq "\003" )
  {
    print "Got control-C\n";
    last;
  }

  if ( $match eq "\0331" )
  {
    #print "Got F1, sending 'pwd'\n";
    print $Proc_pty_handle "pwd\n";
  }

  if ( $match =~ /199\d/ )
  {
    # Suck the time info from the output from "date"
    $match =~ /\d+:\d+:\d+/;
    select( undef, undef, undef, .3 );	# let active shells like zsh catch up
    print $Proc_pty_handle "banner $&\n";
  }

  redo LOOP;
}

&stty_sane(STDIN);

print "sending ^] to telnet...\n";
print $Proc_pty_handle "\035";

( $match, $err, $before, $after ) = &expect( $Proc_pty_handle, 5, 'telnet>' ) ;

die "didn't get a telnet> prompt, err($err) before($before)" unless $match;

print $Proc_pty_handle "quit\n";

{
  ( $match, $err ) = &expect( $Proc_pty_handle, 5, '.+' );
  &print_clean( "waiting for child death, err($err), match($match)\n" );
  die "got EOF, quitting\n" if ( $err eq "EOF" );
  redo;
}


exit 0;

sub print_clean{
  local( $s ) = @_;
  $s =~ s/\n/\\n/g;	# replace real \n with fake \n to clean up the output
  $s =~ s/\r/\\r/g;
  $s =~ s/[\0-\037]/sprintf('\%3.3o', ord($&) )/ge;
  print "$s\n";
}




#--------------------------- Example /bin/sh expect -----------------------------
# This is a useful test in addition to the telnet test because having the 
# "telnet" process between you and the remote shell can mask terminal modes
# problems.

eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl";
&Comm'init( 1.8 );
#$Debug=1;
$|=1;

( $Proc_pty_handle, $Proc_tty_handle, $pid ) = &open_proc( "/bin/sh" );
die "open_proc failed" unless $Proc_pty_handle;

&stty_sane($Proc_tty_handle);	# use $Proc_pty_handle for HP
&stty_raw(STDIN);
print   "You are now connected to the shell process, ^C to break out\n";
LOOP: {
  ( $match, $err ) = &interact( "\003", $Proc_pty_handle );
  if ( $err ) { print "Aborting, err($err)\n"; last; }
  if ( $match eq "\003" ) { print "Got control-C\n"; last; }
  redo LOOP;
}
&stty_sane(STDIN);
print "Disconnected\n";



#-------------------- Example foreign file handle expect ---------------------
#
# This will give an idea of the usage, without becoming overwhelming.  See
# the next example for better error checking and more interesting operations.

eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
& eval 'exec perl -S $0 $argv:q'
if 0;

require "Comm.pl";
&Comm'init( 1.8 );
use IPC::Open3;

$|=1;
open3( WTR, RDR, ERR, "/bin/sh" ) || die "open3 failed";
select(WTR);$|=1;select(STDOUT);

print WTR "who\n";	# do something, anything
{
  # Now, show the results of the above command:
  ( $match, $err, $before, $after ) = &expect( *RDR, 1, '.*\n' );
  print "($match)\n";
  if ( not defined $match )
  {
    print "err=$err, breaking loop\n" if $err;
    last;
  }
  redo;
}
