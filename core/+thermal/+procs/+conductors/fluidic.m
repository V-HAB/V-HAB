classdef fluidic < thermal.procs.conductor
    %FLUIDIC A fluidic conductor modelling the mass bound heat transfer
    
    properties (SetAccess = protected)
        % Thermal resistance of connection
        fResistance = 0; % [K/W].
        
        % Reference to the mass branch whose thermal energy transport
        % should be modelled
        oMassBranch;
    end
    
    methods
        
        function this = fluidic(oContainer, sName, oMassBranch)
            % Create a fluidic conductor to model the thermal energy
            % transport asscociated with mass transfer. Required inputs
            % are:
            % oContainer:       The system in which the conductor is placed
            % sName:            A name for the conductor which is not
            %                   shared by other conductors within oContainer
            % oMassBranch:      The matter branch which models the mass flow
            
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            this.oMassBranch = oMassBranch;
            
            % we do not bind the matter branch update to this conductor,
            % because the solver handles this as it is necessary in any
            % case and adding additional triggers would slow down the
            % simulation
        end
        
        function fResistance = update(this, ~)
            % Update the thermal resistance of this conductor
            
            % get the correct exme for the current flow rate
            if this.oMassBranch.fFlowRate >= 0
                iExme = 1;
            else
                iExme = 2;
            end
                
            % get specific heat capacity of the corresponding phase (we use
            % the phase so that we do not have to calculate the specific
            % heat capacity of the flow individually which would take time
            fSpecificHeatCapacity = this.oThermalBranch.coExmes{iExme}.oCapacity.fSpecificHeatCapacity;
            
            % flowrate in kg/s * J / (kg K) = W/K --> inverse = K/W
            fResistance = 1 / abs(this.oMassBranch.fFlowRate * fSpecificHeatCapacity);
            
            this.fResistance = fResistance;
            
            if ~base.oDebug.bOff
                this.out(1,1,'Flow Rate: %i [kg/s], Heat Capactiy: %i [J/(kgK)]', {this.oMassBranch.fFlowRate, fSpecificHeatCapacity});
            end
        end
        
        function updateConnectedMatterBranch(this, oMassBranch)
            this.oMassBranch = oMassBranch;
        end
    end
end