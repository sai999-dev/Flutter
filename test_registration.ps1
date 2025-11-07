# Test Registration Endpoint
# This tests the exact registration request to see what error we get

$body = @{
    email = "aaa@gmail.com"
    password = "12345678"
    agency_name = "aaa"
    phone = "532472828"
    business_name = "aaa"
    contact_name = "aaa"
    zipcodes = @("75202")
    industry = "Healthcare"
    plan_id = "ad7c81db-0455-424b-b9ed-d4a217495ab8"
    payment_method_id = "pm_test_1762451900172"
} | ConvertTo-Json

Write-Host "Testing registration endpoint..."
Write-Host "URL: http://127.0.0.1:3002/api/mobile/auth/register"
Write-Host "Body: $body"
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:3002/api/mobile/auth/register" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body `
        -UseBasicParsing
    
    Write-Host "✅ SUCCESS!"
    Write-Host "Status Code: $($response.StatusCode)"
    Write-Host "Response: $($response.Content)"
} catch {
    Write-Host "❌ ERROR!"
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
    Write-Host "Error Message: $($_.Exception.Message)"
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody"
    }
}

