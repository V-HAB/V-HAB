classdef manip < base
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
    end
    
    properties (SetAccess = private, GetAccess = private)
        % Function handle to detach the manipulator from the phase
        hDetach;
    end
    
    methods
        function this = manip(sName, oPhase, sRequiredType)
            if nargin >= 3, this.sRequiredType = sRequiredType; end
            
            % If a certain type of phase type is required for this
            % manipulator, we check for it here and throw an error if there
            % is a mismatch.
            if ~isempty(this.sRequiredType)
                if isa(oPhase, [ 'matter.phases.' this.sRequiredType ])
                    this.throw('manip', 'Provided phase (name %s, store %s) is not a "matter.phases.%s"!', oPhase.sName, oPhase.oStore.sName, this.sRequiredType);
                end
            end
            
            % Setting the properties
            this.sName   = sName;
            this.oPhase  = oPhase;
            this.oMT     = oPhase.oMT;
            this.oTimer  = oPhase.oTimer;
            
            % Adding the manipulator to the phase, returns a handle to the
            % detachManipulator() method.
            this.hDetach = this.oPhase.addManipulator(this);
            
            this.hBindPostTickUpdate      = this.oTimer.registerPostTick(@this.update,      'matter' , 'manips');
        end
        
        function delete(this)
            % Function to remove the manipulator from its phase
            if isvalid(this.oPhase)
                this.hDetach();
                this.hDetach = [];
            end
        end
        
        function bindUpdate(this)
            this.hBindPostTickUpdate();
        end
    end
    
    methods (Abstract = true)
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

