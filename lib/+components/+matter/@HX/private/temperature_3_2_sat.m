%Calculates the outlet temperatures of a shell and tube heat exchanger with
%3 outer and 2 inner passes using the cell method.
%
%Fluid 1 stands for the fluid inside the tubes.
%
%The function uses the following input parameters
%
%fArea            = total area of the heat exchanger in m²
%fU               = total heat exchange coefficient in W/m²K for the heat
%                   exchanger
%fHeat_Cap_Flow_1 = heat capacity flow of mixed stream in W/K
%fHeat_Cap_Flow_2 = heat capacity flow of unmixed stream in W/K
%fEntry_Temp_1    = inlet temperature of fluid 1 in K (inside the pipes)
%fEntry_Temp_2    = inlet temperature of fluid 2 in K
%
%These arguments are used in the function as follows:
%
%[fOutlet_Temp_1, fOutlet_Temp_2] = temperature_3_2_sat (fArea, fU,...
%       fHeat_Cap_Flow_1, fHeat_Cap_Flow_2, fEntry_Temp_1, fEntry_Temp_2)
%
%With the outputs fOutlet_Temp_1 and fOutlet_Temp_2 in K

function [fOutlet_Temp_1, fOutlet_Temp_2]=temperature_3_2_sat(fArea, fU,...
          fHeat_Cap_Flow_1, fHeat_Cap_Flow_2, fEntry_Temp_1, fEntry_Temp_2)

%equations according to “Wärmeübertragung Grundlagen und Praxis"
%P. von Böckh and W. Thomas. From now on defined as [8].

%Basic schema of the heat exchanger
%
%                                                      Inlet fluid 2
%                    ____________________________________ \/ __
%                   |                            |             |
%Inlet fluid 1   ->     cell 1   |    cell 2     |    cell 3   |
%                   |____________|_______________|_________    |
%                   |            |               |             |
%Outlet fluid 1  <-     cell 6   |    cell 5     |    cell 4   |
%                   |_    _______|_____________________________|
%                      \/
%                    Outlet fluid 2
%
%The cells are numerated in the order Fluid 1 (the inner fluid)
%passes through them. Fluid 2 passes from 3 -> 4 -> 5 -> 2 -> 1 -> 6

%Number of cells
fCells = 3*2;

%Number of Transferunits fluid 1 and fluid 2
fNTU_1 = (fU*fArea)/fHeat_Cap_Flow_1;                          
fNTU_2 = (fU*fArea)/fHeat_Cap_Flow_2;
%Equation from "Wärme- und Stoffübertragung" Baehr side 58 table 1.4

%Number of transferunits for the cells according to [8] page 221 equation
%(8.15)
fNTU_1_c = fNTU_1/fCells;
fNTU_2_c = fNTU_2/fCells;

%preallocates vectors for the inlet (0) and outlet (1) temperatures for
%each cell and for each fluid stream (1 or 2). This means that the
%vector T11 contains all outlet temperatures of fluid 1 and each cell. So
%the entry T11(2,1) contains the outlet of the second cell.

myT10 = sym ('T10',[fCells,1]);
myT11 = sym ('T11',[fCells,1]);

myT20 = sym ('T20',[fCells,1]);
myT21 = sym ('T21',[fCells,1]);

%set the inlet values for both fluids at the right position.For fluid 1 it
%is the first inlet value since this fluid defines the numbering of the
%cells,for fluid 2 it is the 3rd cell.

myT10(1) = fEntry_Temp_1;
myT20(3) = fEntry_Temp_2;

syms yT1_i yT2_i

%function for the outlet temperature of fluid 1 with the inlet temperatures
%yT1_i and yT2_i
f1(yT1_i, yT2_i) = yT2_i + (yT1_i - yT2_i) * exp( -(fNTU_1_c/fNTU_2_c) *...
                   (1 - exp(-fNTU_2_c)) );

%function for the outlet temperature of fluid 2 using the function from
%above
f2(yT1_i, yT2_i) = (fHeat_Cap_Flow_1/fHeat_Cap_Flow_2) * (yT1_i -...
                   (yT2_i + (yT1_i - yT2_i) * exp( -(fNTU_1_c/fNTU_2_c) *...
                   (1 - exp(-fNTU_2_c)) )) ) + yT2_i;

%uses the functions above to calculate the outlet temperatures of each cell
%depending on the inlet temperatures

for fk = 1:fCells
    myT11(fk) = f1(myT10(fk), myT20(fk));
    myT21(fk) = f2(myT10(fk), myT20(fk));
end

%preallocation of vector A
mA = sym(zeros(2*(fCells-1),1));

%fills the first 5 elements of A with the Temperatures T102 to T106
for fk = 1:(fCells-1)
    mA(fk,1) = myT10(fk+1);
end

%fills the remaining 5 elements of A with the yet unknown temperatures of
%fluid 2
mA(6,1)  = myT20(1);
mA(7,1)  = myT20(2);
mA(8,1)  = myT20(4);
mA(9,1)  = myT20(5);
mA(10,1) = myT20(6); 

%preallocation of vector B
mB = sym(zeros(2*(fCells-1),1));

%fills the first 5 elements of B according to the boundary conditions
%for fluid 1. These conditions are that the inlet temperature of a cell is
%always the outlet temperature of the previous cell (for fluid 1 this is
%the case for fluid 2 it gets more complicated)

for fk = 1:(fCells-1)
    mB(fk,1) = myT11(fk);
end

%fills the remaining five elements of B according to boundary conditions
%for fluid 2, since fluid 2 doesn't pass the cells according to their
%numbering it has to be done by hand (see schematic and description in
%which way fluid 2 passes through the cells at the beginning of the code)

mB(6,1)  = myT21(2);
mB(7,1)  = myT21(5);
mB(8,1)  = myT21(3);
mB(9,1)  = myT21(4);
mB(10,1) = myT21(1); 

%now solves the 10 equations gained from the boundary conditions
csolution = solve (mA == mB);

%since the solution above is in struct which makes it hard to access
%it is converted into a cell array
csolution = struct2cell(csolution);

%gets the solution for T106 which is the inlet temperature of cell 6 for
%fluid 1
fT106 = double(csolution{(fCells-1)});

%gets the solution for T206 which is the inlet temperature of cell 6 for
%fluid 2
fT206 = double(csolution{(2*(fCells-1))});

%calculates the outlet temperatures of cell 6
fOutlet_Temp_1 = f1(fT106, fT206);
fOutlet_Temp_2 = f2(fT106, fT206);

%converts the sym results to double
fOutlet_Temp_1 = double(fOutlet_Temp_1);
fOutlet_Temp_2 = double(fOutlet_Temp_2);

end
