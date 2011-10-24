/* Serially managed message board

Version: 0.1
   Author: quarterturn
   Date: 10/02/2011
   Hardware: Teensy 2.0
  
   testing for storing and displaying of strings in the on-board EEPROM.   
   
   User interaction is via the serial interface. The serial baudrate is 9600. 
   The interface provides a simple menu selection which should work in most
   terminal emulation programs.
   
*/

// for reading flash memory
#include <avr/pgmspace.h>

// define a pstr that will work with serial print
#define PSTR2(s) (__extension__({static unsigned char __c[] PROGMEM = (s); &__c[0];}))

// for using eeprom memory
#include <avr/eeprom.h>

// memory size of the internal EEPROM in bytes
#define EEPROM_BYTES 1024

// how many strings
// 81 char x 10 strings leaves 211 bytes of eeprom to store stuff
#define NUM_STRINGS 3

// message string size
#define MAX_SIZE 81

// serial baudrate
#define SERIAL_BAUD 9600

// for tracking time in delay loops
// global so it can be used in any function
unsigned long previousMillis;
// a global to contain serial menu input
char menuChar;
// global to track main menu display
byte mainMenuCount = 0;
// global buffer for a string copied from internal FLASH or EEPROM
// initialize to '0'
char currentString[MAX_SIZE] = {0};

// eeprom message string
uint8_t EEMEM ee_msgString1[MAX_SIZE];
uint8_t EEMEM ee_msgString2[MAX_SIZE];
uint8_t EEMEM ee_msgString3[MAX_SIZE];

// loop break flag on input
byte breakout = 0;

//---------------------------------------------------------------------------------------------//
// setup
//---------------------------------------------------------------------------------------------//
void setup()
{
  // set up the serial port
  Serial.begin(SERIAL_BAUD);
  
} // end setup

//---------------------------------------------------------------------------------------------//
// main loop
//---------------------------------------------------------------------------------------------//
void loop()
{ 
  // if there is something in the serial buffer read it
  if (Serial.available() >  0) 
  {
    // print the main menu once
    if (mainMenuCount == 0)
    {
      clearAndHome();
      print(PSTR2("EEPROM String Test - Main Menu")); 
      Serial.println();
      print(PSTR2("----------------------"));
      Serial.println();
      print(PSTR2("1     Show String"));
      Serial.println();
      print(PSTR2("2     Edit String"));
      Serial.println();
      print(PSTR2("<ESC> Exit setup"));
      Serial.println();
      mainMenuCount = 1;
    }
      
    menuChar = Serial.read();
    if (menuChar == '1')
    {
      // show the string
      clearAndHome();
      showString();
    }
    else if (menuChar == '2')
    {
      // edit the string
      clearAndHome();
      editString();
    }
    else if (menuChar == 27)
    {
      mainMenuCount = 1;
    }
  }
  // reset the main menu if the serial connection drops
  mainMenuCount = 0;
}

//---------------------------------------------------------------------------------------------//
// function clearAndHome
// returns the cursor to the home position and clears the screen
//---------------------------------------------------------------------------------------------//
void clearAndHome()
{
  Serial.print(27, BYTE); // ESC
  Serial.print("[2J"); // clear screen
  Serial.print(27, BYTE); // ESC
  Serial.print("[H"); // cursor to home
}

//---------------------------------------------------------------------------------------------//
// function showString
// displays the string stored in EEPROM
//---------------------------------------------------------------------------------------------//
void showString()
{
  byte msgCount = 1;
  
  // clear the terminal
  clearAndHome();
  
  // clear the string in RAM
  sprintf(currentString, "");
  
  // display the menu on entry
  print(PSTR2("Here are the strings"));
  Serial.println();
  print(PSTR2("that are stored in the EEPROM:"));
  Serial.println();
  print(PSTR2("-------------------------"));
  Serial.println();
  // read the string stored in EEPROM starting at address 0 into the RAM string
  while (msgCount <= NUM_STRINGS)
  {
    readEepromBlock(msgCount);
    Serial.print("String ");
    Serial.print(msgCount, DEC);
    Serial.print(": ");
    Serial.println(currentString);
    msgCount++;
  }
  
  Serial.println();
  print(PSTR2("<ESC> return to Main Menu"));
  Serial.flush();

  // poll serial until exit
  while (1)
  {
    // if there is something in the serial buffer read it
    if (Serial.available() >  0) 
    {
      menuChar = Serial.read();
      if (menuChar == 27)
      {
        // set flag to redraw menu
        mainMenuCount = 0;
        // return to main menu and return the mode
        return;
      }
    }
  }
}

