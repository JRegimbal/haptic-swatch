static class HapticSwatch {
  public PVector center; // m
  public float radius; // m
  public float k, mu, maxAL, maxAH;
  private float lastK, lastMu, lastAL, lastAH;
  private int id;
  static final float vTh = 0.015; // m/s
  private static int nextID = 0;
  static final long inactiveTime = 500000000; // 500 ms 
  public long lastForceTime = 0;
  boolean active = false;
  
  public HapticSwatch(float x, float y, float r) {
    center = new PVector(x, y);
    radius = r;
    k = mu = maxAL = maxAH = 0;
    id = (HapticSwatch.nextID++);
  }
  
  public int getId() { return id; }
  public void touch() {
    lastForceTime = System.nanoTime();
  }
  public boolean isActive() {
    return (System.nanoTime() - lastForceTime < inactiveTime);
  }
  
  public boolean newState() {
    return (k != lastK) || (mu != lastMu) || (maxAL != lastAL) || (maxAH != lastAH);
  }
  
  public void refresh() {
    lastK = k;
    lastMu = mu;
    lastAL = maxAL;
    lastAH = maxAH;
  }
}
