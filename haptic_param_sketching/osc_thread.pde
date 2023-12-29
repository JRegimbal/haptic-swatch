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
              msg.add((s.k - minK) / (maxK - minK));
              msg.add((s.mu - minMu) / (maxB - minMu));
              msg.add((s.maxA1 - minAL) / (MAL - minAL));
              msg.add((s.freq1 - minF) / (maxF - minF));
              msg.add((s.maxA2 - minAH) / (MAH - minAH));
              msg.add((s.freq2 - minF) / (maxF - minF));
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
  int ID = message.get(0).intValue();
  HapticSwatch swatch = swatches.get(ID);
  synchronized(swatch) {
    TableRow row = log.addRow();
    row.setString("timestamp", OffsetDateTime.now().toString());
    row.setString("command", "modify");
    row.setInt("element", ID);
    swatch.k = message.get(1).floatValue() * (maxK - minK) + minK;
    swatch.mu = message.get(2).floatValue() * (maxB - minMu) + minMu;
    swatch.maxA1 = message.get(3).floatValue() * (MAL - minAL) + minAL;
    swatch.freq1 = message.get(4).floatValue() * (maxF - minF) + minF;
    swatch.maxA2 = message.get(5).floatValue() * (MAH - minAH) + minAH;
    swatch.freq2 = message.get(6).floatValue() * (maxF - minF) + minF;
    row.setString("primary", swatch.valueString());
    row.setString("secondary", "agent");
  }
  refreshKnobs();
}

float rewardFromDuration(long elapsedMs) {
  final float oneAtMs = 5000;
  final float bias = -0.5;
  return sqrt((float)(elapsedMs / oneAtMs)) + bias;
}
