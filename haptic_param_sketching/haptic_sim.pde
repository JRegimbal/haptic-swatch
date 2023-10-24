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
        PVector forceTmp = new PVector(0, 0);
        PVector rDiff = posEE.copy().sub(s.center);
        if (rDiff.mag() < s.radius) {
          if (!s.active) {
            print("Active: ");
            println(posEE);
            s.active = true;
          }
          // Spring
          rDiff.setMag(s.radius - rDiff.mag());
          forceTmp.add(rDiff.mult(s.k));
          // Friction
          //final float vTh = 0.25; // vibes based, m/s
          //final float vTh = 0.015;
          final float vTh = 0.1;
          final float mass = 0.25; // kg
          final float fnorm = mass * 9.81; // kg * m/s^2 (N)
          final float b = fnorm * s.mu / vTh; // kg / s
          if (speed < vTh) {
            forceTmp.add(velEE.copy().mult(-b));
          } else {
            forceTmp.add(velEE.copy().setMag(-s.mu * fnorm));
          }
          // Texture
          final float maxV = vTh;
          fText.set(velEE.copy().rotate(HALF_PI).setMag(
              min(s.maxAH, speed * s.maxAH / maxV) * sin(textureConst * 150f * samp) +
              min(s.maxAL, speed * s.maxAL / maxV) * sin(textureConst * 25f * samp)
          ));
          forceTmp.add(fText);
          force.add(forceTmp);
          //if (forceTmp.mag() > 0) {
            s.touch();
            force.add(forceTmp);
          //}
          if (posEELast != posEE || forceLast != force) {
            s.touch();
          }
          forceLast.set(force);
          posEELast.set(posEE);
        } else {
          if (s.active) {
            print("Out: ");
            println(posEE);
            s.active = false;
          }
        }
      }
      
      samp = (samp + 1) % targetRate;
      fEE.set(graphics_to_device(force));
      //TableRow row = log.addRow();
      //row.setFloat("force", currTime-lastTime);
    }
    torques.set(widget.set_device_torques(fEE.array()));
    widget.device_write_torques();
    renderingForce = false;
  }
}
