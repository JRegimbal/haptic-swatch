import java.time.OffsetDateTime;
import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
import java.lang.System;
import controlP5.*;
import netP5.*;
import oscP5.*;

private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);

public enum HaplyVersion {
  V2,
  V3,
  V3_1
}

public enum InputMode {
  SELECT,
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
RangeSlider k, b, freq1, freq2, maxA1, maxA2;
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
final int supercollider = 57120;
final int source = 8081;
final NetAddress oscDestination = new NetAddress("127.0.0.1", destination);
final NetAddress scDestination = new NetAddress("127.0.0.1", supercollider); 
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
      OscMessage msg = new OscMessage("/controller/updateManual");
      msg.add(activeSwatch.getId());
      msg = activeSwatch.addNormMessage(msg);
      oscp5.send(msg, oscDestination);
    }
  }
};

// Switching to new selected swatch
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
          if (c.equals(k.rangeToggle)) {
            println("checkK");
            id = 0;
            val = activeSwatch.k.parameterEnable;
            label = "k";
          } else if (c.equals(b.rangeToggle)) {
            println("checkMu");
            id = 1;
            val = activeSwatch.mu.parameterEnable;
            label = "mu";
          } else if (c.equals(maxA1.rangeToggle)) {
            println("checkA1");
            id = 2;
            val = activeSwatch.maxA1.parameterEnable;
            label = "A1";
          } else if (c.equals(maxA2.rangeToggle)) {
            println("checkA2");
            id = 4;
            val = activeSwatch.maxA2.parameterEnable;
            label = "A2";
          } else if (c.equals(freq1.rangeToggle)) {
            println("checkF1");
            id = 3;
            val = activeSwatch.freq1.parameterEnable;
            label = "F1";
          } else if (c.equals(freq2.rangeToggle)) {
            println("checkF2");
            id = 5;
            val = activeSwatch.freq2.parameterEnable;
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


// Mode changes
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

void mouseReleased() {
  moveInterimCoordinates = null;
}

void mousePressed(MouseEvent event) {
  if (mouseInWorkspace()) {
    PVector mouse = pixel_to_graphics(mouseX, mouseY);
    if (mode == InputMode.SELECT) {
      boolean clickedInHandle = false;
      for (HapticSwatch s : swatches.values()) {
        for (Handle h : s.getHandles()) {
          if (dist(mouse.x, mouse.y, h.pos.x, h.pos.y) < h.r) {
            if (!handleBuffer.contains(h)) {
              handleBuffer.clear();
              handleBuffer.add(h);
            }
            clickedInHandle = true;
            break;
          }
        }
        if (clickedInHandle) {
          activateSwatch(s);
          moveInterimCoordinates = mouse;
          break;
        }
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
      handleBuffer.clear();
      for (Handle h : s.getHandles()) {
        handleBuffer.add(h);
      }
      s.ready = true;
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
    k.setParameter(null);
    b.setParameter(null);
    freq1.setParameter(null);
    maxA1.setParameter(null);
    freq2.setParameter(null);
    maxA2.setParameter(null);
  }
  if (activeSwatch != null) {
    k.setParameter(activeSwatch.k);
    b.setParameter(activeSwatch.mu);
    freq1.setParameter(activeSwatch.freq1);
    maxA1.setParameter(activeSwatch.maxA1);
    freq2.setParameter(activeSwatch.freq2);
    maxA2.setParameter(activeSwatch.maxA2);
  }
  
  refreshRangeSliders();
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
        handleBuffer.clear();
        for (Handle h : s.getHandles()) {
          handleBuffer.add(h);
        }
        break;
      }
    }
  }
  else if (key == '1' || key == '2') {
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
    refreshRangeSliders();
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
        refreshRangeSliders();
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

void refreshRangeSliders() {
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

void mode(int value) {
  InputMode oldMode = mode;
  if (value == 0) {
    mode = InputMode.SELECT;
  } else if (value == 1) {
    mode = InputMode.CIRCLE;
  } else {
    println("Unknown mode value: " + value);
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
      refreshRangeSliders();
    }
  }
}
