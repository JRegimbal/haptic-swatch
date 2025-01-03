import java.time.OffsetDateTime;
import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
import java.lang.System;
import controlP5.*;
import netP5.*;
import oscP5.*;

private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(3);

public enum Mode {
  Manual,
  Joint,
  Split
}

Mode toolMode = Mode.Split;

public enum HaplyVersion {
  V2,
  V3,
  V3_1,
  DUMMY
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
final HaplyVersion version = HaplyVersion.DUMMY;
final float nsteps = 20f;
final int fbScale = 1;
RewardMode rwMode = RewardMode.EXPLICIT;
boolean isManual = true;
boolean isSwitch = false; // ignore logging when action is side effect from switching active swatch
boolean lastMode = isManual;
ControlP5 cp5;
RangeSlider k, b, freq1, freq2, maxA1, maxA2;
RangeSlider audFreq, audMix, audAtk, audRel, audReson;
Toggle manualTog, rewardModeToggle;
Button posPathFb, negPathFb, posZoneFb, negZoneFb;
Button limitZone, resetLimits, limitZoneSec, resetLimitsSec;
Button jump;
Button hapticLock, audioLock;
RadioButton modeRadio;
HapticParams clipboard = new HapticParams();
Button copyButton, pasteButton;
long currTime, lastTime = 0;
boolean lastButtonPressed = false;

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
final long audioElapsedMs = 20;
final long controlElapsedMs = 500;
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
final float maxK=150, maxB=0.5, MAL=1f, MAH=1f, maxF=200f, maxAudF=700, maxMix=1f, maxAtk=0.5, maxRel=2.0, maxReson=1.5;
final float minK=-100, minMu=0, minAL=0f, minAH=0f, minF=10f, minAudF=261, minMix=0f, minAtk=0.01, minRel=0.1, minReson=0.25;

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

CallbackListener limitLog = new CallbackListener() {
  public void controlEvent(CallbackEvent evt) {
    if (activeSwatch != null && !isSwitch) {
      TableRow row = log.addRow();
      row.setString("timestamp", OffsetDateTime.now().toString());
      row.setString("command", "modify_limit");
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
          } else if (c.equals(audFreq.rangeToggle)) {
            println("checkAF");
            id = 6;
            val = activeSwatch.audFreq.parameterEnable;
            label = "AF";
          } else if (c.equals(audMix.rangeToggle)) {
            println("checkMx");
            id = 7;
            val = activeSwatch.audMix.parameterEnable;
            label = "Mx";
          } else if (c.equals(audAtk.rangeToggle)) {
            println("checkAtk");
            id = 8;
            val = activeSwatch.audAtk.parameterEnable;
            label = "Ak";
          } else if (c.equals(audRel.rangeToggle)) {
            println("checkRl");
            id = 9;
            val = activeSwatch.audRel.parameterEnable;
            label = "Rl";
          } else if (c.equals(audReson.rangeToggle)) {
            println("checkRn");
            id = 10;
            val = activeSwatch.audReson.parameterEnable;
            label = "Rn";
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
      msg.add(11);
      msg.add(1f / nsteps);
      oscp5.send(msg, oscDestination);
      msg = new OscMessage("/audio/create");
      msg.add(s.getId());
      msg.add(s.audFreq.value);  // freq
      msg.add(s.audMix.value);    // mix
      msg.add(s.audAtk.value);    // atk
      msg.add(s.audRel.value);    // rel
      msg.add(s.audReson.value);    // resonz
      msg.add(s.lastForce.mag()); // force N
      oscp5.send(msg, scDestination);
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
  k.setParameter(null);
  b.setParameter(null);
  freq1.setParameter(null);
  maxA1.setParameter(null);
  freq2.setParameter(null);
  maxA2.setParameter(null);
  audFreq.setParameter(null);
  audMix.setParameter(null);
  audAtk.setParameter(null);
  audRel.setParameter(null);
  audReson.setParameter(null);
  if (activeSwatch != null) {
    k.setParameter(activeSwatch.k);
    b.setParameter(activeSwatch.mu);
    freq1.setParameter(activeSwatch.freq1);
    maxA1.setParameter(activeSwatch.maxA1);
    freq2.setParameter(activeSwatch.freq2);
    maxA2.setParameter(activeSwatch.maxA2);
    audFreq.setParameter(activeSwatch.audFreq);
    audMix.setParameter(activeSwatch.audMix);
    audAtk.setParameter(activeSwatch.audAtk);
    audRel.setParameter(activeSwatch.audRel);
    audReson.setParameter(activeSwatch.audReson);
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
    if (toolMode == Mode.Joint) {
      processFb((key == 'q' || key == 'Q') ? 1 : 0, 0);
    } else if (toolMode == Mode.Split) {
      processFb((key == 'q' || key == 'Q') ? 1 : 0, 1);
    }
  }
  else if (key == 'w' || key =='W' || key == 's' || key == 'S') {
    if (toolMode == Mode.Split) {
      processFb((key == 'w' || key == 'W') ? 1 : 0, 2);
    }
  }
  else if ((key == 'r' || key == 'R') && (toolMode != Mode.Manual)) {
    limitPrimZone();
  }
  else if ((key == 'f' || key == 'F') && (toolMode != Mode.Manual)) {
    resetPrimLimit();
  }
  else if ((key == 't' || key == 'T') && (toolMode == Mode.Split)) {
    limitSecZone();
  }
  else if((key == 'g' || key == 'G') && (toolMode == Mode.Split)) {
    resetSecLimit();
  }
  else if (key == 'z' || key == 'Z') {
    // Switch mode
    if (toolMode != Mode.Manual) {
      manualTog.toggle();
    }
  }
  else if ((key == 'j' || key == 'J') && !isManual) {
    jumpUnexplored();
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
        msg.add(11);
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
      msg.add(11);
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
      audFreq.setValue(activeSwatch.audFreq);
      audMix.setValue(activeSwatch.audMix);
      audAtk.setValue(activeSwatch.audAtk);
      audRel.setValue(activeSwatch.audRel);
      audReson.setValue(activeSwatch.audReson);
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

void processPosPrimFb() { processFb(1, (toolMode == Mode.Joint) ? 0 : 1); }
void processNegPrimFb() { processFb(0, (toolMode == Mode.Joint) ? 0 : 1); }
void processPosSecFb() { processFb(1, 2); }
void processNegSecFb() { processFb(0, 2); }

void processFb(int value, int modality) {
  if (activeSwatch != null) {
     int id, feedback;
     synchronized(activeSwatch) {
        OscMessage msg = new OscMessage("/controller/reward");
        id = activeSwatch.getId();
        msg.add(id);
        if (value == 1) {
          feedback = fbScale;
        } else {
          feedback = -fbScale;
        }
        msg.add(feedback);
        if (modality > 0) {
          msg.add(modality);
        }
        oscp5.send(msg, oscDestination);
    }
    TableRow row = log.addRow();
    row.setString("timestamp", OffsetDateTime.now().toString());
    row.setString("command", (modality > 0) ? "guide_" + modality : "guide" );
    row.setInt("element", id);
    row.setInt("primary", feedback);
    println("Reward sent");
  }
}

void limitPrimZone() {
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      if (toolMode == Mode.Split) {
        activeSwatch.setHapticLimit();
      } else {
        activeSwatch.setLimit();
      }
    }
    refreshRangeSliders();
    limitLog.controlEvent(null);
  }
}

void limitSecZone() {
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      activeSwatch.setAudioLimit();
    }
    refreshRangeSliders();
    limitLog.controlEvent(null);
  }
}


void resetPrimLimit() {
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      if (toolMode == Mode.Split) {
        activeSwatch.resetHapticLimit();
      } else {
        activeSwatch.resetLimits();
      }
    }
    refreshRangeSliders();
    limitLog.controlEvent(null);
  }
}

