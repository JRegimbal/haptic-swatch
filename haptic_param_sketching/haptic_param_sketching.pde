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

public enum RewardMode {
  ATTENTION,  // Is based on how long a user interacts with the experience until a new one is requested
  EXPLICIT    // Is based on explicit reward signals sent by the user
}

InputMode mode = InputMode.SELECT;
final HaplyVersion version = HaplyVersion.V3_1;
RewardMode rwMode = RewardMode.EXPLICIT;
boolean isManual = true;
boolean lastMode = isManual;
ControlP5 cp5;
Knob k, b, maxAL, maxAH;
Toggle checkK, checkMu, checkAL, checkAH;
Toggle manualTog, rewardModeToggle;
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
final long controlElapsedMs = 500;
final float textureConst = 2*PI/targetRate;

/** Params */
/*(HapticSwatch[] swatches = {
  new HapticSwatch(-0.02, 0.06, 0.01),
  new HapticSwatch(0.02, 0.06, 0.01),
  new HapticSwatch(-0.02, 0.10, 0.01),
  new HapticSwatch(0.02, 0.10, 0.01)
};*/

HashMap<Integer, HapticSwatch> swatches = new HashMap();


HapticSwatch activeSwatch = null;

String selText = "NONE";
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
    if (activeSwatch != null) {
      Controller c = evt.getController();
      OscMessage msg = new OscMessage("/controller/activate");
      synchronized(activeSwatch) {
        if (activeSwatch.ready) {
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
      for (HapticSwatch s : swatches.values()) {
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
        if (clickedInHandle) {
          activateSwatch(s);
          break;
        }
      }
      if (!clickedInHandle) {
        handleBuffer.clear();
      }
    } else if (mode == InputMode.CIRCLE) {
      HapticSwatch s = new HapticSwatch(mouse.x, mouse.y, 0.01);
      swatches.put(s.getId(), s);
      OscMessage msg = new OscMessage("/controller/init");
      msg.add(s.getId());
      msg.add(4);
      msg.add(1f / nsteps);
      oscp5.send(msg, oscDestination);
      s.k = s.mu = s.maxAL = s.maxAH = 0f;
      activateSwatch(s);
      s.ready = true;
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
        for (HapticSwatch s: swatches.values()) {
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

void mouseWheel(MouseEvent event) {
  if (mouseInWorkspace()) {
    PVector mouse = pixel_to_graphics(mouseX, mouseY);
    // Check if we're in a handle
    for (HapticSwatch s : swatches.values()) {
      for (Handle h : s.getHandles()) {
        if (dist(mouse.x, mouse.y, h.pos.x, h.pos.y) < h.r) {
          s.radius += event.getCount() * 0.0005;
        }
      }
    }
  }
}

void activateSwatch(HapticSwatch swatch) {
  activeSwatch = swatch;
  for (HapticSwatch s : swatches.values()) {
    k.unplugFrom(s);
    checkK.unplugFrom(s);
    b.unplugFrom(s);
    checkMu.unplugFrom(s);
    maxAL.unplugFrom(s);
    checkAL.unplugFrom(s);
    maxAH.unplugFrom(s);
    checkAH.unplugFrom(s);
  }
  if (activeSwatch != null) {
    k.plugTo(activeSwatch);
    checkK.plugTo(activeSwatch);
    b.plugTo(activeSwatch);
    checkMu.plugTo(activeSwatch);
    maxAL.plugTo(activeSwatch);
    checkAL.plugTo(activeSwatch);
    maxAH.plugTo(activeSwatch);
    checkAH.plugTo(activeSwatch);
  }
  
  refreshKnobs();
  refreshToggles();
  selText = (activeSwatch != null) ? ("Swatch " + activeSwatch.getId()) : ("NONE");
}

void keyPressed() {
  if (key == 'y' || key == 'Y') {
    maxSpeed = 0;
  }
  else if (key == ' ') {
    // Select swatch if on handle
    for (HapticSwatch s : swatches.values()) {
      if (s.isTouching(posEE)) {
        activateSwatch(s);
        break;
      }
    }
  }
  else if (key == 'r' || key == 'R') {
    if (rwMode == RewardMode.ATTENTION) {
      // request new state
      if (activeSwatch != null) {
        synchronized(activeSwatch) {
          OscMessage msg = new OscMessage("/controller/reward");
          msg.add(activeSwatch.getId());
          msg.add(rewardFromDuration(activeSwatch.elapsed));
          oscp5.send(msg, oscDestination);
          msg = new OscMessage("/controller/step");
          msg.add(activeSwatch.getId());
          oscp5.send(msg, oscDestination);
        }
        println("Request sent!");
      } else {
        println("No active swatch set - no action taken.");
      }
    } else {
      println("Request does nothing in reward mode '" + rwMode + "'. (Debug reset is now y/Y.)");
    }
  }
  /*else if (key == '1' || key == '2' || key == '3' || key == '4' || key == '5' || key == '6' || key == '7' || key == '8' || key == '9') {
    int keyVal = int(key) - 48;
    activateSwatch(swatches.get(keyVal - 1));
  }*/
  else if (key == 'q' || key == 'Q' || key == 'a' || key == 'A') {
    // POSITIVE/NEGATIVE REWARD
    if (rwMode == RewardMode.EXPLICIT) {
      if (activeSwatch != null) {
        synchronized(activeSwatch) {
          OscMessage msg = new OscMessage("/controller/reward");
          msg.add(activeSwatch.getId());
          if (key == 'q' || key == 'Q') {
            msg.add(1);
          } else {
            msg.add(-1);
          }
          oscp5.send(msg, oscDestination);
        }
        println("Reward sent");
      }
    } else {
      println("ERROR: Explicit reward mode not enabled. Actual reward mode: " + rwMode);
    }
  }
  else if (key == 'w' || key =='W' || key == 's' || key == 'S') {
    // POSITIVE/NEGATIVE ZONE REWARD
    if (rwMode == RewardMode.EXPLICIT) {
      if (activeSwatch != null) {
        synchronized(activeSwatch) {
          OscMessage msg = new OscMessage("/controller/zone_reward");
          msg.add(activeSwatch.getId());
          if (key == 'w' || key == 'W') {
            msg.add(1);
          } else {
            msg.add(-1);
          }
          oscp5.send(msg, oscDestination);
        }
        println("Zone reward sent");
      }
    } else {
      println("ERROR: Explicit reward mode not enabled. Actual reward mode: " + rwMode);
    }
  }
  else if (key == 'z' || key == 'Z') {
    // Switch mode
    manualTog.toggle(); 
  }
  else if (key == 'x' || key == 'X') {
    // switch reward
    rewardModeToggle.toggle();
  }
  else if (key == '0') {
    resetAgents();
    refreshKnobs();
  }
  else if (key == '-') {
    if (activeSwatch != null) {
      synchronized(activeSwatch) {
        OscMessage msg = new OscMessage("/controller/init");
        msg.add(activeSwatch.getId());
        msg.add(4);
        msg.add(1f / nsteps);
        oscp5.send(msg, oscDestination);
        activeSwatch.k = activeSwatch.mu = activeSwatch.maxAL = activeSwatch.maxAH = 0f;
        refreshKnobs();
      }
    }
  }
  else if (key == BACKSPACE) {
    if (activeSwatch != null) {
      synchronized(activeSwatch) {
        swatches.remove(activeSwatch.getId());
      }
      activateSwatch(null);
    }
  }
}

void resetAgents() {
  for (HapticSwatch s : swatches.values()) {
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
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      k.setValue(activeSwatch.k);
      b.setValue(activeSwatch.mu);
      maxAL.setValue(activeSwatch.maxAL);
      maxAH.setValue(activeSwatch.maxAH);
    }
  }
}

void refreshToggles() {
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      checkK.setValue(activeSwatch.checkK);
      checkMu.setValue(activeSwatch.checkMu);
      checkAL.setValue(activeSwatch.checkAL);
      checkAH.setValue(activeSwatch.checkAH);
    }
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
      handleBuffer.clear();
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
