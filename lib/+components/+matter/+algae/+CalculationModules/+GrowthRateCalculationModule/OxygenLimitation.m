classdef OxygenLimitation < base
    %OXYGENLIMITATION calculates the relative growth rate depending on the
    %current O2 concentration in the medium.
    
    %The oxygen concentration influence class constructor allows the
    %vectoral definition of the maximum equivalent partial pressure of
    %oxygen (more information on equivalent partial pressures of substances
    %in a liquid, see thesis 3.3.2.2) at which the optimum growth can occur
    %(i.e. below which growth is not limited) and to what level the
    %relative growth rate falls at 100 kPa partial pressure.
    
    %The update function calculates the current equivalent partial pressure
    %of oxygen in the medium by using information from the Henry?s law
    %oxygen phase to phase processor, which is part of the growth medium
    %module. It then calculates the relative growth rate depending on the
    %behavior entered in the class constructor. Mathematically, the
    %relative growth rate could fall to below zero when it is high above
    %the maximum partial pressure due to its linearly decreasing behavior.
    %For this reason, a check is implemented, which allows 0 as the lowest
    %relative growth rate. Currently the second behavior outlined in thesis
    %chapter 3.1.2.5 is implemented.
    
    properties

     
        oGrowthPhase
        %behavior definition
        mfPressures;            %vector of pressures in Pa
        mrRelativeGrowth;       %vector of unitless ratios between 0 and 1
        
        %model parameters
        fMaximumPartialPressureFullGrowth;      %Pa
        f100kPaGrowthFactor;                    %factor
        
        %current phase conditions
        fEquivalentPartialPressure             %Pa
        
        %output
        rOxygenRelativeGrowth                   %unitless factor between 0 and 1
     
    end
    
    methods
        
        function this = OxygenLimitation(oGrowthPhase)
            this.oGrowthPhase = oGrowthPhase;
            
            %behavior taken from Watts Pirt, 1979 [57], "The Influence of Carbon
            %Dioxide and Oxygen Partial Pressures on Chlorella Growth in
            %Photosynthetic Steady-state Cultures" this paper suggests,
            %that if increase in O2 partial pressure is only slow (talks
            %about mutliple generations), the algae can adapt to it quite
            %well and will only be affected, if the equivalent partial
            %pressure rises above 80 kPa. Beyond the 95kPa mark, where the
            %data idnicates a growth factor of 0.65, it is assumed to
            %further decline linearly. Other sources suggest way more
            %sensitive behavior, see thesis chapter 3.1.2.5. The assumption here is that equivalent partial pressure
            %of what is dissolved in the medium only rises slowly.
            
            this.mfPressures= [80000 100000];
            this.mrRelativeGrowth = [1 0.5]; % factor between 0 and 1, adapted from absolute values in paper.
            
            %no curve fitting necessary due to linear behavior.
            this.fMaximumPartialPressureFullGrowth = this.mfPressures(1); %Pa
            this.f100kPaGrowthFactor = this.mrRelativeGrowth (2); %uniteless factor between 0 and 1



            
        end
        
        function [rOxygenRelativeGrowth] = UpdateOxygenRelativeGrowth(this)

            %get equivalent partial pressure (representing what what the
            %partial pressure of the surrounding atmosphere would be if the
            %current O2 concentration were in equilibrium)
            this.fEquivalentPartialPressure = this.oGrowthPhase.toProcsEXME.O2_to_Air.oFlow.fEquivalentPartialPressure; %Pa
            
            %if the equivalent partial pressure is smaller than where it
            %becomes inhibiting, then the growth factor is 1
            if this.fEquivalentPartialPressure < this.fMaximumPartialPressureFullGrowth
                this.rOxygenRelativeGrowth = 1;
                
                %if the equivalent partial pressure is above where it
                %becomes inhibiting, then the growth factor is calculated
            else

                this.rOxygenRelativeGrowth = ((1-(this.f100kPaGrowthFactor-(100000/this.fMaximumPartialPressureFullGrowth))...
                    /(1-(100000/this.fMaximumPartialPressureFullGrowth)))/this.fMaximumPartialPressureFullGrowth) * this.fEquivalentPartialPressure ...
                    + ((this.f100kPaGrowthFactor-(100000/this.fMaximumPartialPressureFullGrowth))/(1-(100000/this.fMaximumPartialPressureFullGrowth)));
                
                %check if smaller than 0 due to linear behavior of
                %function, then set to 0.
                if this.rOxygenRelativeGrowth < 0
                    this.rOxygenRelativeGrowth = 0;
                end
            end
           rOxygenRelativeGrowth = this.rOxygenRelativeGrowth; %pass back to calling growth rate calculation module
        end
        
        
    end
end
