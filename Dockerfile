# Start from the slim Node.js image
FROM node:20-slim

# Set environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:/opt/allure-2.32.0/bin
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Update package lists and install essential tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        openjdk-17-jdk \
        unzip \
        python3 \
        python3-pip \
        python3-venv \
        iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# Verify Python installation
RUN python3 --version && pip3 --version

# Create a virtual environment
RUN python3 -m venv $VIRTUAL_ENV

# Install Appium globally with Yarn
RUN yarn global add appium && \
    appium driver install uiautomator2 && \
    appium driver install xcuitest

# Install Appium Doctor
RUN npm install @appium/doctor --location=global

# Install Allure command-line tool
RUN curl -sL https://github.com/allure-framework/allure2/releases/download/2.32.0/allure-2.32.0.tgz | tar -xz -C /opt/ && \
    ln -s /opt/allure-2.32.0/bin/allure /usr/bin/allure

# Install Android SDK and necessary tools
RUN mkdir -p $ANDROID_HOME/cmdline-tools/latest && \
    curl -o /tmp/sdk-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-7583922_latest.zip && \
    unzip /tmp/sdk-tools.zip -d $ANDROID_HOME/cmdline-tools/latest && \
    mv $ANDROID_HOME/cmdline-tools/latest/cmdline-tools/* $ANDROID_HOME/cmdline-tools/latest/ && \
    rm -rf $ANDROID_HOME/cmdline-tools/latest/cmdline-tools && \
    rm /tmp/sdk-tools.zip && \
    yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses && \
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "platforms;android-30" \
        "tools" \
        "emulator" \
        "build-tools;34.0.0"

# Set working directory
WORKDIR /app

# Copy Python dependencies file and install in the virtual environment
COPY requirements.txt .
RUN $VIRTUAL_ENV/bin/pip install --no-cache-dir -r requirements.txt

# Copy the APK file, test directory, and entrypoint script into the container
COPY app/ /app/

# Make entrypoint.sh executable
RUN chmod +x /app/entrypoint.sh

# Expose Appium server port (4723 is the default Appium port)
EXPOSE 4723

# Set the entrypoint to the script
ENTRYPOINT ["/app/entrypoint.sh"]
