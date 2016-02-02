/**
 * A Processing 3.0 program that reads input from a Microsoft Kinect 2 camera and 
 * renders a fields of dots that are interrupted by the images detected by the camera.
 * Each dot tries to return back to its "home" position.
 *
 * The physics is provided by the punktiert particle engine, and basically consists of
 * a very simple world of small dots. Each dot is linked to a home position using a spring
 * so that when they get disturbed they will try to return home. The disturbance is provided
 * by BAttraction objects (with a negative force - which means they are repulsive). For each
 * blob detected by the Kinect, an attraction object is added with a fairly large mass. This
 * forces the dots to be disturbed. As the attraction moves away, the dots will return to
 * their original position.
 *
 * Requires the following processing libraries:
 *   * Open Kinect for Processing
 *   * Blob Detection
 *   * punktiert
 */
import org.openkinect.processing.*;
import blobDetection.*;
import punktiert.math.*;
import punktiert.physics.*;

Kinect2       kinect2;
VPhysics      physics;
BAttraction[] attractions = new BAttraction[] {};
PImage[]      dotBlueImages;
PImage[]      dotWhiteImages;

int     dotsPerAxis           = 50;         // screen: how many dots are in each dimension in the matrix
boolean drawBlobs             = false;      // screen: should we draw the blobs (tunable by keyboard)
long    lastUserInteraction   = 0;          // screen: stores the last user interaction time in milliseconds

boolean kinectConnected       = false;      // kinect: assume we aren't connected
int     depthThreshold        = 1400;       // kinect: only include objects closer than this depth (tunable by keyboard)
int     maxVerticesPerBlob    = 50;         // kinect: only blobs with more than this number of vertices will be used
boolean useBlur               = false;      // kinect: blurring the image gives smoother blobs but is slow (tunable by keyboard)
float   blobDetectionScale    = 0.5;        // kinect: scaling the image before blob detection helps speed things up

float   friction              = 0.05;       // physics: how much friction each particle has
int     minDotSize            = 4;          // physics: min size of dots
int     maxDotSize            = 8;          // physics: max size of dots
int     homeSize              = 4;          // physics: size of home particle
int     homeMass              = 100;        // physics: how much the home particle weighs
int     dotMass               = 4;          // physics: how much the moving particles weigh
float   homeSpringStrength    = 0.0003f;    // physics: the force drawing the particles back to their home position

color   movingColor           = color(0x5F, 0xD3, 0xFF);
color   stillColor            = color(0xFF, 0xFF, 0xFF);

public void setup() {
  // demo mode uses the whole screen and hides the cursor
  fullScreen();
  noCursor();

  // initialise the kinect
  kinect2 = new Kinect2(this);
  kinect2.initDepth();
  kinect2.initDevice();
  if (kinect2.getNumKinects() > 0) {
    kinectConnected = true;
  }

  // build the physics world
  setupPhysics();
  
  // drawing rectangles is pretty quick (but looks ugly), however, the
  // ellipse() function is slow and has a big effect on frame rate so we
  // create a bunch of scaled images that we can use to blit onto the screen.
  // to do this, we just read the original image from a file and quickly
  // scale so that we have an array containing 1x1, 2x2, 3x3, ... images
  dotBlueImages = new PImage[maxDotSize];
  dotWhiteImages = new PImage[maxDotSize];
  for (int i = 1; i < maxDotSize; i++) {
    PImage b = loadImage("dot_blue.png");
    PImage w = loadImage("dot_white.png");
    b.resize(i, i);
    w.resize(i, i);
    dotBlueImages[i] = b;
    dotWhiteImages[i] = w;
  }
}

/**
 * Sets up an array of dots that are evenly distributed across the world.
 * Add a spring for each dot that will keep dragging it back to the same
 * spot after it has been moved
 */
