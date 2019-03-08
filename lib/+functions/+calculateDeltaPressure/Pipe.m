function [fDelta_Pressure] = Pipe (fD_Hydraulic, fLength,...
                            fFlowSpeed, fDyn_Visc, fDensity, fRoughness, fConfig, fD_o)
%returns the pressure loss for a pipe in N/m² = Pa
%
%entry parameters of the function are
%
%fD_Hydraulic   = inner hydraulic diameter of the pipe in m
%fLength        = length of the pipe in m
%fFlowSpeed     = flow speed of the fluid in the pipe in m/s
%fDyn_Visc      = dynamic viscosity of the fluid in kg/(m s)
%fDensity       = density of the fluid in kg/m³
%fRoughness     = Surface roughness K of the pipe in m according to [9] 
%                 page 1224 equation (8)
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
%with the return parameter
%
%fDelta_Pressure = pressure loss in N/m²
%
%these parameters are used in the equation as follows:
%
%fDelta_Pressure = pressure_loss_pipe (fD_Hydraulic, fLength, fFlowSpeed,..
%                                      fDyn_Visc, fDensity, fConfig);

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]
%the source "VDI Wärmeatlas" 11. Auflage will from now on be defined as [9]

%% Transitions between laminar, trubulent and developed roughness flow
% see [9] page 1225 Abbildung 1 for a graphical representation of the flow areas
%
% Laminar flow calculations can be used for Re < 2320 and a roughness K of
% less than 0.07mm ([9] page 1223). These can use the Hagen Poisselle
% Equation  (Equation 3 or 4 from [9] page 1223).
%
% Turbulent flow is actually a transition area, which lies between laminar
% and developed roughness flow. The transition region to developed
% roughness flow depends on the Re and the relative roughness, which is
% K divided with the hydraulic diameter. The colebrook equation can be used
% for the turbulent flow area ([9] page 1224 equation 10). The transition
% to developed roughness flow will use a conservative linear boundary which
% uses the colebrook equation in some regions where developed roughness
% flow is already present. This is not an issue since the colebrook
% equation is a more accurate representation and would transition to the
% equation for developed roughness flow. The coolebrook equation however is
% implicit and therefore requires much more computational resources.
%
% Developed roughness flow can then use the simpler equation from [9] page
% 1224 equation 9 again
if nargin == 5
    fRoughness = 0;
    fConfig = 0;
elseif nargin == 6
    fConfig = 0;
end

%Definition of the kinematic viscosity
fKin_Visc_m = fDyn_Visc/fDensity;

%Definition of the Reynolds number according to [1] page 232 equation
%(10.30)
fFlowSpeed = abs(fFlowSpeed);
fRe = (fFlowSpeed * fD_Hydraulic) / fKin_Visc_m;

%%
%calculation for technical smooth pipes
%%
%laminar flow
if (fRe < 2320) % check roughness limit
    %definition of the friction factor according to [9] section Lab
    %equation (4) for a round pipe
    if fConfig == 0
        fFriction_Factor = 64/fRe;
    %definition of the friction factor according to [9] section Lab
    %equation (14) for a square pipe
    elseif fConfig == 1
        fFriction_Factor = 0.89*64/fRe;
    %definition of the friction factor according to [9] section Lab
    %equation (14) for an annular passage using an interpolation for the
    %shape factor
    elseif fConfig == 2
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
elseif fRoughness == 0 && 2320 <= fRe && fRe < 100000
    %definition of the friction factor according to [9] section Lab
    %equation (5)
    fFriction_Factor = 0.3164/nthroot(fRe,4);
    
    % To prevent oscillations in the solver we smooth the transition
    % between laminar and non laminar flows:
    if fRe < 3320
        fFriction_Factor = ((64/2320) * (3320 - fRe)/1000) + (fFriction_Factor * (fRe - 2320)/1000);
    end
    
elseif fRoughness == 0 && 100000 <= fRe && fRe < 10^6
    %definition of the friction factor according to [9] section Lab
    %equation (6)
    fFriction_Factor = (1.8*log10(fRe)-1.5)^(-2);

%the equation for Re > 10^6 is approximate since the accurate equation
%is implicit and would take more calculation time.  The accurate one
%would be equation (7) from the same source.
%definition of the friction factor according to [9] section Lab
%equation (7a)
elseif fRoughness == 0 && fRe > 10^6
    fFriction_Factor = (1/(1.819*log10(fRe)-1.64))^2;

