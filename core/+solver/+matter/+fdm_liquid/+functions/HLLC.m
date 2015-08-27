function [mGodunovFlux, fMaxWaveSpeed, fPressureStar] = ...
            HLLC(system, fPressureLeft, fDensityLeft, fFlowSpeedLeft, fInternalEnergyLeft,...
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

    %the Density at very low Pressure is calculated as one required
    %Datapoint for the Bulk Modulus
    fDensity_0 = system.oBranch.oContainer.oData.oMT.FindProperty('H2O','fDensity','Pressure',1,'Temperature',(max(fTemperatureLeft,fTemperatureRight)),'liquid');
    
    %ensures that the reference Density at low pressure is lower than the
    %other densities
    if fDensity_0 >= fDensityLeft
            fDensity_0 = fDensityLeft - 0.1;
    end
    if fDensity_0 >= fDensityRight
            fDensity_0 = fDensityRight - 0.1;
    end
    while fDensity_0 >= fDensityLeft || fDensity_0 >= fDensityRight
        fDensity_0 = fDensity_0 - 0.01;
    end
    
    %TO DO: replace Bulk Modulus Calculation with matter table values
    %The Bulk Modulus is calculated according to [8] page 967
    %equation (5)
    fBulkModulusLeft = ((1/fDensity_0)*fPressureLeft)/((1/fDensity_0)-...
                        (1/fDensityLeft));
    fBulkModulusRight = ((1/fDensity_0)*fPressureRight)/((1/fDensity_0)-...
                        (1/fDensityRight));

    %The speed of sound for the two initial states is calculated  
    fSonicSpeedLeft = sqrt(fBulkModulusLeft/fDensityLeft);
    fSonicSpeedRight = sqrt(fBulkModulusRight/fDensityRight);


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
    fPressureStarPVRS = 0.5*(fPressureLeft+fPressureRight)+0.5*(fFlowSpeedLeft-...
                    fFlowSpeedRight)*(fAverageDensity*fAverageSonicSpeed);

    fFlowSpeedStarPVRS = 0.5*(fFlowSpeedLeft+fFlowSpeedRight)+(fPressureLeft-...
                    fPressureRight)/(2*fAverageDensity*fAverageSonicSpeed);             

    fDensityLeftStarPVRS = fDensityLeft+(fFlowSpeedLeft-fFlowSpeedStarPVRS)*...
                        (fAverageDensity/fAverageSonicSpeed);            

    fDensityRightStarPVRS = fDensityRight+(fFlowSpeedStarPVRS-fFlowSpeedRight)*...
                        (fAverageDensity/fAverageSonicSpeed);               

    %ensures that the reference Density at low pressure is lower than the
    %other densities
    if fDensity_0 >= fDensityLeftStarPVRS
            fDensity_0 = fDensityLeftStarPVRS - 0.1;
    end
	if fDensity_0 >= fDensityRightStarPVRS
            fDensity_0 = fDensityRightStarPVRS - 0.1;
	end
  	while fDensity_0 >= fDensityLeftStarPVRS || fDensity_0 >= fDensityRightStarPVRS
        fDensity_0 = fDensity_0 - 0.01;
    end
                
    %negative Pressures are physically impossible therefore if an
    %unfortunate combination of values results in negative pressure the
    %pressure is considered to be very low (1 Pa) instead
    if fPressureStarPVRS < 0
        fPressureStarPVRS = 1;
    end
    %from these values the bulk modulus for the two star regions can be 
    %calculated                
    fBulkModulusLeftStarPVRS = ((1/fDensity_0)*fPressureStarPVRS)/((1/fDensity_0)-...
                        (1/fDensityLeftStarPVRS));
    fBulkModulusRightStarPVRS = ((1/fDensity_0)*fPressureStarPVRS)/((1/fDensity_0)-...
                        (1/fDensityRightStarPVRS));

    %using the bulk moduli the speed of sound in the star region can be 
    %calculated       
    fSonicSpeedLeftStarPVRS = sqrt(fBulkModulusLeftStarPVRS/fDensityLeftStarPVRS);
    fSonicSpeedRightStarPVRS = sqrt(fBulkModulusRightStarPVRS/fDensityRightStarPVRS);  

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
 
    %the pressure can be calculated according to [5] page 324 equation
    %(10.36)
	fPressureStarTemp = fPressureLeft+fDensityLeft*(fWaveSpeedLeftPVRS-...
                            fFlowSpeedLeft)*(fWaveSpeedStarPVRS-fFlowSpeedLeft);   

  	%negative Pressures are physically impossible therefore if an
    %unfortunate combination of values results in negative pressure the
    %pressure is considered to be very low (1 Pa) instead
    if fPressureStarTemp < 0
        fPressureStarTemp = 1;
    end
    %ensures that the reference Density at low pressure is lower than the
    %other densities
    if fDensity_0 >= fDensityLeftStarTemp
        fDensity_0 = fDensityLeftStarTemp - 0.1;
    end
	if fDensity_0 >= fDensityRightStarTemp
        fDensity_0 = fDensityRightStarTemp - 0.1;
	end
    while fDensity_0 >= fDensityLeftStarTemp || fDensity_0 >= fDensityRightStarTemp
        fDensity_0 = fDensity_0 - 0.01;
    end
    
                       
    %the new values are again used to calculate the bulk moduli and then 
    %the sonic speed                   
    fBulkModulusLeftStarTemp = ((1/fDensity_0)*fPressureStarTemp)/((1/fDensity_0)-...
                        (1/fDensityLeftStarTemp));
    fBulkModulusRightStarTemp = ((1/fDensity_0)*fPressureStarTemp)/((1/fDensity_0)-...
                        (1/fDensityRightStarTemp));

    fSonicSpeedLeftStarTemp = sqrt(fBulkModulusLeftStarTemp/fDensityLeftStarTemp);
    fSonicSpeedRightStarTemp = sqrt(fBulkModulusRightStarTemp/fDensityRightStarTemp);

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
    %ensures that the reference Density at low pressure is lower than the
    %other densities
    if fDensity_0 >= fDensityLeftStar
    	fDensity_0 = fDensityLeftStar - 0.1;
    end
    if fDensity_0 >= fDensityRightStar
        fDensity_0 = fDensityRightStar - 0.1;
    end
    while fDensity_0 >= fDensityLeftStar || fDensity_0 >= fDensityRightStar
        fDensity_0 = fDensity_0 - 0.01;
    end                                                   
                       
    %calculating the Bulk Moduli and the sonic speed for final estimate                   
    fBulkModulusLeftStar = ((1/fDensity_0)*fPressureStar)/((1/fDensity_0)-...
                        (1/fDensityLeftStar));
    fBulkModulusRightStar = ((1/fDensity_0)*fPressureStar)/((1/fDensity_0)-...
                        (1/fDensityRightStar));

    fSonicSpeedLeftStar = sqrt(fBulkModulusLeftStar/fDensityLeftStar);
    fSonicSpeedRightStar = sqrt(fBulkModulusRightStar/fDensityRightStar);

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
