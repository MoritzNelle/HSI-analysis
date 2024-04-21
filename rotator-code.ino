//Firmware for apple rotator device (ARD)
//Version 1.3
//This firmware is part of the bachelor thesis of Moritz Nelle
//Developed in 2023


//including of libaries
#include <Stepper.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

//pin definition
#define trigger 8
#define lightSens A3
#define buzzer 7
#define enter 5
#define refButton 4

//settings
#define stepperSpeed 10 //defines speed of both steppers
#define SPR 2048 //steps per rotation (constant determind by the stepper)


LiquidCrystal_I2C lcd(0x27, 16, 2); //object definition

Stepper Motor1(SPR, 9,11,10,12);  //object and pin definition
Stepper Motor2(SPR, 2, 6, 3,13);  //object and pin definition

int stepsPerTrigger       = 20;   //# of steps the motor will perform for each trigger
int LightThreshold        = 950;  //analog threshhold at which the holder will trigger rotation
int coolDownLightTrigger  = 25;   //time in seconds in which the holder can not be triggered after light tigger
int actAppleStep          = 0;    //stores the actual step, starts from 0
unsigned long timer       = 0;    //timer variable for buzzer sound
//int imageNum              = 0;

void setup() {
  
  Serial.begin(9600);             //initialize serial conection
  
  Motor1.setSpeed(stepperSpeed);  //sets RPM of the stepper
  Motor2.setSpeed(stepperSpeed);

  lcd.init();                     //initialize LCD-display
  //lcd.setBacklight(0);

//define in- and outputs
  pinMode(lightSens, INPUT);
  pinMode(buzzer, OUTPUT);
  pinMode(enter, INPUT);
  pinMode(refButton, INPUT);

  Serial.print("\nMount first Apple. Confirm with ENTER. Integrity check will start."); //UI text
}

void loop() {

  if(digitalRead(enter)){       //checks whether the ENTER button has been pressed
    rogerBeep();                //calls roger beep
    Serial.println("\nIntegrity check. Counter is reset to 0.");//UI text
    integrityCheck();           //calls integrityCheck
  }

  if(digitalRead(refButton)){   //checks whether the REVERSE button has been pressed
    reverseOneStep();           //calls reverseOneStep
    while (digitalRead(refButton)) {delay(70);} //debounce
  }

  if(digitalRead(trigger)){     //checks whether the TRIGGER button has been pressed
    rotateOneStep();            //calls rotateOneStep
    while(digitalRead(trigger)){delay(70);} //debounce
  }

  if(analogRead(lightSens)>950){  //checks light intensity on photodiode
    shortBeep();                  //calls shortBeep
    rotateOneStep();              //calls rotateOneStep
    coolDown();                 //calls coolDown
  }

  //showActStep();
}


void integrityCheck(){        //lets the apple rotate one full rotation forward and then a full ortation backward to the whether the apple is mounted propperly. Also rests apple steps.
  Motor1.setSpeed(10);
  Motor2.setSpeed(10);
  
  for(int i=0; i<SPR; i++){
    Motor1.step(1);
    Motor2.step(-1);
  }

  delay(100);

  for(int i=0; i<SPR; i++){
    Motor1.step(-1);
    Motor2.step(1);
  }

  actAppleStep = 0;
}


void rotateOneStep (){     //lets the apple rotate one external step (e.g.: 3.52 degree = 20 internal motor steps). External spewidth can be modified in 0.176 degree increments by changing stepsPerTrigger-variable. actAppleStep is updated.
  for(int i=0; i<stepsPerTrigger; i++){
    Motor1.step( 1);
    Motor2.step(-1);
  }

  shortBeep();

  actAppleStep = actAppleStep + stepsPerTrigger;

  countAndControl();
}

void reverseOneStep (){ //reverses one external step
  for(int i=0; i<stepsPerTrigger; i++){
    Motor1.step(-1);
    Motor2.step( 1);
  }

  rogerBeep();

  actAppleStep = actAppleStep - stepsPerTrigger;
  
  countAndControl();
}

void coolDown(){  //blocks all input for the time of cool down after light-trigger to avoid multible back-to-back triggers.
  Serial.print("Cool down after light trigger. Elapsed Time [s]: ");
    for(int i = 0; i < coolDownLightTrigger; i++){
      Serial.print(i + 1);
      Serial.print(" ");
      delay(1000);
    }
  Serial.print("\nReady for next trigger.\n");
}

void shortBeep(){ //generates a short beep
  tone(buzzer, 2000);
  delay(200);
  noTone(buzzer);
}

void intervalBeep(){  //generates a short double beep
  if(millis() - timer >= 2000){
    shortBeep();
    delay(50);
    shortBeep();
    timer = millis();
  }
}

void rogerBeep(){ //generates a double beep in diffrent frequenzies
  tone(buzzer,1800);
  delay(150);
  tone(buzzer, 2200);
  delay(150);
  noTone(buzzer);
}

void countAndControl(){ //prints UI-text to serial
  Serial.print("Step: ");
  Serial.print(actAppleStep);
  Serial.print("/");
  Serial.print(SPR);
  Serial.print(" (Image: ");
  Serial.print(actAppleStep/stepsPerTrigger);
  Serial.print(" of ");
  Serial.print(SPR/stepsPerTrigger);
  Serial.println(")");

  if(actAppleStep > SPR){
    Serial.println("This was the last trigger of the current rotation. Press ENTER to mute.");
    while(!digitalRead(enter)){intervalBeep();}
    while( digitalRead(enter)){}
    delay(200);
    actAppleStep = 0;
    Serial.println("Start integrity check with enter.");
  }
}

void showActStep(){ //prints UI-text to serial
  lcd.print("Step: ");
  lcd.print(actAppleStep/stepsPerTrigger);
  lcd.print(" / ");
  lcd.print(SPR/stepsPerTrigger);
}
