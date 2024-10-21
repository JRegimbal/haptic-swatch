import controlP5.*;

class RangeSlider {
  Slider slider;
  Range range;
  Toggle rangeToggle;
  ControlP5 cp5;
  int space = 25;
  int Height = 20;
  CallbackListener CL;
  private int defaultForeground;
  protected float diff = 1.0f;
  protected boolean rangeEnable = true, autoLock = false;
  protected Parameter param = null;
  
  public RangeSlider(String name, ControlP5 cp5, int x, int y, int Width) {
    slider = cp5.addSlider(name + "-slider")
      .setColorCaptionLabel(color(20, 20, 20))
      .setHeight(Height)
      ;
    defaultForeground = slider.getColor().getForeground();
    range = cp5.addRange(name + "-range")
      .setColorCaptionLabel(color(20, 20, 20))
      .setCaptionLabel("Auto Range")
      .setHeight(Height);
    rangeToggle = cp5.addToggle(name + "-toggle")
      .setSize(20, 20)
      .setCaptionLabel("LCK")
      .onChange(new CallbackListener() {
        public void controlEvent(CallbackEvent evt) {
          Controller c = evt.getController();
          if (c.equals(rangeToggle)) {
            setRangeEnable(rangeToggle.getBooleanValue());
          }
        }
      })
      ;
    this.setPosition(x, y);
    this.setWidth(Width);

    this.cp5 = cp5;
        
    CL = new CallbackListener() {
      public void controlEvent(CallbackEvent evt) {
        Controller c = evt.getController();
        if (c.equals(slider)) {
          resetForeground();
          if (slider.getValue() < range.getLowValue()) {
            range.setLowValue(slider.getValue());
          }
          if (slider.getValue() > range.getHighValue()) {
            range.setHighValue(slider.getValue());
          }
          if (param != null) {
            param.value = slider.getValue();
          }
        } else if (c.equals(range)) {
          range.setBroadcast(false);
          if (slider.getValue() < range.getLowValue()) {
            range.setLowValue(slider.getValue());
          }
          if (slider.getValue() > range.getHighValue()) {
            range.setHighValue(slider.getValue() + diff);
            range.update();
          }
          if (param != null) {
            param.low = range.getLowValue();
            param.high = range.getHighValue();
          }
          range.setBroadcast(true);
        } else if (c.equals(rangeToggle)) {
          if (param != null) {
            param.parameterEnable = rangeToggle.getBooleanValue();
          }
        }
      }
    };
    
    slider.onChange(CL);
    range.onChange(CL);
  }
  
  public RangeSlider setRange(float min, float max) {
    slider.setRange(min, max);
    range.setRange(min, max);
    range.setRangeValues(min, max);
    this.diff = (max - min) / 50f;
    return this;
  }
  
  public RangeSlider setPosition(int x, int y) {
    range.setPosition(x, y);
    slider.setPosition(x, y + space);
    rangeToggle.setPosition(x - 30, y);
    return this;
  }
  
  public RangeSlider setWidth(int w) {
    range.setWidth(w);
    slider.setWidth(w);
    return this;
  }
  
  public RangeSlider setCaptionLabel(String label) {
    slider.setCaptionLabel(label);
    return this;
  }
  
  public RangeSlider setFont(ControlFont f) {
    slider.setFont(f);
    return this;
  }
  
  public float getLowValue() {
    return range.getLowValue();
  }
  
  public float getHighValue() {
    return range.getHighValue();
  }
  
  public float getValue() {
    return slider.getValue();
  }
  
  public void setValue(Parameter p) {
    if (slider.getValue() != p.value) {
      slider.setColorForeground(color(255, 0, 0));
    } else {
      resetForeground();
    }
    slider.setBroadcast(false)
      .setValue(p.value)
      .setBroadcast(true);
    range.setBroadcast(false)
      .setLowValue(p.low)
      .update()
      .setHighValue(p.high)
      .update()
      .setBroadcast(true);
    if (p.parameterEnable != rangeToggle.getBooleanValue()) {
      rangeToggle.setValue(p.parameterEnable);
    }
  }
  
  public void resetForeground() {
    slider.setColorForeground(defaultForeground);
  }
  
  public void setParameter(Parameter p) {
    this.param = p;
  }
  
  protected void refreshLocks() {
    if (autoLock) {
      slider.lock();
      range.lock();
    } else if (!rangeEnable) {
      range.lock();
      slider.unlock();
    } else {
      slider.unlock();
      range.unlock();
    }
  }
  
  public void setAutoLock(boolean lock) {
    this.autoLock = lock;
    this.refreshLocks();
  }
  
  public void setRangeEnable(boolean enable) {
    this.rangeEnable = enable;
    if (param != null) {
      this.param.parameterEnable = this.rangeEnable;
    }
    this.refreshLocks();
  }
}
