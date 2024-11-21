from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy
import pytest
import requests
import time

@pytest.fixture(scope="module")
def driver():
    print("Setting up the Appium driver...")
    
    # Define the desired capabilities using AppiumOptions
    options = UiAutomator2Options()
    options.platform_name = "Android"
    options.device_name = "emulator-5554"              # Emulator's device name
    options.app = "/app/ApiDemos-debug.apk"            # Path to the APK in the container
    options.automation_name = "UiAutomator2"           # Automation engine

    # Connect to the Appium server
    print("Connecting to Appium server...")
    driver = webdriver.Remote("http://127.0.0.1:4723", options=options)
    print("Appium driver setup complete!")
    yield driver
    print("Tearing down the Appium driver...")
    driver.quit()

def test_appium_server_availability():
    """Check if the Appium server is available."""
    url = "http://127.0.0.1:4723/status"
    print(f"Checking availability of Appium server at {url}...")

    try:
        response = requests.get(url)
        print(f"Received response with status code: {response.status_code}")
        assert response.status_code == 200
        print("Appium server is available.")
    except requests.exceptions.RequestException as e:
        print(f"Failed to connect to Appium server: {e}")
        assert False, "Appium server is not available"

def test_app_installed(driver):
    """Check if the app is installed on the device."""
    print("Running test: test_app_installed")
    app_package = "io.appium.android.apis"  # Replace with your actual app package
    is_installed = driver.is_app_installed(app_package)
    print(f"Is app '{app_package}' installed? {is_installed}")
    assert is_installed

def test_open_app(driver):
    """Verify that the app opens and the main activity is displayed"""
    print("Running test: test_open_app")
    activity = driver.current_activity
    print(f"Current activity: {activity}")
    assert activity is not None

def test_click_accessibility(driver):
    """Click the Accessibility option in the main menu"""
    print("Running test: test_click_accessibility")
    try:
        # Finding the 'Accessibility' button
        accessibility_button = driver.find_element(AppiumBy.ACCESSIBILITY_ID, "Accessibility")
        accessibility_button.click()

        # Finding the 'Accessibility Node Provider' option
        node_provider = driver.find_element(AppiumBy.ACCESSIBILITY_ID, "Accessibility Node Provider")
        assert node_provider is not None
    except Exception as e:
        print(f"Test failed with error: {e}")
        raise

def test_scroll_and_click_on_text(driver):
    """Change orientation, scroll to the Text option, and click it."""
    # Navigate back to the main menu
    driver.back()
    time.sleep(1)

    # Change the orientation to landscape
    driver.orientation = "LANDSCAPE"
    time.sleep(1)  # Wait for the screen transition
    
    # Scroll to the Text option and click it
    driver.find_element(AppiumBy.ANDROID_UIAUTOMATOR,
                        'new UiScrollable(new UiSelector().scrollable(true)).scrollTextIntoView("Text")').click()

        # Change the orientation back to portrait
    driver.orientation = "PORTRAIT"
    time.sleep(1)  # Wait for the screen transition

def test_click_Add_text(driver):
    """click Add button and check the default text in the LogTextBox."""
    # Click LogTextBox to enter text
    driver.find_element(AppiumBy.ACCESSIBILITY_ID, "LogTextBox").click()

    # Click Add button to add text
    driver.find_element(AppiumBy.ACCESSIBILITY_ID, "Add").click()

    textBox = driver.find_element(AppiumBy.ID, "io.appium.android.apis:id/text")

    # Verify that the text "This is a test" appeared in the LogTextBox
    assert "This is a test" in textBox.text
