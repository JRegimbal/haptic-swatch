/** Main thread */
void setup() {
  size(1280, 650);
  frameRate(baseFrameRate);
    
  filt = new Butter2();
  PFont pfont = createFont("Sans", 20);
  ControlFont font = new ControlFont(pfont, 12);
  
  /** Logging */
  log = new Table();
  log.addColumn("timestamp");
  log.addColumn("command");
  log.addColumn("element");
  log.addColumn("primary");
  log.addColumn("secondary");
  
  // Start time row for reference
  TableRow row = log.addRow();
  row.setString("timestamp", OffsetDateTime.now().toString());
  row.setString("command", "start");
  
  /** Controls */
  cp5 = new ControlP5(this);
  k = new RangeSlider("k", cp5, 50, 25, 100)
    .setRange(minK, maxK)
    .setCaptionLabel("Spring k")
    //.onChange(knobLog)
    //.setFont(font)
    ;
  k.slider.onChange(knobLog);
  k.rangeToggle.onChange(CL);
  b = new RangeSlider("mu", cp5, 250, 25, 100)
    .setRange(minMu, maxB)
    .setCaptionLabel("Friction mu")
    //.setFont(font)
    //.onChange(knobLog)
    ;
  b.slider.onChange(knobLog);
  b.rangeToggle.onChange(CL);
  maxA1 = new RangeSlider("maxA1", cp5, 50, 100, 100)
    .setRange(minAL, MAL)
    .setCaptionLabel("Max Vib. 1 (N)")
    //.setFont(font)
    //.onChange(knobLog)
    ;
  maxA1.slider.onChange(knobLog);
  maxA1.rangeToggle.onChange(CL);
  freq1 = new RangeSlider("freq1", cp5, 250, 100, 100)
    .setRange(minF, maxF)
    .setCaptionLabel("Vib. Freq. 1 (Hz)")
    //.setFont(font)
    //.onChange(knobLog)
    ;
  freq1.slider.onChange(knobLog);
  freq1.rangeToggle.onChange(CL);
  maxA2 = new RangeSlider("maxA2", cp5, 50, 175, 100)
    .setRange(minAH, MAH)
    .setCaptionLabel("Max Vib. 2 (N)")
    //.setFont(font)
    //.onChange(knobLog)
    ;
  maxA2.slider.onChange(knobLog);
  maxA2.rangeToggle.onChange(CL);
  freq2 = new RangeSlider("freq2", cp5, 250, 175, 100)
    .setRange(minF, maxF)
    .setCaptionLabel("Vib. Freq. 2 (Hz)")
    //.setFont(font)
    //.onChange(knobLog)
    ;
  freq2.slider.onChange(knobLog);
  freq2.rangeToggle.onChange(CL);
  audFreq = new RangeSlider("audFreq", cp5, 50, 250, 100)
    .setRange(minAudF, maxAudF) // A2 to A5
    .setCaptionLabel("Frequency (Hz)")
    ;
  audFreq.slider.onChange(knobLog);
  audFreq.rangeToggle.onChange(CL);
  audMix = new RangeSlider("audMix", cp5, 250, 250, 100)
    .setRange(minMix, maxMix)
    .setCaptionLabel("Noise Mix")
    ;
  audMix.slider.onChange(knobLog);
  audMix.rangeToggle.onChange(CL);
  audAtk = new RangeSlider("audAtk", cp5, 50, 325, 100)
    .setRange(minAtk, maxAtk)
    .setCaptionLabel("Attack (s)")
    ;
  audAtk.slider.onChange(knobLog);
  audAtk.rangeToggle.onChange(CL);
  audRel = new RangeSlider("audRel", cp5, 250, 325, 100)
    .setRange(minRel, maxRel)
    .setCaptionLabel("Release (s)")
    ;
  audRel.slider.onChange(knobLog);
  audRel.rangeToggle.onChange(CL);
  audReson = new RangeSlider("audReson", cp5, 50, 400, 100)
    .setRange(minReson, maxReson)
    .setCaptionLabel("Resonance")
    ;
  audReson.slider.onChange(knobLog);
  audReson.rangeToggle.onChange(CL);
  
  if (useAgent) {
    manualTog = cp5.addToggle("isManual")
      .setPosition(75, 600)
      .setSize(100, 25)
      .setCaptionLabel("Manual/Autonomous Toggle (Z)")
      .setFont(font)
      .setColorCaptionLabel(color(20, 20, 20))
      .setMode(ControlP5.SWITCH)
      .onChange(modeLog);
      
    posPathFb = cp5.addButton("processPosPathFb")
      .setPosition(50, 450)
      .setSize(100,50)
      .setValue(1)
      .setFont(font)
      .setLabel("Like this\npath (Q)");  
    negPathFb = cp5.addButton("processNegPathFb")
      .setPosition(50, 510)
      .setSize(100, 50)
      .setValue(0)
      .setFont(font)
      .setLabel("Dislike this\npath (A)");
      
    posZoneFb = cp5.addButton("processPosZoneFb")
      .setPosition(200, 450)
      .setSize(100, 50)
      .setValue(1)
      .setFont(font)
      .setLabel("Like this\nzone (W)");
    negPathFb = cp5.addButton("processNegZoneFb")
      .setPosition(200, 510)
      .setSize(100, 50)
      .setValue(0)
      .setFont(font)
      .setLabel("Dislike this\nzone (S)");
  }
    
  /*rewardModeToggle = cp5.addToggle("rewardMode")
    .setPosition(75, 575)
    .setValue(false)
    .setCaptionLabel("Attention/Explicit")
    .setColorCaptionLabel(color(20, 20, 20))
    .setMode(ControlP5.SWITCH)
    .onChange(new CallbackListener() {
      public void controlEvent(CallbackEvent evt) {
        Controller c = evt.getController();
        if (c.equals(rewardModeToggle)) {
          if (rwMode == RewardMode.EXPLICIT) {
            rwMode = RewardMode.ATTENTION;
          } else if (rwMode == RewardMode.ATTENTION) {
            rwMode = RewardMode.EXPLICIT;
          } else {
            println("ERROR: Unexpected reward mode state: " + rwMode);
          }
          println(rwMode);
        }
      }
    });*/
    
  modeRadio = cp5.addRadioButton("mode")
    .setPosition(1205, 125)
    .setSize(20, 20)
    .setItemsPerRow(1)
    .setSpacingRow(25)
    .addItem("Select", 0)
    .addItem("Circle", 1)
    .setColorLabel(color(0))
    .activate(0)
    ;
  
  for(Toggle t: modeRadio.getItems()) {
    t.setFont(font);
  }
    
  copyButton = cp5.addButton("copyActive")
    .setPosition(1040, 450)
    .setSize(100, 50)
    .setFont(font)
    .setLabel("Copy\nHaptic Params")
    ;
    
  pasteButton = cp5.addButton("pasteToActive")
    .setPosition(1165, 450)
    .setSize(100, 50)
    .setFont(font)
    .setLabel("Paste\nHaptic Params")
    ;
    
  /** Haply */
  haplyBoard = new Board(this, Serial.list()[0], 0);
  widget = haplysetup(widgetID, haplyBoard);
  panto_setup();

  resetAgents();
  
  /** Spawn haptics thread */
  SimulationThread st = new SimulationThread();
  UpdateThread ot = new UpdateThread();
  handle = scheduler.scheduleAtFixedRate(st, 1000, (long)(1000000f / targetRate), MICROSECONDS);
  scheduler.scheduleAtFixedRate(ot, 1, controlElapsedMs, MILLISECONDS);
}

