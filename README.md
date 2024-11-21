# appium-python
Sandbox repository for an appuum-python testing framework. Currently it runs againt locally installed Android studio. On the next step it will be possible to run it against an android emulator in another Docker container.

# add your tests and apk file if needed
There are sample application and sample tests in the /app folder. Replace them with your files in the /app folder.

# build docker image
`docker build -t <your-image-name> .`

# run docker
`docker run -it --rm <your-image-name> .`
