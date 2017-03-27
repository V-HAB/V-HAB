classdef flow < matter.flow
    
    methods
    function this = flow(oBranch)
        this@matter.flow(oBranch);
    end
    function setMatterPropertiesBranch(this, afFlowRates)
        
        fFlowRate     = sum(afFlowRates);
        
        if fFlowRate == 0
            arPartialMass = zeros(1,this.oMT.iSubstances);
        else
            arPartialMass = afFlowRates/fFlowRate;
        end

        %CHECK see setData, using the IN exme props!
        if this.fFlowRate >= 0
            oPhase = this.oIn.oPhase;
        else
            oPhase = this.oOut.oPhase;
        end
        
        fTemperature   = oPhase.fTemperature;
        fPressure      = oPhase.fPressure;
        
        this.setMatterProperties(fFlowRate, arPartialMass, fTemperature,fPressure);
    end
    end
    methods (Access = protected)
    function setData(~,~,~,~)
        % overwritten setData function, flow values are set otherwise
        
    end
    end
end

