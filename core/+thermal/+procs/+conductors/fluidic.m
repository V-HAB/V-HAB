classdef fluidic < thermal.procs.conductor
    %FLUIDIC A fluidic conductor transporting heat to downstream node
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        
        fResistance = 0; % Thermal resistance of connection in [K/W].
        
        oMassBranch;
    end
    
    methods
        
        function this = fluidic(oContainer, sName, oMassBranch)
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            this.oMassBranch = oMassBranch;
            
            
        end
        
        function fResistance = update(this, ~)
            
            if this.oMassBranch.fFlowRate >= 0
                iExme = 1;
            else
                iExme = 2;
            end
                
            fSpecificHeatCapacity = this.oThermalBranch.coExmes{iExme}.oCapacity.fSpecificHeatCapacity;
            fResistance = 1 / abs(this.oMassBranch.fFlowRate * fSpecificHeatCapacity);
            
            this.fResistance = fResistance;
            
            this.out(1,1,'Flow Rate: %i [kg/s], Heat Capactiy: %i [J/(kgK)]', {this.oMassBranch.fFlowRate, fSpecificHeatCapacity});
        end
        
        
        function updateConnectedMatterBranch(this, oMassBranch)
            this.oMassBranch = oMassBranch;
        end
            
    end
    
end

