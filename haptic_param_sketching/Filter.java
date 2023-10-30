import processing.core.PVector;
import java.util.ArrayList;

public interface Filter {
  PVector push(PVector v);
  PVector calculate();
}
