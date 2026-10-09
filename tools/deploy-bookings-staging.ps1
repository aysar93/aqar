$ErrorActionPreference = 'Stop'
$stagingProject = 'aqar-bookings-test-20261009'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    if ((git branch --show-current).Trim() -ne 'feature/bookings') {
        throw 'Use feature/bookings for staging deployment.'
    }
    & firebase deploy --only firestore --project $stagingProject --config firebase.bookings-staging.json --non-interactive
    if ($LASTEXITCODE -ne 0) { throw 'Staging Firestore deployment failed.' }
} finally { Pop-Location }
