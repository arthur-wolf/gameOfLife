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

    call reset_game

    call get_input  # input is in a0 
    mv s0, a0

    main_loop:
        mv a0, s0
        call select_action
        call update_state
        call update_gsa
        mv s0, a0
        call mask
        call draw_gsa
        call wait
        call decrement_step
        mv s1, a0
        call get_input
        mv s0, a0

        beqz s1, main_loop  # if a0 == 0, go to main_loop

    j main

/* BEGIN:clear_leds */
clear_leds:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

  # red leds
    li s0, 0x03FF           # select all leds and turn them off
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
    addi sp, sp, 12

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
/* END:change_speed */

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
    
    ret
/* END:pause_game */

/* BEGIN:change_steps */
change_steps:
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)

    li s0, 0
    
    change_steps_check_b0:
        beqz a0, change_steps_check_b1

        li s1, 0x1
        or s0, s0, s1
    
    change_steps_check_b1:
        beqz a1, change_steps_check_b2

        li s1, 0x10
        or s0, s0, s1
    
    change_steps_check_b2:
        beqz a2, change_steps_next

        li s1, 0x100
        or s0, s0, s1

    change_steps_next:
        # Load the current step
        la s1, CURR_STEP
        lw s2, 0(s1)

        # Add the new steps
        add s2, s2, s0

        # Store the new steps
        sw s2, 0(s1)

    change_steps_end:
        # Stack teardown
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)

        addi sp, sp, 16

        ret
/* END:change_steps */

/* BEGIN:set_seed */
set_seed:
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)

    # check if seed is bigger than N_SEEDS
    mv s0, a0       # Move the seed id to s0

    li t0, N_SEEDS  # Load the number of available seeds

    bge s0, t0, set_seed_generate   # If the seed id is bigger than N_SEEDS, generate a random seed

    set_seed_load:
        la s1, SEEDS    # Load the address of the seeds
        slli s0, s0, 2  # Multiply the seed id by 4 to get the correct offset
        add s1, s1, s0  # Add the offset to the base address of the seeds
        # s1 now points to the correct seed
        lw s1, 0(s1)    # Load the seed

        li s2, 0            # Line index
        li s3, N_GSA_LINES  # Load the number of GSA lines

        set_seed_load_loop:
            lw s0, 0(s1)    # Load the seed line from the seed array

            mv a0, s0       # Load the seed line 
            mv a1, s2       # Load the line index
            call set_gsa    # Set the GSA line

            addi s2, s2, 1  # Increment the line index
            addi s1, s1, 4  # Increment the seed array pointer
            blt s2, s3, set_seed_load_loop  # Loop for all lines

        j set_seed_end

    set_seed_generate:
        li t0, 4
        li t1, SEED
        sw t0, 0(t1)

    set_seed_end:
        # Stack teardown
        lw s3, 16(sp)
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 20

        ret
/* END:set_seed */

/* BEGIN:increment_seed */
increment_seed:
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s0, 4(sp)

    la t1, SEED
    lw s0, 0(t1)

    li t0, N_SEEDS
    beq s0, t0, increment_seed_generate
    # s0 < 4

    addi s0, s0, 1
    sw s0, 0(t1)
    beq s0, t0, increment_seed_generate

    mv a0, s0
    call set_seed
    j increment_seed_end

    increment_seed_generate:
        call random_gsa

    increment_seed_end:
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 8

        ret
/* END:increment_seed */

