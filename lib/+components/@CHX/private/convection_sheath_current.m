%returns the convection coeffcient alpha for the sheath current of a shell
%and tube heat exchanger with baffles in W/m≤K
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
%fD_Baffle      = diameter of the baffles
%fD_Batch       = outer diameter of the pipe batch
%fD_Hole        = diameter of the holes in the baffles through which the
%                 pipes pass
%fD_Shell       = inner diameter of the shell
%fs_1           = distance between the center of two pipes next to each
%                 other perpendicular to flow direction in m
%fs_2           = distance between the center of two pipes next to each
%                 other in flow direction in m
%fN_Pipes       = total number of pipes in the heat exchanger
%fN_Pipes_Win   = number of pipes in the window left by a baffle
%fN_FlowResist  = number of main flow resistances (see [9] section Gh 4
%                 Bild 6 for instruction on how to count them)
%fN_Sealings    = number of sealing strip pairs, between pipes and shell
%fN_Pipes_Diam  = number of pipes at the diameter, counted parallel to
%                 baffle edges.
%fDist_Baffle   = distance between baffles in m
%fHeight_Baffle = height of baffles
%fFlowSpeed     = flow speed of the fluid outside the pipes in m/s
%fDyn_Visc      = dynamic viscosity of the fluid in kg/(m s)
%fDensity       = density of the fluid in kg/m≥
%fThermal_Conductivity  = thermal conductivity of the fluid in W/(m K)
%fC_p           = heat capacity of the fluid in J/K
%fConfig        = parameter to check the configuration,for fConfig = 0 it
%                 is assumed that the pipes are aligend.For fConfig = 1 it
%                 is assumed that they are shiffted with the pipes of each
%                 row shiffted exactly with fs_1/2. For fConfig = 2 a 
%                 partially shiffted configuration is assumed.  
%
%parameters only used for fConfig = 2:
%fs_3           = distance between the center of two pipes, which are in 
%                 different rows, measured perpendicular to flow direction 
%                 in m. 
%
%for temperature dependant material values the values are needed for the
%average temperature between in and outlet T_m as well as the wall 
%temperature T_w
%These should be saved in the function values as vectors with the first
%entry beeing the material value for T_m and the second value for T_w
%
%for example for temperature dependant material values the inputs could be
%fDyn_Visc              = [21.9 ; 22.7]kg/(m s)
%fDensity               = [0.93; 0.88]kg/m≥
%fThermal_Conductivity  = [31.6; 33] W/(m K)
%fC_p                   = [1.011; 1.013]J/K
%
%with the return parameter
%
%fConvection_alpha      = convection coeffcient in W/m≤K
%
%these parameters are used in the equation as follows:
%
%fConvection_alpha=convection_sheath_current(fD_o, fD_Baffle, fD_Batch,
%   fD_Hole, fD_Shell, fs_1, fs_2, fN_Pipes, fN_Pipes_Win, fN_FlowResist,
%   fN_Sealings, fN_Pipes_Diam, fDist_Baffle, fHeight_Baffle, fFlowSpeed, 
%   fDyn_Visc, fDensity, fThermal_Conductivity, fC_p, fConfig, fs_3)

function [fConvection_alpha] = convection_sheath_current (fD_o, fD_Baffle,...
    fD_Batch, fD_Hole, fD_Shell, fs_1, fs_2, fN_Pipes, fN_Pipes_Win,...
    fN_FlowResist, fN_Sealings, fN_Pipes_Diam, fDist_Baffle,...
    fHeight_Baffle, fFlowSpeed, fDyn_Visc, fDensity,...
    fThermal_Conductivity, fC_p, fConfig, fs_3)

%the source "VDI W‰rmeatlas" will from now on be defined as [9]

%checks the number of input parameters
narginchk(20, 21)

%Definition of the kinematic viscosity
fKin_Visc = fDyn_Visc(1)/fDensity(1);

%Definition of the overflowed length of the pipes according to [9] section
%Gg 1
fOverflow_Length = (pi/2) * fD_o;

%Definition of fPsi the relation between the diameter of the pipes and the
%spacing between them according to [9] section Gg 1 equation (9) + (10)

if fs_2/fD_o >= 1
    fPsi = 1 - (pi * fD_o)/(4 * fs_1);
else
    fPsi = 1 - (pi * fD_o^2)/(4 * fs_1 * fs_2);
