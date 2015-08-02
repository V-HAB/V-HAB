%classdef Valve < solver.basic.matter.procs.f2f & solver.matter.linear.procs.f2f
classdef valve_closable < matter.procs.f2f
    %Valve Summary of this class goes here
    %   Detailed explanation goes here
    %
    %NOTE
    %   - from HaRo - haro.components.Valve
    %   - only works with the iterative solver

    
    properties (SetAccess = protected, GetAccess = public)
        % Valve open or closed?
        bOpen = true;
        
        fFlowCoefficient = 1;
    end
    
%     properties (SetAccess = protected, GetAccess = public)
%         fHydrDiam;
%         fHydrLength;
%         fHydrcoef;
%         bActive = false;
%         fDeltaTemp = 0;
%     end    
    methods
        function  this = valve_closable(oMT, sName, fFlowCoefficient)
            this@matter.procs.f2f(oMT, sName);
            
            this.fFlowCoefficient   = fFlowCoefficient;
            
            this.supportSolver('callback',  @this.solverDeltas);
            this.supportSolver('manual', false);
        end
        
        function fDeltaPress = solverDeltas(this, fFlowRate)
            
            if (fFlowRate == 0)
                fDeltaPress = 0;
                this.fDeltaPressure = fDeltaPress;
                return;
            end
            
            
            if this.bOpen == 0
                fDeltaPress = Inf;
                return;
            end
            
            
            % Get in/out flow object references
            [ oFlowIn, oFlowOut ] = this.getFlows(fFlowRate);
            
            % Average pressure in Pa
            fP = (oFlowIn.fPressure + oFlowOut.fPressure) / 2;
            
            % No pressure at all ... normally just return, drop zero
            if fP == 0
                fDeltaPress = 0;
                return;
            end
            
            % Calculate density in kg/m^3 and flow rate in SLM
            fRoh = (fP * oFlowIn.fMolMass / 1000) / (matter.table.Const.fUniversalGas * oFlowIn.fTemp);
            fFlowRate = fFlowRate * 60; % Convert to kg/min
            fSLM = (fFlowRate / (oFlowIn.fMolMass / 1000) * ...
                   matter.table.Const.fUniversalGas * oFlowIn.fTemp / oFlowIn.fPressure) * 1000;

               
            % Calculate Pressure Difference in   
            if this.fFlowCoefficient == 0
                fDeltaPress = 0;
            else
                fDeltaPress =  fSLM^2 / (fRoh * this.fFlowCoefficient^2);
            end
            
            %this.fDeltaPressure = fDeltaPress;
        end
        
        
        function setOpen(this, bOpen)
            this.bOpen = ~~bOpen;
            
            % Set branch outdated - needs to recalculate flows!
            this.oBranch.setOutdated();
        end   
    end
    
end