/* BEGIN:update_state */
update_state:
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)

    mv s0, a0   # Move the current button state to s0

    and s1, s0, JC
    and s2, s0, JR
    and s3, s0, JB

    la t0, CURR_STATE
    lw t0, 0(t0)

    # Current state is RAND
    la t1, RAND
    beq t0, t1, update_state_rand

    # Current state is RUN
    la t1, RUN
    beq t0, t1, update_state_run

    # Current state is INIT
    update_state_init:
        # Check if the JC button is pressed
        bnez s1, update_state_init_JC

        # Check if the JR button is pressed
        bnez s2, update_state_init_JR

        # Else, go to the end
        j update_state_end

        update_state_init_JC:
            la t0, SEED
            lw t0, 0(t0)
            li t1, N_SEEDS

            # If seed < N_SEEDS, do nothing
            blt t0, t1, update_state_end 

            # Else, if seed == N_SEEDS, go to RAND state
            li t0, RAND
            la t1, CURR_STATE
            sw t0, 0(t1)

            j update_state_end

        update_state_init_JR:
            # If JR is pressed, go to RUN state and unpause the game
            li t0, RUN
            la t1, CURR_STATE
            sw t0, 0(t1)

            la t0, PAUSE
            li t1, RUNNING
            sw t1, 0(t0)

            j update_state_end

    update_state_rand:
        # Check if the JR button is pressed
        bnez s2, update_state_rand_JR

        # Else go to the end
        j update_state_end

        update_state_rand_JR:
            # If JR is pressed, go to RUN state and unpause the game
            li t0, RUN
            la t1, CURR_STATE
            sw t0, 0(t1)

            la t0, PAUSE
            li t1, RUNNING
            sw t1, 0(t0)

            j update_state_end

    update_state_run:
        # Check if the JB button is pressed
        bnez s3, update_state_run_JB

        # Else go to the end
        j update_state_end

        update_state_run_JB:
            # If JB is pressed, go to INIT state and pause the game
            li t0, INIT
            la t1, CURR_STATE
            sw t0, 0(t1)

            la t0, PAUSE
            li t1, PAUSED
            sw t1, 0(t0)

            call reset_game

            j update_state_end
    update_state_end:
        lw s3, 16(sp)
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 20

        ret
/* END:update_state */

/* BEGIN:select_action */
select_action:
    addi sp, sp, -36
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw s6, 28(sp)
    sw s7, 32(sp)

    mv s0, a0   # Move the current button state to s0

    # Save the buttons states in registers
    and s1, s0, JC
    and s2, s0, JR
    and s3, s0, JL
    and s4, s0, JT
    and s5, s0, BUTTON_0
    and s6, s0, BUTTON_1
    and s7, s0, BUTTON_2

    la t0, CURR_STATE
    lw t0, 0(t0)

    # Current state is RAND
    la t1, RAND
    beq t0, t1, select_action_rand

    # Current state is RUN
    la t1, RUN
    beq t0, t1, select_action_run

    # Current state is INIT
    select_action_init:
        # Check if the JC button is pressed
        bnez s1, select_action_init_JC

        # Check if one of the digit buttons is pressed
        add t1, s5, s6
        add t1, t1, s7
        bnez t1, select_action_digit

        # Else, go to the end
        j select_action_end

        select_action_init_JC:
            call increment_seed

            j select_action_end

    select_action_rand:
        # Check if the JC button is pressed
        bnez s1, select_action_rand_JC

        # Check if one of the digit buttons is pressed
        add t1, s5, s6
        add t1, t1, s7
        bnez t1, select_action_digit

        # Else, go to the end
        j select_action_end

        select_action_rand_JC:
            call random_gsa

            j select_action_end

    select_action_run:
        bnez s2, select_action_run_JR
        bnez s3, select_action_run_JL
        bnez s4, select_action_run_JT
        bnez s1, select_action_run_JC

        # Else, go to the end
        j select_action_end

        select_action_run_JR:
            li a0, 0
            call change_speed

            j select_action_end
        select_action_run_JL:
            li a0, 1
            call change_speed

            j select_action_end
        select_action_run_JC:
            call pause_game

            j select_action_end
        select_action_run_JT:
            call random_gsa

            j select_action_end
    select_action_digit:
        li t0, 0

        # Set the correct digit
        slt a0, t0, s5
        slt a1, t0, s6
        slt a2, t0, s7
        call change_steps


    select_action_end:
        lw s7, 32(sp)
        lw s6, 28(sp)
        lw s5, 24(sp)
        lw s4, 20(sp)
        lw s3, 16(sp)
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 36

        ret
/* END:select_action */

