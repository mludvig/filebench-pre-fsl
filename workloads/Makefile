
all: *.f Makefile
	@mkdir -p build
	@for f in *.f ; do cat $$f |sed 's/$$Revision: //' | \
	sed 's/$$ $$Date: //'| \
	sed 's/$$ //' >build/$$f; \
	echo "Processing workload $$f"; \
	done;

clean:

clobber:

install:
	cp build/* /opt/filebench/workloads
