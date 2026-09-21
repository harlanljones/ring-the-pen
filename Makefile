PYTHON ?= python3
SOURCE_DIR ?= $(HOME)/Downloads
CWEVENT ?= cwevent
FETCH_FLAGS ?=

.PHONY: fetch verify-inputs data crosscheck test-data

# Network/disk only for absent pinned inputs; existing verified files are reused.
fetch:
	$(PYTHON) scripts/verify_inputs.py fetch --source-dir "$(SOURCE_DIR)" $(FETCH_FLAGS)

verify-inputs:
	$(PYTHON) scripts/verify_inputs.py verify

# Always offline. Run `make fetch` explicitly before the first build.
data: verify-inputs
	$(PYTHON) scripts/etl.py build --offline

# Offline cross-check; requires a prebuilt Chadwick cwevent (DEC-4 A+C).
crosscheck:
	$(PYTHON) scripts/crosscheck_cwevent.py --cwevent "$(CWEVENT)"

test-data:
	$(PYTHON) -m unittest discover -s tests -v
