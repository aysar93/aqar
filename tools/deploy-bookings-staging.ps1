param([switch]$IncludeAuth)
$ErrorActionPreference = 'Stop'
$stagingProject = 'aqar-bookings-test-20261009'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    if ((git branch --show-current).Trim() -ne 'feature/bookings') {
        throw 'Use feature/bookings for staging deployment.'
    }
    # Auth and Firestore are available on Spark. Paid services stay outside this helper.
    $deployTargets = if ($IncludeAuth) { 'auth,firestore' } else { 'firestore' }
    & firebase deploy --only $deployTargets --project $stagingProject --config firebase.bookings-staging.json --non-interactive
    if ($LASTEXITCODE -ne 0) { throw 'Staging Auth/Firestore deployment failed.' }
} finally { Pop-Location }
