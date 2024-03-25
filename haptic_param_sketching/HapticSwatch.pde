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

class Parameter {
  float value, min, max, low, high;
  boolean parameterEnable;
  
  public Parameter (float value, float min, float max) {
    this.value = value;
    this.min = this.low = min;
    this.max = this.high = max;
    this.parameterEnable = true;
  }
  
  public float normLow() {
    return (this.low - this.min) / (this.max - this.min);
  }
  
  public float normHigh() {
    return (this.high - this.min) / (this.max - this.min);
  }
  
  public float normVal() {
    return (this.value - this.min) / (this.max - this.min);
  }
  
  public OscMessage addNormMessage(OscMessage msg) {
    msg.add(this.normVal());
    msg.add(this.normLow());
    msg.add(this.normHigh());
    return msg;
  }
  
  public void setNormVal(float norm) {
    float newValue = norm * (this.max - this.min) + this.min;
    if (newValue < this.low) {
      println("FP Error: " + newValue + " is lower than " + this.low);
      newValue = this.low;
    } else if (newValue > this.high) {
      println("FP Error: " + newValue + " is greater than " + this.high);
      newValue = this.high;
    }
    this.value = newValue;
  }
}

class HapticParams {
  public Parameter k, mu, maxA1, maxA2, freq1, freq2, audFreq, audMix, audAtk, audRel, audReson;
  
  public HapticParams() {
    k = mu = maxA1 = maxA2 = freq1 = freq2 = audFreq = audMix = audAtk = audRel = audReson = new Parameter(0, 0, 100);
  }
  
  public HapticParams(Parameter k, Parameter mu, Parameter maxA1, Parameter maxA2, Parameter freq1, Parameter freq2, Parameter audFreq, Parameter audMix, Parameter audAtk, Parameter audRel, Parameter audReson) {
    this.k = k;
    this.mu = mu;
    this.maxA1 = maxA1;
    this.maxA2 = maxA2;
    this.freq1 = freq1;
    this.freq2 = freq2;
    this.audFreq = audFreq;
    this.audMix = audMix;
    this.audAtk = audAtk;
    this.audRel = audRel;
    this.audReson = audReson;
  }
}

class HapticSwatch {
  public float radius; // m
  public Handle h;
  public Parameter k, mu, maxA1, maxA2, freq1, freq2, audFreq, audMix, audAtk, audRel, audReson;
  protected float lastK, lastMu, lastA1, lastA2, lastF1, lastF2, lastAudFreq, lastMix, lastAtk, lastRel, lastReson;
  private int id;
  public long elapsed = 0;
  
  static final long inactiveTime = 500000000; // 500 ms 
  public long lastForceTime = 0;
  public boolean lastActive = false;
  public boolean requestPending = false;
  boolean ready = false; // sets to true once after first init to avoid race conditions with activate actions
  
  public HapticParams getParams() {
    return new HapticParams(k, mu, maxA1, maxA2, freq1, freq2, audFreq, audMix, audAtk, audRel, audReson);
  }
  
  public void setParams(HapticParams p) {
    k = p.k;
    mu = p.mu;
    maxA1 = p.maxA1;
    maxA2 = p.maxA2;
    freq1 = p.freq1;
    freq2 = p.freq2;
    audFreq = p.audFreq;
    audMix = p.audMix;
    audAtk = p.audAtk;
    audRel = p.audRel;
    audReson = p.audReson;
  }
  
  public HapticSwatch(float x, float y, float r) {
    id = (nextID++);
    h = new Handle(x, y, id);
    radius = r;
    k = new Parameter(0, minK, maxK);
    mu = new Parameter(0, minMu, maxB);
    maxA1 = new Parameter(0, minAL, MAL);
    maxA2 = new Parameter(0, minAH, MAH);
    freq1 = new Parameter(minF, minF, maxF);
    freq2 = new Parameter(minF, minF, maxF);
    audFreq = new Parameter(minAudF, minAudF, maxAudF);
    audMix = new Parameter(minMix, minMix, maxMix);
    audAtk = new Parameter(minAtk, minAtk, maxAtk);
    audRel = new Parameter(minRel, minRel, maxRel);
    audReson = new Parameter(minReson, minReson, maxReson);

    reset();
    println("Init");
  }

