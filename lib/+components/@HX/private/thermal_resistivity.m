%returns the thermal resistivity resulting from conduction in the heat
%exchanger material in K/W
%
%fThermal_Cond_solid = thermal conductivity of the pipe material in W/(m K)
%fConfig        = config of the thermal resistor:
%                 0: round pipe
%                 1: quadratic pipe
%                 2: plate
%
%Parameters for a pipe, either round or quadratic
%fRadius_in     = inner radius, for quadratic pipes: inner edge length in m
%fRadius_out    = outer radius, for quadratic pipes: outer edge length in m
%fLength        = length of the pipe in m
%
%Parameters for a plate
%fArea          = Area of the plate in m²
%fThickness     = thickness of the plate in m
%
%these parameters are used in the equation as follows:
%
%for a round pipe
%fResist_Cond = thermal_resitivity(fThermal_Cond_solid, fConfig,...
%               fRadius_in, fRadius_out, fLength) 
%
%for a plate
%fResist_Cond = thermal_resitivity(fThermal_Cond_solid, 2,...
%               fArea, fThickness) 

function [fResist_Cond] = thermal_resistivity(fThermal_Cond_solid,...
                          fConfig, fRadius_in, fRadius_out, fLength)

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]
if fConfig == 0
    %thermal resistivity of a pipe according to [1] page 67 equation (3.14)
    fResist_Cond = 1/(2*pi*fLength*fThermal_Cond_solid)*log(fRadius_out/...
                   fRadius_in);
    
elseif fConfig == 1
    %form factor for a quadratic pipe according to [1] page 85 Abb. (3.10)
    if fRadius_out/fRadius_in > 1.4
        fForm_Factor = (2*pi)/(0.93*log(fRadius_out/fRadius_in)-0.05202);
    else
        fForm_Factor =(2*pi)/(0.785*log(fRadius_out/fRadius_in));
    end
    
    fResist_Cond = 1/(fThermal_Cond_solid*fForm_Factor*fLength);
    
elseif fConfig == 2
    %thermal resistivity of a plate according to [1] page 67 equation(3.13)
    %for a plate the variables fRadius_in = fArea and 
    %fRadius_out = fThickness
    fResist_Cond = fRadius_out/(fThermal_Cond_solid*fRadius_in);
else
    error('wrong input for fconcfig in fResist_Cond')
end


end