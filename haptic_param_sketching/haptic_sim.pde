/** Haptics simulation */
class SimulationThread implements Runnable {
  float samp = 0;
  PVector forceLast = new PVector(0, 0);
  
  public void run() {
    renderingForce = true;
    PVector force = new PVector(0, 0);
    lastTime = currTime;
    currTime = System.nanoTime();
    if (haplyBoard.data_available()) {
      widget.device_read_data();
      angles.set(widget.get_device_angles());
      posEE.set(widget.get_device_position(angles.array()));
      posEE.set(device_to_graphics(posEE));
      velEE.set(PVector.mult(PVector.sub(posEE, posEELast),((1000000000f)/(currTime-lastTime))));
      // LPF
      filt.push(velEE.copy());
      velEE.set(filt.calculate());
            
      final float speed = velEE.mag();
      if (speed > maxSpeed) maxSpeed = speed;
      
      // Calculate force
      for (HapticSwatch s : swatches) {
        force.add(s.force(posEE, velEE, samp));
      }
      forceLast.set(force);
      posEELast.set(posEE);
      samp = (samp + 1) % targetRate;
      fEE.set(graphics_to_device(force));
    }
    torques.set(widget.set_device_torques(fEE.array()));
    widget.device_write_torques();
    renderingForce = false;
  }
}
