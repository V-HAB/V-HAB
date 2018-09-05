%returns the pressure loss for the sheath current of a shell and tube heat
%exchanger in N/m² = Pa
%
%sketch of the possible pipe configurations:
%
%                  aligend    |   shiffted     |  partially shiffted
%                 O   O   O   |  O   O   O     |  O     O     O
%                 O   O   O   |    O   O   O   |    O     O    O
%
%                                       /|\
%                  flow direction:       |
%
%entry parameters of the function are
%
%fD_o           = outer diameter of the pipes in m
%fD_Baffle      = diameter of the baffles in m
%fD_Batch       = outer diameter of the pipe batch in m
%fD_Hole        = diameter of the holes in the baffles through which the
%                 pipes pass in m
%fD_Shell       = inner diameter of the shell in m
%fD_Int         = inner diameter of the interface fittings in m
%fLength_Int    = length of the interface fittings in m
%fs_1           = distance between the center of two pipes next to each
%                 other perpendicular to flow direction in m
%fs_2           = distance between the center of two pipes next to each
%                 other in flow direction in m
%fN_Pipes       = total number of pipes in the heat exchanger
%fN_Pipes_Win   = number of pipes in the window left by a baffle
%fN_Resist      = number of main flow resistances (see [9] section Gh 4
%                 Bild 6 for instruction on how to count them)
%fN_Resist_End  = number of main flow resistances in the endzone
%fN_Sealings    = number of sealing strip pairs, between pipes and shell
%fN_Baffles     = number of baffles in the heat exchanger
%fN_Pipes_Diam  = number of pipes at the diameter, counted parallel to
%                 baffle edges.
%fN_Rows_Trans  = number of pipe rows in the transverse zone
%fDist_Baffle   = distance between baffles in m
%fDist_Baffle_End = distance between the first/last baffle and the outer
%                   walls of the heat exchanger in m
%fHeighst_Baffle  = height of baffles
%fMassFlow      = massflow of the fluid in kg/s
%fDyn_Visc      = dynamic viscosity of the fluid in kg/(m s)
%fDensity       = density of the fluid in kg/m³
%fThermal_Conductivity = thermal conductivity of the fluid in W/(m K)
%fC_p           = heat capacity of the fluid in J/K
%fConfig        = parameter to check the configuration,for fConfig = 0 it
%                 is assumed that the pipes are aligend.For fConfig = 1 it
%                 is assumed that they are shiffted with the pipes of each
%                 row shiffted exactly with fs_1/2. For fConfig = 2 a 
%                 partially shiffted configuration is assumed.  
%               
%for temperature dependant material values the values are needed for the
%average temperature between in and outlet T_m as well as the wall 
%temperature T_w
%These should be saved in the function values as vectors with the first
%entry beeing the material value for T_m and the second value for T_w
%
%for example for temperature dependant material values the inputs could be
%fDyn_Visc       = [21.9 ; 22.7]kg/(m s)
%fDensity        = [0.93; 0.88]kg/m³
%
%with the return parameter
%
%fDelta_Pressure = pressure loss in N/m²
%
%these parameters are used in the equation as follows:

%fDelta_Pressure = calculateSheathCurrent (fD_o, fD_Shell,...
%    fD_Baffle, fD_Batch, fD_Hole, fD_Int, fDist_Baffle, fDist_Baffle_End,...
%    fHeighst_Baffle, fLength_Int, fs_1, fs_2, fN_Pipes, fN_Rows_Trans,...
%    fN_Pipes_Diam, fN_Pipes_Win, fN_Sealings, fN_Baffles, fN_Resist,...
%    fN_Resist_End, fDyn_Visc, fDensity, fMassFlow, fConfig)

function [fDelta_Pressure] = SheathCurrent (fD_o, fD_Shell,...
    fD_Baffle, fD_Batch, fD_Hole, fD_Int, fDist_Baffle, fDist_Baffle_End,...
    fHeighst_Baffle, fLength_Int, fs_1, fs_2, fN_Pipes, fN_Rows_Trans,...
    fN_Pipes_Diam, fN_Pipes_Win, fN_Sealings, fN_Baffles, fN_Resist,...
    fN_Resist_End, fDyn_Visc, fDensity, fMassFlow, fConfig)

