#!/bin/bash

# Test runner script for RPC functions integration tests
# This script runs the RPC functions tests and provides clear output

echo "🚀 Starting RPC Functions Integration Tests..."
echo "================================================"

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Check if test file exists
if [ ! -f "test/integration/rpc_functions_test.dart" ]; then
    echo "❌ Test file not found: test/integration/rpc_functions_test.dart"
    exit 1
fi

# Run the tests
echo "📋 Running RPC functions integration tests..."
echo ""

flutter test test/integration/rpc_functions_test.dart --reporter=expanded

# Check test result
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All RPC function tests passed!"
    echo "================================================"
    echo "✓ increment_view_count function tested"
    echo "✓ increment_likes_count function tested"
    echo "✓ decrement_likes_count function tested"
    echo "✓ get_post_interaction_status function tested"
    echo "✓ Authentication and authorization tested"
    echo "✓ Error handling tested"
    echo "✓ Integration flow tested"
    echo "================================================"
else
    echo ""
    echo "❌ Some RPC function tests failed!"
    echo "Please check the output above for details."
    exit 1
fi
