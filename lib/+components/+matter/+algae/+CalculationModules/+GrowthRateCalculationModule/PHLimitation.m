classdef PHLimitation < base
            %PHLIMITATION calculates the pH growth factor as a function of
            %temperature. the minimum pH defines the point below which no
            %growth occurs at all. between minimum and minimum for full
            %growth, the factor rises linearly to 1. it stays 1 between the
            %minimum for full growth and maxmimum for full growth and then
            %decreases linearly to the maximum ph. above the maximum pH no
            %growth can occur and the fator is therefore 0.
            %the calculations where derived from graph 2 in
            %Mayo, 1997 (see thesis literature [35], where temperature and PH are
            %combined. the calculatios here are adapted for relative
            %measures (paper has absolute growth rate) and adjusted
            %to not reflect the influence of temperature on growth, just on
            %the PH boundaries. The temperature influence on growth is calculated in
            %a different part of the program where the temperature growth
            %facture is calculated
            
    properties
        oPhase             %phase of which the PH should be calculated
        fCurrentTemperature; %[K], of growth medium phase
        
        %pH behavior definition
        mfTemp;             %[K] vector of temperatures
        mfLowOpt;           %vector of pH values of lower lower boundary for optimum growth at different temperatures
        mfHighOpt;          %vector of pH values upper boundary for optimum growth at different temperatures
        mfLowZero;          %vector of pH values lower boundary for no growth at different temperatures
        mfHighZero;         %vector of pH values upper boundary for no growth at different temperatures
        mfLowOptPoly;       %factors of approximated polynomial
        mfHighOptPoly;      %factors of approximated polynomial
        mfLowZeroPoly;      %factors of approximated polynomial
        mfHighZeroPoly;     %factors of approximated polynomial
        
        
        %calculated values
        fPH;                 %pH of phase
        
        fMinPH;             %unitless, current absolute minimum ph (beyond no growth possible)
        fMinPHFullGrowth;   %unitless, current minimum ph for optimum growth
        fMaxPHFullGrowth;   %unitless, current maximum ph for optimum growth
        fMaxPH;             %unitless, current absolute maximum ph (beyond no growth possible)

        rPHGrowthFactor;    %unitless, says how much growth is possible in current pH conditions compared to the optimum growth rate
        
    end
    
    methods
        
        function this = PHLimitation(oGrowthPhase)
            this.oPhase = oGrowthPhase;
            
            %% define pH behavior (temperature dependent), taken from Paper Mayo, 1997 [35]
            %temperature vector
            this.mfTemp  = [283.15 293.15 303.15 313.15]; %[K]
            
            warning('OFF', 'MATLAB:polyfit:RepeatedPointsOrRescale')
            %pH of lower boundary for optimum growth at different
            %temperatures
            this.mfLowOpt = [4.75 4.25 3.65 4.9];
            this.mfLowOptPoly = polyfit(this.mfTemp,this.mfLowOpt,3);
            
            %pH of upper boundary for optimum growth at different
            %temperatures
            this.mfHighOpt = [8.6 9.2 10 9];
            this.mfHighOptPoly = polyfit(this.mfTemp,this.mfHighOpt,3);
            
            %pH of lower boundary for no growth at different temperatures
            this.mfLowZero = [2.6 2.2 1.7 2.9];
            this.mfLowZeroPoly = polyfit(this.mfTemp,this.mfLowZero,3);
            
            %pH of upper boundary for no growth at different temperatures
            this.mfHighZero = [10.4 11 11.8 11];
            this.mfHighZeroPoly = polyfit(this.mfTemp,this.mfHighZero,3);
     
            warning('ON', 'MATLAB:polyfit:RepeatedPointsOrRescale')

            
        end
        
        function [rPHRelativeGrowth] = UpdatePHRelativeGrowth(this)
           %% calculate current pH
            fH2OVolume = 1000*this.oPhase.afMass(this.oPhase.oMT.tiN2I.H2O) / this.oPhase.oMT.ttxMatter.H2O.fStandardDensity;   % [1000*kg / (kg / m3)] = [L]
            fHPlusMoles = this.oPhase.afMass(this.oPhase.oMT.tiN2I.Hplus) / this.oPhase.oMT.ttxMatter.Hplus.fMolarMass;         % [mol]
            fHPlusConcentration = (fHPlusMoles / fH2OVolume);                                                                   % [mol/m3]
            this.fPH = -log10(fHPlusConcentration);                                                                             % no unit
           
           
            %% calculate relative growth
            %% get current Temperature
            this.fCurrentTemperature = this.oPhase.fTemperature; % [K]
            %equations are only valid in an area where the temperature is
            %accounted for in the paper (10 °C to 40 °C)
            
            %% calculate the minimum and maximum pH where any growth occurs (as a function of temperature)
            
            this.fMinPH = this.mfLowZeroPoly(1) * this.fCurrentTemperature^3 + this.mfLowZeroPoly(2) * this.fCurrentTemperature^2 + this.mfLowZeroPoly(3) * this.fCurrentTemperature  + this.mfLowZeroPoly(4); %no unit, pH
            this.fMaxPH = this.mfHighZeroPoly(1) * this.fCurrentTemperature^3 + this.mfHighZeroPoly(2) * this.fCurrentTemperature^2 + this.mfHighZeroPoly(3) * this.fCurrentTemperature  + this.mfHighZeroPoly(4); %no unit, pH
             
            %% calculate the minimum and maximum pH where growth occurs at its maximum (as a function of temperature)
            this.fMinPHFullGrowth = this.mfLowOptPoly(1) * this.fCurrentTemperature^3 + this.mfLowOptPoly(2) * this.fCurrentTemperature^2 + this.mfLowOptPoly(3) * this.fCurrentTemperature  + this.mfLowOptPoly(4); %no unit, pH
            this.fMaxPHFullGrowth = this.mfHighOptPoly(1) * this.fCurrentTemperature^3 + this.mfHighOptPoly(2) * this.fCurrentTemperature^2 + this.mfHighOptPoly(3) * this.fCurrentTemperature  + this.mfHighOptPoly(4); %no unit, pH
            
            %% pH Growth Factor Calculation
            %determine the growth factor depending where the current pH of
            %the medium lies with regard to the pH growth boundaries
            %(calculated above)
            
            if this.fPH <= this.fMinPHFullGrowth
                if this.fPH <= this.fMinPH %if smaller or equal min PH it becomes 0
                    this.rPHGrowthFactor = 0; %no unit
                else
                    this.rPHGrowthFactor = (this.fPH - this.fMinPH) / (this.fMinPHFullGrowth - this.fMinPH); %no unit
                end
            else
                if this.fPH <= this.fMaxPHFullGrowth %on max PH Full Growth it is still 1
                    this.rPHGrowthFactor = 1; 
                elseif this.fPH <= this.fMaxPH %on maxPH it becomes 0, 
                    this.rPHGrowthFactor = (this.fMaxPH - this.fPH) - (this.fMaxPH - this.fMaxPHFullGrowth); %no unit
                else %if above max PH it becomes 0
                    this.rPHGrowthFactor = 0; %no unit
                    
                end
            end

            
            %set function output.
            rPHRelativeGrowth = this.rPHGrowthFactor; %no unit, pasesd back to growth rate calculation module.

        end
        
        
    end
end
