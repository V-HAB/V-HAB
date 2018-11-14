classdef boundary < matter.phase
    %% boundary
    % A phase that is modelled as containing an infinite amount of matter
    % with specifiable (and changeable) values for the composition and
    % temperature. The intended use case is e.g. to model vacuum in space
    % and environmental conditions in test cases
    
    properties (SetAccess = protected, GetAccess = public)
        afMassChange;
    end
    
    methods
        function this = boundary(oStore, sName, varargin)
            this@matter.phase(oStore, sName, varargin{1}, varargin{2});
            
            this.fVolume = inf;
            
            % Mass change must be zero for flow nodes, if that is not the
            % case, this enforces V-HAB to make a minimum size time step to
            % keep the error small
            tTimeStepProperties.rMaxChange = inf;
            this.setTimeStepProperties(tTimeStepProperties)
            
            this.afMassChange = zeros(1,this.oMT.iSubstances);
            
            % Set flags to identify this as boundary phase
            this.bBoundary      = true;
        end
        
        function setVolume(~, ~)
            % Must be here because the store tries to overwrite the volume,
            % but for flow_nodes we want the small volumes and the volume
            % is not relevant for the calculations anyway
        end
        %% Setting of boundary phase properties
        function setBoundaryProperties(this, tProperties)
            % using this function the user can set the properties of the
            % boundary phase. Currently the following properties can be
            % set:
            %
            % afMass:       partial mass composition of the phase
            % fPressure:    Total pressure, from which the partial
            %               pressures of the boundary are calculated based
            %               on afMass
            % afPP:         partial pressure composition of the phase (if
            %               afMass is not provided)
            % fTemperature: Temperature of the boundary
            %
            % In order to define these provide a struct with the fieldnames
            % as described here to this function for the values that you
            % want to set
            
            % Since the pressure calculation require the temperature, we
            % first set the temperature if it was provided
            if isfield(tProperties, 'fTemperature')
                this.oCapacity.setBoundaryTemperature(tProperties.fTemperature);
            end
            
            % In case afMass is used we calculate the partial pressures
            if isfield(tProperties, 'afMass')
                if isfield(tProperties, 'fPressure')
                    this.fPressure = tProperties.fPressure;
                end
                
                this.afMass = tProperties.afMass;
                
                % Now we calculate the molar mass fractions, since these
                % represent the partial pressure fractions as well
                afMols = this.afMass .* this.oMT.afMolarMass;
                arMolFractions = afMols/sum(afMols);
                % And then set the correct partial pressure composition for
                % the phase (TO DO: move to gas boundary child class)
                this.afPP = this.fPressure .* arMolFractions;
                
            % Since elseif is used afPP is ignored if afMass is provided
            elseif isfield(tProperties, 'afPP')
                % if the partial pressures are provided the mass
                % composition is calculated
                this.fPressure = sum(tProperties.afPP);
                this.afPP = tProperties.afPP;
                
                arMolFractions = this.afPP ./ sum(this.afPP);
                this.afMass = arMolFractions ./ this.afMolarMass;
            end 
        end
    end
    
    methods  (Access = protected)
        function massupdate(this, varargin)
            % The massupdate for boundary phases only stores what was
            % taken/added over the time of the simulation. It does not
            % change the current composition of the phase
            fTime     = this.oTimer.fTime;
            fLastStep = fTime - this.fLastMassUpdate;
            
            % Return if no time has passed
            if fLastStep == 0
                return;
            end
            
            if ~base.oLog.bOff, this.out(tools.logger.INFO, 1, 'exec', 'Execute massupdate in %s-%s-%s', { this.oStore.oContainer.sName, this.oStore.sName, this.sName }); end

            % Immediately set fLastMassUpdate, so if there's a recursive call
            % to massupdate, e.g. by a p2ps.flow, nothing happens!
            this.fLastMassUpdate     = fTime;
            this.fMassUpdateTimeStep = fLastStep;
            
            % All in-/outflows in [kg/s] and multiply with curernt time
            % step, also get the inflow rates / temperature / heat capacity
            %SPEED OPT - value saved in last calculateTimeStep, still valid
            %[ afTotalInOuts, mfInflowDetails ] = this.getTotalMassChange();
            afTotalInOuts = this.afCurrentTotalInOuts;
            
            if ~base.oLog.bOff, this.out(1, 2, 'total-fr', 'Total flow rate in %s-%s: %.20f', { this.oStore.sName, this.sName, sum(afTotalInOuts) }); end
            
            % Check manipulator
            if ~isempty(this.toManips.substance) && ~isempty(this.toManips.substance.afPartialFlows)
                % Add the changes from the manipulator to the total inouts
                afTotalInOuts = afTotalInOuts + this.toManips.substance.afPartialFlows;
                
                if ~base.oLog.bOff, this.out(tools.logger.MESSAGE, 1, 'manip-substance', 'Has substance manipulator'); end % directly follows message above, so don't output name
            end
            
            % Cache total mass in/out so the EXMEs can use that
            this.fCurrentTotalMassInOut = sum(afTotalInOuts);
            
            % Multiply with current time step
            afTotalInOuts = afTotalInOuts * fLastStep;
            
            % Contrary to the normal phase massupdate we only store the
            % changes in the afMassChange property as this phase models an
            % infinitly large boundary
            this.afMassChange = this.afMassChange + afTotalInOuts;
            
            this.setBranchesOutdated();
        end
    end
end