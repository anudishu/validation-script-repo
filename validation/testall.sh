#!/bin/bash
# All-in-One Runtime Validation Script
# Validates Python, Java, Node.js, PostgreSQL in a single script

set -uo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║         Runtime Validation Suite               ║"
echo "║  Python • Java • Node.js • PostgreSQL           ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

PASSED=0
FAILED=0

# Python Validation
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}🐍 Python Runtime Validation${NC}"
echo -e "${CYAN}======================================${NC}"
if command -v python3 >/dev/null 2>&1; then
    PY_VER=$(python3 --version 2>&1)
    echo -e "${GREEN}✓ Python3 found: $PY_VER${NC}"
    
    if command -v pip3 >/dev/null 2>&1; then
        PIP_VER=$(pip3 --version 2>&1)
        echo -e "${GREEN}✓ pip3 found: $PIP_VER${NC}"
    else
        echo -e "${RED}✗ pip3 not found${NC}"
    fi
    
    # Test Python
    if python3 -c "import sys, os, json; print('✓ Python standard library working')" 2>/dev/null; then
        echo -e "${GREEN}✓ Python standard library functional${NC}"
        echo -e "${GREEN}✓ Python validation PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Python validation FAILED${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Python3 not installed${NC}"
    echo -e "${RED}✗ Python validation FAILED${NC}"
    ((FAILED++))
fi
echo ""

# Java Validation
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}☕ Java SDK Validation${NC}"
echo -e "${CYAN}======================================${NC}"
if command -v java >/dev/null 2>&1; then
    JAVA_VER=$(java -version 2>&1 | head -n1)
    echo -e "${GREEN}✓ Java found: $JAVA_VER${NC}"
    
    if command -v javac >/dev/null 2>&1; then
        JAVAC_VER=$(javac -version 2>&1)
        echo -e "${GREEN}✓ javac found: $JAVAC_VER${NC}"
        echo -e "${GREEN}✓ Java SDK validation PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ javac not found (JDK not installed)${NC}"
        echo -e "${RED}✗ Java SDK validation FAILED${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Java not installed${NC}"
    echo -e "${RED}✗ Java SDK validation FAILED${NC}"
    ((FAILED++))
fi
echo ""

# Node.js Validation
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}🟢 Node.js Runtime Validation${NC}"
echo -e "${CYAN}======================================${NC}"
if command -v node >/dev/null 2>&1; then
    NODE_VER=$(node --version 2>&1)
    echo -e "${GREEN}✓ Node.js found: $NODE_VER${NC}"
    
    if command -v npm >/dev/null 2>&1; then
        NPM_VER=$(npm --version 2>&1)
        echo -e "${GREEN}✓ npm found: v$NPM_VER${NC}"
        echo -e "${GREEN}✓ Node.js validation PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ npm not found${NC}"
        echo -e "${RED}✗ Node.js validation FAILED${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Node.js not installed${NC}"
    echo -e "${RED}✗ Node.js validation FAILED${NC}"
    ((FAILED++))
fi
echo ""

# PostgreSQL Client Validation
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}🐘 PostgreSQL Client Validation${NC}"
echo -e "${CYAN}======================================${NC}"
if command -v psql >/dev/null 2>&1; then
    PSQL_VER=$(psql --version 2>&1)
    echo -e "${GREEN}✓ PostgreSQL client found: $PSQL_VER${NC}"
    echo -e "${GREEN}✓ PostgreSQL client validation PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ PostgreSQL client not installed${NC}"
    echo -e "${RED}✗ PostgreSQL client validation FAILED${NC}"
    ((FAILED++))
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🏁 Validation Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Passed: $PASSED${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL VALIDATIONS PASSED!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some validations failed${NC}"
    exit 1
fi