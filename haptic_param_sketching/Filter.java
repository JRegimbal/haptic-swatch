import processing.core.PVector;
import java.util.ArrayList;

public interface Filter {
  PVector push(PVector v);
  PVector calculate();
}

/*
public class Filter {
  private ArrayList<PVector> memory;
  // FIR with cutoff around 15 Hz (fir1 in Octave)
  final private static double[] coeff = {
    1.1470e-04, 1.5628e-04, 2.0445e-04, 2.6206e-04, 3.3204e-04, 4.1736e-04, 5.2099e-04, 6.4589e-04, 7.9491e-04, 9.7080e-04,
    1.1761e-03, 1.4133e-03, 1.6845e-03, 1.9915e-03, 2.3359e-03, 2.7190e-03, 3.1415e-03, 3.6040e-03, 4.1066e-03, 4.6488e-03,
  5.2298e-03, 5.8484e-03, 6.5029e-03, 7.1911e-03, 7.9105e-03, 8.6581e-03, 9.4305e-03, 1.0224e-02, 1.1034e-02, 1.1857e-02,
    1.2688e-02, 1.3522e-02, 1.4354e-02, 1.5178e-02, 1.5989e-02, 1.6783e-02, 1.7553e-02, 1.8294e-02, 1.9001e-02, 1.9669e-02,
    2.0294e-02, 2.0870e-02, 2.1393e-02, 2.1860e-02, 2.2267e-02, 2.2611e-02, 2.2890e-02, 2.3101e-02, 2.3242e-02, 2.3313e-02,
    2.3313e-02, 2.3242e-02, 2.3101e-02, 2.2890e-02, 2.2611e-02, 2.2267e-02, 2.1860e-02, 2.1393e-02, 2.0870e-02, 2.0294e-02,
    1.9669e-02, 1.9001e-02, 1.8294e-02, 1.7553e-02, 1.6783e-02, 1.5989e-02, 1.5178e-02, 1.4354e-02, 1.3522e-02, 1.2688e-02,
    1.1857e-02, 1.1034e-02, 1.0224e-02, 9.4305e-03, 8.6581e-03, 7.9105e-03, 7.1911e-03, 6.5029e-03, 5.8484e-03, 5.2298e-03,
    4.6488e-03, 4.1066e-03, 3.6040e-03, 3.1415e-03, 2.7190e-03, 2.3359e-03, 1.9915e-03, 1.6845e-03, 1.4133e-03, 1.1761e-03,
    9.7080e-04, 7.9491e-04, 6.4589e-04, 5.2099e-04, 4.1736e-04, 3.3204e-04, 2.6206e-04, 2.0445e-04, 1.5628e-04, 1.1470e-04,
  };
  
  public Filter() {
    memory = new ArrayList<PVector>();
    for (int i = 0; i < coeff.length; i++) {
      memory.add(new PVector(0, 0));
    }
  }
  
  PVector push(PVector v) {
    memory.add(0, v);
    return memory.remove(memory.size() - 1);
  }
  
  PVector calc() {
    PVector tmp = new PVector(0, 0);
    for (int i = 0; i < coeff.length; i++) {
      tmp.set(tmp.add(memory.get(i).mult((float)Filter.coeff[i])));
    }
    return tmp;
  }

}*/
