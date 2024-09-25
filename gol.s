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

  addi a0, zero, 1
  addi a1, zero, 2
  call set_pixel
  nop

  addi a0, zero, 2
  addi a1, zero, 1
  call set_pixel
  nop

  addi a0, zero, 3
  addi a1, zero, 3
  call set_pixel
  nop

  addi a0, zero, 5
  addi a1, zero, 5
  call set_pixel
  nop

  call draw_gsa
  nop
  
  j main

/* BEGIN:clear_leds */
clear_leds:
  # red leds
    li s0, 0x01FF           # select all leds and turn them off
    la s1, LEDS             # load leds address
    sw s0, 0(s1)            # store s0 in leds
    
    ret
/* END:clear_leds */

/* BEGIN:set_pixel */
# a0 : x-coordinate
# a1 : y-coordinate
# s0 : encoded column
# s1 : encoded row
# s2 : encoded color
# s3 : encoded value
# s4 : new register value
set_pixel:
    # encode correct column
    mv s0, a0                 # s0 = x
    or s4, zero, s0           # s4 = x

    # encode correct row
    mv s1, a1          # s1 = y
    slli s1, s1, 4            # s1 = y << 4
    or s4, s4, s1             # s4 = y | x

    # encode correct color
    li s2, RED                # s2 = 0b00000000_00000000_00000001_00000000
    or s4, s4, s2             # s4 = color | y | x

    # encode correct value
    li s3, 1                  # s3 = 1
    slli s3, s3, 16           # s3 = 2^16
    or s4, s4, s3             # s4 = value | color | y | x

    # store new register value
    la s5, LEDS                # load the address of LEDS into s5
    sw s4, 0(s5)               # store the result back at the LEDS address

    ret
/* END:set_pixel */

/* BEGIN:wait */
wait:
    li s0, 1                # s0 = 1
    slli s0, s0, 10         # s0 = 2^10

    la s1, SPEED
    lw s1, 0(s1)            # s1 = SPEED */

wait_loop:
    sub s0, s0, s1          # s0 = s0 - s1
    bgtz s0, wait_loop      # if s0 > 0, go to wait_loop

wait_end:
    ret
/* END:wait */

/* BEGIN:set_gsa */
# a0 : the gsa element to be transferred
# a1 : the line y-coordinate
set_gsa:
    addi sp, sp, -4
    sw ra, 0(sp)

    la s0, GSA_ID           # s0 = GSA_ID address
    lw s0, 0(s0)            # s0 = GSA_ID

    bnez s0, set_gsa_id_1   # if GSA_ID != 0, go to set_gsa_id_1

    set_gsa_id_0:
        la s0, GSA0         # s0 = GSA0 address
        j set_gsa_transfer

    set_gsa_id_1:
        la s0, GSA1         # s0 = GSA1 address

    set_gsa_transfer:
        # Offset to the correct line of the GSA
        mv s1, a1           # s2 = a1
        slli s1, s1, 2      # s2 = a1 * 4 (4 bytes per line, so *4 to skip to the correct line)
        
        # Store the value in the GSA
        sw a0, s1(s0)        # store s2 in s1

    set_gsa_end:
        lw ra, 0(sp)
        addi sp, sp, 4

        ret
/* END:set_gsa */

/* BEGIN:get_gsa */
# a0 : line y-coordinate
get_gsa:
    # Stack stuff
    addi sp, sp, -4
    sw ra, 0(sp)

    # Load the GSA ID
    la s0, GSA_ID
    lw s0, 0(s2)

    # Check which GSA to get the line from
    bnez s0, get_gsa_id_1

    get_gsa_id_0:
        la s0, GSA0
        j get_gsa_transfer

    get_gsa_id_1:
        la s0, GSA1

    get_gsa_trasnfer:
        # Offset to the correct line of the GSA
        mv s1, a0
        slli s1, s1, 2

        # Load the value from the GSA
        lw a0, s1(s0)

    get_gsa_end:
        # Stack stuff
        lw ra, 0(sp)
        addi sp, sp, 4

        ret
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:
    addi sp, sp, -4
    sw ra, 0(sp)

    li s0, 0                # s0 is the line index

    draw_gsa_line_loop:
        mv a0, s0           # a0 is the line index
        call get_gsa        # a0 is the line value

    draw_gsa_draw_line:
        # Load the LEDS value
        mv s1, a0       # s1 will contain the LEDS value
        slli s1, s1, 16 # s1 = a0 << 16

        # Load the row value
        mv s2, s0       # s2 will contain the y-coordinate
        slli s2, s2, 4  # s2 = s0 << 4
        or s1, s1, s2   # s1 = s1 | s2

        # Load the column value
        li s2, ALL      # s2 = 0b00000000_00000000_00000000_00001111
        or s1, s1, s2   # s1 = s1 | s2

        # Load the LEDS color value
        li s2, RED      # s2 = 0b00000000_00000000_00000001_00000000
        or s1, s1, s2   # s1 = s1 | s2

        # Store the LEDS value
        la s2, LEDS     # s2 is the LEDS address
        sw s1, 0(s2)    # store s1 in s2
        
        # Increment the line index
        la s2, N_GSA_LINES
        addi s0, s0, 1  # s0 = s0 + 1
        blt s0, s2, draw_gsa_line_loop # if s0 < N_GSA_LINES, go to draw_gsa_line_loop

    draw_gsa_end:
        lw ra, 0(sp)
        addi sp, sp, 4

        ret
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:
    la s5, RANDOM      # s5 is the random number generator address

    la s0, GSA_ID
    lw s0, 0(s0)

    bnez s0, random_gsa_id_1

    random_gsa_id_0:
        la s0, GSA0
        j random_gsa_next

    random_gsa_id_1:
        la s0, GSA1

    random_gsa_next:
        li s1, 0                # s1 is the line index
        li s2, N_GSA_LINES      # s2 is the number of lines
        
        li s3, 0                # s3 is the column index
        li s4, N_GSA_COLUMNS    # s4 is the number of columns

        random_gsa_line_loop:

    random_gsa_end:
        ret
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