%the source "Wärmeübertragung" Polifke will from now on be defined as [1]
%the source "VDI Wärmeatlas" will from now on be defined as [9]
    
%decides wether temperature dependancy should also be accounted for
if length(fDyn_Visc) == 2 && fConfig == 0
    fConfig = 2;
elseif length(fDyn_Visc) == 2 && fConfig == 1
    fConfig = 3;
end

%Definition of the kinematic viscosity
fKin_Visc_m = fDyn_Visc(1)/fDensity(1);

%Definition of fPsi the relation between the diameter of the pipes and the
%spacing between them according to [9] section Gg 1 equation (9) + (10)
if fs_2/fD_o >= 1
    fPsi = 1 - (pi * fD_o)/(4 * fs_1);
else
    fPsi = 1 - (pi * fD_o^2)/(4 * fs_1 * fs_2);
end

%Definition of the overflowed length of the pipes according to [9] section
%Gg 1
fOverflow_Length = (pi/2) * fD_o;

%flowspeed
fFlowSpeed = fMassFlow/fDensity;

%Definition of the Reynolds number according to [9] section Gg 1 
%equation (6)
fRe = (fFlowSpeed * fOverflow_Length) / (fKin_Visc_m * fPsi);

%%pressureloss in transverse zone

%Definition of fA_SRU, the gap area between the holes in the baffles and
%the pipes, according to [9] section Gh 2 equation (18)
fA_SRU = (fN_Pipes - (fN_Pipes_Win/2)) * (pi * (fD_Hole^2 - fD_o^2))/4;

%Definition of the zentri angle fGamma according to [9] section Gh 2
%equation (20)
fGamma = 2 * acosd(1- ((2*fHeighst_Baffle)/fD_Baffle));

%Definition of fA_SMU, the gap area between the shell and the baffle
%according to [9] section Gh 2 equation (19)
fA_SMU = (pi/4) * ((fD_Shell^2) - (fD_Baffle^2)) * (360 - fGamma)/360;

%Definition of factor fFactor_r according to [9] section Lae4 equation (19) 
fFactor_r = (-0.15*(1 + (fA_SMU/(fA_SRU*fA_SMU))) + 0.8);

%Definition of the shortest connection length according to [9] section Gh3
%Bild 3
%aligend pipe positioning
if fConfig == 0
    fDist_Pipes = fs_1 * fD_o;
    
%shiffted pipe positioning    
elseif fConfig == 1 || fConfig == 2 
    if (fs_2/fD_o) < (0.5 * sqrt(2 * (fs_1/fD_o) + 1))
       fDist_Pipes = sqrt((fs_1/2)^2 + fs_2^2) - fD_o;
    else
       fDist_Pipes = fs_1 - fD_o;
    end  
else
    error('wrong input for config input')
end

%fDist_Pipes_Shell is the distance between the shell and the first outer
%pipe wall near the diameter
fDist_Pipes_Shell = (fD_Shell - fD_Batch)/2;

fConnecting_Length = ((fN_Pipes_Diam - 1) * fDist_Pipes) + (2 *...
                        fDist_Pipes_Shell);

%Definition of the leakage factor for the sheath current
%with baffles according to [9] section Lae4 equation (18) to (23) 
fLeackage_Factor = 0.4 * (fA_SRU/(fA_SRU + fA_SMU)) + (1 - (0.4 *...
                  (fA_SRU/(fA_SRU + fA_SMU)))) * exp(-1.5 * (((fA_SRU +...
                  fA_SMU)/(fDist_Baffle * fConnecting_Length))^fFactor_r));

%Definition of the bypass factor for the sheath current
%with baffles according to [9] section Lae 5 equation (24) + (25)  
if fRe < 100
    fBeta = 4.5;
else
    fBeta = 3.7;
end

%Definition of the area the bypass flow can use according to [9] section
%Gh 4 equation (26) + (27)
if fDist_Pipes >= (fD_Shell - fD_Batch)
    fA_Bypass = 0;
else
    fA_Bypass = fDist_Baffle*(fD_Shell - fD_Batch);
end

