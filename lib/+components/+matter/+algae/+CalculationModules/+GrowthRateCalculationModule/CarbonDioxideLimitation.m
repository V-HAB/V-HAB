classdef CarbonDioxideLimitation < base
    %CARBONDIOXIDELIMITATION calculates the relative growth rate depending
    %on the current CO2 concentration in the medium. This is not due to the
    %lack of CO2 but the effect of high concentrations limiting growth of
    %Chlorella vulgaris.
    
    %the carbon dioxide influence class constructor allows the vectoral
    %definition of the maximum equivalent partial pressure of carbon
    %dioxide  at which the optimum growth can occur (i.e. below which
    %growth is not limited) and to what level the relative growth rate
    %falls at 100 kPa partial pressure. It is important to note, that this
    %limitation is not due to the absence of carbon dioxide as a nutrient
    %for photosynthesis, but due to high concentrations, which can also
    %limit algal growth, see 3.1.2.6. The update function calculates the
    %current equivalent partial pressure of carbon dioxide in the medium by
    %using information from the Henry?s law carbon dioxide phase to phase
    %processor, which is part of the growth medium module. It then
    %calculates the relative growth rate depending on the behavior entered
    %in the class constructor. Mathematically, the relative growth rate
    %could fall to below zero when it is high above the maximum partial
    %pressure due to its linearly decreasing behavior. For this reason, a
    %check is implemented, which allows 0 as the lowest relative growth
    %rate.
    
    properties
        oGrowthPhase
        %behavior definition
        mfPressures;    %vector of pressures in Pa
        mrRelativeGrowth; %vector of unitless ratios between 0 and 1
        %model parameters
        fMaximumPartialPressureFullGrowth;     %Pa
        f100kPaGrowthFactor;                    %factor
        
        %current phase conditions
        fEquivalentPartialPressure             %Pa
        
        %output
        rCarbonDioxideRelativeGrowth            %unitless factor between 0 and 1
        
    end
    
    methods
        
        function this = CarbonDioxideLimitation(oGrowthPhase)
            this.oGrowthPhase = oGrowthPhase;
                     
            %vectors to define behavior of CO2 relative growth. pressure at
            %which growth is not affected and to what it falls at 100 kPa.
            %vectoral definition is not necessary here because behavior is
            %linear (2 points enough) but done to be consistent with other
            %relative growth calculations.
            %behavior taken from Watts Pirt, 1979 (see thesis literature
            %[57], "The Influence of Carbon Dioxide and Oxygen Partial
            %Pressures on Chlorella Growth in Photosynthetic Steady-state
            %Cultures" this paper suggests, that if increase in CO2 partial
            %pressure is only slow (talks about mutliple generations), the
            %algae can adapt to it quite well and will only be affected, if
            %the equivalent partial pressure rises above 65 kPa. Beyond the
            %100kPa mark, where the data idnicates a growth factor of 0.14,
            %it is assumed to further decline linearly. Other sources
            %suggest way more sensitive behavior, see thesis chapter
            %3.1.2.6. assumption here is, that equivalent partial pressure
            %of what is dissolved in the medium only rises slowly.
            
            this.mfPressures= [65000 100000];
            this.mrRelativeGrowth = [1 0.14]; % (assuming 0.03/0.22 µmax growth from graph) factor, adapted from absolute values in paper.
            
            %no curve fitting necessary due to linear behavior.
            this.fMaximumPartialPressureFullGrowth = this.mfPressures(1); %Pa
            this.f100kPaGrowthFactor = this.mrRelativeGrowth (2); %uniteless factor between 0 and 1
            
            
            
        end
        
        function [rCarbonDioxideRelativeGrowth] = UpdateCarbonDioxideRelativeGrowth(this)
            
            %get equivalent partial pressure (representing what what the
            %partial pressure of the surrounding atmosphere would be if the
            %current CO2 concentration were in equilibrium)
            this.fEquivalentPartialPressure = this.oGrowthPhase.toProcsEXME.CO2_from_Air.oFlow.fEquivalentPartialPressure; %Pa
            
            %if the equivalent partial pressure is smaller than where it
            %becomes inhibiting, then the growth factor is 1
            if this.fEquivalentPartialPressure < this.fMaximumPartialPressureFullGrowth
                this.rCarbonDioxideRelativeGrowth = 1;
                
                %if the equivalent partial pressure is above where it
                %becomes inhibiting, then the growth factor is calculated
            else

                this.rCarbonDioxideRelativeGrowth = ((1-(this.f100kPaGrowthFactor-(100000/this.fMaximumPartialPressureFullGrowth))...
                    /(1-(100000/this.fMaximumPartialPressureFullGrowth)))/this.fMaximumPartialPressureFullGrowth) * this.fEquivalentPartialPressure ...
                    + ((this.f100kPaGrowthFactor-(100000/this.fMaximumPartialPressureFullGrowth))/(1-(100000/this.fMaximumPartialPressureFullGrowth)));
                
                %check if smaller than 0 due to linear behavior of
                %function, then set to 0.
                if this.rCarbonDioxideRelativeGrowth < 0
                    this.rCarbonDioxideRelativeGrowth = 0;
                end
            end
            
            %pass back to calling growth rate calculation module
            rCarbonDioxideRelativeGrowth = this.rCarbonDioxideRelativeGrowth;
        end
        
        
    end
end
