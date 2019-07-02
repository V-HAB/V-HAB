classdef PARLimitation < base
    %PARLIMITATION calculates the relative growth due to the limitation of
    %too high or low photosynthetically active radiation in the
    %photobioreactor volume.
    
    properties
        oGrowthPhase;           %Growth medium
        oPARModule;             %PAR Module, where calculations are made. set from chlorella in media system, because PAR module is not instantiated yet when this object is instantiated.
        rLinearGrowthFactor;    %unitless
        rSaturatedGrowthFactor; %unitless
        rPARRelativeGrowth      %unitless, passed back to growth calculation module
       
    end
    
    methods
        
        function this = PARLimitation(oGrowthPhase)
            this.oGrowthPhase = oGrowthPhase;
            %PAR Module reference is set from Chlorella In Media system,
            %once the module is instantiated, because it can't be
            %instantiated in the beginning, when the growth rate
            %calculation module and this calculation object are
            %instantiated.
      
        end
        
        function [rPARRelativeGrowth] = UpdatePARRelativeGrowth(this)
            % Growth factor is comprised of factors of individual growth
            % volumes which are obtained by relating the size of
            %no growth in dark and inhibited. full growth in saturated
            %zone. limited growth in linear zone.
            
            %if wohle volume were illuminated in  saturated growth zone,
            %growth factor would be 1 because the whole volume can grow
            %with the maximum growht rate --> is not light limited
            
            %in linear zone, the growth is calculated with the average
            %light intensity in that zone and how that relates to the
            %saturated light growth (--> linear relation). The average is
            %not 50% of the saturation ppfd because the light decreases
            %exponentially and not linearly. the growth rises linear with
            %light availability but not with depth!
            
            % saturated zone
            this.rSaturatedGrowthFactor = (this.oPARModule.fSaturatedGrowthVolume)/(this.oPARModule.fWaterVolume); %[-]
            
            %linear growth zone where the average PPFD is related to the
            %saturation PPFD (where full growth occurs) to account for the
            %linear relationship between growth and light intensity. this
            %relation is then multiplied with the relation between the
            %volume where linear growth occurs and the total volume. the
            %product is the factor that accounts for how much the linear
            %growth volume contributes to overall growth
            this.rLinearGrowthFactor = (this.oPARModule.fAveragePPFDLinearGrowth/this.oPARModule.fSaturationPPFD)*(this.oPARModule.fLinearGrowthVolume/this.oPARModule.fWaterVolume); %[-]
            
            %sum of the both is the Light Growth factor that accounts for
            %the different rates of growth occuring in the different
            %lighting zones. for example the saturated growth factor could
            %be 0.5 (so 50% of the reactor volume are the saturated zone
            %and growing at 100% in this zone) and the linear zone could be
            %growing at 25% Light Intensity on average (therefore 25% of
            %full growth due to linear relationship)in 30 % of the reactor. the linear
            %growth factor is therefore 0.25*0.3 = 0.075. The overall light
            %growth factor is therefore 0.5+0.075 = 0.575.The reactor is
            %running at 57.7% of its theoretical capability.
            
            this.rPARRelativeGrowth = this.rSaturatedGrowthFactor + this.rLinearGrowthFactor;
            
            %PAR Rel Growth value sometimes becomes slightly larger than 1
            %(typically at 4th decimal point, so really not much), set to
            %1.
            if this.rPARRelativeGrowth > 1 
                this.rPARRelativeGrowth = 1;
            end
            
            %pass relative growth factor back to calling growth rate
            %calculation module
            rPARRelativeGrowth = this.rPARRelativeGrowth;

        end
        
        
    end
end
