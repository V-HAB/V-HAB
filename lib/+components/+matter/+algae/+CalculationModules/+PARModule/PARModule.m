classdef PARModule < base
    %PARMODULE determines the availability of radiation power for
    %photosynthesis in the medium and calculates the heat transfer into the
    %medium due to absorbed, but unused energy.
    
    %The class constructor allows the definition of the photon flux
    %densities that define the radiation growth curve?s shape. They are the
    %minimum, saturation and inhibition photon flux density (more
    %information, see thesis chapter 3.1.2.3 and 3.4), which are defined by
    %the algal species used. Currently the experimentally determined ones
    %(more information, see thesis chapter 5.3). Furthermore, the class
    %constructor takes a radiation source as an input and instantiates the
    %attenuation parameters accordingly. Radiation sources available come
    %from literature sources (more information, see thesis chapter 3.4.4.2)
    %and experiments conducted within the scope of this thesis (more
    %information, see thesis chapter 5.4). The radiation source can be
    %specified in the Photobioreactor system and is called by this module's
    %class constructor.
    properties
        oCallingSystem %system that calls this class (typically the growth media)
        
        %% Light Properties set through PBR system definition
        %Geometry
        sLightColor;                    %string, selected from photobioreactor system. Options are: Red, Blue, Yellow, Green, Daylight, RedExperimental
        fSurfacePPFD;                   %[µmol/m2s] photosynthetic flux density on top of the plate bioreactor, set through PBR system definition
        fDepthBelowSurface;             %[m], depth below the irradiated surface, set through PBR system definition
        fIlluminatedSurface;            %[m2] surface area of reactor as product of depth depth and volume. set through PBR system definition
        
        %% medium properties
        fBiomassConcentration           %[kg/m3]
        fWaterVolume                    %[m3]
        
        %% algae properties
        fMinimumPPFD                    %[µmol/m2s] Photosynthetic Photon Flux Density below which respiration occurs. Above linear growth of PS activity with growing light intensity until Saturation PPFD
        fSaturationPPFD                 %[µmol/m2s] Photosynthetic Photon Flux Density below which linear growth of PS activity with growing light Intensity occurs, above PS activity is saturated (no further increase in PS activity with growing radiation intensity)
        fInhibitionPPFD                 %[µmol/m2s] Photosynthetic Photon Flux Density above which inhibition occurs (no growth). Below this point until SaturationPPFD the activity is saturated
        
        %% parameters of hyperbolic model (see Yun and Park, 2001 [95], p. 6 table 2)
        fAmax;                          %[1/m]
        fBconstant;                     %[kg/m3]
        
        fAmaxRed                        %[1/m]
        fBRed                           %[kg/m3]
        
        fAmaxBlue                       %[1/m]
        fBBlue                          %[kg/m3]
        
        fAmaxYellow                     %[1/m]
        fBYellow                        %[kg/m3]
        
        fAmaxGreen                      %[1/m]
        fBGreen                         %[kg/m3]
        
        fAmaxDaylight                   %[1/m]
        fBDaylight                      %[kg/m3]
        
        %% hyperbolic model with experimentally determined data, see thesis chapter 5.4
        fAmaxRedExperimental            %[1/m], experimentally determined
        fBRedExperimental               %[kg/m3], experimentally determined
        
        %% calculation results
        %calculated for biomass concentration with hyperbolic model
        fAttenuationCoefficient         %[1/m] see if that scales linearly with cell density
        
        % growth volume parameters
        %positions in PBR
        fPositionMinimumPPFD            %[m], position below the PBR's irradiated surface, where the minimum PPFD is reached
        fPositionSaturationPPFD         %[m], position below the PBR's irradiated surface, where the satuartion PPFD is reached
        fPositionInhibitionPPFD         %[m], position below the PBR's irradiated surface, where the inhibition PPFD is reached
        
        %power saving potnentail
        fPowerSavingSurfacePPFD         %[µmol/(m2 s)] Surface PPFD sufficient for the whole reactor to be in saturation zone. If this is less than the normal surface PPFD, power can be saved through dynamic control of the light. Otherwise this value is set to 0.
        rPowerSavingRatio               %fraction how much power can be saved. (1- (savingPPFD / surfacePPFD)). When not whole reactor volume can be in saturation zone, this is set to 0.
        
        %average radiation in linear region
        fAveragePPFDLinearGrowth;       %[µmol/(m2 s)] average PPFD in the linear zone
        
        %Volumes in PBR
        fNoGrowthVolume                 %[m3] volume in which no growth occurs. either too dark or inhibited
        fSaturatedGrowthVolume          %[m3] volume in which light availability is saturated and growth at highest rate can occur
        fLinearGrowthVolume             %[m3] volume in which growth is linearly dependet on light availablility.
        
        
        %% heat development parameters
        fPhotosyntheticEfficiency       %[-] fraction of energy absorbed by algae that is used for photosynthesis (E_ps / E_abs)
        fReferenceWavelength            %[m] relates the spectrum of polychromatic light source to a monochromatic reference for easier calculation (avoids knowing exact distribution)
        
        fInhibitionZoneAbsorbedPPFD     %[µmol/(m2 s)]
        fSaturationZoneAbsorbedPPFD     %[µmol/(m2 s)]
        fLinearZoneAbsorbedPPFD         %[µmol/(m2 s)]
        fDarkZoneAbsorbedPPFD           %[µmol/(m2 s)]
        fExitPPFD                       %[µmol/(m2s)]
        
        fTotalAbsorbedPPFD              %[µmol/(m2s)]
        fPhotonsForPhotosynthesis       %[µmol/(m2s)]
        fPPFDtoHeat                     %[µmol/(m2s)]
        fHeatFlux                       %[W/m2]
        fHeatPower                      %[W]
        
        %photon energy parameters one photon has the energy of h*c/lambda
        fPlancksConstant                %[J*s]
        fSpeedOfLight                   %[m/s]
        
        PPFDtoHeat                      %[µmol/(m2s)]
        
    end
    
    methods
        
        function this = PARModule(oCallingSystem)
            this.oCallingSystem = oCallingSystem;
            
            %% info about PBR model, lighting, geometry
            %lighting properties (will come from different object later)
            this.sLightColor = this.oCallingSystem.oParent.sLightColor; %options, see properties
            this.fSurfacePPFD = this.oCallingSystem.oParent.fSurfacePPFD;    %[µmol/(m2s)], set through PBR system definition
            
            %PBR Properties gathered from PBR system.
            this.fDepthBelowSurface = this.oCallingSystem.oParent.fDepthBelowSurface; %[m]
            this.fWaterVolume = this.oCallingSystem.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oCallingSystem.oMT.tiN2I.H2O)/this.oCallingSystem.fCurrentGrowthMediumDensity; %[m3]
            this.fIlluminatedSurface = this.fWaterVolume / this.fDepthBelowSurface; %[m3]
            
            %% algae parameters, defined experimentally. See thesis chapter 5.4
            this.fMinimumPPFD = 1; %[µmol/(m2s)]
            this.fSaturationPPFD = 100; %[µmol/(m2s)]
            this.fInhibitionPPFD = 400;%[µmol/(m2s)]
            
            
            %% hyperbolic Attenuation-coefficient model parameters from Yun and Park, 2001 [95], p. 6 table 2
            this.fAmaxRed = 1283; %[1/m]
            this.fBRed  = 1.36; %[kg/m3]
            
            this.fAmaxYellow = 1025; %[1/m]
            this.fBYellow = 1.04; %[kg/m3]
            
            this.fAmaxGreen = 945.6; %[1/m]
            this.fBGreen = 0.92; %[kg/m3]
            
            this.fAmaxBlue = 1719; %[1/m]
            this.fBBlue =1.79; %[kg/m3]
            
            this.fAmaxDaylight = 1041; %[1/m]
            this.fBDaylight = 1.03; %[kg/m3]
            
            this.fAmaxRedExperimental = 3619; %[1/m]
            this.fBRedExperimental = 8.369; %[kg/m3]
            
            %which one of the lights is it? -> set attenuation coefficient
            %accordingly
            if isequal(this.sLightColor, 'Red')
                this.fAmax = this.fAmaxRed;
                this.fBconstant = this.fBRed;
                this.fReferenceWavelength = 660*10^-9; %[m] assuming that light is monochromatic although it is not in reality (although LEDs are pertty close)
            elseif isequal(this.sLightColor, 'Blue')
                this.fAmax = this.fAmaxBlue;
                this.fBconstant = this.fBBlue;
                this.fReferenceWavelength = 450*10^-9; %[m] ssuming that light is monochromatic although it is not in reality (although LEDs are pertty close)
            elseif isequal(this.sLightColor, 'Yellow')
                this.fAmax = this.fAmaxYellow;
                this.fReferenceWavelength = 600*10^-9; %[m] assuming that light is monochromatic although it is not in reality (although LEDs are pertty close)
            elseif isequal(this.sLightColor, 'Green')
                this.fAmax = this.fAmaxGreen;
                this.fBconstant = this.fBGreen;
                this.fReferenceWavelength = 550*10^-9; %[m] assuming that light is monochromatic although it is not in reality (although LEDs are pertty close)
            elseif isequal(this.sLightColor, 'Daylight')
                this.fAmax = this.fAmaxDaylight;
                this.fBconstant = this.fBDaylight;
                this.fReferenceWavelength = 495*10^-9; %[m]calculated from conversion factor stated in Table 1 in W. Biggs (LI-COR Company), 'Principles of Radiation Measurement' [95],  with the assumption that sunlight is 2000 µmol / 4.6 = 484.8 W/m2
            elseif isequal(this.sLightColor, 'RedExperimental') %experimentally determined values for red light
                this.fAmax = this.fAmaxRedExperimental;
                this.fBconstant = this.fBRedExperimental;
                this.fReferenceWavelength = 670*10^-9; %[m] assuming that light is monochromatic although it is not in reality (although LEDs are pertty close)
            end
            
            %% heat parameters
            this.fPhotosyntheticEfficiency = 0.05; %fraction of PS-energy over absorbed energy, no unit. See thesis chapter 3.4.6
            this.fPlancksConstant = 6.63*10^-34;   %[J*s]
            this.fSpeedOfLight = 3*10^8; %[m/s]
        end
        
        function update(this)
            %if culture is dead, don't have to calculate all this. old
            %values will be stored from when culture was alive and the heat
            %absorbed photons will fully go to heat.
            
            %get status if culture is dead
            bDead = this.oCallingSystem.oGrowthRateCalculationModule.bDead;
            
            if bDead == 0
                %call all the below functions to update all the respective
                %parts of the model.
                this.CalculateAttenuationCoefficient;
                this.CalculateAlgalRadiationBoundaryPositions;
                this.CalculateGrowthVolumes;
                this.CalculateAverageRadiationInLinearGrowthVolume;
                this.CalculateHeatFromRadiation(bDead);
            else
                this.CalculateHeatFromRadiation(bDead)
            end
            
        end
        
        
        function CalculateAttenuationCoefficient(this)
            %this function calculates the current attenuation coefficient
            %as a function of current biomass concentration (in kg/m3) and
            
            %get current biomass concentration in kg/m3 because it is
            %needed for the attenuation coefficient calculation
            fCurrentBiomass = this.oCallingSystem.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oCallingSystem.oMT.tiN2I.Chlorella); %[kg]
            this.fWaterVolume = this.oCallingSystem.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oCallingSystem.oMT.tiN2I.H2O)/this.oCallingSystem.fCurrentGrowthMediumDensity; %[m3]
            this.fBiomassConcentration = fCurrentBiomass / this.fWaterVolume; %[kg/m3]
            
            %calculation attenuation coefficient from hyperbolic model from
            %Yun and Park, 2001 [95]
            this.fAttenuationCoefficient = (this.fAmax * this.fBiomassConcentration) / (this.fBconstant + this.fBiomassConcentration); %[1/m]
        end
        
        function CalculateAlgalRadiationBoundaryPositions(this)
            %this function calculates the positions in the PBR from top
            %surface (=0), at which the minimum, saturation and inhibition
            %PPFD are reached. This is done with Eq. 4 provided in Yun and
            %Park, 2001 [95] which is rearanged to solve for P(X)
            
            this.fPositionMinimumPPFD = (-log(this.fMinimumPPFD/this.fSurfacePPFD))/(this.fAttenuationCoefficient); %[m]
            this.fPositionSaturationPPFD = (-log(this.fSaturationPPFD/this.fSurfacePPFD))/(this.fAttenuationCoefficient); %[m]
            this.fPositionInhibitionPPFD = (-log(this.fInhibitionPPFD/this.fSurfacePPFD))/(this.fAttenuationCoefficient); %[m]
            
            
            %if calcualted positions are outside of the PBR volume (above
            %or below), must set positions to be on the boundaries for
            %further volume calculations to not imply a larger volume than
            %actually exists.
            if this.fPositionMinimumPPFD > this.fDepthBelowSurface
                this.fPositionMinimumPPFD = this.fDepthBelowSurface; %[m]
            elseif this.fPositionMinimumPPFD < 0
                this.fPositionMinimumPPFD = 0; %[m]
            end
            
            fRealPositionSaturationPPFD = 0; %set for power saving potential calculation, where the real value is needed. initially 0 if smaller than depth below surface and changed to actual value if larger.
            if this.fPositionSaturationPPFD >this.fDepthBelowSurface
                fRealPositionSaturationPPFD = this.fPositionSaturationPPFD; %set for power saving potential, where the real value is needed. initially 0 if smaller than depth below surface and changed to actual value if larger.
                this.fPositionSaturationPPFD = this.fDepthBelowSurface; %[m]
            elseif this.fPositionSaturationPPFD < 0
                this.fPositionSaturationPPFD = 0; %[m]
            end
            
            if this.fPositionInhibitionPPFD > this.fDepthBelowSurface
                this.fPositionInhibitionPPFD = this.fDepthBelowSurface; %[m]
            elseif this.fPositionInhibitionPPFD < 0
                this.fPositionInhibitionPPFD = 0; %[m]
            end
            
            %% determine power saving potential
            %whole photobioreactor should be in saturated growth domain but
            %no energy should be wasted. waste is considered more than
            %saturation PPFD exiting the PBR, which is indicated through
            %the position of the saturationPPFD to be larger than the depth
            %below surface parameter (see previous step). this can be
            %achieved by ensuring conditions for the top and bottom of the
            %PBR. the top of the photobioreactor is irradiated below
            %inhibition PPFD and the bottom of the PBR must be irradiated
            %at saturation PPFD. When these conditions are not met, the
            %fPowerSavingPPFD is set to 0.
            
            %uses real position since the PositionSaturationPPFD can be
            %potentially overwritten.
            if fRealPositionSaturationPPFD > this.fDepthBelowSurface && this.fSurfacePPFD <= this.fInhibitionPPFD
                
                %determine the Surface PPFD sufficient to still irradiate
                %the bottom of the PBR at saturation. This is done by
                %rearranging the attenuation equation to solve for a
                %surface PPFD and defining to have saturation at the bottom
                %of the PBR.
                this.fPowerSavingSurfacePPFD = this.fSaturationPPFD/(exp(-this.fDepthBelowSurface*this.fAttenuationCoefficient)); %[µmol/m2s]
                
                %determine how much power could be saved.
                this.rPowerSavingRatio = 1-(this.fPowerSavingSurfacePPFD/this.fSurfacePPFD); %[-]
                
            else
                this.fPowerSavingSurfacePPFD = 0;
                this.rPowerSavingRatio = 0;
            end
            
            
        end
        
        function CalculateGrowthVolumes(this)
            %this function calculates the volumes each radiation growth
            %domain (inhibited, saturated, linear, shaded), see thesis
            %chapter 3.4.5. actually above the inhibition point the growth
            %doesn't immediately go to zero but quickly drops to there.
            %this is not respected in this model due to simplification -
            %here, it immediately drops to 0.
            
            %No growth is made up of inhibited and too dark zone (below
            %minimum)
            this.fNoGrowthVolume = (this.fDepthBelowSurface - this.fPositionMinimumPPFD + this.fPositionInhibitionPPFD)*this.fIlluminatedSurface; %[m3]
            
            this.fLinearGrowthVolume = (this.fPositionMinimumPPFD - this.fPositionSaturationPPFD)*this.fIlluminatedSurface; %[m3]
            
            this.fSaturatedGrowthVolume = (this.fPositionSaturationPPFD - this.fPositionInhibitionPPFD)*this.fIlluminatedSurface; %[m3]
            
        end
        
        function CalculateAverageRadiationInLinearGrowthVolume(this)
            %in linear zone, the growth is calculated with the average
            % irradiance in that zone and how that relates to the
            %saturated Radiation growth (--> linear relation). The average
            %is not 50% of the saturation ppfd because the radiation
            %decreases exponentially and not linearly. the growth rises
            %linear with radiation availability but not with depth! The
            %average radiation availability can be calculated on the
            %interval of the function between the upper (saturation) and
            %lower limit (minimum) of this zone. then that calculated
            %average ppfd is related to the saturated ppfd to calculate the
            %relative growth. See thesis chapter 3.4.5.
            this.fAveragePPFDLinearGrowth = (this.fSurfacePPFD/(this.fPositionMinimumPPFD - this.fPositionSaturationPPFD))*((exp(-this.fAttenuationCoefficient *this.fPositionSaturationPPFD)-exp(-this.fAttenuationCoefficient *this.fPositionMinimumPPFD))/this.fAttenuationCoefficient); %[µmol/(m2s)]
            
            %when all the boundaries are on the same position (total dark
            %or total inhibition) the average ppfd is not a number because
            %the average is calculated by dividing the integral through an
            %interval (outer boundries of linear) which then becomes zero.
            %have to mitigate this by setting average ppfd to zero if it is
            %NaN since it will set all other flows and masses to NaN
            %otherwise.
            if isnan(this.fAveragePPFDLinearGrowth)
                this.fAveragePPFDLinearGrowth = 0; %[µmol/(m2s)]
            end
            
        end
        
        
        function CalculateHeatFromRadiation(this,bDead)
            %this function determines the absorption in different radiation
            %regiemes. By using the photosynthetic efficiency, it then
            %determines how much of this absorbed radiation was used for
            %photosynthesis . The radiation that was absorbed but not used
            %for photosynthesis is assumed to be turned to heat. Depending
            %on the radiation's wavelength the power of the photons is
            %calculated in watts independent of where it is created
            %(ideally stirred media is assumed). if the culture is dead,
            %all the absorbed radiation will go to heat since it is not
            %used for photosynthesis anymore.
            
            %% Absorption of radiation in zones
            
            %inhibited zone in/out, all that is absorbed goes to heat
            fInhibitionZoneInPPFD = this.fSurfacePPFD; %[µmol/(m2s)]
            fInhibitionZoneOutPPFD = this.fSurfacePPFD * exp(-this.fPositionInhibitionPPFD*this.fAttenuationCoefficient);  %[µmol/(m2s)]this is equal to surface ppfd if position of inhibition zone is 0 (i.e. no inhibition zone exists)
            
            %ppfd lost in inhibition zone
            this.fInhibitionZoneAbsorbedPPFD = fInhibitionZoneInPPFD- fInhibitionZoneOutPPFD; %[µmol/(m2s)]is zero if there is no difference (i.e. no inhibition zone exists)
            
            if this.fInhibitionZoneAbsorbedPPFD < 0
                this.fInhibitionZoneAbsorbedPPFD = 0; %[µmol/(m2s)]
            end
            
            %loss in saturation zone, efficiency determines how much of
            %absorbed radiation goes to PS and how much to heat
            fSaturationZoneInPPFD = fInhibitionZoneOutPPFD;%[µmol/(m2s)]
            fSaturationZoneOut = this.fSurfacePPFD * exp(-this.fPositionSaturationPPFD*this.fAttenuationCoefficient);%[µmol/(m2s)]
            this.fSaturationZoneAbsorbedPPFD = fSaturationZoneInPPFD - fSaturationZoneOut;  %[µmol/(m2s)]
            
            if this.fSaturationZoneAbsorbedPPFD <0
                this.fSaturationZoneAbsorbedPPFD = 0; %[µmol/(m2s)]
            end
            
            %losses in linear zone
            fLinearZoneInPPFD = fSaturationZoneOut; %[µmol/(m2s)]
            fLinearZoneOutPPFD = this.fSurfacePPFD * exp(-this.fPositionMinimumPPFD*this.fAttenuationCoefficient); %[µmol/(m2s)]
            this.fLinearZoneAbsorbedPPFD = fLinearZoneInPPFD - fLinearZoneOutPPFD; %[µmol/(m2s)]
            
            if this.fLinearZoneAbsorbedPPFD < 0
                this.fLinearZoneAbsorbedPPFD = 0; %[µmol/(m2s)]
            end
            
            %dark zone doesn't mean that it is totally dark (0 photons), it
            %just means that it is below the minimum what the algae can
            %use. can still be absorbed and turned to heat.
            fDarkZoneInPPFD = fLinearZoneOutPPFD; %[µmol/(m2s)]
            fDarkZoneOutPPFD = this.fSurfacePPFD * exp(-this.fDepthBelowSurface*this.fAttenuationCoefficient); %[µmol/(m2s)]
            
            this.fDarkZoneAbsorbedPPFD = fDarkZoneInPPFD - fDarkZoneOutPPFD; %[µmol/(m2s)]
            if this.fDarkZoneAbsorbedPPFD < 0
                this.fDarkZoneAbsorbedPPFD = 0; %[µmol/(m2s)]
            end
            %if there is no dark zone:
            this.fExitPPFD = fDarkZoneOutPPFD; %[µmol/(m2s)]
            
            %% total photon flux densities to photosynthesis, heat and passed through
            %add up the absorbed photons (if there is a dark zone in the
            %reactor, this should be close to everything entering the PBR).
            
            this.fTotalAbsorbedPPFD = this.fInhibitionZoneAbsorbedPPFD + this.fSaturationZoneAbsorbedPPFD + this.fLinearZoneAbsorbedPPFD + this.fDarkZoneAbsorbedPPFD; %[µmol/(m2s)]
            %how much of absorbed PPFD was used for photosynthesis based on
            %PS-efficiency
            this.fPhotonsForPhotosynthesis = this.fPhotosyntheticEfficiency * (this.fSaturationZoneAbsorbedPPFD + this.fLinearZoneAbsorbedPPFD); %[µmol/(m2s)]
            this.fPPFDtoHeat = this.fTotalAbsorbedPPFD - this.fPhotonsForPhotosynthesis; %[µmol/(m2s)]
            
            %if culture is dead, all absorbed ppfd will go to heat since it
            %cannot be used for PS anymore.
            if bDead == 1
                this.PPFDtoHeat = this.fSurfacePPFD - this.fExitPPFD; %[µmol/(m2s)]
            end
            
            
            %% transform PPFD to power in Watts
            %calculate the power of absorbed photons -> that is the energy
            %per time going into the solution as heat energy of photon
            %depends on plank's constant, speed of radiation and its
            %wavelength (lower wavelengths have a higher energy). For
            %polychromatic radiation, complicated integrals have to be
            %calculated and the spectral curve of the radiation source has
            %to be known and mathematically formulated as function. In
            %order to ease up this process, the radiation is treated as
            %monochromatic with a reference wavelength (specified in class
            %constructor for different radiation sources). Calculation see
            %thesis chapters 3.4.1 and 3.4.6.
            
            this.fHeatFlux = this.fPPFDtoHeat * 10^-6 * 6.022*10^23 * this.fPlancksConstant * this.fSpeedOfLight / this.fReferenceWavelength; %[W/m2]
            
            %multiply with irradiated surface area to gain the power going
            %into the medium as heat
            this.fHeatPower = this.fHeatFlux * this.fIlluminatedSurface; %[W]
            
            
            
        end
        
        
        
    end
end