/* BEGIN:cell_fate */
cell_fate:
    addi sp, sp, -4
    sw ra, 0(sp)

    mv t0, a0   # Number of live neighbours
    mv t1, a1   # Current cell state

    beqz t1, cell_fate_dead # If the cell is dead, go to cell_fate_dead

    cell_fate_alive:
        li t2, 2
        li t3, 4

        blt t0, t2, cell_fate_alive_die  # If the number of live neighbours is less than 2, the cell dies
        bge t0, t3, cell_fate_alive_die  # If the number of live neighbours is greater than 3, the cell dies

        # Otherwise, the cell stays alive
        li a0, 1
        j cell_fate_end

        cell_fate_alive_die:
            li a0, 0
            j cell_fate_end

    cell_fate_dead:
        li t3, 3
        li a0, 0

        bne t0, t3, cell_fate_end  # If the number of live neighbours is not 3, the cell stays dead

        # Otherwise, the cell becomes alive
        li a0, 1

    cell_fate_end:
        lw ra, 0(sp)
        addi sp, sp, 4

        ret
/* END:cell_fate */

/* BEGIN:find_neighbours */
# arguments:
#      a0 : x-coordinate
#      a1 : y-coordinate
# returns:
#      a0 : number of live neighbours
#      a1 : state of the cell at (x, y)
find_neighbours:
    addi sp, sp, -36
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw s6, 28(sp)
    sw s7, 32(sp)

    mv s1, a0   # s1 = x
    mv s4, a1   # s4 = y
    li s6, 0    # s6 = number of live neighbours
    li s7, 0    # s7 = state of the cell at (x, y)

    # -------- Row handling --------

    # Check if the cell is on the top row
    li t0, 0
    beq s4, t0, find_neighbours_top_row

    # Check if the cell is on the bottom row
    li t0, N_GSA_LINES
    addi t0, t0, -1
    beq s4, t0, find_neighbours_bottom_row

    addi s3, s4, -1
    addi s5, s4, 1

    j find_neighbours_load_rows

    # s3 : y-1
    # s4 : y
    # s5 : y+1

    find_neighbours_top_row:
        li s3, 9    # s3 = 9 = y-1
        li s5, 1    # s5 = 1 = y+1
        j find_neighbours_load_rows

    find_neighbours_bottom_row:
        li s3, 8    # s3 = 8 = y-1
        li s5, 0    # s5 = 0 = y+1
        j find_neighbours_load_rows

    find_neighbours_load_rows:
        mv a0, s3
        call get_gsa
        mv s3, a0

        mv a0, s4
        call get_gsa
        mv s4, a0

        mv a0, s5
        call get_gsa
        mv s5, a0

        # At this point, s3, s4, and s5 contain the GSA lines for y-1, y, and y+1, respectively

    # -------- Column handling --------

    # Check if the cell is on the left column
    li t0, 0
    beq s1, t0, find_neighbours_left_column

    # Check if the cell is on the right column
    li t0, N_GSA_COLUMNS
    addi t0, t0, -1
    beq s1, t0, find_neighbours_right_column

    addi s0, s1, -1
    addi s2, s1, 1

    j find_neighbours_check

    # s0 : x-1
    # s1 : x
    # s2 : x+1

    find_neighbours_left_column:
        li s0, 11  # s0 = 11 = x-1
        li s2, 1   # s2 = 1 = x+1
        j find_neighbours_check

    find_neighbours_right_column:
        li s0, 10  # s0 = 10 = x-1
        li s2, 0   # s2 = 0 = x+1
        j find_neighbours_check

    find_neighbours_check:
        li t0, 1
        # Check neighbours for the first row :
        # 1. (x-1, y-1)
        sll t1, t0, s0
        and t1, t1, s3
        snez t1, t1
        add s6, s6, t1

        # 2. (x, y-1)
        sll t1, t0, s1
        and t1, t1, s3
        snez t1, t1
        add s6, s6, t1

        # 3. (x+1, y-1)
        sll t1, t0, s2
        and t1, t1, s3
        snez t1, t1
        add s6, s6, t1

        # Check neighbours for the second row :
        # 4. (x-1, y)
        sll t1, t0, s0
        and t1, t1, s4
        snez t1, t1
        add s6, s6, t1

        # 5. (x, y)
        sll t1, t0, s1
        and t1, t1, s4
        snez t1, t1
        add s7, s7, t1

        # 6. (x+1, y)
        sll t1, t0, s2
        and t1, t1, s4
        snez t1, t1
        add s6, s6, t1

        # Check neighbours for the third row :
        # 7. (x-1, y+1)
        sll t1, t0, s0
        and t1, t1, s5
        snez t1, t1
        add s6, s6, t1

        # 8. (x, y+1)
        sll t1, t0, s1
        and t1, t1, s5
        snez t1, t1
        add s6, s6, t1

        # 9. (x+1, y+1)
        sll t1, t0, s2
        and t1, t1, s5
        snez t1, t1
        add s6, s6, t1

    find_neighbours_end:
        mv a0, s6
        mv a1, s7

        lw s7, 32(sp)
        lw s6, 28(sp)
        lw s5, 24(sp)
        lw s4, 20(sp)
        lw s3, 16(sp)
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 36

        ret
