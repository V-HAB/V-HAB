classdef AtmosphericGasExchange < matter.procs.p2ps.stationary
    %ATMOSPHERICGASEXCHANGE the rate of solution into and volatility out
    %of water for CO2 or O2 by using Henry's Law. This law defines that the
    %solubility of a gas in water (concentration) is dependent on a
    %temperature dependent Henry's Constant and the partial pressure of the
    %gas (in this case CO2 or O2) in the gas phase. Furthermore, this class
    %calculates the membrane transport through a membrane of defined
    %surface area, permeability and thickness. Commercially available ones
    %are available to chose from.
    
        %this P2P is important for the uptake of CO2 into the growth
    %medium which will then be used by the algae to perform CO2. In a different case
    %this function is importnat to calculate the O2 concentration in water
    %and how much leaves the reactor into the cabin air as a result from
    %algal photosynthesis
    
    %The mass flow must be defined to be positive from the air to the
    %medium phase. Air on the left, medium on the right, wenn P2P is
    %initialized.
   
    %Since CO2 can react with water to form bicarbonate and eventually carbonate
    %(depending on the pH), the effective Henry Constant can be a lot higher than
    %the one that is calculated here. This is due to the fact that CO2 is
    %transformed to bicarbonate and therefore more CO2 can enter the water
    %than the normal Henry constant would yield. This transformation is
    %calculated in a separate manipulator (TotalInorganicCarbonEquilibrium)
    %and the removed carbon dioxide to form bicarbonate is replaced by
    %uptake from the air until an equilibrium is reached. The calculations
    %made here are therefore still correct but only work in a dynamic calculation environment.

    
    
    properties (SetAccess=public, GetAccess=public)
        arExtractPartials;                          %array of ratios, how much of each substance should be removed by this P2P
        sSubstance                                  %string that specifies the gas of which the Henry's Law behavior should be simulated by this P2P. O2 and CO2 available
        fLastExec;                                  %[s] for time step calculations in the update function
        
        %constants for Henry's Law Calculations
        fNormalHenryConstant                        %[mol/(m3*kg)]  Henry Constant of CO2 or O2 into water at reference temperature T=298.15 K and rho=997 kg/m3
        fTemperatureDependence                      %[K] factor needed to calculate temperature dependece of current Henry Constant
       
        
        %membrane related
        sMembraneMaterial                           %string stating the name. commercially available ones are available. Set in the Photobioreactor system.
        fMembranePermeability                       %[(mol*m_thick)/(m2_surface*s*Pa_difference)] values are often not given in SI units. gathered data from datasheet and Internet and transformed to SI
        fMembraneThickness                          %[m] membrane thickness
        fMembraneArea                               %[m2] surface area of membane which supports gas transfer
        
        
        %variables needed for Henry's Law calculation
        fTemperatureOfMedium                        %[K] temperature of the growth medium
        fPartialPressureOfSubstanceInAir            %[Pa] partial pressure of the substance in air (gas phase) that should be soluted into the medium
        fCurrentMolesOfSubstanceInMedium            %[mol] moles of soluted substance currently present in the medium
        fCurrentSubstanceInWaterConcentration       %[mol/m3] moles of substance in water of the medium
        fCurrentHenryConstant                       %[mol/(m3*Pa)]  Calculated based on temperature dependent henry's law
        
        %results of Henry Law calculation
        fTargetSubstanceInWaterConcentration        %[mol/m3] desired moles of substance in water of the medium
        
        % calculations to set flow rate without membrane
        fTargetMolesOfSubstanceInMedium             %[mol]how many moles of the soluted substance should be in the medium with regard to henrys law
        fMoleDifference                             %[mol]what is the difference in moles between what is currently in the solution and what should be there
        fMassDifference                             %[kg] target soluted moles converted to mass with molar mass
        
        %calcualtions to set flow rate with membrane (uses an imgainary
        %partial pressure as a driving force)
        fEquivalentPartialPressure                  %[Pa]
        fMaximumTransportRate                       %[mol/s]
        fPressureGradient                           %[Pa]
        %        fFlowRate                          %[kg/s]   flow rate to reach the target concentration until the next time step (assuming time steps are equally long)
        fFlowFactor                                 %factor that relates the current flow through the membrane to what the algal culture is using (CO2) or producing (O2). if this is smaller than one, then that doesn't necessarily mean that full growth can't be achieved since it is buffered through the water volume. however, in the long run this will lead to a bottleneck of CO2 or an excess of O2
        fPrefixFlowFactor                         %prefix, plus for CO2, minus for o2
    end
    
    methods
        
        %TODO: could update this to include the air and the medium phase as inputs (and not hardcode) to
        %make it more independent.
        function this = AtmosphericGasExchange (oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P, sSubstance)
            this@matter.procs.p2ps.stationary(oStore, sName, sExmePhaseIntoP2P, sExmePhaseOutofP2P);
            this.sSubstance = sSubstance;

            %% P2P-relevant Properties
            %instantiate Extract Partials array
            this.arExtractPartials = zeros(1,this.oMT.iSubstances);
            %tell which substances. Can be more than one substance, but
            %then the sum of all together should be one since it represents
            %the full flow. Can also be changed during sim with update
            %function.
            this.arExtractPartials(this.oMT.tiN2I.(this.sSubstance)) = 1;

            
            this.fLastExec = 0; %[s] starting value is zero, will be updated each time
            
            this.sMembraneMaterial =this.oStore.oContainer.oParent.sMembraneMaterial; 
            this.fMembraneArea  = this.oStore.oContainer.oParent.fMembraneSurface; %[m2]
            this.fMembraneThickness = this.oStore.oContainer.oParent.fMembraneThickness; %[m]
            
            %% Henry Constant Properties for the selected substance
            %used the ones that were mentioned most frequent in the stated
            %source Sander, 2015 (Atmos. Chem. Phys., 15,, 2015)
            
            switch this.sSubstance
                case 'CO2'
                    this.fNormalHenryConstant = 3.3*10^-4;      %[mol/(m3*Pa)] as reported in Sander, 2015 (Atmos. Chem. Phys., 15, 2015) p. 4488. Many values are stated there, range from 3.1*10^-4 to 4.5*10^-4
                    this.fTemperatureDependence = 2300;         %[K] as reported in Sander, 2015 (Atmos. Chem. Phys., 15, 2015) p. 4488. Many values are stated there, range from 2200 to 2900
                    this.fPrefixFlowFactor = 1;               %se positive prefix for co2 flow factor. o2 needs negative
                    switch this.sMembraneMaterial
                        case 'SSP-M823 Silicone'
                            this.fMembranePermeability = 8.438*10^-13; %[(mol*m_thick)/(m2_surface*s*Pa_difference)]from datasheet but changed units to SI
                        case 'Cole Parmer Silicone'
                            this.fMembranePermeability = 6.292*10^-13; %[(mol*m_thick)/(m2_surface*s*Pa_difference)]from datasheet but changed units to SI

                    end
                    
                case 'O2'
                    this.fNormalHenryConstant = 1.3*10^-5;      %[mol/(m3*Pa)] as reported in Sander, 2015 (Atmos. Chem. Phys., 15, 2015) p. 4408. Many values are stated there, range from 1.2*10^-5 to 1.3*10^-5
                    this.fTemperatureDependence = 1500;         %[K] as reported in Sander, 2015 (Atmos. Chem. Phys., 15, 2015) p. 4408. Many values are stated there, range from 1200 to 1800
                    this.fPrefixFlowFactor = -1;              %sets minus for flow since oxygen is flowing in the opposite direction of CO2 and would otherwise result in a negative flow factor
                    switch this.sMembraneMaterial
                        case 'SSP-M823 Silicone'
                            this.fMembranePermeability = 1.563*10^-13; %[(mol*m_thick)/(m2_surface*s*Pa_difference)]from datasheet but changed units to SI
                        case 'Cole Parmer Silicone'
                            this.fMembranePermeability = 2.488*10^-13; %[(mol*m_thick)/(m2_surface*s*Pa_difference)]from datasheet but changed units to SI
                    end
                    
            end
            

            
        end
    end
    
    methods (Access = protected)
        function update(this)
          
            
            %% Henry's Law Calculations
            %Get phase parameters of gas and liquid phase to later
            %calculate henrys constant.
            this.fTemperatureOfMedium = this.oStore.toPhases.GrowthMedium.fTemperature; %[K]
            this.fCurrentMolesOfSubstanceInMedium = this.oStore.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.(this.sSubstance))/this.oMT.ttxMatter.(this.sSubstance).fMolarMass; %[mole], divide mass of substance in medium by its molar mass
            this.fPartialPressureOfSubstanceInAir =this.oStore.toPhases.AirInGrowthChamber.afPP(this.oMT.tiN2I.(this.sSubstance)); %[Pa]
            
            %calculate current temperature dependent Henry Constant
            this.fCurrentHenryConstant = this.fNormalHenryConstant * exp(this.fTemperatureDependence*((1/this.fTemperatureOfMedium)-(1/298.15))); %[mol/(m3*Pa)], 298.15 K refers to the normal temeprature (of the water) at which                                                                                                     the normal henry constant (which is used in this case) is measured
            
            %% calculate concentration of CO2 in Water
            this.fCurrentSubstanceInWaterConcentration = this.fCurrentMolesOfSubstanceInMedium / (this.oStore.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.H2O)/this.oIn.oPhase.oStore.oContainer.fCurrentGrowthMediumDensity); %[mol/m3] 
            
            %calculate Henry's Law of what should be in medium in
            %equilibrium conditions
            this.fTargetSubstanceInWaterConcentration = this.fCurrentHenryConstant * this.oStore.toPhases.AirInGrowthChamber.afPP(this.oMT.tiN2I.(this.sSubstance)); %[mol/m3] 
            
            %calculate how many moles of substance should be soluted in the
            %medium according to henry's law by multiplying with the
            %medium's current current water volume
            this.fTargetMolesOfSubstanceInMedium = this.fTargetSubstanceInWaterConcentration * (this.oStore.toPhases.GrowthMedium.afMass(this.oMT.tiN2I.H2O)/1000); %[mol] 
 
                 %calculate time passed since last update
                fElapsedTime = this.oTimer.fTime - this.fLastExec; %s
            
            %% determine flow rate without or with a membrane (see two if cases)
            if strcmp(this.sMembraneMaterial, 'none')
                %calculate the difference in moles what is actually in there vs
                %what should be in there. This is > 0 for higher target than
                %current (substance drawn from air) and < 0 for current higher
                %than target (substance released to air)
                this.fMoleDifference = this.fTargetMolesOfSubstanceInMedium - this.fCurrentMolesOfSubstanceInMedium; %[mol]
                
                %calculate what this difference is in mass by multiplying with
                %the molar mass
                this.fMassDifference = this.fMoleDifference*this.oMT.ttxMatter.(this.sSubstance).fMolarMass; %[kg]
                
                %% Calculate Flow rate to reach target concentration
                %substance with the time step
               
                
                %ensure that no negative time step is used
                if fElapsedTime <= 0
                    return %returns to invoking function
                end
                % calculate and set the required flow rate kg/s by dividing the
                % mass difference with the time since the last execution. If
                % the fMassDifference is >0, the target concentration is higher
                % than the current one and therefore, mass must flow from the
                % air to medium phase. If the fMassDifference is <0, there is
                % currently more substance  in the solution than the target
                % concentration and the substance must flow from the medium to
                % the air resulting in a negative flow rate.
                fFlowRate = this.fMassDifference / fElapsedTime; %[kg/s]
                
                
            else
                %% calculate an imaginary equivalent partial pressure to set driving force through membrane
                %represents how much is currently soluted in medium. This can
                %then be used as driving force
                this.fEquivalentPartialPressure = this.fCurrentSubstanceInWaterConcentration / this.fCurrentHenryConstant; %[Pa]
                this.fPressureGradient = (this.fPartialPressureOfSubstanceInAir-this.fEquivalentPartialPressure);  %[Pa]
                
                %calculate possible mole transport rate over the membrane at this pressure difference
                this.fMaximumTransportRate = (this.fMembranePermeability * this.fPressureGradient * this.fMembraneArea) / this.fMembraneThickness; %[mol/s]
                
                %set flow based on this
                fFlowRate = this.fMaximumTransportRate * this.oMT.ttxMatter.(this.sSubstance).fMolarMass; %[kg/s]

                
            end
            
            
            
            
            %% Set Flow Rate and update time of last execution for next calculation
            %tell that this matter should be removed
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            %set time of last execution for next update calculation
            this.fLastExec = this.oTimer.fTime; %[s]
            
            %set flow factor that relates flow thorugh membrane and
            %consumption/production of algal culture
            %check if flow required by photosyntehsis is not 0;
            
            if this.oTimer.fTime > 0
                fPhotosynthesisFlow = abs(this.oStore.toPhases.GrowthMedium.toManips.substance.afPartialFlowRatesFromPhotosynthesis(this.oMT.tiN2I.(this.sSubstance)));
                if fPhotosynthesisFlow > 0
                    this.fFlowFactor = this.fPrefixFlowFactor * this.fMaximumTransportRate * this.oMT.ttxMatter.(this.sSubstance).fMolarMass / fPhotosynthesisFlow; %[-]

                else
                    this.fFlowFactor = 0; %[-]
                end
            else
                this.fFlowFactor = 0; %[-]
            end
            
            
        end
        
        
    end
end

