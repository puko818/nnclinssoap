#!/bin/bash

# Prerequisites Check Script for nnclinssoap Container Builds
# Run this before attempting to build containers

set +e  # Don't exit on error, we want to check everything

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

echo "=========================================="
echo "  nnclinssoap Prerequisites Check"
echo "=========================================="
echo ""

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASS++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARN++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAIL++))
}

# Check 1: Container Runtime
echo "Checking container runtime..."
RUNTIME_FOUND=false
if command -v apptainer &> /dev/null; then
    VERSION=$(apptainer --version | head -n1)
    check_pass "Apptainer found: $VERSION"
    RUNTIME_FOUND=true
fi
if command -v singularity &> /dev/null; then
    VERSION=$(singularity --version | head -n1)
    if [ "$RUNTIME_FOUND" = false ]; then
        check_warn "Singularity found: $VERSION (consider upgrading to Apptainer)"
        RUNTIME_FOUND=true
    fi
fi
if command -v docker &> /dev/null; then
    VERSION=$(docker --version | head -n1)
    if [ "$RUNTIME_FOUND" = false ]; then
        check_pass "Docker found: $VERSION"
        RUNTIME_FOUND=true
    else
        check_pass "Docker also found: $VERSION (can use as alternative)"
    fi
fi
if [ "$RUNTIME_FOUND" = false ]; then
    check_fail "No container runtime found (need Apptainer, Singularity, or Docker)"
    echo "   Apptainer: https://apptainer.org/docs/admin/main/installation.html"
    echo "   Docker: https://docs.docker.com/engine/install/"
fi
echo ""

# Check 2: Disk Space
echo "Checking disk space..."
AVAILABLE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE" -ge 30 ]; then
    check_pass "Disk space: ${AVAILABLE}GB available (need ≥30GB)"
elif [ "$AVAILABLE" -ge 20 ]; then
    check_warn "Disk space: ${AVAILABLE}GB available (recommended ≥30GB)"
else
    check_fail "Disk space: ${AVAILABLE}GB available (need ≥20GB minimum)"
fi
echo ""

# Check 3: Memory
echo "Checking memory..."
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -ge 16 ]; then
    check_pass "Memory: ${TOTAL_MEM}GB total (recommended ≥16GB)"
elif [ "$TOTAL_MEM" -ge 8 ]; then
    check_warn "Memory: ${TOTAL_MEM}GB total (minimum 8GB, recommended 16GB)"
else
    check_fail "Memory: ${TOTAL_MEM}GB total (need ≥8GB minimum)"
fi
echo ""

# Check 4: CPU Cores
echo "Checking CPU cores..."
CORES=$(nproc)
if [ "$CORES" -ge 4 ]; then
    check_pass "CPU cores: $CORES (recommended ≥4)"
elif [ "$CORES" -ge 2 ]; then
    check_warn "CPU cores: $CORES (minimum 2, recommended 4+)"
else
    check_fail "CPU cores: $CORES (need ≥2 minimum)"
fi
echo ""

# Check 5: Network Access
echo "Checking network connectivity..."
NETWORK_OK=true

# CRAN
if curl -s -I --max-time 5 https://cloud.r-project.org/ | head -n1 | grep -q "200"; then
    check_pass "CRAN access: OK"
else
    check_fail "CRAN access: Failed (https://cloud.r-project.org/)"
    NETWORK_OK=false
fi

# GitHub
if curl -s -I --max-time 5 https://github.com/ | head -n1 | grep -q "200"; then
    check_pass "GitHub access: OK"
else
    check_fail "GitHub access: Failed (https://github.com/)"
    NETWORK_OK=false
fi

# Bioconductor
if curl -s -I --max-time 5 https://bioconductor.org/ | head -n1 | grep -q "200"; then
    check_pass "Bioconductor access: OK"
else
    check_fail "Bioconductor access: Failed (https://bioconductor.org/)"
    NETWORK_OK=false
fi

# Docker Hub
if curl -s -I --max-time 5 https://hub.docker.com/ | head -n1 | grep -q "200\|301"; then
    check_pass "Docker Hub access: OK"
else
    check_warn "Docker Hub access: Failed (https://hub.docker.com/) - may affect builds"
fi
echo ""