%Definition of the bypass factor according to [9] section Lae 4+5 equation
%(24)+(25)
if fN_Sealings <= (fN_Resist/2)
    fBypass_Factor = exp(-fBeta * fA_Bypass/(fDist_Baffle *...
                     fConnecting_Length) * (1 - nthroot((2*fN_Sealings)/...
                     fN_Resist, 3)));
else
    fBypass_Factor = 1;
end

%pressure loss at a pipe bundle
fDelta_Pressureressure_0 = pressure_loss_pipe_bundle(fD_o, fs_1, fs_2,...
                           fN_Rows_Trans, fFlowSpeed, fDyn_Visc,...
                           fDensity, fConfig);

fDelta_Pressure_Transverse = fLeackage_Factor*fBypass_Factor*...
                             fDelta_Pressureressure_0;

%%pressure loss in endzone

%equal flowspeed at end- and transversezone
if fDist_Baffle_End == fDist_Baffle
    fDelta_Pressure_End = fBypass_Factor*fDelta_Pressureressure_0*...
                          fN_Resist_End/fN_Resist;
%different flowspeed in the endzone compared to the transverse zone
else
    %flow speed in the end zone
    fFlowSpeed_End = fFlowSpeed*(fDist_Baffle/fDist_Baffle_End);
    
    %Reynoldsnumber in the endzone
    fRe_End = fRe*(fDist_Baffle/fDist_Baffle_End);
    
    %definition of correction factors
    if (fConfig == 2 || fConfig == 3) && fN_Rows_Trans > 9
        %factor for temperature dependency for laminar flow and more than 9 
        %rows according to [9] section Lad 4 - 5 equation (13) + (16)
        fLaminar_Factor_End = (fDyn_Visc(2)/fDyn_Visc(1))^(0.57/...
                           (((4*fs_1*fs_2/(pi*fD_o^2) - 1)*fRe_End)^0.25));
        %factor for temperature dependency for turbulent flow according to
        %[9] section Lad 5 equation (14)
        fTemp_Turb_Factor_End = (fDyn_Visc(2)/fDyn_Visc(1))^0.14;
    elseif (fConfig == 2 || fConfig == 3) && fN_Rows_Trans <= 9
        %factor for temperature dependency for laminar flow and less than
        %10 rows according to [9] section Lad 5 equation (15)
        fLaminar_Factor_End = (fDyn_Visc(2)/fDyn_Visc(1))^(0.57*...
                              ((fN_Rows_Trans/10)^0.25)/(((4*fs_1*fs_2/...
                              (pi*fD_o^2) - 1)*fRe_End)^0.25));
        %factor for temperature dependency for turbulent flow according to
        %[9] section Lad 5 equation (14)
        fTemp_Turb_Factor_End = (fDyn_Visc(2)/fDyn_Visc(1))^0.14;
    else
        fLaminar_Factor_End = 1;
        fTemp_Turb_Factor_End = 1;
    end
    
    if (fConfig == 0 || fConfig == 2) 
        %laminar friction factor in the endzone for aligned configuration
        %according to [9] section Lae 3 equation (6) + (7)
        fFriction_Factor_Lam_End = (280*pi*(((fs_2/fD_o)^0.5 -0.6)^(2)+...
                                    0.75))/(fRe_End*(4*(fs_1*fs_2/...
                                    (fD_o^2))-pi)*(fs_1/fD_o)^1.6);
    elseif (fConfig == 1 || fConfig == 3) && (fs_2/fD_o) >= ...
                                             (0.5*sqrt(2*fs_1/fD_o + 1))
        %laminar friction factor in the endzone for shiffted configuration
        %according to [9] section Lae 3 equation (11)
        fFriction_Factor_Lam_End = (280*pi*(((fs_2/fD_o)^0.5 -0.6)^(2)+...
                                   0.75))/(fRe_End*(4*(fs_1*fs_2/...
                                   (fD_o^2))-pi)*(fs_1/fD_o)^1.6);
    elseif (fConfig == 1 || fConfig == 3) && (fs_2/fD_o) < ...
                                              0.5*sqrt(2*fs_1/fD_o + 1)
        %laminar friction factor in the endzone for shiffted configuration
        %according to [9] section Lae 3 equation (12)
        fFriction_Factor_Lam_End = (280*pi*(((fs_2/fD_o)^0.5 -0.6)^(2)+...
                                   0.75))/(fRe_End*(4*(fs_1*fs_2/...
                                   (fD_o^2))-pi)*(sqrt((fs_1/...
                                   (2*fD_o))^(2)+ (fs_2/fD_o)^2))^1.6);
    end

    if fConfig == 0 || fConfig == 2
        %turbulent friction factor in the endzone for aligned configuration
        %according to [9] section Lae 3 equation (8) + (9)
        fFriction_Factor_Turb_End = ((0.22+1.2*((1-0.94*fD_o/fs_2)^0.6)/...
         (((fs_1/fD_o)-0.85)^1.3))*10^(0.47*(fs_2/fs_1 - 1.5))+...
         (0.03*(fs_1/fD_o - 1)*(fs_2/fD_o - 1)))/(fRe_End^(0.1*fs_2/fs_1));
    elseif fConfig == 1 || fConfig == 3 
        %turbulent friction factor in the endzone for shiffted 
        %configuration according to [9] section Lae 3 equation (14) + (15)
        fFriction_Factor_Turb_End = (2.5+(1.2/((fs_1/fD_o-0.85)^1.08))+...
                                    0.4*(fs_2/fs_1 - 1)^3 - 0.01*(fs_1/...
                                    fs_2 - 1)^3)/(fRe_End^(0.1*fs_2/fs_1));
    end

    %%
    %factor for turbulent flow to calculate the influence of the number of
    %pipe rows according to [9] section Lad 5 equation (17) to (20)

    if (fConfig == 1 || fConfig == 3) && (fs_2/fD_o) < ...
                                          0.5*sqrt(2*fs_1/fD_o + 1)
        fFriction_Factor_0_End = (2*(sqrt((fs_1/(2*fD_o))^2 + (fs_2/...
                               fD_o)^2) -1 ))/(fs_1/fD_o * (fs_1/fD_o -1));
    else
        fFriction_Factor_0_End = (fD_o^2)/(fs_1^2);
    end

    if 4 < fN_Rows_Trans && fN_Rows_Trans < 10
        fRow_Turb_Factor_End=fFriction_Factor_0_End*(1/fN_Rows_Trans-1/10);
    else
        fRow_Turb_Factor_End = 0;
    end

    %%
    %combined friction factor according to [9] section Lad 5 equation (21)+(22)
    if fConfig == 0 || fConfig == 2
        fFriction_Factor_End = fFriction_Factor_Lam_End * ...
            fLaminar_Factor_End + (fFriction_Factor_Turb_End * ...
            fTemp_Turb_Factor_End + fRow_Turb_Factor_End) * (1 - ...
            exp(-(fRe_End + 1000)/2000)); 
    elseif fConfig == 1 || fConfig == 3
        fFriction_Factor_End = fFriction_Factor_Lam_End * ...
            fLaminar_Factor_End + (fFriction_Factor_Turb_End * ...
            fTemp_Turb_Factor_End + fRow_Turb_Factor_End) * (1 - ...
            exp(-(fRe_End + 200)/2000));
    else
        error('wrong input for fConfig in pressure_loss_pipe_bundle')
    end
    
    %pressure loss in the endzone for a different flow speed according to
    %[9] section Lae 5 equation (30)
    fDelta_Pressure_End = fBypass_Factor*fN_Resist_End*...
                    fFriction_Factor_End*((fDensity*(fFlowSpeed_End^2))/2);
