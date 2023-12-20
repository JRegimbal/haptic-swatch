import java.util.ArrayList;
import processing.core.PVector;

public class Butter2 implements Filter {  // 20 Hz at 1 kHz Butterworth
  private double coeffB[] = { 3.6217e-03,  7.2434e-03, 3.6217e-03 };
  private double coeffA[] = { -1.8227, 0.8372 }; // 1 implied
  private ArrayList<PVector> memory;
  private PVector outputs[] = { new PVector(0, 0), new PVector(0, 0) };
  public Butter2() {
    memory = new ArrayList<PVector>();
    for (int i = 0; i < coeffB.length; i++) {
      memory.add(new PVector(0, 0));
    }
  }
  public PVector push(PVector v) {
    memory.add(0, v);
    return memory.remove(memory.size() - 1);
  }
  public PVector calculate() {
    PVector tmp = new PVector(0, 0);
    for (int i = 0; i < coeffB.length; i++) {
      tmp.add(PVector.mult(memory.get(i), (float)coeffB[i]));
    }
    for (int i = 0; i < coeffA.length; i++) {
      tmp.sub(PVector.mult(outputs[i], (float)coeffA[i]));
    }
     //<>// //<>// //<>//
    outputs[1] = outputs[0];
    outputs[0] = new PVector(tmp.x, tmp.y);
    return tmp;
  }
}
