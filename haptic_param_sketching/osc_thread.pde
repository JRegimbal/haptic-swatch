/** OSC Data update thread */
class UpdateThread implements Runnable {
  void run() {
    for (HapticSwatch s : swatches.values()) {
      synchronized (s) {
        if (rwMode == RewardMode.EXPLICIT) {
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
              OscMessage msg = new OscMessage("/controller/step");
              msg.add(s.getId());
              oscp5.send(msg, oscDestination);
              // Action applied in oscEvent callback
            }
          } /* else { println("Not Active"); } */
        } else if (rwMode == RewardMode.ATTENTION) {
          if (s.newState()) {
            // Process reward
            s.elapsed = 0;
            s.refresh();
          } else if (s.isActive()) {
            s.elapsed += controlElapsedMs;
            println(s.elapsed);
          }
        } else { println("ERR: Unknown reward mode"); }
      }
    }
  }
}

void oscEvent(OscMessage message) {
  int ID = message.get(0).intValue();  // Pure Data only has floats no ints - temporary
  HapticSwatch swatch = swatches.get(ID);
  synchronized(swatch) {
    swatch.k = message.get(1).floatValue() * maxK;
    swatch.mu = message.get(2).floatValue() * maxB;
    swatch.maxAL = message.get(3).floatValue() * MAL;
    swatch.maxAH = message.get(4).floatValue() * MAH;
  }
  refreshKnobs();
}

float rewardFromDuration(long elapsedMs) {
  final float oneAtMs = 5000;
  final float bias = -0.5;
  return sqrt((float)(elapsedMs / oneAtMs)) + bias;
}
