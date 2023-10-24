/** Just an extra file to organize pantograph specific things. */

/* Screen and world setup parameters */
float             pixelsPerMeter                      = 4000.0;
float             radsPerDegree                       = 0.01745;

/* pantagraph link parameters in meters */
float             l                                   = 0.07;
float             L                                   = 0.09;

/* device graphical position */
PVector           deviceOrigin                        = new PVector(0, 0);

/* end effector radius in meters */
//float             rEE                                 = 0.006;
float              rEE                                = 0.002;
//float rEE = Score.lineSpacing / 2 / pixelsPerMeter;

PShape pGraph, joint, joint1, joint2, endEffector;

void panto_setup() {
  deviceOrigin.add(width / 2, 0);
  create_pantagraph();
}

void create_pantagraph(){
  pushMatrix();
  float lAni = pixelsPerMeter * l;
  float LAni = pixelsPerMeter * L;
  float rEEAni = pixelsPerMeter * rEE;
  
  if (version == HaplyVersion.V3 || version == HaplyVersion.V3_1) {
    pGraph = createShape();
    pGraph.beginShape();
    pGraph.fill(255);
    pGraph.stroke(0);
    pGraph.strokeWeight(2);
    
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.endShape(CLOSE);
    
    joint1 = createShape(ELLIPSE, deviceOrigin.x, deviceOrigin.y, rEEAni, rEEAni);
    //joint1 = createShape(ELLIPSE, deviceOrigin.x + 19e-3 * pixelsPerMeter, deviceOrigin.y, rEEAni, rEEAni);
    joint1.setStroke(color(0));
  
    joint2 = createShape(ELLIPSE, deviceOrigin.x - 38e-3 * pixelsPerMeter, deviceOrigin.y, rEEAni, rEEAni);
    //joint2 = createShape(ELLIPSE, deviceOrigin.x - 19e-3 * pixelsPerMeter, deviceOrigin.y, rEEAni, rEEAni);
    joint2.setStroke(color(0));
    
    endEffector = createShape(ELLIPSE, deviceOrigin.x, deviceOrigin.y, 2*rEEAni, 2*rEEAni);
    endEffector.setStroke(color(0));
    strokeWeight(5);
  } else if (version == HaplyVersion.V2) {
    pGraph = createShape();
    pGraph.beginShape();
    pGraph.fill(255, 0);
    pGraph.stroke(0);
    pGraph.strokeWeight(2);
    
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
    pGraph.endShape(CLOSE);
    
    joint = createShape(ELLIPSE, deviceOrigin.x, deviceOrigin.y, rEEAni, rEEAni);
    joint.setStroke(color(0));
    
    endEffector = createShape(ELLIPSE, deviceOrigin.x, deviceOrigin.y, 2*rEEAni, 2*rEEAni);
    endEffector.setStroke(color(0));
    strokeWeight(5);
  }
  popMatrix();
}

void update_animation(float th1, float th2, float xE, float yE){
  pushMatrix();
  float lAni = pixelsPerMeter * l;
  float LAni = pixelsPerMeter * L;
  
  xE = pixelsPerMeter * xE;
  yE = pixelsPerMeter * yE;
  
  th1 = 3.14 - th1;
  th2 = 3.14 - th2;
  
  if (version == HaplyVersion.V3 || version == HaplyVersion.V3_1) {
    pGraph.setVertex(0, deviceOrigin.x- 38e-3 * pixelsPerMeter, deviceOrigin.y );
    //pGraph.setVertex(0, deviceOrigin.x - 19e-3 * pixelsPerMeter, deviceOrigin.y);
    pGraph.setVertex(1, deviceOrigin.x , deviceOrigin.y );
    //pGraph.setVertex(1, deviceOrigin.x + 19e-3 * pixelsPerMeter, deviceOrigin.y);
    pGraph.setVertex(2, deviceOrigin.x + lAni*cos(th1), deviceOrigin.y + lAni*sin(th1));
    //pGraph.setVertex(2, deviceOrigin.x + lAni*cos(th1) + 19e-3 * pixelsPerMeter, deviceOrigin.y + lAni*sin(th1));
    pGraph.setVertex(3, deviceOrigin.x + xE, deviceOrigin.y + yE);
    pGraph.setVertex(4, deviceOrigin.x + lAni*cos(th2) - 38e-3 * pixelsPerMeter, deviceOrigin.y + lAni*sin(th2));
    //pGraph.setVertex(4, deviceOrigin.x + lAni*cos(th2) - 19e-3 * pixelsPerMeter, deviceOrigin.y + lAni*sin(th2));
    
    shape(pGraph);
    shape(joint1);
    shape(joint2);
  } else if (version == HaplyVersion.V2) {
    pGraph.setVertex(1, deviceOrigin.x + lAni*cos(th1), deviceOrigin.y + lAni*sin(th1));
    pGraph.setVertex(3, deviceOrigin.x + lAni*cos(th2), deviceOrigin.y + lAni*sin(th2));
    pGraph.setVertex(2, deviceOrigin.x + xE, deviceOrigin.y + yE);
    
    shape(pGraph);
    shape(joint);
  }
  
  
  translate(xE, yE);
  shape(endEffector);
  popMatrix();
}

PShape create_ball(float x, float y, float r) {
  x = pixelsPerMeter * x;
  y = pixelsPerMeter * y;
  r = pixelsPerMeter * r;
  
  return createShape(ELLIPSE, deviceOrigin.x + x, deviceOrigin.y + y, 2*r, 2*r);
}

PShape create_ellipse(float x, float y, float a, float b) {
  x = pixelsPerMeter * x;
  y = pixelsPerMeter * y;
  a = pixelsPerMeter * a;
  b = pixelsPerMeter * b;
  return createShape(ELLIPSE, deviceOrigin.x + x, deviceOrigin.y + y, 2*a, 2*b);
}
