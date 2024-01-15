import java.time.OffsetDateTime;
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
boolean isSwitch = false; // ignore logging when action is side effect from switching active swatch
boolean lastMode = isManual;
ControlP5 cp5;
Knob k, b, freq1, freq2, maxA1, maxA2;
Toggle checkK, checkMu, checkF1, checkF2, checkA1, checkA2;
Toggle manualTog, rewardModeToggle;
Button posPathFb, negPathFb, posZoneFb, negZoneFb;
RadioButton modeRadio;
HapticParams clipboard = new HapticParams();
Button copyButton, pasteButton;
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
final float xExtent = 0.075f;
final float yExtent = 0.13f;

PVector angles = new PVector(0, 0);
PVector torques = new PVector(0, 0);
PVector posEE = new PVector(0, 0);
PVector posEELast = new PVector(0, 0);
PVector velEE = new PVector(0, 0);
PVector fEE = new PVector(0, 0);

final float targetRate = 1000f;
final long controlElapsedMs = 100;
final float textureConst = 2*PI/targetRate;

/** Params */
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
final float maxK=150, maxB=0.5, MAL=1f, MAH=1f, maxF=200f;
final float minK=-100, minMu=0, minAL=0f, minAH=0f, minF=10f;

CallbackListener knobLog = new CallbackListener() {
  public void controlEvent(CallbackEvent evt) {
    if (activeSwatch != null && isManual && !isSwitch) {
      TableRow row = log.addRow();
      row.setString("timestamp", OffsetDateTime.now().toString());
      row.setString("command", "modify");
      row.setInt("element", activeSwatch.getId());
      row.setString("primary", activeSwatch.valueString());
      row.setString("secondary", "user");
    }
  }
};

CallbackListener CL = new CallbackListener() {
  public void controlEvent(CallbackEvent evt) {
    if (activeSwatch != null) {
      Controller c = evt.getController();
      OscMessage msg = new OscMessage("/controller/activate");
      synchronized(activeSwatch) {
        if (activeSwatch.ready) {
          int id;
          boolean val;
          String label;
          msg.add(activeSwatch.getId());
          if (c.equals(checkK)) {
            println("checkK");
            id = 0;
            val = activeSwatch.checkK;
            label = "k";
          } else if (c.equals(checkMu)) {
            println("checkMu");
            id = 1;
            val = activeSwatch.checkMu;
            label = "mu";
          } else if (c.equals(checkA1)) {
            println("checkA1");
            id = 2;
            val = activeSwatch.checkA1;
            label = "A1";
          } else if (c.equals(checkA2)) {
            println("checkA2");
            id = 4;
            val = activeSwatch.checkA2;
            label = "A2";
          } else if (c.equals(checkF1)) {
            println("checkF1");
            id = 3;
            val = activeSwatch.checkF1;
            label = "F1";
          } else if (c.equals(checkF2)) {
            println("checkF2");
            id = 5;
            val = activeSwatch.checkF2;
            label = "F2";
          } else {
            println("ERR - unknown controller");
            return;
          }
          msg.add(id);
          msg.add(val);
          oscp5.send(msg, oscDestination);
          if (!isSwitch) {
            TableRow row = log.addRow();
            row.setString("timestamp", OffsetDateTime.now().toString());
            row.setString("command", "lock");
            row.setInt("element", activeSwatch.getId());
            row.setInt("primary", id);
            row.setString("secondary", String.valueOf(val));
          }
        }
      }
    }
  }
};

CallbackListener modeLog = new CallbackListener() {
  public void controlEvent(CallbackEvent evt) {
    Controller c = evt.getController();
    if (c.equals(manualTog)) {
      synchronized(log) {
        TableRow row = log.addRow();
        row.setString("timestamp", OffsetDateTime.now().toString());
        row.setString("command", "switch");
        if (isManual) {
          row.setString("primary", "manual");
        } else {
          row.setString("primary", "autonomous");
        }
      }
    }
  }
};

