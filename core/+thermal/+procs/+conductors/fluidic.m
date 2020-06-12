classdef fluidic < thermal.procs.conductor
    %FLUIDIC A fluidic conductor modelling the mass bound heat transfer
    
    properties (SetAccess = protected)
        % Thermal resistance of connection
        fResistance = 0; % [K/W].
        
        % Specific heat capacity of the matter flow through the matter
        % processor associated with this conductor.
        fSpecificHeatCapacity;
        
        % Reference to the matter object whose thermal energy transport
        % should be modelled
        oMatterObject;
        
        % Reference to the f2f processor associated with this conductor, if
        % it exists. Matter branches without processors are possible when
        % using the manual solver.
        oMatterProcessor;
        
        % A boolean indicating if there is a matter processor associated
        % with this conductor or not. 
        bNoMatterProcessor;
        
        % The following three properties capture the pressure, temperature
        % and partial mass state of the flow through this phase. This is done
        % in an effort to reduce the calls to calculateSpecificHeatCapacity
        % in the matter table. See setMatterProperties() for details.
        fPressureLastHeatCapacityUpdate;
        fTemperatureLastHeatCapacityUpdate;
        arPartialMassLastHeatCapacityUpdate;
    end
    
    methods
        
        function this = fluidic(oContainer, sName, oMatterObject)
            % Create a fluidic conductor to model the thermal energy
            % transport asscociated with mass transfer. Required inputs
            % are:
            % oContainer:       The system in which the conductor is placed
            % sName:            A name for the conductor which is not
            %                   shared by other conductors within oContainer
            % oMatterObject:    The matter object which models the mass
            %                   flow, can either be a matter branch or a
            %                   P2P processor.
            
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            % Setting the reference to the matter object.
            this.oMatterObject = oMatterObject;
            
            % If the oMatterObject is actually a branch and not a P2P, we
            % try to find the F2F processor associated with this conductor.
            if strcmp(oMatterObject.sObjectType, 'branch')
                % Since it is possible to have matter branches without F2F
                % processors, we check for that first.
                if ~isempty(this.oMatterObject.aoFlowProcs)
                    % Getting all processor names
                    csProcessorNames = {this.oMatterObject.aoFlowProcs.sName};
                    
                    % Finding the processor that belongs to this conductor
                    this.oMatterProcessor = oMatterObject.aoFlowProcs(strcmp(sName, csProcessorNames));
                    
                    % Setting the boolean indicating we don't have a
                    % processor to false.
                    this.bNoMatterProcessor = false;
                else
                    % There is no F2F processor in the branch, so this
                    % conductor models the entire branch.
                    this.bNoMatterProcessor = true;
                end
            end
            
            % We do not bind the matter branch update to this conductor,
            % because the solver handles this as it is necessary in any
            % case and adding additional triggers would slow down the
            % simulation
        end
        
        function fResistance = update(this, ~)
            % Update the thermal resistance of this conductor
            
            if this.oMatterObject.fFlowRate == 0
                fResistance = Inf;
                return;
            end
            
            % We need the specific heat capacity of the the matter flowing
            % through this conductor. If it is a P2P processor, we can take
            % its specific heat capacity directly because it is updated
            % during the call to setMatterProperties(). Otherwise we take
            % the value from the matter flow into the matter object that
            % this conductor models, either an entire branch or an
            % individual F2F processor.
            if this.oThermalBranch.oHandler.bP2P
                this.fSpecificHeatCapacity = this.oMatterObject.fSpecificHeatCapacity;
            else
                % First we need to check if there is an F2F processor
                % associated with this conductor.
                if this.bNoMatterProcessor
                    % There is no F2F processor associated with this
                    % conductor, so we want to use the properties of the
                    % flow at the end of this branch, which depends on the
                    % flow rate.
                    if this.oMatterObject.fFlowRate >= 0
                        iFlowIndex = this.oMatterObject.iFlows;
                    else
                        iFlowIndex = 1;
                    end
                    
                    oFlow = this.oMatterObject.aoFlows(iFlowIndex);
                    
                else
                    % There IS an F2F processor associated with this
                    % conductor, so we look at the flow rate to find out
                    % which one of its flows we should use.
                    if this.oMatterObject.fFlowRate > 0
                        iFlowIndex = 1;
                    else
                        iFlowIndex = 2;
                    end
                    
                    oFlow = this.oMatterProcessor.aoFlows(iFlowIndex);
                end
                
                % In order to improve performance, we only recalculate the
                % specific heat capacity if either the pressure, the
                % temperature or the composition of the flow or any
                % combination of these parameters have changed since the
                % last recalculation. 
                if isempty(this.fPressureLastHeatCapacityUpdate) ||...
                        (abs(this.fPressureLastHeatCapacityUpdate - oFlow.fPressure) > 100) ||...
                        (abs(this.fTemperatureLastHeatCapacityUpdate - oFlow.fTemperature) > 1) ||...
                        (max(abs(this.arPartialMassLastHeatCapacityUpdate - oFlow.arPartialMass)) > 0.01)
                    
                    % Recalculating the specific heat capacity
                    this.fSpecificHeatCapacity = this.oMT.calculateSpecificHeatCapacity(oFlow);
                    
                    % Setting the properties for the next check
                    this.fPressureLastHeatCapacityUpdate     = oFlow.fPressure;
                    this.fTemperatureLastHeatCapacityUpdate  = oFlow.fTemperature;
                    this.arPartialMassLastHeatCapacityUpdate = oFlow.arPartialMass;
                end
            end
            
            % Flow rate in kg/s * J / (kg K) = W/K --> inverse = K/W
            fResistance = 1 / abs(this.oMatterObject.fFlowRate * this.fSpecificHeatCapacity);
            
            % Storing the current value in a property for logging and
            % debugging purposes.
            this.fResistance = fResistance;
            
            if ~base.oDebug.bOff
                this.out(1,1,'Flow Rate: %i [kg/s], Heat Capactiy: %i [J/(kgK)]', {this.oMatterObject.fFlowRate, this.fSpecificHeatCapacity});
            end
        end
        
        function updateConnectedMatterBranch(this, oMassBranch)
            this.oMatterObject = oMassBranch;
        end
    end
end