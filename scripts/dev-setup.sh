#!/usr/bin/env bash
#
# Development Environment Setup Script for Grapple
# This script sets up a complete development environment
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Print banner
echo -e "${BLUE}"
cat << "EOF"
   ____                        __
  / ___|_ __ __ _ _ __  _ __  / /__
 | |  _| '__/ _` | '_ \| '_ \| |/ _ \
 | |_| | | | (_| | |_) | |_) | |  __/
  \____|_|  \__,_| .__/| .__/|_|\___|
                 |_|   |_|
  Development Environment Setup
EOF
echo -e "${NC}"

# Check if running from project root
if [ ! -f "mix.exs" ]; then
    error "Please run this script from the project root directory"
    exit 1
fi

info "Starting development environment setup..."
echo ""

# Check Elixir version
info "Checking Elixir installation..."
if command -v elixir &> /dev/null; then
    ELIXIR_VERSION=$(elixir --version | grep "Elixir" | awk '{print $2}')
    success "Elixir $ELIXIR_VERSION found"

    # Check if version is 1.18+
    MAJOR=$(echo $ELIXIR_VERSION | cut -d. -f1)
    MINOR=$(echo $ELIXIR_VERSION | cut -d. -f2)

    if [ "$MAJOR" -lt 1 ] || { [ "$MAJOR" -eq 1 ] && [ "$MINOR" -lt 18 ]; }; then
        error "Elixir 1.18 or later is required (found $ELIXIR_VERSION)"
        info "Please upgrade Elixir: https://elixir-lang.org/install.html"
        exit 1
    fi
else
    error "Elixir is not installed"
    info "Install Elixir: https://elixir-lang.org/install.html"
    exit 1
fi

# Check Erlang version
info "Checking Erlang/OTP installation..."
if command -v erl &> /dev/null; then
    OTP_VERSION=$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)
    success "Erlang/OTP $OTP_VERSION found"

    # Check if OTP 27+
    if [ "${OTP_VERSION//\"/}" -lt 27 ]; then
        warning "Erlang/OTP 27 or later is recommended (found $OTP_VERSION)"
    fi
else
    error "Erlang/OTP is not installed"
    exit 1
fi

# Check for git
info "Checking git installation..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    success "Git $GIT_VERSION found"
else
    error "Git is not installed"
    exit 1
fi

echo ""
info "Installing dependencies..."
mix deps.get
success "Dependencies installed"

echo ""
info "Compiling project..."
if mix compile; then
    success "Project compiled successfully"
else
    error "Compilation failed"
    exit 1
fi

echo ""
info "Running tests to verify setup..."
if mix test --max-failures 1; then
    success "Tests passed"
else
    warning "Some tests failed - this may be expected for development"
fi

echo ""
info "Setting up git hooks..."
HOOKS_DIR=".git/hooks"
if [ -d "$HOOKS_DIR" ]; then
    # Create pre-commit hook
    cat > "$HOOKS_DIR/pre-commit" << 'HOOK_EOF'
#!/bin/bash
# Pre-commit hook for Grapple

echo "Running pre-commit checks..."

# Check formatting
echo "Checking code formatting..."
if ! mix format --check-formatted 2>/dev/null; then
    echo "❌ Code is not properly formatted"
    echo "Run 'mix format' to fix formatting issues"
    exit 1
fi

# Compile with warnings as errors
echo "Checking for compilation warnings..."
if ! mix compile --warnings-as-errors 2>/dev/null; then
    echo "❌ Compilation warnings found"
    exit 1
fi

echo "✓ Pre-commit checks passed"
HOOK_EOF

    chmod +x "$HOOKS_DIR/pre-commit"
    success "Git pre-commit hook installed"
else
    warning "Git hooks directory not found - skipping hook setup"
fi

echo ""
info "Generating documentation..."
if MIX_ENV=dev mix docs 2>/dev/null; then
    success "Documentation generated in doc/"
else
    warning "Documentation generation failed - continuing anyway"
fi

echo ""
info "Running code analysis..."
if mix compile --warnings-as-errors 2>/dev/null; then
    success "No compilation warnings"
else
    warning "Some compilation warnings found"
fi

echo ""
info "Checking test coverage..."
if MIX_ENV=test mix coveralls 2>/dev/null; then
    success "Coverage report generated"
else
    warning "Coverage check skipped"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
success "Development environment setup complete!"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
info "Next steps:"
echo "  1. Start interactive shell:    ${BLUE}iex -S mix${NC}"
echo "  2. Run tests:                  ${BLUE}mix test${NC}"
echo "  3. Run with coverage:          ${BLUE}mix coveralls.html${NC}"
echo "  4. Generate docs:              ${BLUE}mix docs${NC}"
echo "  5. Run benchmarks:             ${BLUE}./scripts/run_benchmarks.sh${NC}"
echo "  6. Format code:                ${BLUE}mix format${NC}"
echo ""
info "Useful commands:"
echo "  • Start Grapple shell:         ${BLUE}Grapple.start_shell()${NC}"
echo "  • Run specific test:           ${BLUE}mix test path/to/test.exs${NC}"
echo "  • Watch tests:                 ${BLUE}mix test.watch${NC} (if installed)"
echo "  • Check formatting:            ${BLUE}mix format --check-formatted${NC}"
echo ""
info "Documentation:"
echo "  • User Guide:                  ${BLUE}GUIDE.md${NC}"
echo "  • Contributing:                ${BLUE}CONTRIBUTING.md${NC}"
echo "  • Troubleshooting:             ${BLUE}TROUBLESHOOTING.md${NC}"
echo "  • FAQ:                         ${BLUE}FAQ.md${NC}"
echo ""
info "For distributed mode setup, see: ${BLUE}README_DISTRIBUTED.md${NC}"
echo ""
success "Happy coding! 🚀"
