function [mGodunovFlux, fMaxWaveSpeed, fPressureStar] = ...
            HLLC(oSystem, fPressureLeft, fDensityLeft, fFlowSpeedLeft, fInternalEnergyLeft,...
            fPressureRight, fDensityRight, fFlowSpeedRight, fInternalEnergyRight, fTemperatureLeft, fTemperatureRight)
% approximate HLLC Riemann Solver
% This code contains a HLLC Riemann Solver used to solve shock and normal
% flow problems in liquids. As part of this programm a linearised primitve
% variable Riemann solver (PVRS) is used in order to estimate the flow 
% speeds. The star state in this code will refer to the region between the
% two waves propagating to the left and right. 
%
% The Basic structure of the code will be that in the first step wave speed
% estimates from the PVRS will be obtained. From these wave speed estimates
% new values for the star state will be calculate which are again used to
% reach new wave speed estimates. These new estimates are then used to
% reach the final approximation for the star state

%the riemann problem is separated into 4 different regions which each have
%different values for pressure, density, flow speed etc. These regions are
%separated by waves where the two waves shown by the pointed line in the
%following sketch are either shock or rarefaction waves and the wave shown
%with the diagonal slashes is a contact wave together with a shear wave

%                     .    left     / right   .
%                       .  star    /  star .
%      left initial       .       /     .        right initial
%         state             .    /   .              state
% ____________________________. /.________________________________

%the source "Riemann Solvers and Numerical Methods for Fluid Dynamics" 
%from E.F. Toro will be denoted as number [5]

%the source "Restoration of the contact surface in the HLL-Riemann solver"
%from E.F. Toro, M. Spurce, W. Speares will be denoted by the number [7]