%in case that no possible solution is found the programm returns the values
%of Reynolds and Prandtlnumber as well as some key data to simplify
%debugging for the user    
elseif fRoughness == 0
    fprintf('Reynolds number is out of bounds. \n Reynolds is valid for Re < 10^6. The value is %d \n the flow speed is: %d \n the kinematic viscosity is %d\n', fRe, fFlowSpeed, fKin_Visc_m);
    error('Reynolds number out of boundaries')
else
% calculation in case of rough pipes. The limit is based on [9] page 1225
% Abb 1 shows the border between the different flow regimes. Based on that
% picture the following linear interpolation for a conservative boundary
% between the transition area and the developed roughness flow is developed
% as follows:
%
% 1.5*10^4 and epsilon = 0.05
% 5*10^8 and epsilon = 0.00005
%
% Y = m*X+t
% 0.05    = m*1.5*10^4 + t
% 0.00005 = m*5*10^8 + t
%
% m = dY/dX = (0.00005 - 0.05) / (5*10^8 - 1.5*10^4) = -9.990299708991270e-11
%
% t = 0.05 - m*1.5*10^4 = 0.050001498544956
    fLimitEpsilon = (-9.990299708991270e-11 * fRe) + 0.050001498544956;
    % relative roughness Equation from [9] page 1224 euqation (8)
    fEpsilon = fRoughness / fD_Hydraulic;
    
    if fEpsilon > fLimitEpsilon
        %definition of the friction factor according to [9] section Lab
        %equation (9)
        %this equation is applicable for developed roughness flow
        fFriction_Factor = (1/(2*log10(fD_Hydraulic/fRoughness)+1.14))^2; 

    else
        % The colebrook equation is used for all other cases, which is the
        % transition area between the laminar and the developed roughness
        % flow. However, even if some other case is caught by this
        % equation, it is not an issue as it is the most accurate one and
        % can also be used for the developed roughness flow
        % Source: [9] page 1224 Equation 10
        %
        % fast, accurate and robust computation of the Darcy-Weisbach
        % friction factor F according to the Colebrook equation:
        %                             -                       -
        %      1                     |  K/d_i        2.51        |
        %  ---------  =  -2 * Log_10 |  ----- + -------------  |
        %   sqrt(F)                  |   3.7     fRe * sqrt(F)   |
        %                             -                       -
        % ACCURACY:
        %   Around machine precision forall fRe > 3 and forall 0 <= K, 
        %   i.e. forall values of physical interest. 
        % Method: Quartic iterations.
        % Reference: http://arxiv.org/abs/0810.5564 
        % Read this reference to understand the method and to modify the code.
        %
        % Author: D. Clamond, 2008-09-16. 

        % Initialization.
        X1 = fRoughness/fD_Hydraulic .* fRe * 0.123968186335417556;     % X1 <- K * fRe * log(10) / 18.574.
        X2 = log(fRe) - 0.779397488455682028;                           % X2 <- log( fRe * log(10) / 5.02 );                   

        % Initial guess.                                              
        fFriction_Factor = X2 - 0.2;     

        % First iteration.
        E = ( log(X1+fFriction_Factor) - 0.2 ) ./ ( 1 + X1 + fFriction_Factor );
        fFriction_Factor = fFriction_Factor - (1+X1+fFriction_Factor+0.5*E) .* E .*(X1+fFriction_Factor) ./ (1+X1+fFriction_Factor+E.*(1+E/3));

        % Second iteration (remove the next two lines for moderate accuracy).
        E = ( log(X1+fFriction_Factor) + fFriction_Factor - X2 ) ./ ( 1 + X1 + fFriction_Factor );
        fFriction_Factor = fFriction_Factor - (1+X1+fFriction_Factor+0.5*E) .* E .*(X1+fFriction_Factor) ./ (1+X1+fFriction_Factor+E.*(1+E/3));

        % Finalized solution.
        fFriction_Factor = 1.151292546497022842 ./ fFriction_Factor; 	% F <- 0.5 * log(10) / F;
        fFriction_Factor = fFriction_Factor .* fFriction_Factor;        % F <- Friction factor.
    end
    
    % To prevent oscillations in the solver we smooth the transition
    % between laminar and non laminar flows:
    if fRe < 3320
        fFriction_Factor = ((64/2320) * (3320 - fRe)/1000) + (fFriction_Factor * (fRe - 2320)/1000);
    end
end
    
%definition of the pressure loss according to [9] section Lab
%equation (1)
if fFlowSpeed == 0
    fDelta_Pressure = 0;
else
    fDelta_Pressure = fFriction_Factor * fLength/fD_Hydraulic * (fDensity(1) * fFlowSpeed^2)/2;
end


end