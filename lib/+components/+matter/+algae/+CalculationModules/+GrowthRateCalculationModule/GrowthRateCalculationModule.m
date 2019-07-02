classdef GrowthRateCalculationModule < base
    %GROWTHRATECALCULATIONMODULE determines the optimum biomass
    %concentration increase rate depending on the current biomass
    %concentration in the medium, instantiates and stores objects to calculate relative growth rates for
    %potentially limiting factors (temperature, pH, availability of
    %photosynthetically active radiation, concentrations of oxygen and
    %carbon dioxide). Finally the module calculates the achievable growth
    %rate for the photosynthesis module by using a multiplicative or
    %minimum threshold model.
    
    properties
        %% General Constructor
        oSystem     %system object that initiates the construction of this object and calls the functions.In this case, ChlorellaInMedia
        fTime       %[s] current time taken from the oTimer of the oParent object
        
        %% Theoretical Growth Rate
        %parameters that describe the growth rate under absolute optimum
        %conditions
        
        fLagTime                                    %[s], time in which the cell growth is inhibited due to getting used to the medium
        fMaxSpecificGrowthRate                      %[1/s], maximum growht the culture can achieve in the exponential phase
        fMaximumBiomassConcentration                %[kg/m3],biomass concentration at which the growth will stop due to overpopulation
        fMaximumGrowthBiomassConcentration          %[kg/m3],biomass concentration at which the strongest growth occurs (inflection point of Population curve, second derivative)
        fCurrentBiomass                             %[kg]
        fTheoreticalCurrentBiomassConcentrationIncrease %[kg/(m3*s)] biomass concentration growth rate
        
        
        
        fTheoreticalCurrentBiomassGrowthRate       %[kg/s]
        fBiomassConcentration                       %[kg/m3] current biomass concentration
        fMediumVolume                               %[m3] current volume of water as representative for medium volume.
        fInitialBiomassConcentration                %[kg/m3]
        bDead                                       % boolean operator to see if the culture is dead. dead if this is set to 1. Then the growth rates are set to 0 because they can't grow anymore.
        
        %% Relative Growth calculation objects
        %Set from the parent Chlorella In Media System once it is
        %instantiated since these calculation objects need information form
        %the parent.
        oTemperatureLimitation                      %calculation object that determines the relative growth rate and possible limitation as a result of temperature influence
        oPhLimitation                               %calculation object that determines the relative growth rate and possible limitation as a result of pH influence
        oO2Limitation                               %calculation object that determines the relative growth rate and possible limitation as a result of O2 concentration influence
        oCO2Limitation                              %calculation object that determines the relative growth rate and possible limitation as a result of co2 Cconcentration influence
        oPARLimitation                              %calculation object that determines the relative growth rate and possible limitation as a result of Photosynthetically active radiation influence
        
        % relative growth influences that differ from the perfect theoretical
        % ones, will negatively influence the growth
        rTemperatureRelativeGrowth                 %Influence of the media's current temperature on the growth rate
        rPhRelativeGrowth                          %Influence of the media's current pH on the  growth rate
        rO2RelativeGrowth                          %Influence of the media's current dissolved oxygen content on the growth rate
        rCO2RelativeGrowth                         %Influence of the media's current dissolved CO2 content on the growth rate
        rPARRelativeGrowth                         %Influence of the current lighting conditions on the growth rate
        
        %% Achievable Growth Rate
        fAchievableCurrentBiomassGrowthRate          %[kg/s], if enough CO2 and Nutrients are available (that is determined in Photosynthesis manipulator)
        
        %% Comparison Values for Time-Controlled Growth Rate
        fNewBiomassConcentration                             %[kg/m3]
        fCurrentBiomassConcentrationDifference      %[kg/m3]
        fLastExecute                                %[s]
        fTimeStep                                   %[s]
        fCompareTheoreticalCurrentBiomassConcentrationIncrease   %[kg/(m3*s)] ideal behavior, without factors (time dependent, not cell density dependent)
        fCompareTheoreticalBiomassConcentration     %[kg/m3] ideal growth
        
        %% achievable growth rate
        sCalculationModel                           %string to specify which calculation model to use. can be multiplicative or minimum (see thesis 3.1.3)
    end
    
    methods
        function this = GrowthRateCalculationModule(oSystem)
            % connect system object
            this.oSystem = oSystem; 

            %% define growth parameters
            this.fLagTime = 0;                                    %[s]
            this.fMaxSpecificGrowthRate =1.6*10^-5;               %[kg/m3s] equals to 1.3/day
            this.fMaximumBiomassConcentration = 2.65;             %[kg/m^3]
            this.bDead = 0;                                       % boolean operator if the algal culture is dead. then nothing can grow anymore
            
            % biomass concentration at which maximum growth occurs. this is
            % used as a set point for the harvester. in gompertz model this
            % is always at 36.8 % of maximum biomass concentration
           this.fMaximumGrowthBiomassConcentration = 0.368*this.fMaximumBiomassConcentration;
            
            %for reference values of time-controlled behavior
            this.fLastExecute = 0;                                 %[s]
            this.fBiomassConcentration = 0;                                 %[s]
            
            
            this.fInitialBiomassConcentration = this.fMaximumBiomassConcentration * exp(-exp(((this.fMaxSpecificGrowthRate*exp(1))/this.fMaximumBiomassConcentration)*(this.fLagTime-0)+1)); %kg/m3 (cell density at t=0);
            

            
            %% achievable growth rate
            this.sCalculationModel = 'multiplicative';              % multiplicative or minimum, see thesis 3.1.3
        end
        
        function update(this)
            this.CalculateTheoreticalGrowthRate;
            this.CalculateInfluenceParameters;
            this.CalculateAchievableGrowthRate;
            
        end
        
        
        function CalculateTheoreticalGrowthRate(this)
            
            %if the culture is dead no growth is calculated
            if this.bDead == 0
                %% Growth Rate as function of cell density
                this.fTime = this.oSystem.oTimer.fTime;
                
                %divide active cell biomass by water volume in growth media
                %phase [kg/m3]
                this.fCurrentBiomass = this.oSystem.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oSystem.oMT.tiN2I.Chlorella);
                this.fMediumVolume = (this.oSystem.toStores.GrowthChamber.toPhases.GrowthMedium.afMass(this.oSystem.oMT.tiN2I.H2O)/this.oSystem.fCurrentGrowthMediumDensity) ; 
                this.fBiomassConcentration = this.fCurrentBiomass / this.fMediumVolume;
                
                %create some theoretical values for comparison
                % growth rate dependent on time
                this.fCompareTheoreticalCurrentBiomassConcentrationIncrease = this.fMaxSpecificGrowthRate * exp(-exp((this.fMaxSpecificGrowthRate * exp(1)/this.fMaximumBiomassConcentration)*(this.fLagTime-this.fTime)+1)+((this.fMaxSpecificGrowthRate * exp(1)/this.fMaximumBiomassConcentration)*(this.fLagTime-this.fTime)+2));
                this.fCompareTheoreticalBiomassConcentration = this.fMaximumBiomassConcentration * exp(-exp(((this.fMaxSpecificGrowthRate*exp(1))/this.fMaximumBiomassConcentration)*(this.fLagTime-this.fTime)+1));
                
                %if the sim time is still below the lag time, the growth rate
                %is time dependent
                if this.fTime < this.fLagTime
                    this.fTheoreticalCurrentBiomassConcentrationIncrease = this.fMaxSpecificGrowthRate * exp(-exp((this.fMaxSpecificGrowthRate * exp(1)/this.fMaximumBiomassConcentration)*(this.fLagTime-this.fTime)+1)+((this.fMaxSpecificGrowthRate * exp(1)/this.fMaximumBiomassConcentration)*(this.fLagTime-this.fTime)+2)); %kg/(m3*s)
                    
                    
                    %if the sim time is above the lag time the cells have
                    %adjusted to the environment and the growth is now
                    %determined by the current cell density this method allows
                    %for respecting the fact that cells could be harvested
                    %during the simulation process. a solely time-dependent
                    %function of growth would not be able to respect that.
                else
                    this.fTheoreticalCurrentBiomassConcentrationIncrease = this.fMaxSpecificGrowthRate * exp(-exp((this.fMaxSpecificGrowthRate*...
                        exp(1)/this.fMaximumBiomassConcentration)*(this.fLagTime-(this.fLagTime-((this.fMaximumBiomassConcentration*...
                        (log(-log(this.fBiomassConcentration/this.fMaximumBiomassConcentration))-1))/(this.fMaxSpecificGrowthRate*...
                        exp(1)))))+1)+((this.fMaxSpecificGrowthRate * exp(1)/this.fMaximumBiomassConcentration)*...
                        (this.fLagTime-(this.fLagTime-((this.fMaximumBiomassConcentration * (log(-log(this.fBiomassConcentration/...
                        this.fMaximumBiomassConcentration))-1))/(this.fMaxSpecificGrowthRate*exp(1)))))+2)); %kg/(m3*s)
                    
                    
                end
                
            else
                this.fTheoreticalCurrentBiomassConcentrationIncrease = 0;
            end
            
            %from density increase to mass growth by multiplying with volume
            this.fTheoreticalCurrentBiomassGrowthRate = this.fTheoreticalCurrentBiomassConcentrationIncrease * this.fMediumVolume; %kg/(m3*s) * m3 = [kg/s]
        end
        
        function CalculateInfluenceParameters(this)
            
            [this.rTemperatureRelativeGrowth, bDead] = this.oTemperatureLimitation.UpdateTemperatureRelativeGrowth;
            %if culture is dead all the absorbed PAR will go to heat since it is not being used for PS anymore.
            this.bDead = bDead;
            
            this.rPARRelativeGrowth = this.oPARLimitation.UpdatePARRelativeGrowth; %calls further functions in PAR Module
            
            this.rPhRelativeGrowth = this.oPhLimitation.UpdatePHRelativeGrowth;
            
            this.rO2RelativeGrowth = this.oO2Limitation.UpdateOxygenRelativeGrowth;
            
            this.rCO2RelativeGrowth = this.oCO2Limitation.UpdateCarbonDioxideRelativeGrowth;
            
            
            
        end
        
        
        function CalculateAchievableGrowthRate(this)
            %this function calculates possible growth rate but does not
            %reflect the availability of algae feedstock (nutrients, CO2
            %and water) - this is done in the photosynthesis manipulator
            
            if this.fTime > this.fLagTime
                if strcmp(this.sCalculationModel, 'multiplicative') == true
                    %take all limiting factors into account
                    
                    this.fAchievableCurrentBiomassGrowthRate = this.fTheoreticalCurrentBiomassGrowthRate * this.rTemperatureRelativeGrowth *...
                        this.rPhRelativeGrowth * this.rO2RelativeGrowth * this.rCO2RelativeGrowth * this.rPARRelativeGrowth; %[kg/s]
                    
                elseif strcmp(this.sCalculationModel, 'minimum') == true
                    %only take most limiting factor into account.
                    
                    %put relative growth rates into one vector to find
                    %minimum
                    mrHelpVector = [this.rTemperatureRelativeGrowth, this.rPhRelativeGrowth, this.rO2RelativeGrowth, this.rCO2RelativeGrowth, this.rPARRelativeGrowth];
                    
                    %find smallest of limiting factors
                    fMinimumLimit = min(mrHelpVector);
                    
                    %multiply smallest limiting factor with growth rate
                    this.fAchievableCurrentBiomassGrowthRate = this.fTheoreticalCurrentBiomassGrowthRate * fMinimumLimit; %[kg/s]
                    
                end
                
                
            else
                %no influence factors below lag time in order to maintain
                %correct behavior afterwards. the growth rate is extremely
                %small anyway and if something is limiting growth in
                %reality, this will have an effect after the lag time. If
                %influence factors had a strong effect during lag time, the
                %mathemtaical consequence would be a lower than normal
                %growth rate after the lag time due to a very low biomass
                %concentration (which then determines the growth rate).
                this.fAchievableCurrentBiomassGrowthRate = this.fTheoreticalCurrentBiomassGrowthRate; %[kg/s]
            end
            
            
        end
    end
    
end