void exit() {
  handle.cancel(true);
  scheduler.shutdown();
  widget.set_device_torques(new float[]{0, 0});
  widget.device_write_torques();
  TableRow row = log.addRow();
  row.setString("timestamp", OffsetDateTime.now().toString());
  row.setString("command", "quit");
  saveTable(log, "data/log.csv");
  OscMessage msg = new OscMessage("/quit");
  oscp5.send(msg, oscDestination);
  println("Quit");
  super.exit();
}

void draw() {
  if (renderingForce == false) {
    background(255);
    
    // Show 2DIY
    update_animation(angles.x * radsPerDegree, angles.y * radsPerDegree, posEE.x, posEE.y);
    fill(0, 0, 0);
    int xcoord = 1180;
    textAlign(RIGHT);
    text("Delay (us): " + nf((int)((currTime - lastTime) / 1000), 4), xcoord, 40);
    text("Vel (mm/s): " + nf((int)(velEE.mag() * 1000), 3), xcoord, 60);
    text("Max speed (mm/s): " + nf((int)(maxSpeed * 1000), 3), xcoord, 80);
    text("Texture (N): " + nf((int)fEE.mag()), xcoord, 100);
    // Clipboard
    textSize(24);
    text("Clipboard value", xcoord, 550);
    textSize(12);
    text("k: " + nf(clipboard.k.value, 3, 2) + "        mu: " + nf(clipboard.mu.value, 1, 2), xcoord, 575);
    text("Vib 1: " + nf(clipboard.maxA1.value, 1, 2) + " Freq 1: " + nf(clipboard.freq1.value, 3, 1), xcoord, 600);
    text("Vib 2: " + nf(clipboard.maxA2.value, 1, 2) + " Freq 2: " + nf(clipboard.freq2.value, 3, 1), xcoord, 625);
    textAlign(CENTER);
    textSize(24);
    text(selText, 100, 20);
    textSize(12);
    fill(255, 255, 255);
    
    // Process move action since last frame
    PVector mouse = pixel_to_graphics(mouseX, mouseY);
    if (mousePressed && mode == InputMode.SELECT && moveInterimCoordinates != null) {
      for (Handle h : handleBuffer) {
        TableRow row = log.addRow();
        row.setString("timestamp", OffsetDateTime.now().toString());
        row.setString("command", "move");
        row.setInt("element", h.id);
        row.setString("primary", "["+h.pos.x+","+h.pos.y+"]");
        h.pos.x += mouse.x - moveInterimCoordinates.x;
        h.pos.y += mouse.y - moveInterimCoordinates.y;
        row.setString("secondary", "["+h.pos.x+","+h.pos.y+"]");
      }
      moveInterimCoordinates = mouse;
    }
    
    // Show swatches
    for (HapticSwatch s : swatches.values()) {
      s.display();
    }
    
    // Draw Workspace bounds
    shape(create_line(-xExtent - 19e-3, 0, -xExtent - 19e-3, yExtent));
    shape(create_line(-xExtent - 19e-3, yExtent, xExtent - 19e-3, yExtent));
    shape(create_line(xExtent - 19e-3, 0, xExtent - 19e-3, yExtent));
    
    // Process change in autonomous/manual update mode
    if (lastMode != isManual) {
      k.setAutoLock(!isManual);
      b.setAutoLock(!isManual);
      maxA1.setAutoLock(!isManual);
      maxA2.setAutoLock(!isManual);
      freq1.setAutoLock(!isManual);
      freq2.setAutoLock(!isManual);
      audFreq.setAutoLock(!isManual);
      audMix.setAutoLock(!isManual);
      audAtk.setAutoLock(!isManual);
      audRel.setAutoLock(!isManual);
      audReson.setAutoLock(!isManual);
      OscMessage msg = new OscMessage("/uistate/setAutonomous");
      msg.add(isManual);
      println("Trig");
      oscp5.send(msg, oscDestination);
      println("Done");
      lastMode = isManual;
    }
  }
}

Device haplysetup(byte widgetID, Board haplyBoard) {
  Device widget = new Device(widgetID, haplyBoard);
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
  return widget;
}
