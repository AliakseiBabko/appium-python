# Appium-python
Sandbox repository for an appium-python testing framework. It is based on a custom docker image with Appium and Pytest.

# Add your tests and apk file if needed
There are sample application and sample tests in the /app folder. Replace them with your files in the /app folder.

# Update docker image with tests
make changes you need
build the image `docker build -t <your-image-name> .`
push it to your docker hub repository or run locally after modifying docker-compose file.

# Run tests in android emulator locally
`docker-compose up -d`
