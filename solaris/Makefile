
#VERSION		= 1.41_s8_sparc
VERSION		= 1.60_s10_x86_sparc_PRERELEASE

PSTAMP:sh	= date "+%d %b %y"

.NO_PARALLEL: all
.NO_PARALLEL: pkg
.NO_PARALLEL: tarball

all: pkg/pkginfo pkg tarball pkg/prototype pkg/copyright

pkginfo: ALWAYS pkginfo.in
	sed 's/XXXXX/$(VERSION)/' pkg/pkginfo.in |\
	sed 's/YYYYY/$(PSTAMP)/' >pkg/pkginfo

pkg: ALWAYS
	mkdir -p packages/$(VERSION)
	cd pkg; pkgmk -o -d ../packages/$(VERSION)

tarball: ALWAYS
	mkdir -p tars
	cd packages/$(VERSION) ; tar cvf - * |compress > \
	../../tars/filebench$(VERSION)_pkg.tar.Z
	chmod a+r tars/filebench$(VERSION)_pkg.tar.Z

ALWAYS:
 








