GIT_VERSION = $(shell cd $(src); git describe --dirty --long --tags)

all: doxygen latex

latex:
	latex ual-doc.tex

doxygen:
	GIT_VERSION=$(GIT_VERSION) doxygen ./doxygen-libual-config
	GIT_VERSION=$(GIT_VERSION) doxygen ./doxygen-libual-config-py

doxygen-contrib:
	GIT_VERSION=$(GIT_VERSION) doxygen ./doxygen-libual-config-contrib


clean:
	rm -rf doxy-libual*
# Latex stuff
	rm -f *.dvi *.aux *.out *.log *.backup