end

%Definition of the Reynolds number according to [9] section Gg 1 
%equation (6)
fRe = (fFlowSpeed * fOverflow_Length) / (fKin_Visc * fPsi);

%calculates the nuﬂelt number for a batch of pipesin
%aligend config
if fConfig == 0
    fAlpha_Batch = convection_multiple_pipe_row(fD_o, fs_1, fs_2,...
        fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fC_p,...
        fConfig);
%shiffted config
elseif fConfig == 1
    fAlpha_Batch = convection_multiple_pipe_row(fD_o, fs_1, fs_2,...
        fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fC_p,...
        fConfig);    
%partially shiffted config
elseif fConfig == 2
    fAlpha_Batch = convection_multiple_pipe_row(fD_o, fs_1, fs_2,...
        fFlowSpeed, fDyn_Visc, fDensity, fThermal_Conductivity, fC_p,...
        fConfig, fs_3);
else
    error('wrong input for fConfig')
end

%Definition of the Nuﬂelt number according to [9] Section Gg 1 equation
%(5)
fNu_batch = (fAlpha_Batch * fOverflow_Length)/fThermal_Conductivity(1);
  
%Definition of the geometric correction factor for the sheath current
%with baffles according to [9] section Gh2 equation (14) + (15) 
fGeometry_Factor = 1 - (fN_Pipes_Win/fN_Pipes) + 0.524 * ...
                   (fN_Pipes_Win/fN_Pipes)^0.32;

%Definition of the shortest connection length according to [9] section Gh3
%Bild 3 (fDist_Pipes is e in the Literature)
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
%pipe wall near the diameter. fDist_Pipes_Shell is e_1 in the literature
fDist_Pipes_Shell = (fD_Shell - fD_Batch)/2;

fConnecting_Length = ((fN_Pipes_Diam - 1) * fDist_Pipes) +...
                     (2 * fDist_Pipes_Shell);

%%
%Definition of fA_SRU, the gap area between the holes in the baffles and
%the pipes, according to [9] section Gh 2 equation (18)
fA_SRU = (fN_Pipes - (fN_Pipes_Win/2)) * (pi * (fD_Hole^2 - fD_o^2))/4;

%Definition of the zentri angle fGamma according to [9] section Gh 2
%equation (20)
fGamma = 2 * acosd(1- ((2*fHeight_Baffle)/fD_Baffle));

%Definition of fA_SMU, the gap area between the shell and the baffle
%according to [9] section Gh 2 equation (19)
fA_SMU = (pi/4) * ((fD_Shell^2) - (fD_Baffle^2)) *(360 - fGamma)/360;

%Definition of the leakage factor for the sheath current
%with baffles according to [9] section Gh2 equation (16) + (17) + (21) 
fLeakage_Factor = 0.4 * (fA_SRU/(fA_SRU + fA_SMU)) + ...
                  (1 - (0.4 * (fA_SRU/(fA_SRU + fA_SMU)))) ...
                  * exp(-1.5 * ((fA_SRU + fA_SMU)/...
                  (fDist_Baffle * fConnecting_Length)));
%%
%Definition of the bypass factor for the sheath current
%with baffles according to [9] section Gh 3 equation (23) + (24)  

if fRe < 100
    fBeta = 1.5;
else
    fBeta = 1.35;
end

%Definition of the area the bypass flow can use according to [9] section
%Gh 4 equation (26) + (27)
if fDist_Pipes >= (fD_Shell - fD_Batch)
    fA_Bypass = 0;
else
    fA_Bypass = fDist_Baffle*(fD_Shell - fD_Batch);
end

if fN_Sealings <= (fN_FlowResist/2)
    fBypass_Factor = exp(-fBeta * fA_Bypass/(fDist_Baffle *...
                     fConnecting_Length) *...
                     (1 - nthroot((2*fN_Sealings)/fN_FlowResist, 3)));
else
    fBypass_Factor = 1;
end

%Definition of the Nuﬂelt number according to [9] Section Gg 1 equation
%(5) transposed for fConvection_alpha the convection coeffcient
fNu = fGeometry_Factor*fLeakage_Factor*fBypass_Factor*fNu_batch;

%Definition of the convection coeffcient according to [9] section Gh 4
%equation (28)
fConvection_alpha = (fNu * fThermal_Conductivity(1))/((pi/2) * fD_o);

end