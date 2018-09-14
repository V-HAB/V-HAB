classdef fluidic < thermal.procs.conductor
    %FLUIDIC A fluidic conductor transporting heat to downstream node
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity = 0; % Thermal conductivity of connection in [W/K].
        
        oMassBranch;
        
        bRadiative  = false;
        bConvective = false;
        bConductive = false;
    end
    
    methods
        
        function this = fluidic(oContainer, sName, oMassBranch)
            % Create a fluidic conductor instance
             
            this@thermal.procs.conductor(oContainer, sName);
            
            this.oMassBranch = oMassBranch;
            
            
        end
        
        function fConductivity = update(this, ~)
            
            if this.oMassBranch.fFlowRate >= 0
                iExme = 1;
            else
                iExme = 2;
            end
                
            fSpecificHeatCapacity = this.oThermalBranch.coExmes{iExme}.oCapacity.fSpecificHeatCapacity;
            this.fConductivity = abs(this.oMassBranch.fFlowRate * fSpecificHeatCapacity);
            
            fConductivity = this.fConductivity;
        end
        
        
        function updateConnectedMatterBranch(this, oMassBranch)
            this.oMassBranch = oMassBranch;
        end
            
    end
    
end

