#!/bin/bash

APPIUM_HOST=${APPIUM_HOST:-0.0.0.0}
APPIUM_PORT=${APPIUM_PORT:-4723}
ADB_DEVICE=${ADB_DEVICE:-host.docker.internal:5555}
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
        kill "${APPIUM_PID}"
        log "INFO" "Appium server stopped"
    fi
    adb disconnect
    adb kill-server
}

# Set trap for cleanup
trap cleanup EXIT

# Ensure ADB is connected to the Android device/emulator
log "INFO" "Starting ADB over TCP..."

# Start the ADB server
adb start-server || { log "ERROR" "Failed to start ADB server"; exit 1; }

# Set ADB to listen on TCP (for connection via Docker)
log "INFO" "Listening on TCP 5555..."
adb tcpip 5555

# Retry ADB connection until the device is authorized
RETRY_COUNT=10
for i in $(seq 1 "${RETRY_COUNT}"); do
    log "INFO" "Attempt ${i} to connect to ${ADB_DEVICE}..."
    adb connect "${ADB_DEVICE}"
    ADB_STATUS=$(adb devices | grep "${ADB_DEVICE}" | awk '{print $2}')
    if [[ "${ADB_STATUS}" == "device" ]]; then
        log "INFO" "ADB device connected and authorized."
        break
    elif [[ "${ADB_STATUS}" == "unauthorized" ]]; then
        log "WARN" "Device unauthorized. Please confirm 'Allow USB Debugging' on the emulator."
        sleep 10
    fi

    if [[ ${i} -eq ${RETRY_COUNT} ]]; then
        log "ERROR" "Failed to connect to the device after ${RETRY_COUNT} attempts."
        exit 1
    fi
done

# Start Appium
appium --address "${APPIUM_HOST}" --port "${APPIUM_PORT}" &
APPIUM_PID=$!
sleep 10

# Check if Appium process is still running
if ! kill -0 "${APPIUM_PID}" 2>/dev/null; then
    log "ERROR" "Appium server failed to start. Exiting."
    exit 1
fi
log "INFO" "Appium server started"

# Check if Appium server is responsive
if ! curl -f "http://localhost:${APPIUM_PORT}/status" > /dev/null 2>&1; then
    log "ERROR" "Appium server is not responding. Exiting."
    exit 1
fi

# Wait for emulator to be ready with timeout
TIMEOUT=300
start_time=$(date +%s)
adb wait-for-device
while ! adb shell getprop sys.boot_completed | grep -m 1 "1" > /dev/null; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    if [[ ${elapsed} -ge ${TIMEOUT} ]]; then
        log "ERROR" "Timeout waiting for emulator to be ready. Exiting."
        exit 1
    fi
    log "INFO" "Waiting for emulator to be ready..."
    sleep 5
done

# Run Appium Doctor to validate environment
log "INFO" "Running Appium Doctor to validate Android environment..."
if ! appium-doctor --android; then
    log "ERROR" "Appium Doctor validation failed. Exiting."
    exit 1
fi

log "INFO" "Checking if APK is already installed..."

# Check if the application is installed
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

# Run Python tests in the virtual environment
log "INFO" "Running Python tests..."
/opt/venv/bin/pytest /app/tests --alluredir=/app/reports/allure-results

# Generate the Allure report
log "INFO" "Generating Allure Report..."
if ! /opt/allure-2.32.0/bin/allure generate /app/reports/allure-results -o /app/reports/allure-report --clean; then
    log "ERROR" "Failed to generate Allure report"
    exit 1
fi

# Finish
log "INFO" "Tests complete!"
