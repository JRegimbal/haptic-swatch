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
              msg = s.addNormMessage(msg);
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
  if (message.checkAddrPattern("/controller/agentSet")) {
    int ID = message.get(0).intValue();
    HapticSwatch swatch = swatches.get(ID);
    synchronized(swatch) {
      TableRow row = log.addRow();
      row.setString("timestamp", OffsetDateTime.now().toString());
      row.setString("command", "modify");
      row.setInt("element", ID);
      swatch.processOscSet(message);
      row.setString("primary", swatch.valueString());
      row.setString("secondary", "agent");
    }
    refreshRangeSliders();
    return;
  } else if (message.checkAddrPattern("/controller/rewardImpact")) {
    int ID = message.get(0).intValue();
    if (ID == activeSwatch.getId()) {
      message.printData();
    }
  }
  println("Unexpected message: " + message.addrPattern());
}