//---------------------------------------------------------------------------------------------//
// function editString
// edits the string and writes it to EEPROM
//---------------------------------------------------------------------------------------------//
void editString()
{
  
  // track how many characters entered
  byte cCount;
  // track menu display
  byte displayEditProgramMenu = 0;  
  // input valid flag
  byte inputBad = 1;  
  // slot number
  int slot;
  // track when string is done
  byte stringDone = 0;
  
  // clear the terminal
  clearAndHome();
  
  // clear the string in RAM
  sprintf(currentString, "");
  
  // display the menu on entry
  if (displayEditProgramMenu == 0)
  {
    // display the menu on entry
    print(PSTR2("Enter a new string to be stored in EEPROM"));
    Serial.println();
    print(PSTR2("up to "));
    Serial.print(MAX_SIZE - 1, DEC);
    print(PSTR2(" characters."));
    Serial.println();
    print(PSTR2("-------------------------"));
    Serial.println();
    print(PSTR2("Choose a slot 1 to "));
    Serial.print(NUM_STRINGS, DEC);
    Serial.println();
    print(PSTR2("or enter 0 to exit"));
    Serial.println();
  }
  
  // poll serial until exit
  while (1)
  {
    // set the string index to 0 each time through the loop
    cCount = 0;
    
    print(PSTR2("Enter the number of the slot to edit: "));
    Serial.println();
    // loop until the input is acceptable
    while (inputBad)
    {
      slot = getSerialInt();
      // slots 0 to NUM_STRINGS
      // 0 is ok as it means exit
      if ((slot >= 0) && (slot <= NUM_STRINGS))
      {
        inputBad = 0;
      }
      else
      {
        print(PSTR2("Error: slot "));
        Serial.println();
        Serial.print(slot);
        print(PSTR2(" is out of range. Try again."));
        Serial.println();
      }   
    }
    // reset the input test flag for the next time around
    inputBad = 1;
    
    // the user wants to edit a slot
    if (slot > 0)
    {
      // show the choice since no echo
      print(PSTR2("Slot: "));
      Serial.println(slot);
      Serial.flush();
      // loop until done
      while (stringDone == 0)
      {
        // if there is something in the serial buffer read it
        while (Serial.available() >  0) 
        {
          // grab a character
          menuChar = Serial.read();
          // echo the input
          Serial.print(menuChar);
          
          // do stuff until we reach MAX_SIZE
          if (cCount < (MAX_SIZE - 1))
          {
            // pressed <ENTER> (either one)
            if ((menuChar == 3) || (menuChar == 13))
            {
              // set flag to redraw menu
              mainMenuCount = 0;
              // make the last character a null
              cCount++;
              currentString[cCount] = 0;
              // mark the string done
              stringDone = 1;             
            }
            // if we are not at the end of the string and <delete> not pressed
            else if (menuChar != 127)
            {
              currentString[cCount] = menuChar;
              cCount++;
            }
            // if index is between start and end and delete is pressed
            // clear the current character and go back one in the index
            else if ((cCount > 0) && (menuChar == 127))
            {
              currentString[cCount] = 0;
              cCount--;
              // print a delete to the screen so things get deleted
              Serial.print(127);
            }
          }
          // we reached MAX_SIZE
          else
          {
            // set flag to redraw menu
            mainMenuCount = 0;
            // set the current character to null
            currentString[cCount] = 0;
            // mark the string as done
            stringDone = 1;
          }
        }
      } // end of the string input loop
    
      // reset string done flag
      stringDone = 0;
      // write the string to the EEPROM
      writeEepromBlock(slot);
      // display the string
      Serial.println();
      print(PSTR2("You entered: "));
      Serial.println();
      Serial.println(currentString);
      print(PSTR2("<Y> to enter another or"));
      Serial.println();
      print(PSTR2("<N> return to Main Menu"));
      Serial.println();
      Serial.flush();
      while (menuChar != 'y')
      {
        if (Serial.available() > 0)
        {
          menuChar = Serial.read();
          if (menuChar == 'n')
          {
            Serial.println(menuChar);
            // set flag to redraw menu
            mainMenuCount = 0;
            // return to main menu
            return;
          }
          if (menuChar == 'y')
          {
            Serial.println(menuChar);
          }
        }
      } // end of the y/n input loop     
    }
    // the user did not want to edit anything
    else if (slot == 0)
    {
      break;
    }
  } // end of the edit string loop
  // set flag to redraw menu
  mainMenuCount = 0;
  // return to main menu
  return;
}