%the source "Compressibility equations for liquids: a comparative study" 
%from A. T.  J.  HAYWARD will be described by the number [8]
    
    if nargin < 10
        fTemperatureLeft = 293;
        fTemperatureRight = 293;
    end

    if fPressureLeft < 0 || fPressureRight < 0
        error(['negative pressure not allowed in Riemann Solver!\n ', ...
               'First try decreasing the Courant Number of the Branch if ',...
               'this does not help see list of other possible errors:\n ',...
               '-the number of cells for the branch is too low \n ',...
               '-the diameter of the pipes is large compared to the volume of a tank \n ',...
               '-the pressures set in the system are wrong ',...
               '(e.g. a pump that has a too high pressure jump)']);
    elseif fDensityLeft < 0 || fDensityRight <0
        error(['negative densities not allowed in Riemann Solver!\n ',...
               'First try decreasing the Courant Number other possible',...
               'error might be wrong temperature in the system']);
    end
    
    %The speed of sound for the two initial states is calculated  
    fSonicSpeedRight= oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureRight, fPressureRight);
    fSonicSpeedLeft = oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureLeft, fPressureLeft);


    %%
    %PVRS (primitve variable Riemann solver) approximation to reach 
    %estimates for the wave speeds. All the values calculated in this
    %section will be marked by adding PVRS at the end of the variable name
    
    %first the averages of Density and sonic speed are calculated as the
    %state space around which the Riemann problem will be linearised
    fAverageDensity = 0.5*(fDensityLeft+fDensityRight);
    fAverageSonicSpeed = 0.5*(fSonicSpeedLeft+fSonicSpeedRight);

    %then the values in the star region are calculated according to [5]
    %page 299 equation (9.20)
    fFlowSpeedStarPVRS = 0.5*(fFlowSpeedLeft + fFlowSpeedRight) + (fPressureLeft - fPressureRight) / (2*fAverageDensity*fAverageSonicSpeed);             

    fDensityLeftStarPVRS = fDensityLeft + (fFlowSpeedLeft-fFlowSpeedStarPVRS) * (fAverageDensity/fAverageSonicSpeed);            

    fDensityRightStarPVRS = fDensityRight + (fFlowSpeedStarPVRS-fFlowSpeedRight) * (fAverageDensity/fAverageSonicSpeed);               

    if abs((fDensityRightStarPVRS-fDensityRight)/fDensityRight) < 0.01 %density changed by less than 1%
        fSonicSpeedRightStarPVRS = fSonicSpeedRight;
    else
        fSonicSpeedRightStarPVRS = oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureRight, fDensityRightStarPVRS, true);
    end
    if abs((fDensityRightStarPVRS-fDensityLeft)/fDensityLeft) < 0.01 %density changed by less than 1%
        fSonicSpeedLeftStarPVRS = fSonicSpeedLeft;
    else
        fSonicSpeedLeftStarPVRS = oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureLeft, fDensityLeftStarPVRS, true);
    end
    %estimated wave speeds using the PVRS
    %left and right wave speed according to [7] page 28 equation (14)
    fWaveSpeedLeftPVRS = min((fFlowSpeedLeft-fSonicSpeedLeft),(fFlowSpeedStarPVRS-...
                        fSonicSpeedLeftStarPVRS));
    fWaveSpeedRightPVRS = max((fFlowSpeedRight+fSonicSpeedRight),(fFlowSpeedStarPVRS+...
                        fSonicSpeedRightStarPVRS));

    %wave speed of the contact wave in the star region according to [5] 
    %page 325 equation (10.37)
    fWaveSpeedStarPVRS = (fPressureRight-fPressureLeft+fDensityLeft*fFlowSpeedLeft*...
                     (fWaveSpeedLeftPVRS-fFlowSpeedLeft)-fDensityRight*fFlowSpeedRight*...
                     (fWaveSpeedRightPVRS-fFlowSpeedRight))/(fDensityLeft*...
                     (fWaveSpeedLeftPVRS-fFlowSpeedLeft)-fDensityRight*...
                     (fWaveSpeedRightPVRS-fFlowSpeedRight));

    %%             
    %Now the estimates for the wave speeds gained from the PVRS are used to
    %calculate new values for the star state using the HLLC approximation.
    %These values will have temp added to their names to signify that they 
    %are not the final estimates.
    
    %values according to [5] page 325 equation (10.39)
    fFlowSpeedStarTemp =  ((fWaveSpeedLeftPVRS-fFlowSpeedLeft)/...
                           (fWaveSpeedLeftPVRS-fWaveSpeedStarPVRS))*...
                           fWaveSpeedStarPVRS;

    fDensityLeftStarTemp = fDensityLeft*((fWaveSpeedLeftPVRS-fFlowSpeedLeft)/...
                           (fWaveSpeedLeftPVRS-fWaveSpeedStarPVRS));

    fDensityRightStarTemp = fDensityRight*((fWaveSpeedRightPVRS-fFlowSpeedRight)/...
                           (fWaveSpeedRightPVRS-fWaveSpeedStarPVRS));
                       
    if abs((fDensityRightStarTemp-fDensityRightStarPVRS)/fDensityRightStarPVRS) < 0.01 %density changed by less than 1%
        fSonicSpeedRightStarTemp = fSonicSpeedRightStarPVRS;
    else
        fSonicSpeedRightStarTemp = oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureRight, fDensityRightStarTemp, true);
    end
    if abs((fDensityLeftStarTemp-fDensityLeftStarPVRS)/fDensityLeftStarPVRS) < 0.01 %density changed by less than 1%
        fSonicSpeedLeftStarTemp = fSonicSpeedLeftStarPVRS;
    else
        fSonicSpeedLeftStarTemp = oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureLeft, fDensityLeftStarTemp, true);
    end
    %with these values new wave speed estimates based on the HLLC Riemann
    %solver are derived
    %left and right wave speed according to [7] page 28 equation (14)
    fWaveSpeedLeftTemp = min((fFlowSpeedLeft-fSonicSpeedLeft),(fFlowSpeedStarTemp-...
                        fSonicSpeedLeftStarTemp));
    fWaveSpeedRightTemp = max((fFlowSpeedRight+fSonicSpeedRight),(fFlowSpeedStarTemp+...
                        fSonicSpeedRightStarTemp));

    %wave speed of the contact wave in the star region according to [5] 
    %page 325 equation (10.37)                
    fWaveSpeedStarTemp = (fPressureRight-fPressureLeft+fDensityLeft*fFlowSpeedLeft*...
                     (fWaveSpeedLeftTemp-fFlowSpeedLeft)-fDensityRight*fFlowSpeedRight*...
                     (fWaveSpeedRightTemp-fFlowSpeedRight))/(fDensityLeft*...
                     (fWaveSpeedLeftTemp-fFlowSpeedLeft)-fDensityRight*...
                     (fWaveSpeedRightTemp-fFlowSpeedRight));

    %%            
    %these intermediate values are now used to reach the final estimates 
    %for the star state values
    
    %values according to [5] page 325 equation (10.39)
    fFlowSpeedStar =  ((fWaveSpeedLeftTemp-fFlowSpeedLeft)/...
                           (fWaveSpeedLeftTemp-fWaveSpeedStarTemp))*...
                           fWaveSpeedStarTemp;

    fDensityLeftStar = fDensityLeft*((fWaveSpeedLeftTemp-fFlowSpeedLeft)/...
                           (fWaveSpeedLeftTemp-fWaveSpeedStarTemp));

    fInternalEnergyLeftStar = fDensityLeft*((fWaveSpeedLeftTemp-fFlowSpeedLeft)/...
                           (fWaveSpeedLeftTemp-fWaveSpeedStarTemp))*...
                           (fInternalEnergyLeft/fDensityLeft)+(fWaveSpeedStarTemp-...
                           fFlowSpeedLeft)*(fWaveSpeedStarTemp+(fPressureLeft/...
                           (fDensityLeft*(fWaveSpeedLeftTemp-fFlowSpeedLeft))));    
                       
	fDensityRightStar = fDensityRight*((fWaveSpeedRightTemp-fFlowSpeedRight)/...
                           (fWaveSpeedRightTemp-fWaveSpeedStarTemp));

    fInternalEnergyRightStar = fDensityRight*((fWaveSpeedRightTemp-fFlowSpeedRight)/...
                           (fWaveSpeedRightTemp-fWaveSpeedStarTemp))*...
                           (fInternalEnergyRight/fDensityRight)+(fWaveSpeedStarTemp-...
                           fFlowSpeedRight)*(fWaveSpeedStarTemp+(fPressureRight/...
                           (fDensityRight*(fWaveSpeedRightTemp-fFlowSpeedRight))));                   

    %the pressure can be calculated according to [5] page 324 equation
    %(10.36)
    fPressureStar = fPressureLeft+fDensityLeft*(fWaveSpeedLeftTemp-...
                            fFlowSpeedLeft)*(fWaveSpeedStarTemp-fFlowSpeedLeft);   

   	%negative Pressures are physically impossible therefore if an
    %unfortunate combination of values results in negative pressure the
    %pressure is considered to be very low (1 Pa) instead
    if fPressureStar < 0
        fPressureStar = 1;
    end
    
    if abs((fDensityRightStar-fDensityRightStarTemp)/fDensityRightStarTemp) < 0.01 %density changed by less than 1%
        fSonicSpeedRightStar = fSonicSpeedRightStarTemp;
    else
        fSonicSpeedRightStar = oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureRight, fDensityRightStar, true);
    end
    if abs((fDensityRightStar-fDensityRightStarTemp)/fDensityRightStarTemp) < 0.01 %density changed by less than 1%
        fSonicSpeedLeftStar = fSonicSpeedLeftStarTemp;
    else
        fSonicSpeedLeftStar = oSystem.oBranch.oContainer.oMT.calculateSpeedOfSound(oSystem.sPhase, oSystem.oBranch.aoFlows(1,1).arPartialMass, fTemperatureLeft, fDensityLeftStar, true);
    end
    
    %with these values the final wave speed estimates are                   
    %left and right wave speed according to [7] page 28 equation (14)
    fWaveSpeedLeft = min((fFlowSpeedLeft-fSonicSpeedLeft),(fFlowSpeedStar-...
                        fSonicSpeedLeftStar));
    fWaveSpeedRight = max((fFlowSpeedRight+fSonicSpeedRight),(fFlowSpeedStar+...
                        fSonicSpeedRightStar));

    %wave speed of the contact wave in the star region according to [5] 
    %page 325 equation (10.37)                
    fWaveSpeedStar = (fPressureRight-fPressureLeft+fDensityLeft*fFlowSpeedLeft*...
                     (fWaveSpeedLeft-fFlowSpeedLeft)-fDensityRight*fFlowSpeedRight*...
                     (fWaveSpeedRight-fFlowSpeedRight))/(fDensityLeft*...
                     (fWaveSpeedLeft-fFlowSpeedLeft)-fDensityRight*...
                     (fWaveSpeedRight-fFlowSpeedRight));                   
                       
    %%
    %now using the final estimates the numerical godunov flux can be
    %defined according to [5] page 323 equation (10.26)
    if 0 <= fWaveSpeedLeft
        mGodunovFlux = [fDensityLeft*fFlowSpeedLeft, fDensityLeft*(fFlowSpeedLeft^2)+fPressureLeft, fFlowSpeedLeft*(fInternalEnergyLeft+fPressureLeft)];
    elseif fWaveSpeedLeft <= 0 && 0 <= fWaveSpeedStar
        mGodunovFlux = [fDensityLeftStar*fFlowSpeedStar, fDensityLeftStar*(fFlowSpeedStar^2)+fPressureStar, fFlowSpeedStar*(fInternalEnergyLeftStar+fPressureStar)];
    elseif fWaveSpeedStar <= 0 && 0 <= fWaveSpeedRight   
        mGodunovFlux = [fDensityRightStar*fFlowSpeedStar, fDensityRightStar*(fFlowSpeedStar^2)+fPressureStar, fFlowSpeedStar*(fInternalEnergyRightStar+fPressureStar)];
    elseif 0 >= fWaveSpeedRight 
        mGodunovFlux = [fDensityRight*fFlowSpeedRight, fDensityRight*(fFlowSpeedRight^2)+fPressureRight, fFlowSpeedRight*(fInternalEnergyRight+fPressureRight)];
    else
        error('an error in the riemann solver prevented calculation of fluxes. Most likley somewhere a NaN occured')
    end

    if abs(fWaveSpeedLeft) >= abs(fWaveSpeedRight) && abs(fWaveSpeedLeft) >= abs(fWaveSpeedStar)
        fMaxWaveSpeed = fWaveSpeedLeft;
    elseif abs(fWaveSpeedRight) > abs(fWaveSpeedLeft) && abs(fWaveSpeedRight) >= abs(fWaveSpeedStar)
        fMaxWaveSpeed = fWaveSpeedRight;
    else
        fMaxWaveSpeed = fWaveSpeedStar;
    end
    
    if ~isreal(mGodunovFlux)
        error(['an error in the riemann solver lead to imaginary results!\n',...
               'First try decreasing the Courant Number of the Branch if this does not help see list of other possible errors:\n'...
               '-the number of cells for the branch is too low \n -the diameter of the pipes is large compared to the volume of a tank \n'...
               '-the pressures set in the system are wrong (e.g. a pump that has a too high pressure jump)'])
    end
        
end
