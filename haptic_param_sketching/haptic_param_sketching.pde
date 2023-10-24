import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
import java.lang.System;
import controlP5.*;
import netP5.*;
import oscP5.*;

/* TODO better stepping based on active/update work on Wednesday */

private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);

public enum HaplyVersion {
  V2,
  V3,
  V3_1
}

final HaplyVersion version = HaplyVersion.V3_1;
boolean isManual = true;
boolean lastMode = isManual;
ControlP5 cp5;
Knob k, b, maxAL, maxAH;
Toggle checkK, checkMu, checkAL, checkAH;
Toggle manualTog;
long currTime, lastTime = 0;

/** 2DIY setup */
Board haplyBoard;
Device widget;
Mechanisms pantograph;

byte widgetID = 5;
int CW = 0;
int CCW = 1;
boolean renderingForce = false; 
long baseFrameRate = 120;
ScheduledFuture<?> handle;
Filter filt;
Table log;

PVector angles = new PVector(0, 0);
PVector torques = new PVector(0, 0);
PVector posEE = new PVector(0, 0);
PVector posEELast = new PVector(0, 0);
PVector velEE = new PVector(0, 0);
PVector fEE = new PVector(0, 0);

final float targetRate = 1000f;
final float textureConst = 2*PI/targetRate;
PVector fText = new PVector(0, 0);

/** Params */
HapticSwatch[] swatches = {
  new HapticSwatch(-0.02, 0.06, 0.01),
  new HapticSwatch(0.02, 0.06, 0.01),
  new HapticSwatch(-0.02, 0.10, 0.01),
  new HapticSwatch(0.02, 0.10, 0.01)
};

HapticSwatch activeSwatch = swatches[0];

String selText = "Upper Left";
float maxSpeed = 0f;

/** OSC */
final int destination = 8080;
final int source = 8081;
final NetAddress oscDestination = new NetAddress("127.0.0.1", destination);
OscP5 oscp5 = new OscP5(this, source);

//final float maxK=500, maxB=1.0, MAL=2f, MAH=2f;
final float maxK=250, maxB=0.5, MAL=1f, MAH=1f;

CallbackListener CL = new CallbackListener() {
  public void controlEvent(CallbackEvent evt) {
    Controller c = evt.getController();
    OscMessage msg = new OscMessage("/controller/activate");
    synchronized(activeSwatch) {
      msg.add(activeSwatch.getId());
      if (c.equals(checkK)) {
        println("checkK");
        msg.add(0);
        msg.add(activeSwatch.checkK);
      } else if (c.equals(checkMu)) {
        println("checkMu");
        msg.add(1);
        msg.add(activeSwatch.checkMu);
      } else if (c.equals(checkAL)) {
        println("checkAL");
        msg.add(2);
        msg.add(activeSwatch.checkAL);
      } else if (c.equals(checkAH)) {
        println("checkAH");
        msg.add(3);
        msg.add(activeSwatch.checkAH);
      } else {
        println("ERR - unknown controller");
        return;
      }
      oscp5.send(msg, oscDestination);
    }
  }
};

/** Main thread */
void setup() {
  size(1000, 650);
  frameRate(baseFrameRate);
  filt = new Butter2();
  log = new Table();
  log.addColumn("force");
  
  /** Controls */
  cp5 = new ControlP5(this);
  k = cp5.addKnob("k")
    .plugTo(swatches[0])
    .setRange(0, maxK)
    .setValue(0)
    .setPosition(50, 25)
    .setRadius(50)
    .setCaptionLabel("Spring k")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkK = cp5.addToggle("checkK")
    .plugTo(swatches[0])
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 105)
    .onChange(CL);
  b = cp5.addKnob("mu")
    .plugTo(swatches[0])
    .setRange(0, maxB)
    .setValue(0) // unitless
    .setPosition(50, 150)
    .setRadius(50)
    .setCaptionLabel("Friction mu")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkMu = cp5.addToggle("checkMu")
    .plugTo(swatches[0])
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 230)
    .onChange(CL);
  maxAL = cp5.addKnob("maxAL")
    .plugTo(swatches[0])
    .setRange(0, MAL)
    .setValue(0)
    .setPosition(50, 275)
    .setRadius(50)
    .setCaptionLabel("Low Texture Amp. (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkAL = cp5.addToggle("checkAL")
    .plugTo(swatches[0])
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 355)
    .onChange(CL);
  maxAH = cp5.addKnob("maxAH")
    .plugTo(swatches[0])
    .setRange(0, MAH)
    .setValue(0)
    .setPosition(50, 400)
    .setRadius(50)
    .setCaptionLabel("Texture Amp. (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkAH = cp5.addToggle("checkAH")
    .plugTo(swatches[0])
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 480)
    .onChange(CL);
  manualTog = cp5.addToggle("isManual")
    .setPosition(75, 525)
    .setCaptionLabel("Manual/Autonomous")
    .setColorCaptionLabel(color(20, 20, 20));
    
  /** Haply */
  haplyBoard = new Board(this, Serial.list()[0], 0);
  widget = new Device(widgetID, haplyBoard);
  if (version == HaplyVersion.V2) {
    pantograph = new Pantograph(2);
    widget.set_mechanism(pantograph);
    widget.add_actuator(1, CCW, 2);
    widget.add_actuator(2, CW, 1);
    widget.add_encoder(1, CCW, 241, 10752, 2);
    widget.add_encoder(2, CW, -61, 10752, 1);
  } else if (version == HaplyVersion.V3 || version == HaplyVersion.V3_1) {
    pantograph = new Pantograph(3);
    widget.set_mechanism(pantograph);
    widget.add_actuator(1, CCW, 2);
    widget.add_actuator(2, CCW, 1);
    if (version == HaplyVersion.V3) {
      widget.add_encoder(1, CCW, 97.23, 2048*2.5*1.0194*1.0154, 2);   //right in theory
      widget.add_encoder(2, CCW, 82.77, 2048*2.5*1.0194, 1);    //left in theory
    } else {
      //widget.add_encoder(1, CCW, 166.58, 2048*2.5*1.0194*1.0154, 2);   //right in theory
      //widget.add_encoder(2, CCW, 11.11, 2048*2.5*1.0194, 1);    //left in theory
      widget.add_encoder(1, CCW, 168, 4880, 2);   //right in theory
      widget.add_encoder(2, CCW, 12, 4880, 1);    //left in theory
    }
  }
  widget.device_set_parameters();
  panto_setup();
  
  /** Spawn haptics thread */
  SimulationThread st = new SimulationThread();
  UpdateThread ot = new UpdateThread();
  handle = scheduler.scheduleAtFixedRate(st, 1000, (long)(1000000f / targetRate), MICROSECONDS);
  scheduler.scheduleAtFixedRate(ot, 1, 1000, MILLISECONDS);
}

