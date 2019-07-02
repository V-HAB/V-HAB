classdef TemperatureLimitation < base
    %TEMPERATURELIMITATION 
    %The temperature influence class?s class
    %constructor allows the definition of the upper and lower extreme
    %boundaries beyond which no growth is possible, and of the temperature
    %influence curve. In two separate vectors, temperature data points can
    %be entered with corresponding relative growth rates, which should be 0
    %at the extreme lower and upper boundary and 1 around the optimum
    %growth rate. The data is then automatically approximated with the
    %MATLAB curve fitting tool to create a 4th order polynomial curve,
    %which represents the growth rate with varying medium temperature. The
    %currently implemented behavior follows that introduced in 3.1.2.1
    %shown in Figure 3-6.
    
    properties
        oGrowthPhase;
        fMinimumTemperature;        %[K]
        fMaximumTemperature;        %[K]
        bDead;                      %boolean to tell if algal culture is dead. happenns when exposed to higher than maxmimum temperature
        rTemperatureRelativeGrowth; %factor between 0 and 1
        fCurrentTemperature         %[K]
        mfTemp;                     %vector of temperatures
        mrGrowthrate;               %vector of relative growth rates at specified temperatures
        mfFactors;                  %vector of polynomial factors
        
    end
    
    methods
        
        function this = TemperatureLimitation(oGrowthPhase)
            this.oGrowthPhase = oGrowthPhase;
            this.fMinimumTemperature = 274; %[K]
            this.fMaximumTemperature = 313; %[K]
            this.bDead = 0; %set to 0 initially and is only changed to 1 if temperature increases over maximum temperature
            
            %curve fit the temperature influence curve with data from graph
            %in pHAndTemperatureCombined.pdf and added minimum temperature
            %close to 0C possible from GrowthResponseRangeLightTemp.pdf
            this.mfTemp  = [this.fMinimumTemperature 284 289 294 298 302 309 313]; %[K]
            
            this.mrGrowthrate = 2.0833* [0 0.25 0.325 0.4 0.44 0.48 0.45 0.35]; %[-], between 0 and 1.
            
            warning('OFF', 'MATLAB:polyfit:RepeatedPointsOrRescale')
            this.mfFactors = polyfit(this.mfTemp,this.mrGrowthrate,4); %factors of curve-fitted polynomial
            warning('ON', 'MATLAB:polyfit:RepeatedPointsOrRescale')
            
        end
        
        function [rTemperatureRelativeGrowth,bDead] = UpdateTemperatureRelativeGrowth(this)
           this.fCurrentTemperature = this.oGrowthPhase.fTemperature;
            
            this.rTemperatureRelativeGrowth = this.mfFactors(1) * this.fCurrentTemperature^4 + this.mfFactors(2) * this.fCurrentTemperature^3  + this.mfFactors(3) * this.fCurrentTemperature^2 + this.mfFactors(4)*this.fCurrentTemperature +this.mfFactors(5) ;
            %since function is not only defined on an interval the growth
            %factor has to be cut off when larger than 1 or smaller than 0
            
            if this.rTemperatureRelativeGrowth > 1
                this.rTemperatureRelativeGrowth = 1;
            elseif this.rTemperatureRelativeGrowth < 0
                this.rTemperatureRelativeGrowth = 0;
            end
            
            %culture dies when above maximum temperature
            if this.fCurrentTemperature > this.fMaximumTemperature
                this.rTemperatureRelativeGrowth = 0; %function doesn't suggest its zero, but no growth can happen above this point.
                this.bDead =1; %isn't set to zero anywhere else meaning the culture stays dead once this is set to 1.
             end
            
            %pass values back to calling growth rate calculation module
            rTemperatureRelativeGrowth = this.rTemperatureRelativeGrowth;
            bDead = this.bDead;
        end
        
        
    end
end
