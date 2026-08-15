RELEASE=$(shell git describe --always --dirty)

all : wrpc.pdf



.PHONY : all clean

wrpc.pdf : wrpc.tex HDLdoc/*.tex
# Generate version
	bash -c "echo '\\newcommand{\\gitrevinfo}{'$(subst _,\\\\_,$(RELEASE))'}' > version.tex"
# Run twice to create TOC.
	pdflatex -dPDFSETTINGS=/prepress -dSubsetFonts=true -dEmbedAllFonts=true -dMaxSubsetPct=100 -dCompatibilityLevel=1.4 $^
	pdflatex -dPDFSETTINGS=/prepress -dSubsetFonts=true -dEmbedAllFonts=true -dMaxSubsetPct=100 -dCompatibilityLevel=1.4 $^

clean :
	rm -f *.eps *.pdf *.dat *.log *.out *.aux *.dvi *.ps *.toc version.tex