void exit() {
  handle.cancel(true);
  scheduler.shutdown();
  widget.set_device_torques(new float[]{0, 0});
  widget.device_write_torques();
  saveTable(log, "log.csv");
  OscMessage msg = new OscMessage("/quit");
  oscp5.send(msg, oscDestination);
  println("Quit");
  super.exit();
}

void draw() {
  if (renderingForce == false) {
    background(255);
    for (HapticSwatch s : swatches) {
      shape(create_ellipse(s.center.x, s.center.y, s.radius, s.radius));
    }
    update_animation(angles.x * radsPerDegree, angles.y * radsPerDegree, posEE.x, posEE.y);
    fill(0, 0, 0);
    textAlign(RIGHT);
    text("Delay (us): " + nf((int)((currTime - lastTime) / 1000), 4), 800, 40);
    text("Vel (mm/s): " + nf((int)(velEE.mag() * 1000), 3), 800, 60);
    text("Max speed (mm/s): " + nf((int)(maxSpeed * 1000), 3), 800, 80);
    text("Texture (N): " + nf((int)fText.mag()), 800, 100);
    textAlign(CENTER);
    text(selText, 100, 20);
    fill(255, 255, 255);
    
    if (lastMode != isManual) {
      if (isManual) {
        k.unlock();
        b.unlock();
        maxAL.unlock();
        maxAH.unlock();
      } else {
        k.lock();
        b.lock();
        maxAL.lock();
        maxAH.lock();
      }
      OscMessage msg = new OscMessage("/uistate/setAutonomous");
      msg.add(isManual);
      oscp5.send(msg, oscDestination);
      lastMode = isManual;
    }
  }
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    maxSpeed = 0;
  }
  else if (key == '1' || key == '2' || key == '3' || key == '4') {
    int keyVal = int(key) - 48;
    activeSwatch = swatches[keyVal - 1];
    for (HapticSwatch s : swatches) {
      k.unplugFrom(s);
      checkK.unplugFrom(s);
      b.unplugFrom(s);
      checkMu.unplugFrom(s);
      maxAL.unplugFrom(s);
      checkAL.unplugFrom(s);
      maxAH.unplugFrom(s);
      checkAH.unplugFrom(s);
    }
    k.plugTo(activeSwatch);
    checkK.plugTo(activeSwatch);
    b.plugTo(activeSwatch);
    checkMu.plugTo(activeSwatch);
    maxAL.plugTo(activeSwatch);
    checkAL.plugTo(activeSwatch);
    maxAH.plugTo(activeSwatch);
    checkAH.plugTo(activeSwatch);
    
    refreshKnobs();
    refreshToggles();
    switch (keyVal) {
      case 1:
        selText = "Upper Left"; break;
      case 2:
        selText = "Upper Right"; break;
      case 3:
        selText = "Bottom Left"; break;
      case 4:
      default:
        selText = "Bottom Right"; break;
    }
  }
  else if (key == 'w') {
    //saveTable(log, "log.csv");
  }
  else if (key == 'q' || key == 'Q' || key == 'a' || key == 'A') {
    // POSITIVE/NEGATIVE REWARD
    synchronized(activeSwatch) {
      OscMessage msg = new OscMessage("/controller/reward");
      msg.add(activeSwatch.getId());
      if (key == 'q' || key == 'Q') {
        msg.add(1);
      } else {
        msg.add(-1);
      }
      oscp5.send(msg, oscDestination);
      // TODO Bootstrap (handle in agent?)
    }
    println("Reward sent");
  }
  else if (key == 'z' || key == 'Z') {
    // Switch mode
    manualTog.toggle();
  }
}

void refreshKnobs() {
  synchronized(activeSwatch) {
    k.setValue(activeSwatch.k);
    b.setValue(activeSwatch.mu);
    maxAL.setValue(activeSwatch.maxAL);
    maxAH.setValue(activeSwatch.maxAH);
  }
}

void refreshToggles() {
  synchronized(activeSwatch) {
    checkK.setValue(activeSwatch.checkK);
    checkMu.setValue(activeSwatch.checkMu);
    checkAL.setValue(activeSwatch.checkAL);
    checkAH.setValue(activeSwatch.checkAH);
  }
}

/** Helper */
PVector device_to_graphics(PVector deviceFrame) {
  return deviceFrame.set(-deviceFrame.x, deviceFrame.y);
}

PVector graphics_to_device(PVector graphicsFrame) {
  return graphicsFrame.set(-graphicsFrame.x, graphicsFrame.y);
}
