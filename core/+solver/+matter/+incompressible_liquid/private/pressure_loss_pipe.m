%returns the pressure loss for a pipe in N/m² = Pa
%
%entry parameters of the function are
%
%fD_Hydraulic   = inner hydraulic diameter of the pipe in m
%fLength        = length of the pipe in m
%fFlowSpeed     = flow speed of the fluid in the pipe in m/s
%fDyn_Visc      = dynamic viscosity of the fluid in kg/(m s)
%fDensity       = density of the fluid in kg/m³
%fConfig        = parameter to set the function configuration 
%                 for fConfig = 0 a round pipe is assumed
%                 for fConfig = 1 a quadratic pipe is assumed
%                 for fConfig = 2 an annular passage is assumed
%
%for an annular passage the additional parameter fD_o is needed
%fD_o           = inner diameter of the outer pipe in m
%
%for temperature dependant material values the values are needed for the
%average temperature between in and outlet T_m as well as the wall 
%temperature T_w
%These should be saved in the function values as vectors with the first
%entry beeing the material value for T_m and the second value for T_w
%
%for example for temperature dependant material values the inputs could be
%fDyn_Visc      = [21.9 ; 22.7]kg/(m s)
%fDensity       = [0.93; 0.88]kg/m³
%
%with the return parameter
%
%fDelta_Pressure = pressure loss in N/m²
%
%these parameters are used in the equation as follows:
%
%fDelta_Pressure = pressure_loss_pipe (fD_Hydraulic, fLength, fFlowSpeed,..
%                                      fDyn_Visc, fDensity, fConfig);

function [fDelta_Pressure] = pressure_loss_pipe (fD_Hydraulic, fLength,...
                            fFlowSpeed, fDyn_Visc, fDensity, fRoughness, fConfig, fD_o)

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]
%the source "VDI Wärmeatlas" will from now on be defined as [9]
    
if nargin == 5
    fRoughness = 0;
    fConfig = 0;
elseif nargin == 6
    fConfig = 0;
end
%decides wether temperature dependancy should also be accounted for
if length(fDyn_Visc) == 2 && fConfig == 0
    fConfig = 3;
elseif length(fDyn_Visc) == 2 && fConfig == 1
    fConfig = 4;
elseif length(fDyn_Visc) == 2 && fConfig == 2
    fConfig = 5;
end

%Definition of the kinematic viscosity
fKin_Visc_m = fDyn_Visc(1)/fDensity(1);

%Definition of the Reynolds number according to [1] page 232 equation
%(10.30)
fRe = (fFlowSpeed * fD_Hydraulic) / fKin_Visc_m;

%%
%calculation for technical smooth pipes
if fRoughness == 0
    %%
    %laminar flow
    if fRe < 3000
        %definition of the friction factor according to [9] section Lab
        %equation (4) for a round pipe
        if fConfig == 0 || fConfig == 3
            fFriction_Factor = 64/fRe;
        %definition of the friction factor according to [9] section Lab
        %equation (14) for a square pipe
        elseif fConfig == 1 || fConfig == 4
            fFriction_Factor = 0.89*64/fRe;
        %definition of the friction factor according to [9] section Lab
        %equation (14) for an annular passage using an interpolation for the
        %shape factor
        elseif fConfig == 2 || fConfig ==5
            %calculation of the outer diameter of the inner tube from the
            %hydraulic diameter
            fD_i = fD_o - fD_Hydraulic;
            %interpolation for the shape factor of an annular passage
            if 1 < (fD_o/fD_i) && (fD_o/fD_i) < 2
                fFriction_Factor = 1.5*64/fRe;
            elseif 2 <= (fD_o/fD_i) && (fD_o/fD_i) < 9
                fFriction_Factor =(1.5+(1.4-1.5)/(9-2)*((fD_o/fD_i)-2))*64/fRe;
            elseif 9 <= (fD_o/fD_i) && (fD_o/fD_i) < 40
                fFriction_Factor=(1.4+(1.3-1.4)/(40-9)*((fD_o/fD_i)-9))*64/fRe;
            elseif 40 <= (fD_o/fD_i) && (fD_o/fD_i) < 100
                fFriction_Factor = (1.3+(1.25-1.3)/(100-40)*((fD_o/fD_i)-40))...
                                    *64/fRe;
            else
                error('no interpolation for values of fD_o/fD_i larger than 100 in pressure_loss_pipe')
            end
        end
    elseif 3000 <= fRe && fRe < 100000
        %definition of the friction factor according to [9] section Lab
        %equation (5)
        fFriction_Factor = 0.3164/nthroot(fRe,4);
    elseif 100000 <= fRe && fRe < 10^6
        %definition of the friction factor according to [9] section Lab
        %equation (6)
        fFriction_Factor = (1.8*log10(fRe)-1.5)^(-2);

    %the equation for Re > 10^6 is approximate since the accurate equation
    %is implicit and would take more calculation time.  The accurate one
    %would be equation (7) from the same source.
    %definition of the friction factor according to [9] section Lab
    %equation (7a)
    elseif fRe > 10^6
        fFriction_Factor = (1/(1.819*log10(fRe)-1.64))^2;
        
    %in case that no possible solution is found the programm returns the values
    %of Reynolds and Prandtlnumber as well as some key data to simplify
    %debugging for the user    
    else
        fprintf(['Reynolds number is out of bounds. \n', ...
                'Reynolds is valid for Re < 10^6. The value is %d \n', ...
                'The flow speed is: %d \n', ...
                'the kinematic viscosity is %d'], ...
                fRe, fFlowSpeed, fKin_Visc_m);
        error('Reynolds number out of bounds.')    
    end
%%
%calculation in case of rough pipes
else
    %definition of the friction factor according to [9] section Lab
    %equation (9)
    %this equation is applicable for developed roughness flow
    fFriction_Factor = (1/(2*log10(fD_Hydraulic/fRoughness)+1.14))^2; 
    
    %for turbulent flow there is a more accurate equation but because it is
    %implicit it will not be used ( [9] section Lab
    %equation (10))
end
    
%definition of the pressure loss according to [9] section Lab
%equation (1)
if fFlowSpeed == 0
    fDelta_Pressure = 0;
else
    fDelta_Pressure = fFriction_Factor * fLength/fD_Hydraulic * (fDensity(1)*...
                  fFlowSpeed^2)/2;
end


end