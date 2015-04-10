classdef manip < base
    %MANIP Basic manipulator class
    %   All manips in manips.[x].[y] use this as a base class. The type in
    %   the manip package path (x) defines the attribute of the phase that
    %   is changed:
    %       matter.manips.temps.xyz can manipulate fTemp in .update()
    %       matter.manips.vols.gas.xyz can for example calcualte the work
    %                           that was required for the vol change and 
    %                           the change in temperature within the gas,
    %                           would be called in setVolume
    %       matter.manips.partials.xyz can change partial masses in a phase
    %                           within the .massupdate method
    %
    %TODO when to use getInFlows, when to use getMasses? If getMasses is
    %     used, the .updateAbsolute() should probably be used for setting.
    %     Define some isStationary, compare masses vs. inFRs * timestep
    %     => if inFRs*TS > 0.1 * masses ...?
    %     => just always use masses?
    
    properties (SetAccess = private, GetAccess = public)
        oPhase;
        
        sName;
        
        % Required sType of oPhase, empty if no restriction
        sRequiredType;
    end
    
    properties (SetAccess = private, GetAccess = private)
        % Function handle to detach the manipulator from the phase
        hDetach;
    end
    
    methods
        function this = manip(sName, oPhase, sRequiredType)
            if nargin >= 3, this.sRequiredType = sRequiredType; end;
            
            if ~isempty(this.sRequiredType)
                if isa(oPhase, [ 'matter.phases.' this.sRequiredType ])
                    this.throw('manip', 'Provided phase (name %s, store %s) is not a "matter.phases.%s"!', oPhase.sName, oPhase.oStore.sName, this.sRequiredType);
                end
            end
            
            this.sName   = sName;
            this.oPhase  = oPhase;
            this.hDetach = this.oPhase.addManipulator(this);
        end
        
        function delete(this)
            if isvalid(this.oPhase)
                this.hDetach();
                this.hDetach = [];
            end
        end
    end
    
    methods (Abstract = true)
        update(this)
    end
    
    
    methods (Access = protected)
        function fTimeStep = getTimeStep(this)
            fTimeStep = this.oPhase.fMassUpdateTimeStep;%oStore.oTimer.fTime - this.oPhase.fLastMassUpdate;
        end
        
        
        
        
        
        
        function [ afInFlowrates, mrInPartials ] = getInFlows(this)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow.
            % Adds the local mass by division by curr time step.
            
            
            %CHECK store on obj var, as long as the amount of inflows
            %      doesn't change -> kind of preallocated?
            mrInPartials  = zeros(0, this.oPhase.oMT.iSubstances);
            afInFlowrates = [];
            
            % See phase.getTotalMassChange
            for iI = 1:this.oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, ~ ] = this.oPhase.coProcsEXME{iI}.getFlowData();
                
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials  = [ mrInPartials;  mrFlowPartials(abInf, :) ];
                    afInFlowrates = [ afInFlowrates; afFlowRates(abInf) ];
                end
            end
            
            % 
            fTimeStep = this.getTimeStep();
            
            if fTimeStep > 0
                %CHECK deactivated for now .... e.g. weird for partials
                %manip.
                mrInPartials  = [ mrInPartials;  this.oPhase.arPartialMass ];
                %CHECK does that make sense? Treat the stored mass as a flow?
                afInFlowrates = [ afInFlowrates; this.oPhase.fMass / 1 ]; %fTimeStep ];
            end
        end
        
        function [ afInMasses, mrInPartials ] = getMasses(this)
            % Return vector with all INWARD flow rates and matrix with 
            % partial masses of each in flow MULTIPLIED with current time
            % step so the become absolute masses. Then the currently stored
            % mass is added!
            
            % Get last time step
            fTimeStep = this.getTimeStep();
            
            
            %CHECK store on obj var, as long as the amount of inflows
            %      doesn't change -> kind of preallocated?
            mrInPartials  = zeros(0, this.oPhase.oMT.iSubstances);
            afInMasses = [];
            
            % See phase.getTotalMassChange
            for iI = 1:this.oPhase.iProcsEXME
                [ afFlowRates, mrFlowPartials, ~ ] = this.oPhase.coProcsEXME{iI}.getFlowData();
                
                % Inflowing?
                abInf = (afFlowRates > 0);
                
                if any(abInf)
                    mrInPartials  = [ mrInPartials;  mrFlowPartials(abInf, :) ];
                    afInMasses = [ afInMasses; afFlowRates(1, abInf) ];
                end
            end
            
            mrInPartials  = [ mrInPartials;  this.oPhase.arPartialMass ];
            afInMasses = [ afInMasses * fTimeStep; this.oPhase.fMass ];
        end
    end
end
