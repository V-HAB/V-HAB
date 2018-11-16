classdef (Abstract) boundary < matter.phase
    %% boundary
    % A phase that is modelled as containing an infinite amount of matter
    % with specifiable (and changeable) values for the composition and
    % temperature. The intended use case is e.g. to model vacuum in space
    % and environmental conditions in test cases
    
    properties (SetAccess = protected, GetAccess = public)
        
        % Property to store the total mass exchange of the boundary with
        % other systems. Positive values represent mass that flowed into
        % the boundary, negative values represent mass that flowed out of
        % the boundary. All values in kg
        afMassChange;
        
        % Volume in m^3
        fVolume;       
        
    end
    
    methods
        function this = boundary(oStore, sName, varargin)
            this@matter.phase(oStore, sName, varargin{1}, varargin{2}, 'boundary');
            
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
            % but for flow nodes we want the small volumes and the volume
            % is not relevant for the calculations anyway
        end
        
    end
    
    %% Setting of boundary phase properties
    methods (Abstract = true)
        setBoundaryProperties(this)
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
            
            % Phase sets new time step (registered with parent store, used
            % for all phases of that store)
            this.setOutdatedTS();
        end
    end
end