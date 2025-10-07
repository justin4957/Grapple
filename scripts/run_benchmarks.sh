#!/usr/bin/env bash
# Comprehensive benchmark runner for Grapple performance testing

set -e

echo "======================================================================"
echo "Grapple Performance Benchmark Suite"
echo "======================================================================"
echo ""

# Create results directory if it doesn't exist
mkdir -p bench/results

# Get timestamp for this benchmark run
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="bench/results/${TIMESTAMP}"
mkdir -p "${RESULTS_DIR}"

echo "Results will be saved to: ${RESULTS_DIR}"
echo ""

# Compile the project
echo "Compiling project..."
mix compile
echo ""

# Run graph operations benchmarks
echo "======================================================================"
echo "1. Graph Operations Benchmarks"
echo "======================================================================"
echo ""
mix run bench/graph_operations_bench.exs
mv bench/results/graph_operations.html "${RESULTS_DIR}/graph_operations.html" 2>/dev/null || true
echo ""

# Run scalability benchmarks
echo "======================================================================"
echo "2. Scalability Benchmarks"
echo "======================================================================"
echo ""
mix run bench/scalability_bench.exs
mv bench/results/scalability_creation.html "${RESULTS_DIR}/scalability_creation.html" 2>/dev/null || true
mv bench/results/scalability_lookup.html "${RESULTS_DIR}/scalability_lookup.html" 2>/dev/null || true
mv bench/results/scalability_edges.html "${RESULTS_DIR}/scalability_edges.html" 2>/dev/null || true
echo ""

# Run memory profiling
echo "======================================================================"
echo "3. Memory Profiling"
echo "======================================================================"
echo ""
mix run bench/memory_bench.exs > "${RESULTS_DIR}/memory_report.txt"
cat "${RESULTS_DIR}/memory_report.txt"
echo ""

# Generate summary report
echo "======================================================================"
echo "Generating Summary Report"
echo "======================================================================"
echo ""

cat > "${RESULTS_DIR}/README.md" << EOF
# Grapple Benchmark Results

**Run Date:** $(date)
**Git Commit:** $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
**Branch:** $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

## Benchmark Suite

This directory contains the results of a comprehensive performance benchmark run.

### Files

- \`graph_operations.html\` - Core graph operation benchmarks
- \`scalability_creation.html\` - Node creation scalability tests
- \`scalability_lookup.html\` - Property lookup scalability tests
- \`scalability_edges.html\` - Edge creation scalability tests
- \`memory_report.txt\` - Detailed memory profiling analysis

### How to View Results

Open the HTML files in a web browser to see interactive benchmark reports with:
- Average execution times
- Memory consumption
- Standard deviations
- Performance comparisons

### Memory Analysis

See \`memory_report.txt\` for detailed memory usage analysis including:
- Per-node memory consumption
- Per-edge memory consumption
- Memory scaling projections
- Total graph memory usage

## Notes

All benchmarks were run on the same machine to ensure consistency.
Results may vary based on hardware specifications and system load.
EOF

echo "Summary report generated: ${RESULTS_DIR}/README.md"
echo ""

# Create a "latest" symlink
ln -sfn "${RESULTS_DIR}" bench/results/latest

echo "======================================================================"
echo "Benchmark suite complete!"
echo "======================================================================"
echo ""
echo "Results saved to: ${RESULTS_DIR}"
echo "View results: open ${RESULTS_DIR}/graph_operations.html"
echo ""
echo "Quick access via: bench/results/latest/"
echo ""
