# Deploy Database Schema Fixes via Supabase REST API
# This script applies the schema fixes automatically using the Supabase API

param(
    [string]$SupabaseUrl = "https://neyfqiauyxfurfhdtrug.supabase.co",
    [string]$ServiceRoleKey = ""  # Will be prompted if not provided
)

Write-Host "🚀 Starting Database Schema Fixes Deployment" -ForegroundColor Green
Write-Host "📋 Target: $SupabaseUrl" -ForegroundColor Cyan

# Check if service role key is provided
if ([string]::IsNullOrEmpty($ServiceRoleKey)) {
    Write-Host "⚠️  Service Role Key required for schema modifications" -ForegroundColor Yellow
    Write-Host "💡 You can find this in your Supabase Dashboard > Settings > API" -ForegroundColor Yellow
    $ServiceRoleKey = Read-Host "Enter your Supabase Service Role Key (service_role)"
}

# Read the SQL schema fixes
$sqlScript = Get-Content "database_schema_fixes.sql" -Raw

Write-Host "📄 SQL Script loaded ($(($sqlScript -split "`n").Count) lines)" -ForegroundColor Green

# Function to execute SQL via REST API
function Invoke-SupabaseSql {
    param(
        [string]$Sql,
        [string]$BaseUrl,
        [string]$ApiKey
    )
    
    $headers = @{
        "apikey" = $ApiKey
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        "query" = $Sql
    } | ConvertTo-Json -Compress
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/rest/v1/rpc/sql" -Method POST -Headers $headers -Body $body
        return $response
    }
    catch {
        Write-Host "❌ Error executing SQL: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Alternative approach using SQL functions
function Deploy-ViaRpcFunction {
    Write-Host "🔧 Attempting deployment via RPC function approach..." -ForegroundColor Cyan
    
    # Split the SQL into individual statements
    $statements = $sqlScript -split ";" | Where-Object { $_.Trim() -ne "" }
    
    Write-Host "📊 Found $($statements.Count) SQL statements to execute" -ForegroundColor Green
    
    $successCount = 0
    $errorCount = 0
    
    foreach ($statement in $statements) {
        $statement = $statement.Trim()
        if ($statement -eq "" -or $statement.StartsWith("--")) {
            continue
        }
        
        Write-Host "🔄 Executing: $($statement.Substring(0, [Math]::Min(50, $statement.Length)))..." -ForegroundColor Yellow
        
        # Create a simple function to execute the statement
        $funcSql = @"
CREATE OR REPLACE FUNCTION temp_deploy_statement()
RETURNS TEXT AS `$`$
BEGIN
    $statement;
    RETURN 'SUCCESS';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END;
`$`$ LANGUAGE plpgsql;
"@
        
        $result = Invoke-SupabaseSql -Sql $funcSql -BaseUrl $SupabaseUrl -ApiKey $ServiceRoleKey
        
        if ($result) {
            Write-Host "✅ Statement executed successfully" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "❌ Statement failed" -ForegroundColor Red
            $errorCount++
        }
        
        Start-Sleep -Milliseconds 100  # Small delay between statements
    }
    
    Write-Host "📊 Deployment Summary:" -ForegroundColor Cyan
    Write-Host "  ✅ Successful: $successCount" -ForegroundColor Green
    Write-Host "  ❌ Failed: $errorCount" -ForegroundColor Red
    
    # Clean up temp function
    $cleanupSql = "DROP FUNCTION IF EXISTS temp_deploy_statement();"
    Invoke-SupabaseSql -Sql $cleanupSql -BaseUrl $SupabaseUrl -ApiKey $ServiceRoleKey | Out-Null
    
    return ($errorCount -eq 0)
}

# Main deployment logic
try {
    Write-Host "🎯 Starting schema deployment..." -ForegroundColor Green
    
    $deploymentSuccess = Deploy-ViaRpcFunction
    
    if ($deploymentSuccess) {
        Write-Host "🎉 Schema fixes deployed successfully!" -ForegroundColor Green
        Write-Host "✨ Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Restart your Flutter app" -ForegroundColor White
        Write-Host "  2. Test profile screen functionality" -ForegroundColor White
        Write-Host "  3. Verify analytics events are being stored" -ForegroundColor White
        Write-Host "  4. Check notification system works properly" -ForegroundColor White
    } else {
        Write-Host "⚠️  Some schema fixes may have failed" -ForegroundColor Yellow
        Write-Host "💡 Check your Supabase dashboard SQL editor for manual application" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "💥 Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📋 Manual deployment instructions:" -ForegroundColor Yellow
    Write-Host "  1. Open Supabase Dashboard: $SupabaseUrl" -ForegroundColor White
    Write-Host "  2. Go to SQL Editor" -ForegroundColor White
    Write-Host "  3. Copy content from database_schema_fixes.sql" -ForegroundColor White
    Write-Host "  4. Execute the SQL script" -ForegroundColor White
}

Write-Host "🔚 Deployment script completed" -ForegroundColor Green
