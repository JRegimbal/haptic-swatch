import controlP5.*;

class RangeSlider {
  Slider slider;
  Range range;
  Toggle rangeToggle;
  ControlP5 cp5;
  int space = 25;
  int Height = 20;
  CallbackListener CL;
  protected float diff = 1.0f;
  protected boolean rangeLock = false, autoLock = false;
  
  public RangeSlider(String name, ControlP5 cp5, int x, int y, int Width) {
    slider = cp5.addSlider(name + "-slider")
      .setColorCaptionLabel(color(20, 20, 20))
      .setHeight(Height)
      ;
    range = cp5.addRange(name + "-range")
      .setBroadcast(false)
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
            setRangeLock(rangeToggle.getBooleanValue());
          }
        }
      })
      ;
    this.setPosition(x, y);
    this.setWidth(Width);
    slider.setValue(0)
      .setRange(0, 100)
      ;
    range.setRange(0, 100)
      .setRangeValues(0, 100)
      .setBroadcast(true)
      ;
    this.cp5 = cp5;
        
    CL = new CallbackListener() {
      public void controlEvent(CallbackEvent evt) {
        Controller c = evt.getController();
        if (c.equals(slider)) {
          if (slider.getValue() < range.getLowValue()) {
            range.setLowValue(slider.getValue());
          }
          if (slider.getValue() > range.getHighValue()) {
            range.setHighValue(slider.getValue());
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
          range.setBroadcast(true);
        }
      }
    };
    
    slider.onChange(CL);
    range.onChange(CL);
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
  
  public float getLowValue() {
    return range.getLowValue();
  }
  
  public float getHighValue() {
    return range.getHighValue();
  }
  
  public float getValue() {
    return slider.getValue();
  }
  
  protected void refreshLocks() {
    if (autoLock) {
      slider.lock();
      range.lock();
    } else if (rangeLock) {
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
  
  public void setRangeLock(boolean lock) {
    this.rangeLock = lock;
    this.refreshLocks();
  }
}