/* END:find_neighbours */

/* BEGIN:update_gsa */
update_gsa:
    addi sp, sp, -32
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw s6, 28(sp)

    # Only update the GSA if the game is not paused
    la t0, PAUSE
    lw t0, 0(t0)
    li t2, PAUSED
    beq t0, t2, update_gsa_end

    # Load the current GSA ID
    la s0, GSA_ID
    lw s0, 0(s0)

    li s1, 0                # s1 is the line index (y)
    li s2, N_GSA_LINES      # s2 is the number of lines

    update_gsa_line_loop:
        li s3, 0                # s3 is the column index (x)
        li s4, N_GSA_COLUMNS    # s4 is the number of columns
        li s6, 0                # s6 is the gsa line that will be updated

        update_gsa_column_loop:
            mv a0, s3           # get the current column index
            mv a1, s1           # get the current line index
            call find_neighbours
            call cell_fate

            mv s5, a0           # s5 is the new state of the cell at (x, y), 1 = alive
            sll s5, s5, s3
            or s6, s6, s5       # s6 = s6 | s5

            addi s3, s3, 1                      # increment the column index
            blt s3, s4, update_gsa_column_loop   # if s3 < s4, loop

        # Save the new GSA line
        xori s0, s0, 1
        la t0, GSA_ID
        sw s0, 0(t0)

        mv a0, s6           # a0 is the new GSA line
        mv a1, s1           # a1 is the line index
        call set_gsa        # set the new GSA line

        xori s0, s0, 1
        la t0, GSA_ID
        sw s0, 0(t0)

        addi s1, s1, 1                      # increment the line index
        blt s1, s2, update_gsa_line_loop     # if s1 < s2, loop

        xori s0, s0, 1
        la t0, GSA_ID
        sw s0, 0(t0)

    update_gsa_end:
        lw s6, 28(sp)
        lw s5, 24(sp)
        lw s4, 20(sp)
        lw s3, 16(sp)
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 32

        ret
/* END:update_gsa */

/* BEGIN:get_input */
get_input:
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

    # Load the button state
    li t0, BUTTONS
    lw s0, 0(t0)

    # Clear the button state
    sw zero, 0(t0)

    # extract the smallest button pressed and return it
    li t0, JC
    and s1, s0, t0
    bnez s1, get_input_end

    li t0, JR
    and s1, s0, t0
    bnez s1, get_input_end

    li t0, JL
    and s1, s0, t0
    bnez s1, get_input_end

    li t0, JB
    and s1, s0, t0
    bnez s1, get_input_end

    li t0, JT
    and s1, s0, t0
    bnez s1, get_input_end

    li t0, BUTTON_1
    and s1, s0, t0
    bnez s1, get_input_end

    li t0, BUTTON_0
    and s1, s0, t0
    bnez s1, get_input_end

    li t0, BUTTON_2
    and s1, s0, t0
    bnez s1, get_input_end

    # No button pressed
    li s1, 0

    get_input_end:
        mv a0, s1

        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 12

        ret
/* END:get_input */