boolean mouseInWorkspace() {
  PVector mouse = pixel_to_graphics(mouseX, mouseY);
  return (mouse.x > -xExtent - 19e-3 && mouse.x < xExtent - 19e-3 && mouse.y < yExtent && mouse.y > 0f);
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
      msg.add(6);
      msg.add(1f / nsteps);
      oscp5.send(msg, oscDestination);
      synchronized(log) {
        TableRow row = log.addRow();
        row.setString("timestamp", OffsetDateTime.now().toString());
        row.setString("command", "create");
        row.setInt("element", s.getId());
        row.setString("primary", s.valueString());
        row.setString("secondary", s.locString());
      }
      s.reset();
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
          TableRow row = log.addRow();
          row.setString("timestamp", OffsetDateTime.now().toString());
          row.setString("command", "resize");
          row.setInt("element", s.getId());
          row.setFloat("primary", s.radius); 
          s.radius += event.getCount() * 0.0005;
          row.setFloat("secondary", s.radius);
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
    maxA1.unplugFrom(s);
    checkA1.unplugFrom(s);
    freq1.unplugFrom(s);
    checkF1.unplugFrom(s);
    maxA2.unplugFrom(s);
    checkA2.unplugFrom(s);
    freq2.unplugFrom(s);
    checkF2.unplugFrom(s);
  }
  if (activeSwatch != null) {
    k.plugTo(activeSwatch);
    checkK.plugTo(activeSwatch);
    b.plugTo(activeSwatch);
    checkMu.plugTo(activeSwatch);
    maxA1.plugTo(activeSwatch);
    checkA1.plugTo(activeSwatch);
    freq1.plugTo(activeSwatch);
    checkF1.plugTo(activeSwatch);
    maxA2.plugTo(activeSwatch);
    checkA2.plugTo(activeSwatch);
    freq2.plugTo(activeSwatch);
    checkF2.plugTo(activeSwatch);
  }
  
  refreshKnobs();
  refreshToggles();
  selText = (activeSwatch != null) ? ("Swatch " + activeSwatch.getId()) : ("NONE");
}

void keyPressed() {
  if (key == 'y' || key == 'Y') {
    maxSpeed = 0;
  }
  else if (key == ESC) {
    key = 0;
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
  else if (key == '1' || key == '2' || key == '3') {
    int val = key - 49;
    Toggle tmp = modeRadio.getItem(val);
    if (!tmp.getBooleanValue()) tmp.toggle();
  }
  else if (key == 'q' || key == 'Q' || key == 'a' || key == 'A') {
    processPathFb((key == 'q' || key == 'Q') ? 1 : 0);
  }
  else if (key == 'w' || key =='W' || key == 's' || key == 'S') {
    processZoneFb((key == 'w' || key == 'W') ? 1 : 0);
  }
  else if (key == 'z' || key == 'Z') {
    // Switch mode
    manualTog.toggle(); 
  }
  else if (key == 'x' || key == 'X') {
    // switch reward
    //rewardModeToggle.toggle();
  }
  else if (key == '0') {
    resetAgents();
    refreshKnobs();
  }
  else if (key == '-') {
    if (activeSwatch != null) {
      int id = -1;
      synchronized(activeSwatch) {
        id = activeSwatch.getId();
        OscMessage msg = new OscMessage("/controller/init");
        msg.add(id);
        msg.add(6);
        msg.add(1f / nsteps);
        oscp5.send(msg, oscDestination);
        activeSwatch.reset();
        refreshKnobs();
      }
      TableRow row = log.addRow();
      row.setString("timestamp", OffsetDateTime.now().toString());
      row.setString("command", "reset");
      row.setInt("element", id);
    }
  }
  else if (key == BACKSPACE) {
    if (activeSwatch != null) {
      synchronized(activeSwatch) {
        swatches.remove(activeSwatch.getId());
      }
      synchronized(log) {
        TableRow row = log.addRow();
        row.setString("timestamp", OffsetDateTime.now().toString());
        row.setString("command", "delete");
        row.setInt("element", activeSwatch.getId());
        row.setString("primary", activeSwatch.valueString());
        row.setString("secondary", activeSwatch.locString());
      }
      activateSwatch(null);
    }
  }
  else if (key == 'c') {
    copyActive();
  }
  else if (key == 'v') {
    pasteToActive();
  }
  else if (key == '_') {
    widget = haplysetup(widgetID, haplyBoard);
  }
}

void resetAgents() {
  for (HapticSwatch s : swatches.values()) {
    int id = -1;
    synchronized(s) {
      id = s.getId();
      OscMessage msg = new OscMessage("/controller/init");
      msg.add(id);
      msg.add(6);
      msg.add(1f / nsteps);
      oscp5.send(msg, oscDestination);
      s.reset();
    }
    TableRow row = log.addRow();
    row.setString("timestamp", OffsetDateTime.now().toString());
    row.setString("command", "reset");
    row.setInt("element", id);
  }
}

void refreshKnobs() {
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      isSwitch = true;
      k.setValue(activeSwatch.k);
      b.setValue(activeSwatch.mu);
      maxA1.setValue(activeSwatch.maxA1);
      freq1.setValue(activeSwatch.freq1);
      maxA2.setValue(activeSwatch.maxA2);
      freq2.setValue(activeSwatch.freq2);
      isSwitch = false;
    }
  }
}

