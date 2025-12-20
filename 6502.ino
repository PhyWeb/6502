//const char ADDR[] = {22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52};
const char ADDR[] = {52,50,48,46,44,42,40,38,36,34,32,30,28,26,24,22};
const char DATA[] = {39, 41, 43, 45, 47, 49, 51, 53};

#define CLOCK 2
#define READ_WRITE 3

void setup() {
  for(int i = 0; i < 16; i += 1) {
    pinMode(ADDR[i], INPUT);
  }
  for(int i = 0; i < 8; i += 1) {
    pinMode(DATA[i], INPUT);
  }
  pinMode(CLOCK, INPUT);
  pinMode(READ_WRITE, INPUT);

  attachInterrupt(digitalPinToInterrupt(CLOCK), onClock, RISING);
  Serial.begin(57600);
}

void onClock(){
  char output[15];

  unsigned int address = 0;
  for(int i = 0; i < 16; i += 1) {
    int bit = digitalRead(ADDR[i]) ? 1 : 0;
    Serial.print(bit);
    address = (address << 1) + bit;
  }

  Serial.print("    ");

  unsigned int data = 0;
  for(int i = 0; i < 8; i += 1) {
    int bit = digitalRead(DATA[i]) ? 1 : 0;
    Serial.print(bit);
    data = (data << 1) + bit;
  }

  sprintf(output, "    %04x  %c  %02x", address, digitalRead(READ_WRITE) ? 'r' : 'W', data);

  Serial.println(output);
}

void loop() {

}
