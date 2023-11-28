library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top is 
    port (
        SIG_IN : in std_logic;
        LED : out std_logic
    );
end top;

architecture arch_top of top is

    -- signal sig_out : std_logic;

begin

    -- Assign the output of the component to the LED
    LED <= SIG_IN;

end arch_top;