#!/bin/ksh

#
# Verify root privilege
#
if [[ `/usr/ucb/whoami` != root ]]
then
    print -u2 "** System Configuration script needs to be run as root."
    exit 1
fi

#
# Defines
#
BASE=$1
CONFDIR=$2/system_config
mkdir -p $CONFDIR

#
# Commands
#
LS="/bin/ls"
RM="/bin/rm -f"
CP="/bin/cp"
CAT="/bin/cat"
HW="unknown"

#
# System config settings.
#
ARCH=""
HOST=`uname -n`
OS=""
OSRL=""
PLATFORM=""

#
# System & Statistics Utilities
#
FORMAT=format
IFCONFIG=ifconfig
IPCS=ipcs
ISALIST=isalist
ISAINFO=isainfo
LUXADM=luxadm
METASTAT=metastat
MOUNT=mount
MPSTAT=mpstat
NDD=$BASE/scripts/ndd.ksh
PRTCONF=prtconf
PRTDIAG="/usr/platform/`uname -m`/sbin/prtdiag"
SHOWREV=showrev
SWAP=swap
UNAME=uname
VXPRINT=vxprint

##############################################################################
# Functions
##############################################################################

SetSysConfig()
{
    HW=`$BASE/scripts/syshw.sh`
    if [ "$HW" != "SPARC" -a "$HW" != "Xeon" -a "$HW" != "Opteron" ]; then
        print -u2 "** Unsupported Hardware ($HW)."
        echo "This script expects 'SPARC', 'Xeon' or 'Opteron' CPUs"
        exit 1
    fi
    OS=`uname -s`
    OSRL=`uname -r`
    OSMN=`uname -m`
    if [ "$HW" = "SPARC" ]; then
        PLATFORM=`${PRTDIAG} | grep "System Configuration:"`
        PLATFORM=${PLATFORM##*sun4u }
    fi

    typeset tmpFile="/tmp/arch.$$"
    typeset chip=""

    if [ "$HW" = "Xeon" ]; then
        ARCH="Pentium4"
        $RM $tmpFile
        return
    fi

    if [ "$HW" = "Opteron" ]; then
        ARCH="Opteron"
        $RM $tmpFile
        return
    fi

    ${PRTDIAG} | egrep "[CS]-|V240" > $tmpFile

	# Check for US-IV
	chip=`grep "[CS]-IV[ )\t]" $tmpFile`
	if [[ -n $chip  ]]
	then
		ARCH="US-IV"
		$RM $tmpFile
		return
	fi

	# Check for US-IIIi - special case for V240
    	if test `grep -c V240 $tmpFile` -ge 1
	then
		chip=`head -1 $tmpFile`
	else
		chip=`grep "[CS]-IIIi[ )\t]" $tmpFile`
	fi

	if [[ -n $chip  ]]
	then
		ARCH="US-IIIi"
		$RM $tmpFile
		return
	fi

	# Check for US-III+
	chip=`grep "[CS]-III+[ )\t]" $tmpFile`
	if [[ -n $chip  ]]
	then
		ARCH="US-III+"
		$RM $tmpFile
		return
	fi

	# Check for US-III
	chip=`grep "[CS]-III[ )\t]" $tmpFile`
	if [[ -n $chip ]]
	then
		ARCH="US-III"
		$RM $tmpFile
		return
	fi

	# Check for US-IIe
	chip=`grep "[CS]-IIe[ )\t]" $tmpFile`
	if [[ -n $chip ]]
	then
		ARCH="US-IIe"
		$RM $tmpFile
		return
	fi

	# Check for US-IIi
	chip=`grep "[CS]-IIi[ )\t]" $tmpFile`
	if [[ -n $chip ]]
	then
		ARCH="US-IIi"
		$RM $tmpFile
		return
	fi

	# Check for US-II
	chip=`grep "[CS]-II[ )\t]" $tmpFile`
	if [[ -n $chip ]]
	then
		ARCH="US-II"
		$RM $tmpFile
		return
	fi

	# Unknown architecture
	print "Warning: Unsupported chip architecture"
	ARCH="Unsupported"
	$RM $tmpFile
}


DisplaySysConfig()
{
    print "\n\nSystem configs"
    print "    Host Name:\t\t$HOST"
    print "    Platform:\t\t$PLATFORM"
    print "    Chip Arch:\t\t$ARCH"
    print "    OS:\t\t\t$OS $OSRL"
}


Conf()
{
    typeset cmd="$1"
    typeset out="$CONFDIR/$2"
    typeset doc="$3"
    typeset bkg="$4"
    typeset pid=""

    if [[ $doc -eq 1 ]]
    then
	print "# $cmd (`date '+%m/%d/%y %H:%M:%S'`)" >> $out
	print "# $OS $OSRL\n" >> $out
    fi

    if [[ $bkg -eq 1 ]]
    then
	$cmd >> $out 2>&1 &
	return
    fi

    $cmd >> $out 2>&1
}


GetConfig()
{
    print "\nProbing system configuration.  Please wait... might take a while\n"
    $CP /etc/release /var/adm/messages /etc/system /etc/hosts \
	/etc/vfstab $CONFDIR
    Conf "$PRTDIAG" prtdiag.out 1 1
    Conf "$UNAME -a" uname.out 1 1
    Conf "$ISALIST" isalist.out 1 1
    Conf "$ISAINFO -v" isainfo.out 1 1
    Conf "$SWAP -l" swap.out 1 1
    Conf "$IPCS -a" ipcs.out 1 1
    Conf "$MOUNT -v" mount.out 1 1
    Conf "$IFCONFIG -a" ifconfig.out 1 1
    Conf "$PRTCONF -v" prtconf.out 1 1
    Conf "$SHOWREV -p" patches.out 1 1
    Conf "$NDD" ndd.out 1 1

    wait $!

    if [[ -a /usr/sbin/$VXPRINT ]]
    then
	Conf "$VXPRINT" vxprint.out 1 1
    fi

    if [[ -a /usr/sbin/$METASTAT ]]
    then
	Conf "$METASTAT" metastat.out 1 1
    fi
    $FORMAT <<-EOF > $CONFDIR/format.out 2>&1 &
	0
	quit
	EOF

#    if [[ -a /usr/sbin/$LUXADM ]]
#    then
#	$LUXADM probe -p > $CONFDIR/luxadm.out 2>&1
#	grep "Name:" $CONFDIR/luxadm.out |
#	while read line
#	do
#	    typeset name=`print $line | cut -f2 -d':' | nawk '{ print $1 }'`
#	    typeset cmd="$LUXADM display $name"
#	    print "\n=> $cmd" >> $CONFDIR/luxadm.out
#	    $cmd >> $CONFDIR/luxadm.out 2>&1
#	done
#    fi

    wait $!
}


##############################################################################
# Main
##############################################################################

SetSysConfig

DisplaySysConfig

GetConfig
