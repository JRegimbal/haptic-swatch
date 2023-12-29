/** Main thread */
void setup() {
  size(1600, 650);
  frameRate(baseFrameRate);
    
  filt = new Butter2();
  
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
  k = cp5.addKnob("k")
    .setRange(minK, maxK)
    .setValue(0)
    .setPosition(50, 25)
    .setRadius(50)
    .setCaptionLabel("Spring k")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL)
    .onChange(knobLog);
  checkK = cp5.addToggle("checkK")
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 105)
    .onChange(CL);
  b = cp5.addKnob("mu")
    .setRange(minMu, maxB)
    .setValue(0) // unitless
    .setPosition(200, 25)
    .setRadius(50)
    .setCaptionLabel("Friction mu")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL)
    .onChange(knobLog);
  checkMu = cp5.addToggle("checkMu")
    .setValue(true)
    .setSize(20, 20)
    .setPosition(300, 105)
    .onChange(CL);
  maxA1 = cp5.addKnob("maxA1")
    .setRange(minAL, MAL)
    .setValue(0)
    .setPosition(50, 150)
    .setRadius(50)
    .setCaptionLabel("Max Vib. 1 (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL)
    .onChange(knobLog);
  checkA1 = cp5.addToggle("checkA1")
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 230)
    .onChange(CL);
  freq1 = cp5.addKnob("freq1")
    .setRange(minF, maxF)
    .setValue(minF)
    .setPosition(200, 150)
    .setRadius(50)
    .setCaptionLabel("Vib. Freq. 1 (Hz)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL)
    .onChange(knobLog);
  checkF1 = cp5.addToggle("checkF1")
    .setValue(true)
    .setSize(20, 20)
    .setPosition(300, 230)
    .onChange(CL);
  maxA2 = cp5.addKnob("maxA2")
    .setRange(minAH, MAH)
    .setValue(0)
    .setPosition(50, 275)
    .setRadius(50)
    .setCaptionLabel("Max Vib. 2 (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL)
    .onChange(knobLog);
  checkA2 = cp5.addToggle("checkA2")
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 355)
    .onChange(CL);
  freq2 = cp5.addKnob("freq2")
    .setRange(minF, maxF)
    .setValue(minF)
    .setPosition(200, 275)
    .setRadius(50)
    .setCaptionLabel("Vib. Freq. 2 (Hz)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL)
    .onChange(knobLog);
  checkF2 = cp5.addToggle("checkF2")
    .setValue(true)
    .setSize(20, 20)
    .setPosition(300, 355)
    .onChange(CL);
  manualTog = cp5.addToggle("isManual")
    .setPosition(75, 600)
    .setSize(100, 25)
    .setCaptionLabel("Manual/Autonomous Toggle (Z)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setMode(ControlP5.SWITCH)
    .onChange(modeLog);
    
  posPathFb = cp5.addButton("processPosPathFb")
    .setPosition(50, 450)
    .setSize(100,50)
    .setValue(1)
    .setLabel("Like this path (Q)");  
  negPathFb = cp5.addButton("processNegPathFb")
    .setPosition(50, 510)
    .setSize(100, 50)
    .setValue(0)
    .setLabel("Dislike this path (A)");
    
  posZoneFb = cp5.addButton("processPosZoneFb")
    .setPosition(200, 450)
    .setSize(100, 50)
    .setValue(1)
    .setLabel("Like this zone (W)");
  negPathFb = cp5.addButton("processNegZoneFb")
    .setPosition(200, 510)
    .setSize(100, 50)
    .setValue(0)
    .setLabel("Dislike this zone (S)");
    
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
    
  cp5.addRadioButton("mode")
    .setPosition(1325, 125)
    .setSize(20, 20)
    .setItemsPerRow(1)
    .setSpacingRow(25)
    .addItem("Select", 0)
    .addItem("Move", 1)
    .addItem("Circle", 2)
    .setColorLabel(color(0))
    .activate(0)
    ;
    
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
    int xcoord = 1500;
    textAlign(RIGHT);
    text("Delay (us): " + nf((int)((currTime - lastTime) / 1000), 4), xcoord, 40);
    text("Vel (mm/s): " + nf((int)(velEE.mag() * 1000), 3), xcoord, 60);
    text("Max speed (mm/s): " + nf((int)(maxSpeed * 1000), 3), xcoord, 80);
    text("Texture (N): " + nf((int)fEE.mag()), xcoord, 100);
    textAlign(CENTER);
    text(selText, 100, 20);
    fill(255, 255, 255);
    
    // Process move action since last frame
    PVector mouse = pixel_to_graphics(mouseX, mouseY);
    if (mousePressed && mode == InputMode.MOVE && moveInterimCoordinates != null) {
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
      if (isManual) {
        k.unlock();
        b.unlock();
        maxA1.unlock();
        maxA2.unlock();
        freq1.unlock();
        freq2.unlock();
      } else {
        k.lock();
        b.lock();
        maxA1.lock();
        maxA2.lock();
        freq1.lock();
        freq2.lock();
      }
      OscMessage msg = new OscMessage("/uistate/setAutonomous");
      msg.add(isManual);
      oscp5.send(msg, oscDestination);
      lastMode = isManual;
    }
  }
}
