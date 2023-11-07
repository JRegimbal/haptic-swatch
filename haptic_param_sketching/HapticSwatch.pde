import java.util.List;

ArrayList<Handle> handleBuffer = new ArrayList<Handle>();
PVector moveInterimCoordinates = null;
int nextID = 0;

class Handle {
  PVector pos;
  final float r = 0.0025;
  
  Handle(float _x, float _y) {
    pos = new PVector(_x, _y);
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
  public float k, mu, maxAL, maxAH;
  protected float lastK, lastMu, lastAL, lastAH;
  public boolean checkK, checkMu, checkAL, checkAH;
  private int id;
  
  static final long inactiveTime = 500000000; // 500 ms 
  public long lastForceTime = 0;
  boolean active = false;
  
  public HapticSwatch(float x, float y, float r) {
    id = (nextID++);
    h = new Handle(x, y);
    radius = r;
    k = mu = maxAL = maxAH = 0;
    checkK = checkMu = checkAL = checkAH = true;
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
  
  public boolean isTouching(PVector posEE) {
    PVector rDiff = posEE.copy().sub(h.pos);
    return rDiff.mag() < radius;
  }
  
  public void refresh() {
    lastK = k;
    lastMu = mu;
    lastAL = maxAL;
    lastAH = maxAH;
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
      if (!active) {
        //print("Active: ");
        //println(posEE);
        active = true;
      }
      // Spring
      rDiff.setMag(radius - rDiff.mag());
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
      fText.set(velEE.copy().rotate(HALF_PI).setMag(
          min(maxAH, speed * maxAH / maxV) * sin(textureConst * 150f * samp) +
          min(maxAL, speed * maxAL / maxV) * sin(textureConst * 25f * samp)
      ));
      forceTmp.add(fText);
      touch();
    } else {
      if (active) {
        //print("Out: ");
        //println(posEE);
        active = false;
      }
    }
    return forceTmp;
  }
}