void resetSecLimit() {
  if (activeSwatch != null) {
    synchronized(activeSwatch) {
      activeSwatch.resetAudioLimit();
    }
    refreshRangeSliders();
    limitLog.controlEvent(null);
  }
}

void jumpUnexplored() {
  if (activeSwatch != null) {
    int id = activeSwatch.getId();
    OscMessage msg = new OscMessage("/controller/jump");
    msg.add(id);
    oscp5.send(msg, oscDestination);
    // Agent will automatically step following a jump - no further action needed
    TableRow row = log.addRow();
    row.setString("timestamp", OffsetDateTime.now().toString());
    row.setString("command", "jump");
    row.setInt("element", id);
  }
}

void toggleHapticLock() {
  boolean newVal = !(
    k.getRangeEnable() && b.getRangeEnable() && maxA1.getRangeEnable() &&
    freq1.getRangeEnable() && maxA2.getRangeEnable() && freq2.getRangeEnable()
  );
  
  println(newVal);
  
  k.rangeToggle.setValue(newVal);
  b.rangeToggle.setValue(newVal);
  maxA1.rangeToggle.setValue(newVal);
  freq1.rangeToggle.setValue(newVal);
  maxA2.rangeToggle.setValue(newVal);
  freq2.rangeToggle.setValue(newVal);
}

void toggleAudioLock() {
  boolean newval = !(
    audFreq.getRangeEnable() && audMix.getRangeEnable() && audAtk.getRangeEnable() &&
    audRel.getRangeEnable() && audReson.getRangeEnable()
  );
  audFreq.rangeToggle.setValue(newval);
  audMix.rangeToggle.setValue(newval);
  audAtk.rangeToggle.setValue(newval);
  audRel.rangeToggle.setValue(newval);
  audReson.rangeToggle.setValue(newval);
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
      activeSwatch.setParams(new HapticParams(clipboard)); //<>//
      activateSwatch(activeSwatch); // Necessary to update the parameter objects associated to the UI elements
      refreshRangeSliders();
    }
  }
}
