# Test Backend Registration with Zipcodes
# Run this in PowerShell to test if backend handles zipcodes correctly
# Make sure your backend server is running on localhost:3000

Write-Host "🧪 Testing Backend Registration with Zipcodes" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test data
$testEmail = "zipcode_test_$(Get-Date -Format 'HHmmss')@example.com"
$testData = @{
    email = $testEmail
    password = "Test123456"
    agency_name = "Zipcode Test Agency"
    business_name = "Zipcode Test Business"
    contact_name = "Test User"
    phone = "555-1234"
    industry = "Insurance"
    plan_id = "plan_basic_10"
    zipcodes = @("75001", "75002", "75003")  # ARRAY OF STRINGS
} | ConvertTo-Json

Write-Host "📝 Test Data:" -ForegroundColor Yellow
Write-Host $testData
Write-Host ""

# Test 1: Registration
Write-Host "Test 1: Registration with Zipcodes Array" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

try {
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/mobile/auth/register" `
        -Method Post `
        -ContentType "application/json" `
        -Body $testData `
        -ErrorAction Stop

    Write-Host "✅ Registration successful!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Yellow
    Write-Host ($response | ConvertTo-Json -Depth 10)
    Write-Host ""

    # Save token for next tests
    $token = $response.token
    $agencyId = $response.agency_id

    # Verify zipcodes in response
    if ($response.user_profile.zipcodes) {
        Write-Host "✅ Zipcodes in response:" -ForegroundColor Green
        Write-Host "   Type: $($response.user_profile.zipcodes.GetType().Name)" -ForegroundColor Cyan
        Write-Host "   Count: $($response.user_profile.zipcodes.Count)" -ForegroundColor Cyan
        Write-Host "   Values: $($response.user_profile.zipcodes -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ Warning: No zipcodes in response" -ForegroundColor Yellow
    }
    Write-Host ""

    # Test 2: Get Territories
    Write-Host "Test 2: Get Territories" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor Green

    $headers = @{
        "Authorization" = "Bearer $token"
    }

    $territories = Invoke-RestMethod -Uri "http://localhost:3000/api/mobile/territories" `
        -Method Get `
        -Headers $headers `
        -ErrorAction Stop

    Write-Host "✅ Territories fetched!" -ForegroundColor Green
    Write-Host ($territories | ConvertTo-Json -Depth 10)
    Write-Host ""

    # Verify zipcodes match
    if ($territories.zipcodes -and $territories.zipcodes.Count -eq 3) {
        Write-Host "✅ Zipcodes match! Count: $($territories.zipcodes.Count)" -ForegroundColor Green
    } else {
        Write-Host "❌ Zipcodes don't match! Expected 3, got $($territories.zipcodes.Count)" -ForegroundColor Red
    }
    Write-Host ""

    # Test 3: Add Territory
    Write-Host "Test 3: Add Territory" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor Green

    $newZipcode = @{
        zipcode = "75004"
        city = "Dallas, TX"
    } | ConvertTo-Json

    $addResult = Invoke-RestMethod -Uri "http://localhost:3000/api/mobile/territories" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $newZipcode `
        -ErrorAction Stop

    Write-Host "✅ Territory added!" -ForegroundColor Green
    Write-Host ($addResult | ConvertTo-Json -Depth 10)
    Write-Host ""

    # Verify count increased
    if ($addResult.territory_count -eq 4) {
        Write-Host "✅ Territory count correct: 4" -ForegroundColor Green
    } else {
        Write-Host "❌ Territory count incorrect: $($addResult.territory_count)" -ForegroundColor Red
    }
    Write-Host ""

    # Test 4: Remove Territory
    Write-Host "Test 4: Remove Territory" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor Green

    $removeResult = Invoke-RestMethod -Uri "http://localhost:3000/api/mobile/territories/75004" `
        -Method Delete `
        -Headers $headers `
        -ErrorAction Stop

    Write-Host "✅ Territory removed!" -ForegroundColor Green
    Write-Host ($removeResult | ConvertTo-Json -Depth 10)
    Write-Host ""

    # Verify count decreased
    if ($removeResult.territory_count -eq 3) {
        Write-Host "✅ Territory count correct: 3" -ForegroundColor Green
    } else {
        Write-Host "❌ Territory count incorrect: $($removeResult.territory_count)" -ForegroundColor Red
    }
    Write-Host ""

    # Final Summary
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "✅ ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Database Verification:" -ForegroundColor Yellow
    Write-Host "Run this SQL query in Supabase to verify:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "SELECT id, email, agency_name, zipcodes, territory_count" -ForegroundColor Cyan
    Write-Host "FROM agencies" -ForegroundColor Cyan
    Write-Host "WHERE email = '$testEmail';" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Expected Result:" -ForegroundColor Yellow
    Write-Host "- zipcodes: {75001,75002,75003} (TEXT[] array)" -ForegroundColor Yellow
    Write-Host "- territory_count: 3" -ForegroundColor Yellow

} catch {
    Write-Host "❌ Test failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Make sure backend server is running on http://localhost:3000" -ForegroundColor Yellow
    Write-Host "2. Check backend console for error messages" -ForegroundColor Yellow
    Write-Host "3. Verify database has TEXT[] array type for zipcodes column" -ForegroundColor Yellow
    Write-Host "4. Run FIX_ZIPCODE_COLUMNS.sql to fix database schema" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
