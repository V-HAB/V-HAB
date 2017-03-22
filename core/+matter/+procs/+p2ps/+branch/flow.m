classdef flow < matter.flow
    properties (SetAccess = protected)
        txSetDataValues;
    end
    methods
    function this = flow(oBranch)
        this@matter.flow(oBranch);
        
        this.txSetDataValues.fFlowRate      = 0;
        this.txSetDataValues.arPartialMass  = zeros(1,this.oMT.iSubstances);
        this.txSetDataValues.fTemperature   = 293;
        this.txSetDataValues.fPressure      = 1e5;
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
        
        this.txSetDataValues.fFlowRate      = fFlowRate;
        this.txSetDataValues.arPartialMass  = arPartialMass;
        this.txSetDataValues.fTemperature   = oPhase.fTemperature;
        this.txSetDataValues.fPressure      = oPhase.fPressure;
    end
    end
    methods (Access = protected)
    function setData(this,~,~,~)
        % overwritten setData function, flow values are set otherwise
        
        this.setMatterProperties(this.txSetDataValues.fFlowRate, this.txSetDataValues.arPartialMass,...
            this.txSetDataValues.fTemperature, this.txSetDataValues.fPressure);

    end
    end
end

