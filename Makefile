# Default installation directory:
PREFIX ?= /usr/local

# Installation directories:
INSTALL_DIR := $(PREFIX)
SCRIPTS_INST_DIR := $(INSTALL_DIR)/bin
SCRIPT_NAME := vidip
SCRIPT_FILE := $(SCRIPT_NAME).sh

.DEFAULT_GOAL := help
RM ?= rm -f

# Provide information on available targets:
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install     Install $(SCRIPT_NAME) to $(SCRIPTS_INST_DIR)"
	@echo "  uninstall   Remove $(SCRIPT_NAME) from $(SCRIPTS_INST_DIR)"
	@echo "  lint        Lint $(SCRIPT_NAME) using shellcheck"
	@echo "  format      Format $(SCRIPT_NAME) using shfmt"
	@echo "  help        Show this help message"
	@echo ""
	@echo "Options:"
	@echo "  PREFIX      Installation prefix (default: /usr/local)"

# Check if shellcheck and shfmt are installed:
.PHONY: check
check:
	@command -v shellcheck >/dev/null 2>&1 || { \
		echo >&2 "*** Please install shellcheck first"; \
		exit 1; \
	}
	@command -v shfmt >/dev/null 2>&1 || { \
		echo >&2 "*** Please install shfmt first"; \
		exit 1; \
	}

# Lint script using shellcheck:
.PHONY: lint
lint: check
	@shellcheck $(SCRIPT_FILE)

# Format script using shfmt:
.PHONY: format
format: check
	@shfmt -i 2 -w $(SCRIPT_FILE)

# Check root access before installation or uninstallation:
.PHONY: check_root_access
check_root_access:
	@if [ ! -w "$(INSTALL_DIR)" ]; then \
		echo "Error: $(INSTALL_DIR) requires root access to write to."; \
		exit 1; \
	fi

# Install script to SCRIPTS_INST_DIR:
.PHONY: install
install: check_root_access
	@echo "Installing $(SCRIPTS_INST_DIR)/$(SCRIPT_NAME)"
	@install -d "$(SCRIPTS_INST_DIR)"
	@install -m 755 "$(SCRIPT_FILE)" "$(SCRIPTS_INST_DIR)/$(SCRIPT_NAME)"

# Remove script from SCRIPTS_INST_DIR:
.PHONY: uninstall
uninstall: check_root_access
	@echo "Removing $(SCRIPTS_INST_DIR)/$(SCRIPT_NAME)"
	@$(RM) "$(SCRIPTS_INST_DIR)/vidip"
