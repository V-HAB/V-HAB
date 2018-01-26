classdef fluidic < thermal.procs.conductor
    %FLUIDIC A fluidic conductor transporting heat to downstream node
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fConductivity = 0; % Thermal conductivity of connection in [W/K].
        
        oMassBranch;
    end
    
    methods
        
        function this = fluidic(oContainer, sName, oMassBranch)
            % Create a fluidic conductor instance
             
            this@thermal.procs.conductor(oContainer, sName);
            
            this.oMassBranch = oMassBranch;
        end
        
        function fConductivity = update(this, ~)
            
            % TO DO: if we allow heat capacity changes inside a branch, we
            % have to decide how to close the energy balance for that case
            % (as thermal branches, like mass branches, do not contain
            % "thermal mass" this is in the current logic difficult and
            % would require us to allow branches to contain mass or in this
            % case energy)
            if this.oMassBranch.fFlowRate >= 0
                iExme = 1;
            else
                iExme = 2;
            end
                
            fSpecificHeatCapacity = this.oThermalBranch.coExmes{iExme}.oCapacity.fSpecificHeatCapacity;
            this.fConductivity = this.oMassBranch.fFlowRate * fSpecificHeatCapacity;
            
            fConductivity = this.fConductivity;
        end
    end
    
end