  public void reset() {
    k.value = mu.value = maxA1.value = maxA2.value = 0;
    freq1.value = freq2.value = minF;
    audFreq.value = minAudF;
    audMix.value = minMix;
    audAtk.value = minAtk;
    audRel.value = minRel;
    audReson.value = minReson;
  }
  
  public int getId() { return id; }
  
  public void touch() {
    lastForceTime = System.nanoTime();
  }
  
  public String valueString() {
    return "[" + k.normVal() + "," + k.normLow() + "," + k.normHigh() + "," +
      mu.normVal() + "," + mu.normLow() + "," + mu.normHigh() + "," +
      maxA1.normVal() + "," + maxA1.normLow() + "," + maxA1.normHigh() + "," +
      freq1.normVal() + "," + freq1.normLow() + "," + freq1.normHigh() + "," +
      maxA2.normVal() + "," + maxA2.normLow() + "," + maxA2.normHigh() + "," +
      freq2.normVal() + "," + freq2.normLow() + "," + freq2.normHigh() + "]";
  }
  
  public void processOscSet(OscMessage msg) {
    this.k.setNormVal(msg.get(1).floatValue());
    this.mu.setNormVal(msg.get(2).floatValue());
    this.maxA1.setNormVal(msg.get(3).floatValue());
    this.freq1.setNormVal(msg.get(4).floatValue());
    this.maxA2.setNormVal(msg.get(5).floatValue());
    this.freq2.setNormVal(msg.get(6).floatValue());
    this.audFreq.setNormVal(msg.get(7).floatValue());
    this.audMix.setNormVal(msg.get(8).floatValue());
    this.audAtk.setNormVal(msg.get(9).floatValue());
    this.audRel.setNormVal(msg.get(10).floatValue());
    this.audReson.setNormVal(msg.get(11).floatValue());
  }
  
  public OscMessage addNormMessage(OscMessage msg) {
    msg = this.k.addNormMessage(msg);
    msg = this.mu.addNormMessage(msg);
    msg = this.maxA1.addNormMessage(msg);
    msg = this.freq1.addNormMessage(msg);
    msg = this.maxA2.addNormMessage(msg);
    msg = this.freq2.addNormMessage(msg);
    msg = this.audFreq.addNormMessage(msg);
    msg = this.audMix.addNormMessage(msg);
    msg = this.audAtk.addNormMessage(msg);
    msg = this.audRel.addNormMessage(msg);
    msg = this.audReson.addNormMessage(msg);

    return msg;
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
    return (k.value != lastK) || (mu.value != lastMu) || (maxA1.value != lastA1) || (maxA2.value != lastA2) || (freq1.value != lastF1) || (freq2.value != lastF2) ||
      (audFreq.value != lastAudFreq) || (audMix.value != lastMix) || (audAtk.value != lastAtk) || (audRel.value != lastRel) || (audReson.value != lastReson);
  }
  
  public boolean isTouching(PVector posEE) {
    PVector rDiff = posEE.copy().sub(h.pos);
    return rDiff.mag() < radius;
  }
  
  public void refresh() {
    lastK = k.value;
    lastMu = mu.value;
    lastA1 = maxA1.value;
    lastA2 = maxA2.value;
    lastF1 = freq1.value;
    lastF2 = freq2.value;
    lastAudFreq = audFreq.value;
    lastMix = audMix.value;
    lastAtk = audAtk.value;
    lastRel = audRel.value;
    lastReson = audReson.value;
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
      if (k.value >= 0f) {
        rDiff.setMag(radius - rDiff.mag());
      }
      forceTmp.add(rDiff.mult(k.value));
      // Friction
      final float vTh = 0.1;
      final float mass = 0.25; // kg
      final float fnorm = mass * 9.81; // kg * m/s^2 (N)
      final float b = fnorm * mu.value / vTh; // kg / s
      if (speed < vTh) {
        forceTmp.add(velEE.copy().mult(-b));
      } else {
        forceTmp.add(velEE.copy().setMag(-mu.value * fnorm));
      }
      // Texture
      final float maxV = vTh;
      forceTmp.add(velEE.copy().rotate(HALF_PI).setMag(
          min(maxA2.value, speed * maxA2.value / maxV) * sin(textureConst * freq2.value * samp) +
          min(maxA1.value, speed * maxA1.value / maxV) * sin(textureConst * freq1.value * samp)
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
