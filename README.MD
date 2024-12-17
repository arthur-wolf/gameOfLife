![Logo](https://upload.wikimedia.org/wikipedia/commons/9/95/Logo_EPFL_2019.svg)

# Game of Life

## Introduction and motivation

The aim of this project was to develop a small program in (RISC-V / RV32I) assembly.  
It is a simplified version of the [Game of Life](https://www.google.com/search?client=safari&rls=en&q=game+of+life&ie=UTF-8&oe=UTF-8), which is well known accross the CS community.  
This project was made in the context of the **CS200** course at EPFL.

## Handout
The original handout we received for this project can be found [here](resources/GameOfLife.pdf).

## How to download and run the game

Disclaimer : This project was designed to run on a custom made VSCode extension. Therefore, you need to have both VSCode and the **CS200** extension installed.

1. Clone the repository to your machine

HTTPS:
```shell
git clone https://github.com/arthur-wolf/gameOfLife.git
```
SSH:
```shell
git clone git@github.com:arthur-wolf/gameOfLife.git
```
2. Open the project in VSCode
```shell
cd gameOfLife
code .
```
3. Once in VSCode, open the **gol.s** file and click on the debug icon

4. A panel should open on the right with a grid (the screen) and buttons around it.  
You can start playing by clicking on the **run** icon from the debug bar !

## Controls

The game panel mentioned above consists of different elements:
 - 4 Seven segmemt displays
 - A screen
 - 8 switches on the left below the screen (unused)
 - 3 square buttons to the right of the switches (b2 to b0, from left to right)
- A joystick to the right of the buttons with 5 input modes (jc = joystick center, jl = joystick left, jr = joystick right, jt = joystick top, jb = joystick bottom)
- 2 buttons on the top of the joystick (unused)

In the initial state, you can :
- use b2, b1 and b0 to add iterations to the game (256, 16, 1 respectively). The number of iterations is displayed on the 4 seven segment displays in hexadecimal notation.  
- use JC to fo through the different predefined seeds (There are 4). After the 4th seed, a new random seed will be generated on each press.  
- use JR to start the selected seed for the number of iterations selected and switch to the run mode.   

Once the game has started (and is is run mode), you can:
- use JC to start/pause the game.
- use JR to increase the speed of the game.
- use JL to decrease the speed of the game.
- use JB to reset the game to the inital state.
- use JT to replace the current game state with a new random seed.