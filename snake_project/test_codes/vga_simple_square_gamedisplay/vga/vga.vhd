-- Device: Cyclone V 5CEBA4F23C7
----------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
----------------------------------------------------------
PACKAGE vga_disp_buf IS 
    CONSTANT SCREEN_W: INTEGER := 640;
    CONSTANT SCREEN_H: INTEGER := 480;
    CONSTANT SQ_SIZE: INTEGER := 32;	-- Need such low res to actually fit design
    -- A display row, of SLVs in [G, R] format
	 -- No support for blue (not needed)
    TYPE disp_row IS ARRAY 
        (0 to (SCREEN_W / SQ_SIZE) - 1) OF std_logic_vector(1 downto 0);
    -- The whole display 
    TYPE disp_buf IS ARRAY 
        (0 to (SCREEN_H / SQ_SIZE) - 1) OF disp_row;
END PACKAGE;
----------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE work.vga_disp_buf.all;
----------------------------------------------------------
ENTITY vga IS
    GENERIC (
        Ha: INTEGER := 96; --Hpulse
        Hb: INTEGER := 144; --Hpulse+HBP
        Hc: INTEGER := 784; --Hpulse+HBP+Hactive
        Hd: INTEGER := 800; --Hpulse+HBP+Hactive+HFP
        Va: INTEGER := 2; --Vpulse
        Vb: INTEGER := 35; --Vpulse+VBP
        Vc: INTEGER := 515; --Vpulse+VBP+Vactive
        Vd: INTEGER := 525); --Vpulse+VBP+Vactive+VFP
    PORT (
        -- Display buffer
        --      Pass in from game code
        --display_buffer: IN disp_buf;
        -- VGA signals:
        clk: IN STD_LOGIC; --50MHz in our board
        pixel_clk: BUFFER STD_LOGIC;
        Hsync, Vsync: BUFFER STD_LOGIC;
        R, G, B: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        nblanck, nsync : OUT STD_LOGIC);
END vga;
----------------------------------------------------------
ARCHITECTURE vga OF vga IS
    SIGNAL Hactive, Vactive, dena: STD_LOGIC;