//---------------------------------------------------------------------------------------------//
// function getSerialInt
// uses serial input to get an integer
//---------------------------------------------------------------------------------------------//
int getSerialInt()
{
  char inChar;
  int in;
  int input = 0;
  
  Serial.flush();  
  do
  // do at least once
  {
    while (Serial.available() > 0)
    {
      inChar = Serial.read();
       // echo the input
       Serial.print(inChar);
       // convert 0-9 character to 0-9 int
       in = inChar - '0';
       if ((in >= 0) && (in <= 9))
       {          
          // since numbers are entered left to right
          // the current number can be shifted to the left
          // to make room for the new digit by multiplying by ten
          input = (input * 10) + in;
        }
     }
  }
  // stop looping when an ^M is received
  while (inChar != 13);
  // return the number
  return input;
}

//---------------------------------------------------------------------------------------------//
// function print()
// prints a string to Serial directly from flash using pstr
//---------------------------------------------------------------------------------------------//
void print(prog_uchar  *data)
{
  while(pgm_read_byte(data) != 0x00)
  Serial.print(pgm_read_byte(data++));
}

//---------------------------------------------------------------------------------------------//
// function readEeepromBlock
// reads a block from eeprom into a char arry
// uses globals
// returns nothing
//---------------------------------------------------------------------------------------------//
void readEepromBlock(byte msgNum)
{
  switch (msgNum)
  {
    case 1:
      eeprom_read_block((void*)&currentString, (const void*)&ee_msgString1, sizeof(currentString));
      //Serial.println("reading ee_msgString1");
      break;
    case 2:
      eeprom_read_block((void*)&currentString, (const void*)&ee_msgString2, sizeof(currentString));
      //Serial.println("reading ee_msgString2");
      break;
    case 3:
      eeprom_read_block((void*)&currentString, (const void*)&ee_msgString3, sizeof(currentString));
      //Serial.println("reading ee_msgString3");
      break;
    default:
      break;
  }
}

//---------------------------------------------------------------------------------------------//
// function writeEeepromBlock
// writes a block from a char array into the eeprom
// uses globals
// returns nothing
//---------------------------------------------------------------------------------------------//
void writeEepromBlock(byte msgNum)
{
  switch (msgNum)
  {
    case 1:
      eeprom_write_block((const void*) &currentString, (void*) &ee_msgString1, sizeof(currentString));
      //Serial.println("writing ee_msgString1");
      break;
    case 2:
      eeprom_write_block((const void*) &currentString, (void*) &ee_msgString2, sizeof(currentString));
      //Serial.println("writing ee_msgString2");
      break;
    case 3:
      eeprom_write_block((const void*) &currentString, (void*) &ee_msgString3, sizeof(currentString));
      //Serial.println("writing ee_msgString3");
      break;
    default:
      break;
  }
}