/* BEGIN:decrement_step */
decrement_step:
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)

    # If current state is RUN, decrement the step
    la t0, CURR_STATE
    lw t0, 0(t0)
    li t1, RUN
    beq t0, t1, decrement_step_run

    # Else, display the current step
    j decrement_step_display

    decrement_step_run:
        # If the game is paused, just display the current step
        la t0, PAUSE
        lw t0, 0(t0)
        li t1, PAUSED
        beq t0, t1, decrement_step_display

        # Check if the current step is 0, if so return 1
        la t0, CURR_STEP
        lw t1, 0(t0)
        li a0, 1
        beqz t1, decrement_step_end

        # Else decrement the current step and display it
        addi t1, t1, -1
        sw t1, 0(t0)

        j decrement_step_display
    
    decrement_step_display:
        # return 0
        li a0, 0

        # Load the current step
        la t0, CURR_STEP
        lw s0, 0(t0)    # s0 is the current number of steps

        # Load the font data address
        la s2, font_data

        li t0, 0xF  # 7-segment display mask

        # -------- Extract the digits --------
        extract_third_digit:
            srl t1, s0, 12
            and t1, t1, t0

        extract_second_digit:
            srl t2, s0, 8
            and t2, t2, t0

        extract_first_digit:
            srl t3, s0, 4
            and t3, t3, t0
    
        extract_last_digit:
            and t4, s0, t0

        # Offset the digits
        slli t1, t1, 2
        slli t2, t2, 2
        slli t3, t3, 2
        slli t4, t4, 2

        # Load each digit's font data
        add t1, s2, t1
        lw t1, 0(t1)
        slli t1, t1, 24

        add t2, s2, t2
        lw t2, 0(t2)
        slli t2, t2, 16

        add t3, s2, t3
        lw t3, 0(t3)
        slli t3, t3, 8

        add t4, s2, t4
        lw t4, 0(t4)

        # Combine the digits
        or t4, t4, t3
        or t4, t4, t2
        or t4, t4, t1

        # Display the digits
        la t1, SEVEN_SEGS
        sw t4, 0(t1)

    decrement_step_end:
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 16

        ret
/* END:decrement_step */

/* BEGIN:reset_game */
reset_game:
    addi sp, sp, -4
    sw ra, 0(sp)

    call clear_leds

    # Set the game to PAUSED
    li t0, PAUSED
    la t1, PAUSE
    sw t0, 0(t1)

    # Set current steps to 1 and display it
    la t0, CURR_STEP
    la t1, 1
    sw t1, 0(t0)
    call decrement_step

    # Use GSA0
    la t0, GSA_ID
    sw zero, 0(t0)

    # Set seed id to 0
    la t0, SEED
    sw zero, 0(t0)

    # select seed 0
    la a0, 0
    call set_seed
    call mask
    call draw_gsa

    # Set the game speed to MIN_SPEED
    li t0, MIN_SPEED
    la t1, SPEED
    sw t0, 0(t1)

    lw ra, 0(sp)
    addi sp, sp, 4
    

    ret
/* END:reset_game */

/* BEGIN:mask */
mask:
    addi sp, sp, -32
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp)
    sw s3, 16(sp)
    sw s4, 20(sp)
    sw s5, 24(sp)
    sw s6, 28(sp)


    la t0, SEED
    lw s0, 0(t0) # s0 is the mask ID
    
    li t0, N_SEEDS

    # If the mask ID is bigger than N_SEEDS, set it to 4
    blt s0, t0, mask_next

    li s0, 4

    mask_next:

        slli s0, s0, 2  # s0 = s0 << 2 --> mask offset

        la s1, MASKS
        add s1, s1, s0  # s1 is the mask address
        lw s1, 0(s1)    # s1 is the mask base address

        li s3, 0                # s3 is the line index (y)
        li s4, N_GSA_LINES      # s4 is the number of lines

        mask_line_loop:
            # Get the GSA line
            mv a0, s3
            call get_gsa
            mv s5, a0

            # Load the corresponding mask line
            lw s6, 0(s1)

            # Apply the mask
            and s5, s5, s6

            # Set the new GSA line
            mv a0, s5
            mv a1, s3
            call set_gsa

            # Draw the mask in blue
            li t0, 0xFFF
            xor s6, s6, t0

            slli s6, s6, 16     # LEDS value

            li t0, BLUE         # LEDS color
            or s6, s6, t0

            ori s6, s6, 0xf     # Column selector

            mv t0, s3
            slli t0, t0, 4
            or s6, s6, t0       # Row selector

            la t0, LEDS
            sw s6, 0(t0)
            
            addi s1, s1, 4                      # increment the mask line index
            addi s3, s3, 1                      # increment the line index
            blt s3, s4, mask_line_loop           # if s3 < s4, loop

    mask_end:
        lw s6, 28(sp)
        lw s5, 24(sp)
        lw s4, 20(sp)
        lw s3, 16(sp)
        lw s2, 12(sp)
        lw s1, 8(sp)
        lw s0, 4(sp)
        lw ra, 0(sp)
        addi sp, sp, 32

        ret

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
