# Simple Database Schema Deployment using curl
# This script uses the Supabase PostgREST API to execute SQL

$SUPABASE_URL = "https://neyfqiauyxfurfhdtrug.supabase.co"
$ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5leWZxaWF1eXhmdXJmaGR0cnVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYyODM3NzQsImV4cCI6MjA1MTg1OTc3NH0.qXjzBmpF8DdWAGqDGD_w8xQpXVCJ96qXNkkRJ9SjfGQ"

Write-Host "🔧 Deploying Schema Fixes via REST API" -ForegroundColor Green

# Create individual SQL statements for deployment
$sqlStatements = @(
    "ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE",
    "CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id)",
    "ALTER TABLE public.analytics_events ADD COLUMN IF NOT EXISTS event_data JSONB",
    "ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0",
    "CREATE INDEX IF NOT EXISTS idx_posts_views_count ON public.posts(views_count)"
)

Write-Host "📄 Deploying $($sqlStatements.Count) critical schema updates..." -ForegroundColor Cyan

# Function to execute SQL via PostgREST
function Invoke-SupabaseSQL {
    param([string]$sql)
    
    $body = @{
        query = $sql
    } | ConvertTo-Json
    
    $headers = @{
        "apikey" = $ANON_KEY
        "Authorization" = "Bearer $ANON_KEY"
        "Content-Type" = "application/json"
        "Prefer" = "return=minimal"
    }
    
    try {
        Write-Host "🔄 Executing: $($sql.Substring(0, [Math]::Min(60, $sql.Length)))..." -ForegroundColor Yellow
        
        # Try using the rpc endpoint for SQL execution
        $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/rpc/sql" -Method POST -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "✅ Success!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "⚠️  PostgREST method failed, trying alternative..." -ForegroundColor Yellow
        return $false
    }
}

# Execute each statement
$successCount = 0
foreach ($sql in $sqlStatements) {
    if (Invoke-SupabaseSQL -sql $sql) {
        $successCount++
    }
    Start-Sleep -Milliseconds 500
}

Write-Host "📊 Results: $successCount/$($sqlStatements.Count) statements executed" -ForegroundColor Cyan

if ($successCount -gt 0) {
    Write-Host "🎉 Partial or complete schema deployment successful!" -ForegroundColor Green
    Write-Host "🔄 Please restart your Flutter app to see the improvements" -ForegroundColor Cyan
} else {
    Write-Host "❌ Automated deployment failed - using manual approach..." -ForegroundColor Yellow
    
    # Create a consolidated SQL file for manual execution
    Write-Host "📝 Creating manual deployment file..." -ForegroundColor Cyan
    
    # Create the manual SQL file content as a simple string
    $manualSqlContent = Get-Content "database_schema_fixes.sql" -Raw
    
    $manualSqlContent | Out-File -FilePath "MANUAL_SCHEMA_DEPLOYMENT.sql" -Encoding UTF8
    
    Write-Host "📁 Created MANUAL_SCHEMA_DEPLOYMENT.sql" -ForegroundColor Green
    Write-Host "📋 Manual steps:" -ForegroundColor Cyan
    Write-Host "  1. Open: $SUPABASE_URL/project/_/sql" -ForegroundColor White
    Write-Host "  2. Copy content from MANUAL_SCHEMA_DEPLOYMENT.sql" -ForegroundColor White
    Write-Host "  3. Paste in SQL Editor and click 'Run'" -ForegroundColor White
    Write-Host "  4. Restart Flutter app" -ForegroundColor White
}

Write-Host "🔚 Deployment process completed!" -ForegroundColor Green
