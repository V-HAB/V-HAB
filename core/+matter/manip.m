classdef (Abstract) manip < base & event.source
    %MANIP Basic manipulator class
    %   All manips in manips.[x].[y] use this as a base class. The type in
    %   the manip package path (x) defines the attribute of the phase that
    %   is changed:
    %       matter.manips.temperature.xyz can manipulate fTemperature in .update()
    %       matter.manips.volume.gas.xyz can for example calcualte the work
    %                           that was required for the vol change and 
    %                           the change in temperature within the gas,
    %                           would be called in setVolume
    %       matter.manips.substances.xyz can change partial masses in a phase
    %                           within the .massupdate method
    
    properties (SetAccess = private, GetAccess = public)
        % Handle of the phase object this manipulator is attached to
        oPhase;
        
        % Name of the manipulators
        sName;
        
        % Required sType of oPhase, empty if no restriction
        sRequiredType;
        
        % Reference to the matter table
        oMT;
        
        % Reference to the timer
        oTimer;
        
        hBindPostTickUpdate;
        
        bAttached;
    end
    
    properties (SetAccess = private, GetAccess = private)
        % Function handle to detach the manipulator from the phase
        hDetach;
    end
    
    methods
        function this = manip(sName, oPhase, sRequiredType)
            if nargin >= 3, this.sRequiredType = sRequiredType; end
            
            % Setting the properties
            this.sName   = sName;
            this.oMT     = oPhase.oMT;
            this.oTimer  = oPhase.oTimer;
            
            % "re"attaching the manipulator and the phase. This is a
            % general function which would also allow us to reattach the
            % manipulator after it has been detached from its phase
            this.reattachManip(oPhase);
            
            this.hBindPostTickUpdate = this.oTimer.registerPostTick(@this.update, 'matter', 'manips');
        end
        
        function detachManip(this)
            % Function to deatach the manipulator from its phase. The
            % manipulator still exists but is no longer connected to the
            % phase and cannot be updated. The now defunct manip can then
            % be reattached to a different phase by using the reattachManip
            % function.
            % Note that any event callbacks that the manipulator had
            % registered before will be unbound (deleted)! If you want to
            % keep any of them you must rebind these after reattaching the
            % manipulator!
            if ~isempty(this.oPhase)
                % If the manipulator had registered events all of these are
                % unbound (deleted). If any of the events should still be
                % valid they must be readded after reattaching the manip.
                % However, if a callback remained that triggers a
                % calculation within the P2P it would most likely crash
                % after detaching the manip
                if this.bHasCallbacks
                    this.unbindAllEvents();
                end
                
                this.hDetach();
                this.hDetach = [];
                this.oPhase = [];
                this.bAttached = false;
            end
        end
        
        function reattachManip(this, oPhase)
            % Function to reattach the manip to a phase after it has been
            % detached or on its initialization. 
            % Necessary input parameters are:
            % oPhase:   a phase object which fullfills the required phase
            %           condition of the manip specified in the
            %           sRequiredType property.
            
            % Check if the manipulator is not still attached to a phase
            if ~isempty(this.oPhase)
                error('the manipulator %s which is supposed to be reattached to phase %s is still connected to phase %s. Use the detachManip function first to seperate the manip from its phase!', this.sName, oPhase.sName, this.oPhase.sName)
            else
                % If a certain type of phase type is required for this
                % manipulator, we check for it here and throw an error if
                % there is a mismatch.
                if ~isempty(this.sRequiredType)
                    % for mixture we do not check the sType property but
                    % the sPhaseType property
                    if strcmp(oPhase.sType, 'mixture')
                        sCompareField = 'sPhaseType';
                    else
                        sCompareField = 'sType';
                    end
                    if ~strcmp(oPhase.(sCompareField), this.sRequiredType)
                        this.throw('manip', 'Provided phase (name %s, store %s) is not a %s!', oPhase.sName, oPhase.oStore.sName, this.sRequiredType);
                    end
                end
                % use the addManipulator function of the phase, so that we
                % do not have to use two function calles to reattach a
                % manipulator.
                this.oPhase = oPhase;
                this.hDetach = this.oPhase.addManipulator(this);
                this.bAttached = true;
            end
        end
        
        function registerUpdate(this)
            % we only register update for manipulators that are currently
            % connected to a phase
            if this.bAttached
                this.hBindPostTickUpdate();
            end
        end
    end
    
    methods (Abstract = true)
        % Every child class must implement this function with the
        % corresponding calculation to set the according flow rates
        update(this)
    end
    
    methods (Access = protected)
        function fTimeStep = getTimeStep(this)
            fTimeStep = this.oPhase.fMassUpdateTimeStep;
        end
        
        function afFlowRates = getTotalFlowRates(this)
            % Get all inwards and the stored partial masses as total kg/s
            % values.
            
            [ afFlowRates, mrInPartials ] = this.getInFlows();
            
            
            if ~isempty(afFlowRates)
                afFlowRates = sum(bsxfun(@times, afFlowRates, mrInPartials), 1);
            else
                afFlowRates = zeros(1, this.oMT.iSubstances);
            end
        end
        
        function [ afInFlowrates, mrInPartials ] = getInFlows(this)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow.
            % Adds the local mass by division by curr time step.
            
            % Getting the number of EXMEs for better legibility and a very
            % minor code performance improvement.
            iNumberOfEXMEs = this.oPhase.iProcsEXME;
            
            % Initializing temporary matrix and array to save the per-exme
            % data. 
            mrInPartials  = zeros(iNumberOfEXMEs, this.oMT.iSubstances);
            afInFlowrates = zeros(iNumberOfEXMEs, 1);
            
            % Creating an array to log which of the flows are not in-flows
            abOutFlows = true(iNumberOfEXMEs, 1);
            
            % See phase.getTotalMassChange
            for iI = 1:this.oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, ~ ] = this.oPhase.coProcsEXME{iI}.getFlowData();
                
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials(iI,:) = mrFlowPartials(abInf, :);
                    afInFlowrates(iI)  = afFlowRates(abInf);
                    abOutFlows(iI)     = false;
                end
            end
            
            % Now we delete all of the rows in the mrInPartials matrix
            % that belong to out-flows.
            if any(abOutFlows)
                mrInPartials(abOutFlows,:)  = [];
                afInFlowrates(abOutFlows,:) = [];
            end
        end
    end
end