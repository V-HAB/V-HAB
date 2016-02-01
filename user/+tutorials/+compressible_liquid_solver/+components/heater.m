classdef heater < matter.procs.f2f
    %Heater: static heater model
    % the value fTemp is the temperature up to which the heater is capable
    % to heat the fluid
    
    properties
        fDeltaPressure = 0;      % Pressure difference created by the heater in Pa
        
        iDir = 0;            % Direction of flow
        
        fTempMax = 0;
        
        fRoughness = 0;
        
       
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fDiameter = 0.5;        % Hydraulic diameter
        fLength = 1;            % Hydraulic Length
        fDeltaTemp = 0;         % temperature difference created by the heater in K
        bActive = true;         % Must be true so the update function is called from the branch solver
    end
    
    methods
        function this = heater(oContainer, sName, fTemperature, fDiameter, fLength, fRoughness)
            this@matter.procs.f2f(oContainer, sName);
                        
            this.fTempMax = fTemperature;
            if nargin == 4
                this.fDiameter = fDiameter;
            elseif nargin == 5
                this.fLength = fLength;
                this.fDiameter = fDiameter;
            elseif nargin == 6
                this.fLength = fLength;
                this.fDiameter = fDiameter;
                this.fRoughness = fRoughness;
            end
            this.supportSolver('hydraulic', fDiameter, fLength);

        end
        
        function update(this)
            
            bZeroFlows = 0;
            for k = 1:length(this.aoFlows)
                if this.aoFlows(1,k).fFlowRate == 0
                   bZeroFlows = 1; 
                end
            end
            if bZeroFlows == 1
                this.fDeltaTemp = 0;
            else
                [ oInFlow, ~ ]      = this.getFlows();
                
                this.fDeltaTemp     = this.fTempMax - oInFlow.fTemperature;
                
                this.fHeatFlow      = oInFlow.fSpecificHeatCapacity * oInFlow.fFlowRate * this.fDeltaTemp;
                
                fDensity            = this.oMT.calculateDensity(oInFlow);
                fDynamicViscosity   = this.oMT.calculateDynamicViscosity(oInFlow);

                fFlowSpeed          = oInFlow.fFlowRate/(fDensity*pi*0.25*this.fDiameter^2);

                this.fDeltaPressure = pressure_loss_pipe (this.fDiameter, this.fLength,...
                                fFlowSpeed, fDynamicViscosity, fDensity, this.fRoughness, 0);
                            
                fDeltaPress = this.fDeltaPressure;
            end
            
            
        end
        
    end
    
end