end
 
%%
%pressure loss in the window zone

%number of main flow resistances in the window zone according to [9]
%section Lae 6 equation (39)
fN_Resists_Win = 0.8*fHeighst_Baffle/fs_1;

%flow area of the window zone according to [9] section Lae 6 equation (41)
%to (43)
fA_Win = ((pi/4)*fD_Shell*(fGamma/360) - (((fD_Baffle - 2*...
          fHeighst_Baffle)*fD_Baffle)/4) * sin(fGamma/2)) - ((pi/4)*...
          (fD_o^2)*(fN_Pipes_Win/2));

%hydraulic diameter of the window zone according to [9] section Lae 6
%equation (40) + (44)
fD_Win = 4*(fA_Win/(pi*fD_Shell*(fGamma/360) + pi*fD_o*(fN_Pipes_Win/2)));

%flow speed in the window zone according to [9] section Lae 6 equation (45)
fFlowSpeed_Win = fMassFlow/(fDensity*fA_Win);

%reference flow speed in the window zone according to [9] section Lae 6 
%equation (45)
fFlowSpeed_z = sqrt(fFlowSpeed * fFlowSpeed_Win);

%Reynoldsnumber in the windowzone
fRe_Win = (fFlowSpeed_Win * fOverflow_Length) / (fKin_Visc_m * fPsi);