BEGIN
    -------------------------------------------------------
    --Part 1: CONTROL GENERATOR
    -------------------------------------------------------
    --Static signals for DACs:
    nblanck <= '1'; --no direct blanking
    nsync <= '0'; --no sync on green
    --Create pixel clock (50MHz->25MHz):
    PROCESS (clk)
    BEGIN
        IF (clk'EVENT AND clk='1') THEN
            pixel_clk <= NOT pixel_clk;
        END IF;
    END PROCESS;
    --Horizontal signals generation:
    PROCESS (pixel_clk)
        VARIABLE Hcount: INTEGER RANGE 0 TO Hd;
    BEGIN
        IF (pixel_clk'EVENT AND pixel_clk='1') THEN
            Hcount := Hcount + 1;
            IF (Hcount=Ha) THEN
                Hsync <= '1';
            ELSIF (Hcount=Hb) THEN
                Hactive <= '1';
            ELSIF (Hcount=Hc) THEN
                Hactive <= '0';
            ELSIF (Hcount=Hd) THEN
                Hsync <= '0';
                Hcount := 0;
            END IF;
        END IF;
    END PROCESS;
    --Vertical signals generation:
    PROCESS (Hsync)
        VARIABLE Vcount: INTEGER RANGE 0 TO Vd;
    BEGIN
    IF (Hsync'EVENT AND Hsync='0') THEN
        Vcount := Vcount + 1;
        IF (Vcount=Va) THEN
            Vsync <= '1';
        ELSIF (Vcount=Vb) THEN
            Vactive <= '1';
        ELSIF (Vcount=Vc) THEN
            Vactive <= '0';
        ELSIF (Vcount=Vd) THEN
            Vsync <= '0';
            Vcount := 0;
        END IF;
    END IF;
    END PROCESS;
    ---Display enable generation:
    dena <= Hactive AND Vactive;
    -------------------------------------------------------
    --Part 2: IMAGE GENERATOR
    -------------------------------------------------------
    PROCESS (Hsync, Vsync, Vactive, dena, pixel_clk)
        VARIABLE row_counter: INTEGER RANGE 0 TO Vc;
        VARIABLE col_counter: INTEGER RANGE 0 TO Hc;
        VARIABLE game_row: INTEGER RANGE 0 TO SCREEN_H / SQ_SIZE;
        VARIABLE game_col: INTEGER RANGE 0 TO SCREEN_W / SQ_SIZE;
        VARIABLE game_row_row: INTEGER RANGE 0 TO SQ_SIZE - 1;
        VARIABLE game_col_col: INTEGER RANGE 0 TO SQ_SIZE - 1;
        VARIABLE curr_sq:     std_logic_vector(1 downto 0);
		  VARIABLE display_buffer: disp_buf;
    BEGIN
        -- Initialize display buffer - test image
		  FOR row IN 0 TO (SCREEN_H / SQ_SIZE) - 1 LOOP 
		      FOR col IN 0 TO (SCREEN_W / SQ_SIZE) - 1 LOOP
				    IF ((row mod 2 = 1) AND (col mod 2 = 1)) THEN 
					     display_buffer(row)(col) := "11";
					 ELSIF ((row mod 2 = 0) AND (col mod 2 = 0)) THEN 
					     display_buffer(row)(col) := "00";
				    ELSIF ((row mod 2 = 0) AND (col mod 2 = 1)) THEN 
					     display_buffer(row)(col) := "01";
					 ELSE 
					     display_buffer(row)(col) := "10";
					 END IF;
				END LOOP;
		  END LOOP;
        -- Reset row counter if Vsync is low
        IF (Vsync='0') THEN
            row_counter := 0;
        -- Otherwise increment row counter if Hsync rising edge and Vactive 
        -- is high
        ELSIF rising_edge(Hsync) THEN
            IF (Vactive='1') THEN
                row_counter := row_counter + 1;
            END IF;
        END IF;
        -- Reset column counter if Hsync is low
        IF (Hsync='0') THEN
            col_counter := 0;
        -- Otherwise increment column counter if pixel_clk rising edge and 
        -- Hactive is high
        ELSIF rising_edge(pixel_clk) THEN
            IF (Hactive='1') THEN
                col_counter := col_counter + 1;
            END IF;
        END IF;
		-- If screen enabled
        IF (dena='1') THEN
		    -- Plot the screen here
    
            -- Get the current square [G, R] slv
            game_row := row_counter / SQ_SIZE;          -- Current row, col of 
            game_col := col_counter / SQ_SIZE;          -- game square
            game_row_row := row_counter mod SQ_SIZE;    -- Current row, col
            game_col_col := col_counter mod SQ_SIZE;    -- inside game square
            curr_sq := display_buffer(game_row)(game_col);
            
            -- Get RG components of square 
            -- Clear the border
            -- IF((row_counter = SQ_SIZE * game_row) OR 
            --    (row_counter = SQ_SIZE * (game_row + 1) - 1) OR
            --    (col_counter = SQ_SIZE * game_col) OR 
            --    (col_counter = SQ_SIZE * (game_col + 1) - 1)) THEN 
            --     R <= (OTHERS => '0');
            --     G <= (OTHERS => '0');
            -- Clear the outer corners 
            IF( (game_row_row + game_col_col >= 8) AND 
                (game_row_row - game_col_col <= SQ_SIZE - 8) AND 
                (game_col_col - game_row_row <= SQ_SIZE - 8) AND 
                (game_row_row + game_col_col <= 2 * SQ_SIZE - 8) ) THEN 
                R <= (OTHERS => curr_sq(0));
                G <= (OTHERS => curr_sq(1));
            --B <= (OTHERS => '0');
            --B <= (OTHERS => curr_sq(2));
            ELSE 
                R <= (OTHERS => '0');
                G <= (OTHERS => '0');
            END IF;
        -- If screen disabled, turn off the entire screen
        ELSE
            R <= (OTHERS => '0');
            G <= (OTHERS => '0');
            --B <= (OTHERS => '0');
        END IF;
		  B <= (OTHERS => '0');
    END PROCESS;
END vga;
----------------------------------------------------------