#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

APPIUM_HOST=${APPIUM_HOST:-0.0.0.0}
APPIUM_PORT=${APPIUM_PORT:-4723}
APP_PACKAGE=${APP_PACKAGE:-io.appium.android.apis}

# Function for logging
log() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] ${message}"
}

# Function for cleanup
cleanup() {
    log "INFO" "Performing cleanup..."
    if [[ -n "${APPIUM_PID}" ]]; then
        kill "${APPIUM_PID}" || true
        log "INFO" "Appium server stopped"
    fi
    adb disconnect || true
    adb kill-server || true
}
# Set trap for cleanup
trap cleanup EXIT

# Start ADB server
log "INFO" "Starting ADB server..."
adb start-server || { log "ERROR" "Failed to start ADB server"; exit 1; }

# Set ADB to listen on TCP (for connection via Docker)
log "INFO" "Setting ADB to TCP mode on port 5555..."
adb tcpip 5555 || true

# Retry ADB connection until the device is authorized
log "INFO" "Attempting to connect to the ADB device..."
RETRY_COUNT=10
for i in $(seq 1 "${RETRY_COUNT}"); do
    log "INFO" "Attempt ${i} to connect to ${ADB_DEVICE}..."
    
    ADB_STATUS=$(adb devices | grep "${ADB_DEVICE}" | awk '{print $2}')
    if [[ "${ADB_STATUS}" == "device" ]]; then
        log "INFO" "ADB device connected and authorized."
        break
    elif [[ "${ADB_STATUS}" == "unauthorized" ]]; then
        log "WARN" "Device unauthorized. Please confirm 'Allow USB Debugging' on the emulator."
    elif [[ "${ADB_STATUS}" == "offline" ]]; then
        log "WARN" "Device is offline. Please check the emulator connection."
    else
        adb connect "${ADB_DEVICE}" && log "INFO" "Successfully connected to ${ADB_DEVICE}." || log "WARN" "Failed to connect. Retrying..."
    fi

    if [[ ${i} -eq ${RETRY_COUNT} ]]; then
        log "ERROR" "Failed to connect after ${RETRY_COUNT} attempts."
        exit 1
    fi
    sleep 10
done

# Ensure the device is online
log "INFO" "Waiting for ADB device to be online..."
while ! adb devices | grep -q "${ADB_DEVICE}.*device"; do
    log "WARN" "Device ${ADB_DEVICE} not online yet. Retrying..."
    sleep 5
done
log "INFO" "ADB device is now online."

# Start Appium server
log "INFO" "Starting Appium server..."
appium --address "${APPIUM_HOST}" --port "${APPIUM_PORT}" &
APPIUM_PID=$!
sleep 10

# Check if Appium process is still running
if ! kill -0 "${APPIUM_PID}" 2>/dev/null; then
    log "ERROR" "Appium server failed to start. Exiting."
    exit 1
fi
log "INFO" "Appium server started successfully."

# Run Appium Doctor to validate environment
log "INFO" "Running Appium Doctor to validate Android environment..."
if ! appium-doctor --android; then
    log "ERROR" "Appium Doctor validation failed. Exiting."
    exit 1
fi

log "INFO" "Checking if APK is already installed..."

# Check if the application is installed (for the local env)
if adb shell pm list packages | grep -q "${APP_PACKAGE}"; then
    log "INFO" "APK is already installed. Skipping installation."
else
    log "INFO" "Installing APK..."

    # Check for the APK file
    if [[ ! -f /app/ApiDemos-debug.apk ]]; then
        log "ERROR" "APK file not found at /app/ApiDemos-debug.apk"
        exit 1
    fi

    # Install the APK on the device
    adb install -r /app/ApiDemos-debug.apk || { log "ERROR" "Failed to install APK"; exit 1; }
fi

# Start the application
log "INFO" "Starting the app..."
adb shell monkey -p "${APP_PACKAGE}" -c android.intent.category.LAUNCHER 1 || {
    log "ERROR" "Failed to start the app"
    exit 1
}

# Run Python tests
log "INFO" "Running tests..."
/opt/venv/bin/pytest /app/tests --alluredir=/app/reports/allure-results

# Generate Allure report
log "INFO" "Generating Allure Report..."
/opt/allure-2.32.0/bin/allure generate /app/reports/allure-results -o /app/reports/allure-report --clean || {
    log "ERROR" "Failed to generate Allure report"
    exit 1
}

# Finish
log "INFO" "Test scenario completed!"