%laminar pressure loss in the window zone according to [9] section Lae 6
%equation (37)
fDelta_Pressure_Win_l = ((56/(fDist_Pipes*fFlowSpeed_z*fDensity/...
 fDyn_Visc(1)))*fN_Resists_Win + (52/(fD_Win*fFlowSpeed_z*fDensity/...
 fDyn_Visc(1)))*(fDist_Baffle/fD_Win) + 2)*(fDensity*fFlowSpeed_z^2)/2;

%turbulent pressure loss in the window zone according to [9] section Lae 6
%equation (38)
fDelta_Pressure_Win_t = (0.6*fN_Resists_Win+2)*(fDensity*fFlowSpeed_z^2)/2;

%definition of correction factors for temperature dependency
if (fConfig == 2 || fConfig == 3) && fN_Rows_Trans > 9
    %factor for temperature dependency for laminar flow and more than 9 
    %rows according to [9] section Lad 4 - 5 equation (13) + (16)
    fLaminar_Factor_Win = (fDyn_Visc(2)/fDyn_Visc(1))^(0.57/(((4*fs_1*...
                          fs_2/(pi*fD_o^2) - 1)*fRe_Win)^0.25));
    %factor for temperature dependency for turbulent flow according to [9]
    %section Lad 5 equation (14)
    fTemp_Turb_Factor_Win = (fDyn_Visc(2)/fDyn_Visc(1))^0.14;
elseif (fConfig == 2 || fConfig == 3) && fN_Rows_Trans <= 9
    %factor for temperature dependency for laminar flow and less than 10 
    %rows according to [9] section Lad 5 equation (15)
    fLaminar_Factor_Win = (fDyn_Visc(2)/fDyn_Visc(1))^(0.57*...
                          ((fN_Rows_Trans/10)^0.25)/(((4*fs_1*fs_2/...
                          (pi*fD_o^2) - 1)*fRe_Win)^0.25));
    %factor for temperature dependency for turbulent flow according to [9]
    %section Lad 5 equation (14)
    fTemp_Turb_Factor_Win = (fDyn_Visc(2)/fDyn_Visc(1))^0.14;
else
    fLaminar_Factor_Win = 1;
    fTemp_Turb_Factor_Win = 1;
end

%temperature dependency of the viscosity using the equations defined above
%according to [9] section Lae 6 equation (46) + (47)
if fRe < 100
    fTemp_Factor = fLaminar_Factor_Win;
else
    fTemp_Factor = fTemp_Turb_Factor_Win;
end

%pressure loss in the window zone according to [9] section Lae 6 
%equation (36)
%leakage factor fLeackage_Factor identical to transverse zone
fDelta_Pressure_Win = fTemp_Factor*fLeackage_Factor*...
                   sqrt(fDelta_Pressure_Win_l^2 + fDelta_Pressure_Win_t^2);

%%
%pressure loss in the interface fittings

fFlowSpeed_Int = fMassFlow/(fDensity*pi*((fD_Int^2)/4));

%pressure loss in the interface fittings according to [9] section Lae 6
%equation (48)
fDelta_Pressure_Int = pressure_loss_pipe (fD_Int, fLength_Int,...
                        fFlowSpeed_Int, fDyn_Visc, fDensity, fConfig);

%%
%total pressure loss in the sheath current according to [9] section Lae 2
%equation (1)
%the pressure loss in the interfaces is multiplied with 2 because two
%identical interfaces are assumed and the pressure loss fDelta_Pressure_Int
%was calculated only for one fitting
fDelta_Pressure = (fN_Baffles - 1)*fDelta_Pressure_Transverse +...
                2*fDelta_Pressure_End + fN_Baffles*fDelta_Pressure_Win +...
                2*fDelta_Pressure_Int;

end