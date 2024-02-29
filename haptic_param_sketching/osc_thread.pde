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
              msg.add((s.k.value - minK) / (maxK - minK));
              msg.add((s.mu.value - minMu) / (maxB - minMu));
              msg.add((s.maxA1.value - minAL) / (MAL - minAL));
              msg.add((s.freq1.value - minF) / (maxF - minF));
              msg.add((s.maxA2.value - minAH) / (MAH - minAH));
              msg.add((s.freq2.value - minF) / (maxF - minF));
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
    swatch.k.value = message.get(1).floatValue() * (maxK - minK) + minK;
    swatch.mu.value = message.get(2).floatValue() * (maxB - minMu) + minMu;
    swatch.maxA1.value = message.get(3).floatValue() * (MAL - minAL) + minAL;
    swatch.freq1.value = message.get(4).floatValue() * (maxF - minF) + minF;
    swatch.maxA2.value = message.get(5).floatValue() * (MAH - minAH) + minAH;
    swatch.freq2.value = message.get(6).floatValue() * (maxF - minF) + minF;
    row.setString("primary", swatch.valueString());
    row.setString("secondary", "agent");
  }
  refreshRangeSliders();
}
