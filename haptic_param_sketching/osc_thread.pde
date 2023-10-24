/** OSC Data update thread */
class UpdateThread implements Runnable {
  void run() {
    for (HapticSwatch s : swatches) {
      synchronized (s) {
        if (s.isActive()) {
          if (isManual) {
            OscMessage msg = new OscMessage("/controller/manualSet");
            msg.add(s.getId());
            msg.add(s.k / maxK);
            msg.add(s.mu / maxB);
            msg.add(s.maxAL / MAL);
            msg.add(s.maxAH / MAH);
            oscp5.send(msg, oscDestination);
            // TODO check if we should update only once or on each active timestep
          } else {
            // TODO Obtain action a from agent
            OscMessage msg = new OscMessage("/controller/step");
            msg.add(s.getId());
            oscp5.send(msg, oscDestination);
            // Action applied in oscEvent callback
          }
        } /* else { println("Not Active"); } */
      }
    }
  }
}

void oscEvent(OscMessage message) {
  int ID = message.get(0).intValue();  // Pure Data only has floats no ints - temporary
  HapticSwatch swatch = swatches[ID];
  synchronized(swatch) {
    swatch.k = message.get(1).floatValue() * maxK;
    swatch.mu = message.get(2).floatValue() * maxB;
    swatch.maxAL = message.get(3).floatValue() * MAL;
    swatch.maxAH = message.get(4).floatValue() * MAH;
  }
  refreshKnobs();
}
