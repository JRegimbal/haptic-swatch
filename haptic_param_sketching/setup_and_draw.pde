/** Main thread */
void setup() {
  size(1000, 650);
  frameRate(baseFrameRate);
  
  swatches.put(0, new HapticSwatch(-0.02, 0.06, 0.01));
  swatches.put(1, new HapticSwatch(0.02, 0.06, 0.01));
  swatches.put(2, new HapticSwatch(-0.02, 0.10, 0.01));
  swatches.put(3, new HapticSwatch(0.02, 0.10, 0.01));
  
  filt = new Butter2();
  log = new Table();
  log.addColumn("force");
  
  /** Controls */
  cp5 = new ControlP5(this);
  k = cp5.addKnob("k")
    .plugTo(swatches.get(0))
    .setRange(0, maxK)
    .setValue(0)
    .setPosition(50, 25)
    .setRadius(50)
    .setCaptionLabel("Spring k")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkK = cp5.addToggle("checkK")
    .plugTo(swatches.get(0))
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 105)
    .onChange(CL);
  b = cp5.addKnob("mu")
    .plugTo(swatches.get(0))
    .setRange(0, maxB)
    .setValue(0) // unitless
    .setPosition(50, 150)
    .setRadius(50)
    .setCaptionLabel("Friction mu")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkMu = cp5.addToggle("checkMu")
    .plugTo(swatches.get(0))
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 230)
    .onChange(CL);
  maxAL = cp5.addKnob("maxAL")
    .plugTo(swatches.get(0))
    .setRange(0, MAL)
    .setValue(0)
    .setPosition(50, 275)
    .setRadius(50)
    .setCaptionLabel("Low Texture Amp. (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkAL = cp5.addToggle("checkAL")
    .plugTo(swatches.get(0))
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 355)
    .onChange(CL);
  maxAH = cp5.addKnob("maxAH")
    .plugTo(swatches.get(0))
    .setRange(0, MAH)
    .setValue(0)
    .setPosition(50, 400)
    .setRadius(50)
    .setCaptionLabel("Texture Amp. (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  checkAH = cp5.addToggle("checkAH")
    .plugTo(swatches.get(0))
    .setValue(true)
    .setSize(20, 20)
    .setPosition(150, 480)
    .onChange(CL);
  manualTog = cp5.addToggle("isManual")
    .setPosition(75, 525)
    .setCaptionLabel("Manual/Autonomous")
    .setColorCaptionLabel(color(20, 20, 20));
    
  cp5.addRadioButton("mode")
    .setPosition(825, 125)
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
  scheduler.scheduleAtFixedRate(ot, 1, 500, MILLISECONDS);
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
    
    // Process move action since last frame
    PVector mouse = pixel_to_graphics(mouseX, mouseY);
    if (mousePressed && mode == InputMode.MOVE && moveInterimCoordinates != null) {
      for (Handle h : handleBuffer) {
        h.pos.x += mouse.x - moveInterimCoordinates.x;
        h.pos.y += mouse.y - moveInterimCoordinates.y;
      }
      moveInterimCoordinates = mouse;
    }
    
    // Show swatches
    for (HapticSwatch s : swatches.values()) {
      s.display();
    }
    
    // Show 2DIY
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
    
    // Process change in autonomous/manual update mode
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
