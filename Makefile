.PHONY: install docs
SHELL=/bin/bash
OS := $(shell uname | tr '[:upper:]' '[:lower:]')

# for porechop on travis (or other platform with older gcc)
CXX         ?= g++

CONDA?=~/miniconda3/

# Builds a cache of binaries which can just be copied for CI
BINARIES=minimap2 miniasm racon samtools bcftools seqkit

BINCACHEDIR=bincache
$(BINCACHEDIR):
	mkdir -p $(BINCACHEDIR)

BINBUILDDIR=binbuild
$(BINBUILDDIR):
	mkdir -p $(BINBUILDDIR)

MAPVER=2.14
$(BINCACHEDIR)/minimap2: | $(BINCACHEDIR) $(BINBUILDDIR)
	@echo Making $(@F)
	if [ ! -e ${BINBUILDDIR}/minimap2-${MAPVER}.tar.bz2 ]; then \
	  cd ${BINBUILDDIR}; \
	  wget https://github.com/lh3/minimap2/releases/download/v${MAPVER}/minimap2-${MAPVER}.tar.bz2; \
	  tar -xjf minimap2-${MAPVER}.tar.bz2; \
	fi
	cd ${BINBUILDDIR}/minimap2-${MAPVER} && make
	cp ${BINBUILDDIR}/minimap2-${MAPVER}/minimap2 $@

ASMVER=0.3
$(BINCACHEDIR)/miniasm: | $(BINCACHEDIR) $(BINBUILDDIR)
	@echo Making $(@F)
	if [ ! -e ${BINBUILDDIR}/miniasm-v${ASMVER}.tar.gz ]; then \
	  cd ${BINBUILDDIR}; \
	  wget -O miniasm-v${ASMVER}.tar.gz https://github.com/lh3/miniasm/archive/v${ASMVER}.tar.gz; \
	  tar -xzf miniasm-v${ASMVER}.tar.gz; \
	fi
	cd ${BINBUILDDIR}/miniasm-${ASMVER} && make
	cp ${BINBUILDDIR}/miniasm-${ASMVER}/miniasm $@

RACONVER=1.3.1
$(BINCACHEDIR)/racon: | $(BINCACHEDIR) $(BINBUILDDIR)
	@echo Making $(@F)
	@echo GCC is $(GCC)
	if [ ! -e ${BINBUILDDIR}/racon-v${RACONVER}.tar.gz ]; then \
	  cd ${BINBUILDDIR}; \
	  wget https://github.com/isovic/racon/releases/download/${RACONVER}/racon-v${RACONVER}.tar.gz; \
	  tar -xzf racon-v${RACONVER}.tar.gz; \
	fi
	cd ${BINBUILDDIR}/racon-v${RACONVER} && mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release ..
	cd ${BINBUILDDIR}/racon-v${RACONVER}/build && make
	cp ${BINBUILDDIR}/racon-v${RACONVER}/build/bin/racon $@

SAMVER=1.8
$(BINCACHEDIR)/samtools: | $(BINCACHEDIR) $(BINBUILDDIR)
	@echo Making $(@F)
	# tar.bz is not a dependency, since that would cause it to be fetched
	#   even when installing from $(BINCACHEDIR)
	if [ ! -e ${BINBUILDDIR}/samtools-${SAMVER}.tar.bz2 ]; then \
	  cd ${BINBUILDDIR}; \
	  wget https://github.com/samtools/samtools/releases/download/${SAMVER}/samtools-${SAMVER}.tar.bz2; \
	  tar -xjf samtools-${SAMVER}.tar.bz2; \
	fi
	cd ${BINBUILDDIR}/samtools-${SAMVER} && make
	cp ${BINBUILDDIR}/samtools-${SAMVER}/samtools $@

BCFVER=1.7
$(BINCACHEDIR)/bcftools: | $(BINCACHEDIR) $(BINBUILDDIR)
	@echo Making $(@F)
	if [ ! -e ${BINBUILDDIR}/bcftools-${BCFVER}.tar.bz2 ]; then \
	  cd ${BINBUILDDIR}; \
	  wget https://github.com/samtools/bcftools/releases/download/${BCFVER}/bcftools-${BCFVER}.tar.bz2; \
	  tar -xjf bcftools-${BCFVER}.tar.bz2; \
	fi
	cd ${BINBUILDDIR}/bcftools-${BCFVER} && make
	cp ${BINBUILDDIR}/bcftools-${BCFVER}/bcftools $@

SEQKITVER=0.8.0
$(BINCACHEDIR)/seqkit: | $(BINCACHEDIR) $(BINBUILDDIR)
	@echo Making $(@F)
	if [ ! -e ${BINBUILDDIR}/seqkit_${OS}_amd64.tar.gz ]; then \
	  cd ${BINBUILDDIR}; \
	  wget https://github.com/shenwei356/seqkit/releases/download/v${SEQKITVER}/seqkit_${OS}_amd64.tar.gz; \
	  tar -xzvf seqkit_${OS}_amd64.tar.gz; \
	fi
	cp ${BINBUILDDIR}/seqkit $@	

venv: venv/bin/activate
IN_VENV=. ./venv/bin/activate

venv/bin/activate:
	test -d venv || virtualenv venv --prompt '(pomoxis) ' --python=python3
	${IN_VENV} && pip install pip --upgrade
	${IN_VENV} && pip install -r requirements.txt


install: venv | $(addprefix $(BINCACHEDIR)/, $(BINARIES))
	${IN_VENV} && POMO_BINARIES=1 python setup.py install

PYVER=3.6
IN_CONDA=. ${CONDA}/etc/profile.d/conda.sh
conda:
	${IN_CONDA} && conda remove -n pomoxis --all
	${IN_CONDA} && conda create -y -n pomoxis -c bioconda -c conda-forge porechop \
		samtools=${SAMVER} bcftools=${BCFVER} seqkit=${SEQKITVER} \
		miniasm=${ASMVER} minimap2=${MAPVER} racon=${RACONVER} \
		python=${PYVER}
	grep -v Porechop requirements.txt > conda_reqs.txt
	${IN_CONDA} && conda activate pomoxis && pip install -r conda_reqs.txt
	${IN_CONDA} && conda activate pomoxis && python setup.py install \
		--single-version-externally-managed --record=conda_install.out
	rm conda_reqs.txt


IN_BUILD=. ./pypi_build/bin/activate
pypi_build/bin/activate:
	test -d pypi_build || virtualenv pypi_build --python=python3 --prompt "(pypi) "
	${IN_BUILD} && pip install pip --upgrade
	${IN_BUILD} && pip install --upgrade pip setuptools twine wheel readme_renderer[md]


sdist: pypi_build/bin/activate
	${IN_BUILD} && python setup.py sdist


# You can set these variables from the command line.
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
PAPER         =
BUILDDIR      = _build

# Internal variables.
PAPEROPT_a4     = -D latex_paper_size=a4
PAPEROPT_letter = -D latex_paper_size=letter
ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees $(PAPEROPT_$(PAPER)) $(SPHINXOPTS) .

DOCSRC = docs

docs: venv
	${IN_VENV} && pip install sphinx sphinx_rtd_theme sphinx-argparse
	${IN_VENV} && cd $(DOCSRC) && $(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html
	@echo
	@echo "Build finished. The HTML pages are in $(DOCSRC)/$(BUILDDIR)/html."
	touch $(DOCSRC)/$(BUILDDIR)/html/.nojekyll
