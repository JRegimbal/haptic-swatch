/**
 **********************************************************************************************************************
 * @file       Pantograph.java
 * @author     Steve Ding, Colin Gallacher
 * @version    V3.0.0
 * @date       15-January-2021
 * @brief      Mechanism extension example
 **********************************************************************************************************************
 * @attention
 *
 *
 **********************************************************************************************************************
 */

import static java.lang.Math.*;


public class Pantograph extends Mechanisms{

  private float l, L, d;
  
  private float th1, th2;
  private float tau1, tau2;
  private float f_x, f_y;
  private float x_E, y_E;
  
  private float pi = 3.14159265359f;
  private float JT11, JT12, JT21, JT22;
  private float gain = 1.0f;
  

  public Pantograph(int hardwareVersion){
  
    if(hardwareVersion == 2){
      this.l = 0.07f;
      this.L = 0.09f;
      this.d = 0.0f;
    }
    else if(hardwareVersion == 3){
      this.l = 0.07f;
      this.L = 0.09f;
      this.d = 0.038f;
    }
    else{
      this.l = 0.07f;
      this.L = 0.09f;
      this.d = 0.038f;
    }
  
  }
  
  
  public void torqueCalculation(float[] force){
    f_x = force[0];
    f_y = force[1];

    
    tau1 = JT11*f_x + JT12*f_y;
    tau2 = JT21*f_x + JT22*f_y;
    
    tau1 = tau1*gain;
    tau2 = tau2*gain;  
  }
  
  public void forwardKinematics(float[] angles){  
    float l1 = l;
    float l2 = l;
    float L1 = L;
    float L2 = L;
    
    th1 = pi/180*angles[0];
    th2 = pi/180*angles[1];

    // Forward Kinematics
    float c1 = (float)cos(th1);
    float c2 = (float)cos(th2);
    float s1 = (float)sin(th1);
    float s2 = (float)sin(th2);
    float xA = l1*c1;
    float yA = l1*s1;
    float xB = d+l2*c2;
     
    float yB = l2*s2;
    float hx = xB-xA; 
    float hy = yB-yA; 
    float hh = (float) pow(hx,2) + (float) pow(hy,2); 
    float hm = (float)sqrt(hh); 
    float cB = - ((float) pow(L2,2) - (float) pow(L1,2) - hh) / (2*L1*hm); 
    
    float h1x = L1*cB * hx/hm; 
    float h1y = L1*cB * hy/hm; 
    float h1h1 = (float) pow(h1x,2) + (float) pow(h1y,2); 
    float h1m = (float) sqrt(h1h1); 
    float sB = (float) sqrt(1-pow(cB,2));  
     
    float lx = -L1*sB*h1y/h1m; 
    float ly = L1*sB*h1x/h1m; 
    
    float x_P = xA + h1x + lx; 
    float y_P = yA + h1y + ly; 
     
    float phi1 = (float)acos((x_P-l1*c1)/L1);
    float phi2 = (float)acos((x_P-d-l2*c2)/L2);
     
    float c11 = (float) cos(phi1); 
    float s11 =(float) sin(phi1); 
    float c22= (float) cos(phi2); 
    float s22 = (float) sin(phi2); 
  
    float dn = L1 *(c11 * s22 - c22 * s11); 
    float eta = (-L1 * c11 * s22 + L1 * c22 * s11 - c1 * l1 * s22 + c22 * l1 * s1)  / dn;
    float nu = l2 * (c2 * s22 - c22 * s2)/dn;
    
    JT11 = -L1 * eta * s11 - L1 * s11 - l1 * s1;
    JT12 = L1 * c11 * eta + L1 * c11 + c1 * l1;
    JT21 = -L1 * s11 * nu;
    JT22 = L1 * c11 * nu;

    x_E = x_P;
    y_E = y_P;    
  }
  
  public void forceCalculation(){
  }
  
  
  public void positionControl(){
  }
  
  
  public void inverseKinematics(){
  }
  
  
  public void set_mechanism_parameters(float[] parameters){
    this.l = parameters[0];
    this.L = parameters[1];
    this.d = parameters[2];
  }
  
  
  public void set_sensor_data(float[] data){
  }
  
  
  public float[] get_coordinate(){
    float temp[] = {x_E, y_E};
    return temp;
  }
  
  
  public float[] get_torque(){
    float temp[] = {tau1, tau2};
    return temp;
  }
  
  
  public float[] get_angle(){
    float temp[] = {th1, th2};
    return temp;
  }





}
