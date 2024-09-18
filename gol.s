.section ".word"
   /* Game state memory locations */
  .equ CURR_STATE, 0x90001000       /* Current state of the game */
  .equ GSA_ID, 0x90001004           /* ID of the GSA holding the current state */
  .equ PAUSE, 0x90001008            /* Is the game paused or running */
  .equ SPEED, 0x9000100C            /* Current speed of the game */
  .equ CURR_STEP,  0x90001010       /* Current step of the game */
  .equ SEED, 0x90001014             /* Which seed was used to start the game */
  .equ GSA0, 0x90001018             /* Game State Array 0 starting address */
  .equ GSA1, 0x90001058             /* Game State Array 1 starting address */
  .equ CUSTOM_VAR_START, 0x90001200 /* Start of free range of addresses for custom vars */
  .equ CUSTOM_VAR_END, 0x90001300   /* End of free range of addresses for custom vars */
  .equ RANDOM, 0x40000000           /* Random number generator address */
  .equ LEDS, 0x50000000             /* LEDs address */
  .equ SEVEN_SEGS, 0x60000000       /* 7-segment display addresses */
  .equ BUTTONS, 0x70000004          /* Buttons address */

  /* States */
  .equ INIT, 0
  .equ RAND, 1
  .equ RUN, 2

  /* Colors (0bBGR) */
  .equ RED, 0x100
  .equ BLUE, 0x400

  /* Buttons */
  .equ JT, 0x10
  .equ JB, 0x8
  .equ JL, 0x4
  .equ JR, 0x2
  .equ JC, 0x1
  .equ BUTTON_2, 0x80
  .equ BUTTON_1, 0x20
  .equ BUTTON_0, 0x40

  /* LED selection */
  .equ ALL, 0xF

  /* Constants */
  .equ N_SEEDS, 4           /* Number of available seeds */
  .equ N_GSA_LINES, 10       /* Number of GSA lines */
  .equ N_GSA_COLUMNS, 12    /* Number of GSA columns */
  .equ MAX_SPEED, 10        /* Maximum speed */
  .equ MIN_SPEED, 1         /* Minimum speed */
  .equ PAUSED, 0x00         /* Game paused value */
  .equ RUNNING, 0x01        /* Game running value */

.section ".text.init"
  .globl main

main:
  li sp, CUSTOM_VAR_END /* Set stack pointer, grows downwards */ 
  # call reset_game

  add a0, zero, 1
  add a1, zero, 1
  call set_pixel
  nop

  add a0, zero, 2
  add a1, zero, 2
  call set_pixel
  nop

  call clear_leds
  nop
  
  j main

/* BEGIN:clear_leds */
clear_leds:
  # red leds
    add t0, zero, 0x01FF   # select all leds and turn them off
    la t1, LEDS             # load leds address
    sw t0, 0(t1)            # store t0 in leds
    
    ret
/* END:clear_leds */

/* BEGIN:set_pixel */
# a0 : x-coordinate
# a1 : y-coordinate
# t0 : encoded column
# t1 : encoded row
# t2 : encoded color
# t3 : encoded value
# t4 : new register value
set_pixel:
    # encode correct column
    add t0, zero, a0          # t0 = x
    or t4, zero, t0            # t4 = x

    # encode correct row
    add t1, zero, a1          # t1 = y
    slli t1, t0, 4             # t1 = y << 4
    or t4, t4, t1              # t4 = y | x

    # encode correct color
    add t2, zero, 0x100       # t2 = 0b00000000_00000000_00000001_00000000
    or t4, t4, t2              # t4 = color | y | x

    # encode correct value
    add t3, zero, 1           # t3 = 1
    slli t3, t3, 16            # t3 = 2^16
    or t4, t4, t3              # t4 = value | color | y | x

    # store new register value
    la t5, LEDS                # load the address of LEDS into t5
    lw t6, 0(t5)               # load the value stored at LEDS into t6
    or t6, t6, t4              # t6 = current LEDS value & value in t4
    sw t6, 0(t5)               # store the result back at the LEDS address

    ret
/* END:set_pixel */

/* BEGIN:wait */
wait:
    li t0, 1                # t0 = 1
    slli t0, t0, 10         # t0 = 2^10

    la t1, SPEED
    lw t1, 0(t1)            # t1 = SPEED */

wait_loop:
    sub t0, t0, t1          # t0 = t0 - t1
    bgtz t0, wait_loop      # if t0 > 0, go to wait_loop

wait_end:
    ret
/* END:wait */

/* BEGIN:set_gsa */
set_gsa:
/* END:set_gsa */

/* BEGIN:get_gsa */
# a0 : line y-coordinate
get_gsa:
    add t0, zero, a0
    slli t0, t0, 5

    la t2, GSA_ID
    lw t2, 0(t2)
    bnez t2, gsa_id_1

    gsa_id_0:
        la t1, GSA0
        j get_gsa_end

    gsa_id_1:
        la t1, GSA1

    get_gsa_end:
        add t1, t1, t0
        add a0, zero, t1

        ret
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:           
/* END:random_gsa */

/* BEGIN:change_speed */
change_speed:
    beq a0, zero, change_speed_increment

change_speed_decrement:
    
change_speed_increment:

change_speed_end:
    ret
/* BEGIN:pause_game */
pause_game:
/* END:pause_game */

/* BEGIN:change_steps */
change_steps:           
/* END:change_steps */

/* BEGIN:set_seed */
set_seed:
/* END:set_seed */

/* BEGIN:increment_seed */
increment_seed:                
/* END:increment_seed */

/* BEGIN:update_state */
update_state:
/* END:update_state */

/* BEGIN:select_action */
select_action:
/* END:select_action */

/* BEGIN:cell_fate */
cell_fate:
/* END:cell_fate */

/* BEGIN:find_neighbours */
find_neighbours:
/* END:find_neighbours */

/* BEGIN:update_gsa */
update_gsa:
/* END:update_gsa */

/* BEGIN:get_input */
get_input:
/* END:get_input */

/* BEGIN:decrement_step */
decrement_step:
/* END:decrement_step */

/* BEGIN:reset_game */
reset_game:
/* END:reset_game */

/* BEGIN:mask */
mask:
/* END:mask */

/* 7-segment display */
font_data:
  .word 0x3F
  .word 0x06
  .word 0x5B
  .word 0x4F
  .word 0x66
  .word 0x6D
  .word 0x7D
  .word 0x07
  .word 0x7F
  .word 0x6F
  .word 0x77
  .word 0x7C
  .word 0x39
  .word 0x5E
  .word 0x79
  .word 0x71

  seed0:
	.word 0xC00
	.word 0xC00
	.word 0x000
	.word 0x060
	.word 0x0A0
	.word 0x0C6
	.word 0x006
	.word 0x000
  .word 0x000
  .word 0x000

seed1:
	.word 0x000
	.word 0x000
	.word 0x05C
	.word 0x040
	.word 0x240
	.word 0x200
	.word 0x20E
	.word 0x000
  .word 0x000
  .word 0x000

seed2:
	.word 0x000
	.word 0x010
	.word 0x020
	.word 0x038
	.word 0x000
	.word 0x000
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000

seed3:
	.word 0x000
	.word 0x000
	.word 0x090
	.word 0x008
	.word 0x088
	.word 0x078
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000


# Predefined seeds
SEEDS:
  .word seed0
  .word seed1
  .word seed2
  .word seed3

mask0:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
  .word 0xFFF
  .word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF
  .word 0x1FF
  .word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
  .word 0x7FF
  .word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

MASKS:
  .word mask0
  .word mask1
  .word mask2
  .word mask3
  .word mask4