private void setupPhysics() {
  // create the physics world and set an initial friction
  physics = new VPhysics();
  physics.setfriction(friction);
  
  // calculate the gaps between each dot vertically and horizontally
  float xgap = width / dotsPerAxis;
  float ygap = height / dotsPerAxis;
  for (int x = 0; x < dotsPerAxis; x++) {
    for (int y = 0; y < dotsPerAxis; y++) {
      // this is the home position of the dot
      Vec homePos    = new Vec(x*xgap + (xgap/2), y*ygap + (ygap*1.5));
      
      // create a "virtual" particle that isn't added to the physics engine
      // as a particle, but is used as an anchor point for the spring. note
      // that it needs to be locked into space, otherwise the spring will 
      // gradually move the home location.
      VParticle home = new VParticle(homePos, homeMass, homeSize);
      home.lock();
      
      // create the actual dot
      VParticle dot  = new VParticle(homePos, dotMass, random(minDotSize, maxDotSize));

      // when the dots get repulsed away from the attractor, they might collide with each
      // other. adding collision behaviour makes this interaction much more organic and
      // natural
      dot.addBehavior(new BCollision());
      
      // add dot to world, and associate a spring between the dot and the home location
      physics.addParticle(dot);
      physics.addSpring(new VSpringRange(home, dot, 0, 0, homeSpringStrength));
    }
  }
}


public void draw() {
  // start with a fresh background
  background(0);
  
  // we only want to do blob detection if the kinect is connected
  if (kinectConnected) {
    // create a black/white image that is constrained to the supplied depth 
    DepthFilter depthFilter = new DepthFilter(depthThreshold);
    PImage filteredImage = depthFilter.filteredImage(kinect2.getRawDepth(), kinect2.depthWidth, kinect2.depthHeight);
    
    // create a blob detector. by scaling the inbound image before detecting, we get a 
    // pretty good performance boost without losing much fidelity. So, we pass in the
    // scaled dimensions of the image that it should search. We also pass in a threshold
    // for the size of the blobs... if this number is too small, we end up with hundreds 
    // of really small blobs (due to image noise being picked up as blobs).
    Detector detector = new Detector((int)(filteredImage.width * blobDetectionScale), (int)(filteredImage.height * blobDetectionScale), maxVerticesPerBlob);
    detector.detectBlobs(filteredImage); 
    
    // if blobs are detected, then we know there is something out there. This is used
    // later to draw some random noise in case there is nothing in front of the kinect
    if (detector.blobs.size() > 0) {
      lastUserInteraction = System.currentTimeMillis();
    }
    
    // should we actually draw the blobs?
    if (drawBlobs) {
      detector.drawBlobs(movingColor);
    }

    // now, we insert the detected blobs into the physics world
    injectAttractions(detector.makePunktiertAttractions());
  }
  
  // if not much has gone on, then we add random attractors to keep things a bit lively
  if (System.currentTimeMillis() - lastUserInteraction > 1000) {
    injectAttractions(new BAttraction[] {
     new BAttraction(new Vec(random(0, width), random(0, height)), 250, -0.5f)
    });
  }

  // update the physics world based on the current state
  physics.update();

  // now draw the actual dots 
  for (VParticle p : physics.particles) {
    Vec velocity = p.getVelocity();
    // based on the size of the dot and whether it is moving, we grab the 
    // previously resized images and draw them to the screen. Note that
    // if we wait for velocity to get to zero, it takes too long. As long 
    // as they're moving really slowly, that is close enough.
    int radius = Math.min((int)p.getRadius(), maxDotSize-1);
    if (velocity.x < 0.005 && velocity.y < 0.005) {
      image(dotBlueImages[radius], p.x, p.y);
    }
    else {
      image(dotWhiteImages[radius], p.x, p.y);
    }
  }
}

/**
 * Removes any previously added attractors, and adds the new ones
 */
private void injectAttractions(BAttraction[] newAttractions) {
  physics.behaviors.clear();
  for (BAttraction attraction : newAttractions) {
    physics.addBehavior(attraction);
  }
}  

public void keyPressed() {
  if (keyCode == UP) {
    depthThreshold += 50;
    System.out.println("Current depth: "+depthThreshold);
  } 
  else if (keyCode == DOWN) {
    depthThreshold -= 50;
    System.out.println("Current depth: "+depthThreshold);
  }
  else if (keyCode == 66) {    // lowercase B
    useBlur = !useBlur;
    System.out.println("Blur: "+useBlur);
  }
  else if (keyCode == 68) {    // lowercase D
    drawBlobs = !drawBlobs;
    System.out.println("Drawing blobs: "+drawBlobs);
  }
}