# Check 6: GitHub Token
echo "Checking GitHub API token..."
if [ -n "$GITHUB_PAT" ]; then
    # Test token
    RATE_LIMIT=$(curl -s -H "Authorization: token $GITHUB_PAT" https://api.github.com/rate_limit | grep -o '"limit":[0-9]*' | head -n1 | cut -d: -f2)
    if [ "$RATE_LIMIT" -gt 1000 ]; then
        check_pass "GITHUB_PAT set and valid (rate limit: $RATE_LIMIT/hour)"
    else
        check_warn "GITHUB_PAT set but may be invalid (rate limit: ${RATE_LIMIT:-unknown}/hour)"
    fi
else
    check_warn "GITHUB_PAT not set (recommended to avoid rate limits)"
    echo "   Set with: export GITHUB_PAT='your_token'"
    echo "   Create at: https://github.com/settings/tokens"
fi
echo ""

# Check 7: Required Files
echo "Checking repository structure..."
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$REPO_ROOT/docker/build_all_images.sh" ]; then
    check_pass "Build script found"
else
    check_fail "Build script missing: docker/build_all_images.sh"
fi

DEF_COUNT=0
for container in preprocessing analysis spatialxenium; do
    if [ -f "$REPO_ROOT/docker/$container/apptainer.def" ] || [ -f "$REPO_ROOT/docker/$container/Dockerfile" ]; then
        ((DEF_COUNT++))
    fi
done

if [ "$DEF_COUNT" -eq 3 ]; then
    check_pass "All container definitions found (3/3)"
else
    check_fail "Missing container definitions (found $DEF_COUNT/3)"
fi

if [ -f "$REPO_ROOT/tests/test_containers.sh" ]; then
    check_pass "Test script found"
else
    check_warn "Test script missing: tests/test_containers.sh"
fi
echo ""

# Check 8: Environment Variables (optional)
echo "Checking optional environment variables..."
if [ -n "$APPTAINER_CACHEDIR" ]; then
    if [ -d "$APPTAINER_CACHEDIR" ]; then
        check_pass "APPTAINER_CACHEDIR set: $APPTAINER_CACHEDIR"
    else
        check_warn "APPTAINER_CACHEDIR set but directory doesn't exist: $APPTAINER_CACHEDIR"
    fi
else
    echo "   APPTAINER_CACHEDIR not set (will use default: ~/.apptainer/cache)"
fi

if [ -n "$APPTAINER_TMPDIR" ]; then
    if [ -d "$APPTAINER_TMPDIR" ]; then
        check_pass "APPTAINER_TMPDIR set: $APPTAINER_TMPDIR"
    else
        check_warn "APPTAINER_TMPDIR set but directory doesn't exist: $APPTAINER_TMPDIR"
    fi
else
    echo "   APPTAINER_TMPDIR not set (will use default: /tmp)"
fi
echo ""

# Summary
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

# Recommendations
if [ $FAIL -eq 0 ]; then
    if [ $WARN -eq 0 ]; then
        echo -e "${GREEN}✅ All checks passed! Ready to build containers.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Build all containers: ./docker/build_all_images.sh"
        echo "  2. Or build single: ./docker/build_single.sh [preprocessing|analysis|spatialxenium]"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}⚠️  All critical checks passed, but there are warnings.${NC}"
        echo ""
        echo "Recommendations:"
        [ -z "$GITHUB_PAT" ] && echo "  • Set GITHUB_PAT to avoid rate limits: export GITHUB_PAT='your_token'"
        [ "$CORES" -lt 4 ] && echo "  • Consider using system with more CPU cores for faster builds"
        [ "$TOTAL_MEM" -lt 16 ] && echo "  • Consider requesting more memory (16GB+) if on HPC"
        echo ""
        echo "You can proceed with building, but may experience slower builds or rate limits."
        echo ""
        exit 0
    fi
else
    echo -e "${RED}❌ Some critical checks failed. Please address these issues before building.${NC}"
    echo ""
    echo "Required actions:"
    if ! command -v apptainer &> /dev/null && ! command -v singularity &> /dev/null; then
        echo "  • Install Apptainer: https://apptainer.org/docs/admin/main/installation.html"
    fi
    [ "$AVAILABLE" -lt 20 ] && echo "  • Free up disk space (need ≥20GB)"
    [ "$TOTAL_MEM" -lt 8 ] && echo "  • Use system with more memory (need ≥8GB)"
    [ "$NETWORK_OK" = false ] && echo "  • Check network connectivity and firewall settings"
    echo ""
    echo "For detailed help, see: docker/DEPENDENCIES.md"
    echo ""
    exit 1
fi
