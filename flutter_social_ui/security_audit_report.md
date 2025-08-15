# Security Audit Report
Generated: 2025-08-15 19:06:17.642178
Project: Flutter Social UI

## Summary
- Total Issues: 9
- Critical: 5
- High: 2
- Medium: 2

## Issues
### CRITICAL - lib\config\app_config.dart:5
**Type:** HARDCODED_SECRET
**Message:** Potential hardcoded secret detected
**Context:** `'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0.gKc0NEJvKwipztJyDLcGB2ScJwkh3de8-5BRKk9V6qY';`
**Evidence:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0`

### CRITICAL - lib\utils\environment.dart:10
**Type:** HARDCODED_SECRET
**Message:** Potential hardcoded secret detected
**Context:** `defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0.gKc0NEJvKwipztJyDLcGB2ScJwkh3de8-5BRKk9V6qY',`
**Evidence:** `defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0`

### CRITICAL - lib\utils\environment.dart:10
**Type:** HARDCODED_SECRET
**Message:** Potential hardcoded secret detected
**Context:** `defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0.gKc0NEJvKwipztJyDLcGB2ScJwkh3de8-5BRKk9V6qY',`
**Evidence:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNzQzNzgsImV4cCI6MjA2OTk1MDM3OH0`

### CRITICAL - lib\utils\environment.dart:16
**Type:** HARDCODED_SECRET
**Message:** Potential hardcoded secret detected
**Context:** `defaultValue: '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',`
**Evidence:** `6b5140093f6873cf4d154ca154a6f6ca5cc2aef45372fe123ede6ddd52b49585`

### CRITICAL - android/app/build.gradle.kts:9
**Type:** INSECURE_CONFIG
**Message:** Using example package name in production build

### HIGH - web/manifest.json:2
**Type:** PROD_READINESS
**Message:** Generic app name in web manifest

### MEDIUM - lib/services/error_handling_service.dart:135
**Type:** PROD_READINESS
**Message:** TODO comment found in critical file
**Context:** `// TODO: In production, send to crash reporting service`

### HIGH - pubspec.yaml:1
**Type:** DEPENDENCY
**Message:** Missing mockito dependency for testing

### MEDIUM - pubspec.yaml:1
**Type:** DEPENDENCY
**Message:** Missing integration_test dependency

