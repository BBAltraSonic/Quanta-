# Simple Schema Fix Deployment Script
$SUPABASE_URL = "https://neyfqiauyxfurfhdtrug.supabase.co"
$ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYyODM3NzQsImV4cCI6MjA1MTg1OTc3NH0.qXjzBmpF8DdWAGqDGD_w8xQpXVCJ96qXNkkRJ9SjfGQ"

Write-Host "🚀 Deploying Critical Schema Fixes" -ForegroundColor Green

# Core SQL fixes needed for the app to work
$sqlFixes = @(
    "ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE;",
    "ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS event_data JSONB;",
    "ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;"
)

Write-Host "📋 Attempting to deploy $($sqlFixes.Count) critical fixes..." -ForegroundColor Cyan

$successCount = 0

foreach ($sql in $sqlFixes) {
    Write-Host "🔄 Trying: $($sql.Substring(0, [Math]::Min(50, $sql.Length)))..." -ForegroundColor Yellow
    
    try {
        $headers = @{
            "apikey" = $ANON_KEY
            "Authorization" = "Bearer $ANON_KEY"
            "Content-Type" = "application/json"
        }
        
        $body = @{ query = $sql } | ConvertTo-Json
        
        # Try the SQL execution endpoint (this might not work with anon key)
        $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/rpc/sql" -Method POST -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "✅ Success!" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "❌ Failed: $($_.Exception.Message.Substring(0, [Math]::Min(80, $_.Exception.Message.Length)))" -ForegroundColor Red
    }
    
    Start-Sleep -Milliseconds 200
}

Write-Host ""
Write-Host "📊 Deployment Results: $successCount/$($sqlFixes.Count) fixes applied" -ForegroundColor Cyan

if ($successCount -eq 0) {
    Write-Host "⚠️  Automated deployment failed - creating manual deployment files" -ForegroundColor Yellow
    
    # Copy the comprehensive schema fixes for manual deployment
    Copy-Item "database_schema_fixes.sql" "DEPLOY_MANUALLY.sql"
    
    Write-Host "📁 Created DEPLOY_MANUALLY.sql for manual execution" -ForegroundColor Green
    Write-Host "🌐 Open Supabase Dashboard: $SUPABASE_URL/project/_/sql" -ForegroundColor Cyan
    Write-Host "📋 Copy and paste the content of DEPLOY_MANUALLY.sql into the SQL Editor" -ForegroundColor White
    Write-Host "▶️  Click RUN to apply all fixes" -ForegroundColor White
}
elseif ($successCount -gt 0) {
    Write-Host "🎉 Some fixes were applied successfully!" -ForegroundColor Green
    Write-Host "🔄 Restart your Flutter app to test improvements" -ForegroundColor Cyan
    
    if ($successCount -lt $sqlFixes.Count) {
        Write-Host "⚠️  Some fixes still need manual application - check DEPLOY_MANUALLY.sql" -ForegroundColor Yellow
        Copy-Item "database_schema_fixes.sql" "DEPLOY_MANUALLY.sql"
    }
}

Write-Host ""
Write-Host "🏁 Schema deployment process completed!" -ForegroundColor Green
Write-Host "📱 Next: Test your Flutter app at http://localhost:3000" -ForegroundColor Cyan
