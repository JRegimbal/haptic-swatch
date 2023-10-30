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

public enum InputMode {
  SELECT,
  MOVE,
  CIRCLE
}

InputMode mode = InputMode.SELECT;
final HaplyVersion version = HaplyVersion.V3_1;
boolean isManual = true;
boolean lastMode = isManual;
ControlP5 cp5;
Knob k, b, maxAL, maxAH;
Toggle checkK, checkMu, checkAL, checkAH;
Toggle manualTog;
final float nsteps = 20f;
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
final float xExtent = 0.065f;
final float yExtent = 0.15f;

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
/*(HapticSwatch[] swatches = {
  new HapticSwatch(-0.02, 0.06, 0.01),
  new HapticSwatch(0.02, 0.06, 0.01),
  new HapticSwatch(-0.02, 0.10, 0.01),
  new HapticSwatch(0.02, 0.10, 0.01)
};*/
ArrayList<HapticSwatch> swatches = new ArrayList(List.of(
  new HapticSwatch(-0.02, 0.06, 0.01),
  new HapticSwatch(0.02, 0.06, 0.01),
  new HapticSwatch(-0.02, 0.10, 0.01),
  new HapticSwatch(0.02, 0.10, 0.01)
  ));

HapticSwatch activeSwatch = swatches.get(0);

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

boolean mouseInWorkspace() {
  PVector mouse = pixel_to_graphics(mouseX, mouseY);
  return (mouse.x > -xExtent && mouse.x < xExtent && mouse.y < yExtent && mouse.y > 0f);
}

void mouseClicked() {
  if (mouseInWorkspace()) {
    PVector mouse = pixel_to_graphics(mouseX, mouseY);
    if (mode == InputMode.SELECT) {
      boolean clickedInHandle = false;
      for (HapticSwatch s : swatches) {
        for (Handle h : s.getHandles()) {
          if (dist(mouse.x, mouse.y, h.pos.x, h.pos.y) < h.r) {
            if (keyPressed && key == CODED && keyCode == SHIFT) {
              if (!handleBuffer.contains(h)) {
                handleBuffer.add(h);
              } else {
                handleBuffer.remove(h);
              }
            } else {
              if (!handleBuffer.contains(h)) {
                handleBuffer.clear();
                handleBuffer.add(h);
              }
            }
            clickedInHandle = true;
            break;
          }
        }
      }
      if (!clickedInHandle) {
        handleBuffer.clear();
      }
    }
  }
}

void mouseReleased() {
  moveInterimCoordinates = null;
}

void mousePressed(MouseEvent event) {
  if (mouseInWorkspace()) {
    PVector mouse = pixel_to_graphics(mouseX, mouseY);
    if (mode == InputMode.MOVE) {
      if (moveInterimCoordinates == null) {
        // Starting new drag (possibly!)
        for (HapticSwatch s: swatches) {
          for (Handle h : s.getHandles()) {
            if (dist(mouse.x, mouse.y, h.pos.x, h.pos.y) < h.r) {
              if (!handleBuffer.contains(h)) {
                handleBuffer.add(h);
                break;
              }
            }
          }
        }
        if (handleBuffer.size() > 0) {
          // Start drag!
          moveInterimCoordinates = mouse;
        }
      }
    }
  }
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    maxSpeed = 0;
  }
  else if (key == '1' || key == '2' || key == '3' || key == '4') {
    int keyVal = int(key) - 48;
    activeSwatch = swatches.get(keyVal - 1);
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
  else if (key == '0') {
    resetAgents();
    refreshKnobs();
  }
}

void resetAgents() {
  for (HapticSwatch s : swatches) {
    synchronized(s) {
      OscMessage msg = new OscMessage("/controller/init");
      msg.add(s.getId());
      msg.add(4);
      msg.add(1f / nsteps);
      oscp5.send(msg, oscDestination);
      s.k = s.mu = s.maxAL = s.maxAH = 0f;
    }
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

void mode(int value) {
  InputMode oldMode = mode;
  if (value == 0) {
    mode = InputMode.SELECT;
  } else if (value == 1) {
    mode = InputMode.MOVE;
  } else if (value == 2) {
    mode = InputMode.CIRCLE;
  } else {
    println("Unknown mode value: " + value);
  }
  if (oldMode != mode) {
    // Would need logic for polygons or whatever
    if ((oldMode == InputMode.MOVE || oldMode == InputMode.SELECT) && (mode != InputMode.MOVE && mode != InputMode.SELECT)) {
      handleBuffer = null;
      moveInterimCoordinates = null;
    }
  }
}

PVector pixel_to_graphics(float x, float y) {
  return new PVector(
    (x - deviceOrigin.x) / pixelsPerMeter,
    (y - deviceOrigin.y) / pixelsPerMeter
    );
}

/** Helper */
PVector device_to_graphics(PVector deviceFrame) {
  return deviceFrame.set(-deviceFrame.x, deviceFrame.y);
}

PVector graphics_to_device(PVector graphicsFrame) {
  return graphicsFrame.set(-graphicsFrame.x, graphicsFrame.y);
}
