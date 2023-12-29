import java.util.List;

ArrayList<Handle> handleBuffer = new ArrayList<Handle>();
PVector moveInterimCoordinates = null;
int nextID = 0;

class Handle {
  PVector pos;
  final float r = 0.0025;
  int id = -1;
  
  Handle(float _x, float _y) {
    pos = new PVector(_x, _y);
  }
  
  Handle(float _x, float _y, int _id) {
    this(_x, _y);
    id = _id;
  }
  
  void display() {
    boolean isSelected = handleBuffer != null && handleBuffer.contains(this);
    color oldFill = g.fillColor;
    if (isSelected) {
      fill(255, 0, 0);
    }
    shape(create_ellipse(pos.x, pos.y, r, r));
    if (isSelected) {
      fill(oldFill);
    }
  }
}

class HapticSwatch {
  public float radius; // m
  public Handle h;
  public float k, mu, maxA1, maxA2, freq1, freq2;
  protected float lastK, lastMu, lastA1, lastA2, lastF1, lastF2;
  public boolean checkK, checkMu, checkA1, checkA2, checkF1, checkF2;
  private int id;
  public long elapsed = 0;
  
  static final long inactiveTime = 500000000; // 500 ms 
  public long lastForceTime = 0;
  public boolean requestPending = false;
  boolean ready = false; // sets to true once after first init to avoid race conditions with activate actions
  
  public HapticSwatch(float x, float y, float r) {
    id = (nextID++);
    h = new Handle(x, y, id);
    radius = r;
    reset();
    checkK = checkMu = checkA1 = checkA2 = checkF1 = checkF2 = true;
  }

  public void reset() {
    k = mu = maxA1 = maxA2 = 0;
    freq1 = freq2 = minF;
  }
  
  public int getId() { return id; }
  
  public void touch() {
    lastForceTime = System.nanoTime();
  }
  
  public String valueString() {
    return "[" + (k - minK) / (maxK - minK) + "," +
      (mu - minMu) / (maxB - minMu) + "," +
      (maxA1 - minAL) / (MAL - minAL) + "," +
      (freq1 - minF) / (maxF - minF) + "," +
      (maxA2 - minAH) / (MAH - minAH) + "," +
      (freq2 - minF) / (maxF - minF) + "]";
  }
  
  public String locString() {
    return "[" + h.pos.x + "," +
      h.pos.y + "," +
      radius + "]";
  }
  
  public boolean isActive() {
    return (System.nanoTime() - lastForceTime < inactiveTime);
  }
  
  public boolean newState() {
    return (k != lastK) || (mu != lastMu) || (maxA1 != lastA1) || (maxA2 != lastA2) || (freq1 != lastF1) || (freq2 != lastF2);
  }
  
  public boolean isTouching(PVector posEE) {
    PVector rDiff = posEE.copy().sub(h.pos);
    return rDiff.mag() < radius;
  }
  
  public void refresh() {
    lastK = k;
    lastMu = mu;
    lastA1 = maxA1;
    lastA2 = maxA2;
    lastF1 = freq1;
    lastF2 = freq2;
  }
  
  ArrayList<Handle> getHandles() {
    return new ArrayList<Handle>(List.of(h));
  }
  
  void display() {
    noFill();
    shape(create_ellipse(h.pos.x, h.pos.y, radius, radius));
    h.display();
  }
  
  PVector force(PVector posEE, PVector velEE, float samp) {
    PVector forceTmp = new PVector(0, 0);
    PVector rDiff = posEE.copy().sub(h.pos);
    float speed = velEE.mag();
    if (isTouching(posEE)) {
      // Spring
      if (k >= 0f) {
        rDiff.setMag(radius - rDiff.mag());
      }
      forceTmp.add(rDiff.mult(k));
      // Friction
      final float vTh = 0.1;
      final float mass = 0.25; // kg
      final float fnorm = mass * 9.81; // kg * m/s^2 (N)
      final float b = fnorm * mu / vTh; // kg / s
      if (speed < vTh) {
        forceTmp.add(velEE.copy().mult(-b));
      } else {
        forceTmp.add(velEE.copy().setMag(-mu * fnorm));
      }
      // Texture
      final float maxV = vTh;
      forceTmp.add(velEE.copy().rotate(HALF_PI).setMag(
          min(maxA2, speed * maxA2 / maxV) * sin(textureConst * freq2* samp) +
          min(maxA1, speed * maxA1 / maxV) * sin(textureConst * freq1 * samp)
      ));
      if (!posEE.equals(posEELast)) {
        // Require end effector to be moving for activation
        touch();
      }
    } else {
      // NOOP
    }
    return forceTmp;
  }
}
