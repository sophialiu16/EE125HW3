library verilog;
use verilog.vl_types.all;
entity abs_difference_calculator is
    port(
        a0              : in     vl_logic_vector(4 downto 0);
        a1              : in     vl_logic_vector(4 downto 0);
        a2              : in     vl_logic_vector(4 downto 0);
        a3              : in     vl_logic_vector(4 downto 0);
        a4              : in     vl_logic_vector(4 downto 0);
        a5              : in     vl_logic_vector(4 downto 0);
        b0              : in     vl_logic_vector(4 downto 0);
        b1              : in     vl_logic_vector(4 downto 0);
        b2              : in     vl_logic_vector(4 downto 0);
        b3              : in     vl_logic_vector(4 downto 0);
        b4              : in     vl_logic_vector(4 downto 0);
        b5              : in     vl_logic_vector(4 downto 0);
        abs_diff        : out    vl_logic_vector(0 to 7)
    );
end abs_difference_calculator;
