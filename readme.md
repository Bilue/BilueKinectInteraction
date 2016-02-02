## Bilue Kinect Interaction
[Bilue](www.bilue.com.au) recently turned 5 years old, and we decided that we wanted to build something a little different for our staff, customers and family to interact with. 

This project contains the Processing 3 code that we used to interact with a Kinect 2 device and project on the wall. 

### Overview
The basic gist of the application is that the screen has a field of dots that all have a physical mass and velocity. Initially, these dots are all at rest.

The app reads input from the Kinect, determines where the blobs are, and inserts objects into the scene that repulse the dots. As the blobs move around, the dots try to return to their home position. 

![Demo](demo.gif)

### Dependencies
The code does reply on Processing 3, however, it wouldn't take too much to back-port to Processing 2, if required. 

The following Processing libraries are used:

* [Open Kinect for Processing](http://shiffman.net/p5/kinect/) - Used to read images from the Kinect
* [BlobDetection](http://www.v3ga.net/processing/BlobDetection/) - Used to extract blob shapes from the images
* [punktiert](https://github.com/djrkohler/punktiert) - Particle engine to manage the physics

All three of the above are downloadable using the Processing library manager.

### Running
By default, it should work out of the box on a Mac.

However, after running for 30 mins or so, the Kinect sometimes just stops sending images. Turns out there is a [bug deep in the bowels](https://github.com/OpenKinect/libfreenect2/pull/435) of libfreenect2 that seems to cause this. We attempted to build the Open Kinect for Processing library from source (with that patch included), but the Processing runtime kept complaining saying that it was an invalid `.dylib`.

This meant that we had to end up deploying on Windows 10 (using bootcamp on our Mac). To get this working, we needed to [install the libusbK driver](https://github.com/OpenKinect/libfreenect2/blob/master/README.md#windows--visual-studio). Once that was installed, the Processing code worked with no changes.

