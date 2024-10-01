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

  li t0, SPEED
  li t1, 1
  sw t1, 0(t0)

  main_loop:

  li a0, 1
  call change_speed
  nop

  j main_loop

/* BEGIN:clear_leds */
clear_leds:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

  # red leds
    li s0, 0x01FF           # select all leds and turn them off
    la s1, LEDS             # load leds address
    sw s0, 0(s1)            # store s0 in leds
    
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12

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
    addi sp, sp, -28
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)

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

    lw s5, 24(sp)
    lw s4, 20(sp)
    lw s3, 16(sp)
    lw s2, 12(sp)
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 28

    ret
/* END:set_pixel */

/* BEGIN:wait */
wait:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

    li s0, 1                # s0 = 1
    slli s0, s0, 10         # s0 = 2^10

    la s1, SPEED
    lw s1, 0(s1)            # s1 = SPEED */

wait_loop:
    sub s0, s0, s1          # s0 = s0 - s1
    bgtz s0, wait_loop      # if s0 > 0, go to wait_loop

wait_end:
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)

    ret
/* END:wait */

/* BEGIN:set_gsa */
# a0 : the gsa element to be transferred
# a1 : the line y-coordinate
set_gsa:
    # Stack
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

    # Load the GSA ID
    la s0, GSA_ID
    lw s0, 0(s0)

    # Check which GSA to set the line to
    bnez s0, set_gsa_id_1

    set_gsa_id_0:
        la s0, GSA0
        j set_gsa_transfer

    set_gsa_id_1:
        la s0, GSA1

    set_gsa_transfer:
        # Calculate the line offset (1 line is 4 bytes)
        mv s1, a1
        slli s1, s1, 2

        # Calculate the GSA address
        add s0, s0, s1

        # Store the GSA element
        sw a0, 0(s0)

    # Stack
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12

    ret
/* END:set_gsa */

/* BEGIN:get_gsa */
# a0 : line y-coordinate
get_gsa:
    # Stack
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

    # Load the GSA ID
    la s0, GSA_ID
    lw s0, 0(s0)

    # Check which GSA to get the line from
    bnez s0, get_gsa_id_1

    get_gsa_id_0:
        la s0, GSA0
        j get_gsa_transfer

    get_gsa_id_1:
        la s0, GSA1

    get_gsa_transfer:
        # Calculate the line offset (1 line is 4 bytes)
        mv s1, a0
        slli s1, s1, 2

        # Calculate the GSA address
        add s0, s0, s1

        # Load the GSA element
        lw a0, 0(s0)

    # Stack
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12

    ret
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:
    addi sp, sp, -24
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)

    # Load the GSA ID
    la s0, GSA_ID
    lw s0, 0(s0)

    # Check which GSA to get the line from
    bnez s0, draw_gsa_id_1

    draw_gsa_id_0:
        la s0, GSA0
        j draw_gsa_draw

    draw_gsa_id_1:
        la s0, GSA1

    draw_gsa_draw:
        li s1, 0                # s1 is the line index
        li s2, N_GSA_LINES      # s2 is the number of lines
        
        draw_gsa_line_loop:
            mv a0, s1           # get the current line index
            call get_gsa        # get the current GSA line

            mv s3, a0           # s3 is the current GSA line
            slli s3, s3, 16     # s3 = s3 << 16

            mv s4, s1           # s4 is the current line index
            slli s4, s4, 4      # s4 = s4 << 4
            or s3, s3, s4       # s3 = s3 | s4

            li s4, ALL          # s4 is the column mask
            or s3, s3, s4       # s3 = s3 | s4

            li s4, RED          # s4 is the LED color
            or s3, s3, s4       # s3 = s3 | s4

            la s4, LEDS         # s4 is the LED address
            sw s3, 0(s4)        # set the LED value for this line

            addi s1, s1, 1                      # increment the line index
            blt s1, s2, draw_gsa_line_loop       # if s1 < s2, loop

    lw s4, 20(sp)
    lw s3, 16(sp)
    lw s2, 12(sp)
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24

    ret
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:
    # Stack setup
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

    # Load the GSA ID to determine which GSA is used
    la s0, GSA_ID
    lw s0, 0(s0)

    # Check which GSA to use: GSA0 or GSA1
    bnez s0, random_gsa_id_1

    random_gsa_id_0:
        la s0, GSA0      # Load base address of GSA0
        j random_gsa_draw

    random_gsa_id_1:
        la s0, GSA1      # Load base address of GSA1

    random_gsa_draw:
        li s1, 0                # Initialize line index (0 to N_GSA_LINES-1)

    random_gsa_line_loop:
        li t1, 0                # Clear t1 to accumulate the 12-bit GSA value
        li t2, 0                # Initialize column index (0 to N_GSA_COLUMNS-1)

    random_gsa_column_loop:
        # Get a random 32-bit value
        la t0, RANDOM           # Load random number address
        lw t3, 0(t0)            # Load random number into t3

        # Generate either 0 or 1 using modulo 2
        andi t3, t3, 1          # t3 = t3 % 2

        # Shift the result to the correct column position
        sll t3, t3, t2          # t3 = t3 << column_index

        # Accumulate the result into t1
        or t1, t1, t3           # t1 = t1 | t3

        # Increment column index
        addi t2, t2, 1
        li t4, N_GSA_COLUMNS    # Compare with number of columns
        blt t2, t4, random_gsa_column_loop  # Loop for each column

        # Now t1 contains the 12-bit value for the GSA line

        # Calculate the line offset (each line is 4 bytes)
        slli t3, s1, 2          # t3 = s1 * 4 (4 bytes per line)
        add t0, s0, t3          # t0 = GSA base + offset (to target correct line)

        # Store the random 12-bit value into the GSA line
        sw t1, 0(t0)

        # Increment the line index
        addi s1, s1, 1          # s1 = s1 + 1
        li t4, N_GSA_LINES      # Compare with number of lines
        blt s1, t4, random_gsa_line_loop  # Loop for all lines

    # Stack teardown
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12
    ret

/* END:random_gsa */

/* BEGIN:change_speed */
change_speed:
    # Stack setup
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)

    beqz a0, change_speed_increment

change_speed_decrement:
    la s0, SPEED
    lw s1, 0(s0)
    li s2, MIN_SPEED

    # Check if the speed is already at the minimum
    beq s1, s2, change_speed_end

    # Decrement the speed
    addi s1, s1, -1

    # Store the new speed
    sw s1, 0(s0)

    # Jump to the end
    j change_speed_end

change_speed_increment:

    la s0, SPEED
    lw s1, 0(s0)
    li s2, MAX_SPEED

    # Check if the speed is already at the maximum
    beq s1, s2, change_speed_end

    # Increment the speed
    add s1, s1, 1

    # Store the new speed
    sw s1, 0(s0)

change_speed_end:
    # Stack teardown
    lw s2, 12(sp)
    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 16

    ret
/* BEGIN:pause_game */
pause_game:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

    # Load the PAUSE value
    la s0, PAUSE
    lw s1, 0(s0)

    # Toggle the PAUSE value
    xor s1, s1, 1
    sw s1, 0(s0)

    lw s1, 8(sp)
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12
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