void refreshToggles() {
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      isSwitch = true;
      checkK.setValue(activeSwatch.checkK);
      checkMu.setValue(activeSwatch.checkMu);
      checkA1.setValue(activeSwatch.checkA1);
      checkF1.setValue(activeSwatch.checkF1);
      checkA2.setValue(activeSwatch.checkA2);
      checkF2.setValue(activeSwatch.checkF2);
      isSwitch = false;
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

void processPosPathFb() { processPathFb(1); }
void processNegPathFb() { processPathFb(0); }
void processPosZoneFb() { processZoneFb(1); }
void processNegZoneFb() { processZoneFb(0); }

void processPathFb(int value) {
  // POSITIVE/NEGATIVE REWARD
  if (rwMode == RewardMode.EXPLICIT) {
    if (activeSwatch != null) {
      int id, feedback;
      synchronized(activeSwatch) {
        OscMessage msg = new OscMessage("/controller/reward");
        id = activeSwatch.getId();
        msg.add(id);
        if (value == 1) {
          feedback = 1;
        } else {
          feedback = -1;
        }
        msg.add(feedback);
        oscp5.send(msg, oscDestination);
      }
      TableRow row = log.addRow();
      row.setString("timestamp", OffsetDateTime.now().toString());
      row.setString("command", "guide");
      row.setInt("element", id);
      row.setInt("primary", feedback);
      println("Reward sent");
    }
  } else {
    println("ERROR: Explicit reward mode not enabled. Actual reward mode: " + rwMode);
  }
}

void processZoneFb(int value) {
// POSITIVE/NEGATIVE ZONE REWARD
  if (rwMode == RewardMode.EXPLICIT) {
    if (activeSwatch != null) {
      int id, feedback;
      synchronized(activeSwatch) {
        OscMessage msg = new OscMessage("/controller/zone_reward");
        id = activeSwatch.getId();
        msg.add(id);
        if (value == 1) {
          feedback = 1;
        } else {
          feedback = -1;
        }
        msg.add(feedback);
        oscp5.send(msg, oscDestination);
      }
      TableRow row = log.addRow();
      row.setString("timestamp", OffsetDateTime.now().toString());
      row.setString("command", "zone");
      row.setInt("element", id);
      row.setInt("primary", feedback);
      println("Zone reward sent");
    }
  } else {
    println("ERROR: Explicit reward mode not enabled. Actual reward mode: " + rwMode);
  }
}

void copyActive() {
  println("Ping");
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      clipboard = activeSwatch.getParams();
    }
  }
}

void pasteToActive() {
  println("Pong");
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      activeSwatch.setParams(clipboard);
      refreshKnobs();
    }
  }
}
